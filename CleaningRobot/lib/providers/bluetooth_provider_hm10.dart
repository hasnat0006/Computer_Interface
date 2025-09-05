import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

class BluetoothProvider extends ChangeNotifier {
  BluetoothDevice? _connectedDevice;
  BluetoothConnectionState _connectionState =
      BluetoothConnectionState.disconnected;
  List<BluetoothDevice> _pairedDevices = [];
  List<BluetoothDevice> _scanResults = [];
  bool _isBluetoothEnabled = false;
  bool _isScanning = false;
  String? _errorMessage;
  BluetoothCharacteristic? _writeCharacteristic;
  BluetoothCharacteristic? _readCharacteristic;
  StreamSubscription<BluetoothAdapterState>? _adapterStateSubscription;
  StreamSubscription<BluetoothConnectionState>? _connectionStateSubscription;
  StreamSubscription<List<int>>? _characteristicSubscription;

  // HM-10 BLE Service and Characteristic UUIDs
  static const String hm10ServiceUuid = "0000FFE0-0000-1000-8000-00805F9B34FB";
  static const String hm10CharacteristicUuid =
      "0000FFE1-0000-1000-8000-00805F9B34FB";

  // Getters
  BluetoothDevice? get connectedDevice => _connectedDevice;
  BluetoothConnectionState get connectionState => _connectionState;
  List<BluetoothDevice> get pairedDevices => _pairedDevices;
  List<BluetoothDevice> get scanResults => _scanResults;
  bool get isBluetoothEnabled => _isBluetoothEnabled;
  bool get isScanning => _isScanning;
  String? get errorMessage => _errorMessage;
  bool get isConnected =>
      _connectionState == BluetoothConnectionState.connected;

  BluetoothProvider() {
    _initialize();
  }

  Future<void> _initialize() async {
    await _checkBluetoothState();
    await _requestPermissions();
    _listenToAdapterState();
  }

  Future<void> _checkBluetoothState() async {
    try {
      _isBluetoothEnabled = await FlutterBluePlus.isOn;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to check Bluetooth state: $e';
      notifyListeners();
    }
  }

  void _listenToAdapterState() {
    _adapterStateSubscription = FlutterBluePlus.adapterState.listen((state) {
      _isBluetoothEnabled = state == BluetoothAdapterState.on;
      if (!_isBluetoothEnabled &&
          _connectionState == BluetoothConnectionState.connected) {
        _onConnectionLost();
      }
      notifyListeners();
    });
  }

  Future<void> _requestPermissions() async {
    Map<Permission, PermissionStatus> permissions = await [
      Permission.bluetooth,
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
      Permission.location,
    ].request();

    bool allGranted = permissions.values.every(
      (status) => status == PermissionStatus.granted,
    );

    if (!allGranted) {
      _errorMessage =
          'Bluetooth permissions are required for the app to function';
      notifyListeners();
    }
  }

  Future<void> enableBluetooth() async {
    try {
      if (await FlutterBluePlus.isSupported == false) {
        _errorMessage = 'Bluetooth not supported by this device';
        notifyListeners();
        return;
      }

      await FlutterBluePlus.turnOn();
      // Wait a bit for the adapter to turn on
      await Future.delayed(const Duration(seconds: 2));
      _isBluetoothEnabled = await FlutterBluePlus.isOn;

      if (_isBluetoothEnabled) {
        _errorMessage = null;
        await loadPairedDevices();
      }
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to enable Bluetooth: $e';
      notifyListeners();
    }
  }

  Future<void> loadPairedDevices() async {
    if (!_isBluetoothEnabled) return;

    try {
      _pairedDevices = await FlutterBluePlus.bondedDevices;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to load paired devices: $e';
      notifyListeners();
    }
  }

  Future<void> startScan() async {
    if (!_isBluetoothEnabled || _isScanning) return;

    try {
      _isScanning = true;
      _scanResults.clear();
      notifyListeners();

      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 15),
        androidUsesFineLocation: true,
      );

      FlutterBluePlus.scanResults.listen((results) {
        _scanResults = results.map((r) => r.device).toList();
        notifyListeners();
      });

