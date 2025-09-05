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

  // JSON response handling
  Function(String)? _responseCallback;

  // Minimal command delay for maximum responsiveness
  DateTime? _lastCommandTime;
  static const Duration _commandDelay = Duration(milliseconds: 20);

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

  // Response handling
  void setResponseCallback(Function(String) callback) {
    _responseCallback = callback;
  }

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
      debugPrint('Looking for HM-10 service: $hm10ServiceUuid');
      for (BluetoothService service in services) {
        debugPrint('Available service UUID: ${service.uuid}');
        String serviceUuidStr = service.uuid.toString().toLowerCase();
        String targetServiceUuidStr = hm10ServiceUuid.toLowerCase();

        debugPrint('Comparing: "$serviceUuidStr" with "$targetServiceUuidStr"');
        debugPrint('Contains ffe0? ${serviceUuidStr.contains('ffe0')}');
        debugPrint('Equals ffe0? ${serviceUuidStr == 'ffe0'}');

        // Check for both full UUID and short form (ffe0)
        if (serviceUuidStr == targetServiceUuidStr ||
            serviceUuidStr.contains('ffe0') ||
            serviceUuidStr == 'ffe0') {
          hm10Service = service;
          debugPrint('✅ Found HM-10 service: ${service.uuid}');
          break;
        }
      }

      if (hm10Service == null) {
        debugPrint('❌ HM-10 service (FFE0) not found!');
        debugPrint('Available services:');
        for (BluetoothService service in services) {
          debugPrint(
              '  - ${service.uuid} (${service.characteristics.length} characteristics)');
        }

        // Try to find any service with FFE1 characteristic as fallback
        debugPrint('Searching for FFE1 characteristic in any service...');
        for (BluetoothService service in services) {
          for (BluetoothCharacteristic char in service.characteristics) {
            if (char.uuid.toString().toLowerCase().contains('ffe1')) {
              hm10Service = service;
              debugPrint(
                  '✅ Found FFE1 characteristic in service: ${service.uuid}');
              break;
            }
          }
          if (hm10Service != null) break;
        }

        if (hm10Service == null) {
          _errorMessage =
              'HM-10 service (FFE0) not found. Make sure you\'re connecting to a genuine HM-10 module.';
          _connectionState = BluetoothConnectionState.disconnected;
          notifyListeners();
          return false;
        }
      }

      debugPrint('Using service: ${hm10Service.uuid}');
      debugPrint(
          'Service has ${hm10Service.characteristics.length} characteristics');

      // Find the HM-10 characteristic - be strict about UUID matching
      bool foundHm10Characteristic = false;
      for (BluetoothCharacteristic char in hm10Service.characteristics) {
        debugPrint(
            'Characteristic: ${char.uuid}, Properties: write=${char.properties.write}, writeWithoutResponse=${char.properties.writeWithoutResponse}, read=${char.properties.read}, notify=${char.properties.notify}');

        String charUuidStr = char.uuid.toString().toLowerCase();
        String targetUuidStr = hm10CharacteristicUuid.toLowerCase();

        // Match HM-10 UART characteristic exactly
        if (charUuidStr == targetUuidStr || charUuidStr.contains('ffe1')) {
          _writeCharacteristic = char;
          _readCharacteristic = char;
          foundHm10Characteristic = true;
          debugPrint('✅ Found HM-10 UART characteristic: ${char.uuid}');
          debugPrint('   - Write: ${char.properties.write}');
          debugPrint(
              '   - WriteNoResponse: ${char.properties.writeWithoutResponse}');
          debugPrint('   - Read: ${char.properties.read}');
          debugPrint('   - Notify: ${char.properties.notify}');
          break;
        }
      }

      if (!foundHm10Characteristic) {
        debugPrint('❌ HM-10 UART characteristic (FFE1) not found!');
        debugPrint('Available characteristics:');
        for (BluetoothCharacteristic char in hm10Service.characteristics) {
          debugPrint(
              '  - ${char.uuid} (properties: write=${char.properties.write}, writeNoResp=${char.properties.writeWithoutResponse})');
        }
        _errorMessage =
            'HM-10 UART characteristic (FFE1) not found. Make sure you\'re connecting to a genuine HM-10 module.';
        _connectionState = BluetoothConnectionState.disconnected;
        notifyListeners();
        return false;
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

      // After successful connection, sync time and schedules with Arduino
      _onDeviceConnected();

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
    // Handle incoming data from robot (for debugging only - no JSON responses expected)
    String message = utf8.decode(data);
    debugPrint('Received from HM-10: $message');

    // Since we don't expect JSON responses, we can optionally process
    // raw data for debugging purposes only
    if (_responseCallback != null) {
      _responseCallback!(message);
    }
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

  void _onDeviceConnected() {
    // This will be called after successful Arduino connection
    // We'll use a callback pattern to avoid circular dependencies
    debugPrint('Device connected - triggering sync operations');
    Future.delayed(Duration(seconds: 2), () {
      // Give a small delay for connection to stabilize, then sync
      _triggerScheduleSync();
    });
  }

  void _triggerScheduleSync() {
    // This method will be called by the ScheduleProvider through a callback
    debugPrint('Bluetooth connected - ready for schedule sync');
    if (_scheduleProvider != null) {
      _scheduleProvider!(this);
    }
  }

  // Static reference to schedule provider for callback
  static Function(BluetoothProvider)? _scheduleProvider;

  // Method to set the schedule sync callback
  static void setScheduleSyncCallback(Function(BluetoothProvider) callback) {
    _scheduleProvider = callback;
  }

  Future<bool> sendCommand(String command) async {
    if (!isConnected || _writeCharacteristic == null) {
      debugPrint(
          'Cannot send command: not connected or no write characteristic');
      return false;
    }

    // Implement command throttling to prevent concatenation
    if (_lastCommandTime != null) {
      final timeSinceLastCommand = DateTime.now().difference(_lastCommandTime!);
      if (timeSinceLastCommand < _commandDelay) {
        final remainingDelay = _commandDelay - timeSinceLastCommand;
        debugPrint(
            'Throttling command: waiting ${remainingDelay.inMilliseconds}ms');
        await Future.delayed(remainingDelay);
      }
    }

    try {
      // HM-10 typically doesn't need CRLF, but you can add \n if your Arduino expects it
      List<int> bytes = utf8.encode(command);
      debugPrint('Sending command to HM-10: $command (bytes: $bytes)');

      // Update last command time
      _lastCommandTime = DateTime.now();

      // Use write with response since writeWithoutResponse is not supported
      if (_writeCharacteristic!.properties.write) {
        await _writeCharacteristic!.write(bytes, withoutResponse: false);
        debugPrint(
            'Command sent successfully to HM-10 with response: $command');
      } else if (_writeCharacteristic!.properties.writeWithoutResponse) {
        await _writeCharacteristic!.write(bytes, withoutResponse: true);
        debugPrint(
            'Command sent successfully to HM-10 without response: $command');
      } else {
        debugPrint('HM-10 characteristic does not support writing');
        return false;
      }

      return true;
    } catch (e) {
      debugPrint('Failed to send command to HM-10: $e');
      _errorMessage = 'Failed to send command: $e';
      notifyListeners();
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