      // Wait for scan to complete
      await FlutterBluePlus.isScanning.where((val) => val == false).first;
      _isScanning = false;
      notifyListeners();
    } catch (e) {
      _isScanning = false;
      _errorMessage = 'Failed to scan for devices: $e';
      notifyListeners();
    }
  }

  Future<void> stopScan() async {
    try {
      await FlutterBluePlus.stopScan();
      _isScanning = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to stop scan: $e';
      notifyListeners();
    }
  }

  Future<bool> connectToDevice(BluetoothDevice device) async {
    if (_connectionState == BluetoothConnectionState.connecting) return false;

    try {
      _connectionState = BluetoothConnectionState.connecting;
      _errorMessage = null;
      notifyListeners();

      debugPrint(
          'Attempting to connect to HM-10: ${device.platformName} (${device.remoteId})');

      // Connect to device with timeout for HM-10
      await device.connect(
        timeout: const Duration(seconds: 20),
        autoConnect: false,
      );
      _connectedDevice = device;

      debugPrint('HM-10 connected, discovering services...');

      // Listen to connection state changes
      _connectionStateSubscription = device.connectionState.listen((state) {
        debugPrint('Connection state changed: $state');
        _connectionState = state;
        if (state == BluetoothConnectionState.disconnected) {
          _onConnectionLost();
        }
        notifyListeners();
      });

      // Wait a bit for the connection to stabilize
      await Future.delayed(const Duration(seconds: 1));

      // Discover services
      List<BluetoothService> services =
          await device.discoverServices(timeout: 10);
      debugPrint('Found ${services.length} services');

      // Find the HM-10 BLE service
      BluetoothService? hm10Service;
      for (BluetoothService service in services) {
        debugPrint('Service UUID: ${service.uuid}');
        if (service.uuid.toString().toLowerCase() ==
            hm10ServiceUuid.toLowerCase()) {
          hm10Service = service;
          break;
        }
      }

      if (hm10Service == null) {
        debugPrint('HM-10 service not found, trying generic approach...');
        // If HM-10 service not found, use the first available service with characteristics
        for (BluetoothService service in services) {
          if (service.characteristics.isNotEmpty) {
            hm10Service = service;
            break;
          }
        }
      }

      if (hm10Service != null) {
        debugPrint('Using service: ${hm10Service.uuid}');
        debugPrint(
            'Service has ${hm10Service.characteristics.length} characteristics');

        // Find the HM-10 characteristic
        for (BluetoothCharacteristic char in hm10Service.characteristics) {
          debugPrint(
              'Characteristic: ${char.uuid}, Properties: ${char.properties}');
          if (char.uuid.toString().toLowerCase() ==
              hm10CharacteristicUuid.toLowerCase()) {
            _writeCharacteristic = char;
            _readCharacteristic = char;
            debugPrint('Found HM-10 characteristic: ${char.uuid}');
            break;
          }
          // Fallback: use any writable characteristic
          if (char.properties.write || char.properties.writeWithoutResponse) {
            _writeCharacteristic = char;
            debugPrint('Found write characteristic: ${char.uuid}');
          }
          if (char.properties.read || char.properties.notify) {
            _readCharacteristic = char;
            debugPrint('Found read characteristic: ${char.uuid}');
          }
        }
      }

      // Subscribe to notifications if available
      if (_readCharacteristic != null &&
          _readCharacteristic!.properties.notify) {
        debugPrint('Setting up notifications for HM-10 characteristic');
        await _readCharacteristic!.setNotifyValue(true);
        _characteristicSubscription =
            _readCharacteristic!.onValueReceived.listen(
          _onDataReceived,
          onError: (error) {
            debugPrint('Error receiving data: $error');
          },
        );
      }

      _connectionState = BluetoothConnectionState.connected;
      debugPrint('Successfully connected to HM-10 device');
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('HM-10 connection failed: $e');
      _connectionState = BluetoothConnectionState.disconnected;
      _errorMessage = 'Failed to connect: $e';
      notifyListeners();
      return false;
    }
  }

  void _onDataReceived(List<int> data) {
    // Handle incoming data from robot (status updates, confirmations, etc.)
    String message = utf8.decode(data);
    debugPrint('Received from HM-10: $message');
    // This can be expanded to parse robot status and update other providers
  }

  void _onConnectionLost() {
    _connectionState = BluetoothConnectionState.disconnected;
    _connectedDevice = null;
    _writeCharacteristic = null;
    _readCharacteristic = null;
    _connectionStateSubscription?.cancel();
    _connectionStateSubscription = null;
    _characteristicSubscription?.cancel();
    _characteristicSubscription = null;
    debugPrint('HM-10 connection lost');
    notifyListeners();
  }

  Future<bool> sendCommand(String command) async {
    if (!isConnected || _writeCharacteristic == null) {
      debugPrint(
          'Cannot send command: not connected or no write characteristic');
      return false;
    }

    try {
      List<int> bytes = utf8.encode(command);
      debugPrint('Sending command to HM-10: $command (bytes: $bytes)');

      // Check if command fits in single packet (20 bytes max for HM-10 BLE)
      if (bytes.length <= 20) {
        // Send as single packet
        await _writeCharacteristic!.write(bytes, withoutResponse: true);
        debugPrint('Command sent successfully to HM-10: $command');
        return true;
      } else {
        // Command too long, use chunking
        debugPrint('Command too long (${bytes.length} bytes), chunking...');
        return await _sendCommandInChunks(command, bytes);
      }
    } catch (e) {
      debugPrint('Failed to send command to HM-10: $e');
      _errorMessage = 'Failed to send command: $e';
      notifyListeners();
      return false;
    }
  }

  // Send long commands in chunks with proper reassembly markers
  Future<bool> _sendCommandInChunks(String command, List<int> bytes) async {
    const int chunkSize = 18; // Leave 2 bytes for chunk metadata
    const int maxChunks = 9; // Limit to prevent excessive fragmentation

    if (bytes.length > chunkSize * maxChunks) {
      debugPrint('Command too long even for chunking: ${bytes.length} bytes');
      return false;
    }

    try {
      int totalChunks = (bytes.length / chunkSize).ceil();
      debugPrint(
          'Splitting into $totalChunks chunks of max $chunkSize bytes each');

      for (int i = 0; i < totalChunks; i++) {
        int start = i * chunkSize;
        int end = (start + chunkSize < bytes.length)
            ? start + chunkSize
            : bytes.length;

        List<int> chunk = bytes.sublist(start, end);

        // Add chunk metadata: [chunk_number, total_chunks, ...data]
        List<int> chunkWithMetadata = [i, totalChunks - 1, ...chunk];

        debugPrint(
            'Sending chunk ${i + 1}/$totalChunks: ${chunkWithMetadata.length} bytes');

        await _writeCharacteristic!
            .write(chunkWithMetadata, withoutResponse: true);

        // Small delay between chunks to prevent overwhelming the receiver
        if (i < totalChunks - 1) {
          await Future.delayed(const Duration(milliseconds: 50));
        }
      }

      debugPrint('Successfully sent chunked command: $command');
      return true;
    } catch (e) {
      debugPrint('Failed to send chunked command: $e');
      return false;
    }
  }

  // Test HM-10 connection
  Future<bool> testConnection() async {
    if (!isConnected) return false;

    try {
      debugPrint('Testing HM-10 connection...');
      bool result = await sendCommand('TEST');
      if (result) {
        debugPrint('HM-10 connection test successful');
      }
      return result;
    } catch (e) {
      debugPrint('HM-10 connection test failed: $e');
      return false;
    }
  }

  // Get connection info for debugging
  String getConnectionInfo() {
    return '''
Connection Status: ${isConnected ? 'Connected' : 'Disconnected'}
Device: ${_connectedDevice?.platformName ?? 'None'}
Device ID: ${_connectedDevice?.remoteId ?? 'None'}
Write Characteristic: ${_writeCharacteristic?.uuid ?? 'None'}
Read Characteristic: ${_readCharacteristic?.uuid ?? 'None'}
Bluetooth Enabled: $_isBluetoothEnabled
Error: ${_errorMessage ?? 'None'}
    '''
        .trim();
  }

  Future<void> disconnect() async {
    try {
      _characteristicSubscription?.cancel();
      _characteristicSubscription = null;
      _connectionStateSubscription?.cancel();
      _connectionStateSubscription = null;

      if (_connectedDevice != null) {
        await _connectedDevice!.disconnect();
      }

      _connectedDevice = null;
      _writeCharacteristic = null;
      _readCharacteristic = null;
      _connectionState = BluetoothConnectionState.disconnected;
      _errorMessage = null;
      debugPrint('Disconnected from HM-10');
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Error during disconnect: $e';
      notifyListeners();
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _adapterStateSubscription?.cancel();
    _connectionStateSubscription?.cancel();
    _characteristicSubscription?.cancel();
    disconnect();
    super.dispose();
  }
}
