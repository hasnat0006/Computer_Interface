import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/robot_models.dart';
import 'bluetooth_provider.dart';

class RobotControlProvider extends ChangeNotifier {
  RobotStatus _status = RobotStatus.initial();
  bool _isMoving = false;
  String? _lastCommand;
  DateTime? _lastCommandTime;

  // Getters
  RobotStatus get status => _status;
  bool get isMoving => _isMoving;
  String? get lastCommand => _lastCommand;
  DateTime? get lastCommandTime => _lastCommandTime;
  bool get isConnected => _status.state != RobotState.disconnected;

  void updateConnectionStatus(bool connected) {
    if (connected) {
      _status = _status.copyWith(state: RobotState.idle);
    } else {
      _status = _status.copyWith(state: RobotState.disconnected);
    }
    notifyListeners();
  }

  // Parse incoming raw responses from robot (no JSON expected)
  void parseRobotResponse(String response) {
    // Since Arduino doesn't send JSON responses, we just log for debugging
    print('Raw robot response: $response');

    // We can optionally parse simple text responses if needed in the future
    // For now, robot state is managed locally based on sent commands
  }

  Future<bool> sendMovementCommand(
      String jsonCommand, BluetoothProvider bluetoothProvider) async {
    if (!bluetoothProvider.isConnected) return false;

    bool success = await bluetoothProvider.sendCommand(jsonCommand);
    if (success) {
      _lastCommand = jsonCommand;
      _lastCommandTime = DateTime.now();

      // Parse the JSON command to determine if robot is moving
      try {
        final Map<String, dynamic> command = jsonDecode(jsonCommand);
        if (command['action'] == 'move') {
          _isMoving =
              command['direction'] != 's'; // 's' is stop in abbreviated format
        } else if (command['action'] == 'multi') {
          _isMoving =
              command['direction'] != null && command['direction'] != 's';
        }
      } catch (e) {
        print('Failed to parse sent command: $e');
      }

      if (_isMoving) {
        _status = _status.copyWith(state: RobotState.moving);
      } else {
        _status = _status.copyWith(state: RobotState.idle);
      }

      notifyListeners();
    }
    return success;
  }

  Future<bool> toggleVacuum(BluetoothProvider bluetoothProvider) async {
    if (!bluetoothProvider.isConnected) return false;

    String command =
        _status.vacuumActive ? RobotCommands.vacuumOff : RobotCommands.vacuumOn;
    bool success = await bluetoothProvider.sendCommand(command);

    if (success) {
      _status = _status.copyWith(vacuumActive: !_status.vacuumActive);
      _lastCommand = command;
      _lastCommandTime = DateTime.now();
      notifyListeners();
    }
    return success;
  }

  Future<bool> toggleMop(BluetoothProvider bluetoothProvider) async {
    if (!bluetoothProvider.isConnected) return false;

    String command =
        _status.mopActive ? RobotCommands.mopOff : RobotCommands.mopOn;
    bool success = await bluetoothProvider.sendCommand(command);

    if (success) {
      _status = _status.copyWith(mopActive: !_status.mopActive);
      _lastCommand = command;
      _lastCommandTime = DateTime.now();
      notifyListeners();
    }
    return success;
  }

  Future<bool> setVacuum(
      bool enabled, BluetoothProvider bluetoothProvider) async {
    if (!bluetoothProvider.isConnected) return false;
    if (_status.vacuumActive == enabled) return true;

    String command = enabled ? RobotCommands.vacuumOn : RobotCommands.vacuumOff;
    bool success = await bluetoothProvider.sendCommand(command);

    if (success) {
      _status = _status.copyWith(vacuumActive: enabled);
      _lastCommand = command;
      _lastCommandTime = DateTime.now();
      notifyListeners();
    }
    return success;
  }

  Future<bool> setMop(bool enabled, BluetoothProvider bluetoothProvider) async {
    if (!bluetoothProvider.isConnected) return false;
    if (_status.mopActive == enabled) return true;

    String command = enabled ? RobotCommands.mopOn : RobotCommands.mopOff;
    bool success = await bluetoothProvider.sendCommand(command);

    if (success) {
      _status = _status.copyWith(mopActive: enabled);
      _lastCommand = command;
      _lastCommandTime = DateTime.now();
      notifyListeners();
    }
    return success;
  }

  Future<bool> togglePump(BluetoothProvider bluetoothProvider) async {
    if (!bluetoothProvider.isConnected) return false;

    String command =
        _status.pumpActive ? RobotCommands.pumpOff : RobotCommands.pumpOn;
    bool success = await bluetoothProvider.sendCommand(command);

    if (success) {
      _status = _status.copyWith(pumpActive: !_status.pumpActive);
      _lastCommand = command;
      _lastCommandTime = DateTime.now();
      notifyListeners();
    }
    return success;
  }

  Future<bool> setPump(
      bool enabled, BluetoothProvider bluetoothProvider) async {
    if (!bluetoothProvider.isConnected) return false;
    if (_status.pumpActive == enabled) return true;

    String command = enabled ? RobotCommands.pumpOn : RobotCommands.pumpOff;
    bool success = await bluetoothProvider.sendCommand(command);

    if (success) {
      _status = _status.copyWith(pumpActive: enabled);
      _lastCommand = command;
      _lastCommandTime = DateTime.now();
      notifyListeners();
    }
    return success;
  }

  Future<bool> setAutonomousMode(BluetoothProvider bluetoothProvider) async {
    if (!bluetoothProvider.isConnected) return false;

    bool success =
        await bluetoothProvider.sendCommand(RobotCommands.autonomousMode);
    if (success) {
      _status = _status.copyWith(state: RobotState.autonomous);
      _lastCommand = RobotCommands.autonomousMode;
      _lastCommandTime = DateTime.now();
      notifyListeners();
    }
    return success;
  }

  Future<bool> toggleAutonomousMode(BluetoothProvider bluetoothProvider) async {
    if (!bluetoothProvider.isConnected) return false;

    if (_status.state == RobotState.autonomous) {
      // If currently autonomous, stop the robot
      return await stopRobot(bluetoothProvider);
    } else {
      // If not autonomous, start autonomous mode
      return await setAutonomousMode(bluetoothProvider);
    }
  }

  Future<bool> setManualMode(BluetoothProvider bluetoothProvider) async {
    if (!bluetoothProvider.isConnected) return false;

    bool success =
        await bluetoothProvider.sendCommand(RobotCommands.manualMode);
    if (success) {
      _status = _status.copyWith(state: RobotState.manual);
      _lastCommand = RobotCommands.manualMode;
      _lastCommandTime = DateTime.now();
      notifyListeners();
    }
    return success;
  }

  Future<bool> stopRobot(BluetoothProvider bluetoothProvider) async {
    if (!bluetoothProvider.isConnected) return false;

    bool success = await bluetoothProvider.sendCommand(RobotCommands.stop);
    if (success) {
      _isMoving = false;
      _status = _status.copyWith(state: RobotState.idle);
      _lastCommand = RobotCommands.stop;
      _lastCommandTime = DateTime.now();
      notifyListeners();
    }
    return success;
  }

  Future<bool> emergencyStop(BluetoothProvider bluetoothProvider) async {
    if (!bluetoothProvider.isConnected) return false;

    bool success = await bluetoothProvider.sendCommand(RobotCommands.emergency);
    if (success) {
      _isMoving = false;
      _status = _status.copyWith(
        state: RobotState.idle,
        vacuumActive: false,
        mopActive: false,
        pumpActive: false,
      );
      _lastCommand = RobotCommands.emergency;
      _lastCommandTime = DateTime.now();
      notifyListeners();
    }
    return success;
  }

  Future<bool> requestStatus(BluetoothProvider bluetoothProvider) async {
    if (!bluetoothProvider.isConnected) return false;

    return await bluetoothProvider.sendCommand(RobotCommands.getStatus);
  }

  Future<bool> testLED(BluetoothProvider bluetoothProvider) async {
    if (!bluetoothProvider.isConnected) return false;

    bool success = await bluetoothProvider.sendCommand(RobotCommands.ledTest);
    if (success) {
      _lastCommand = RobotCommands.ledTest;
      _lastCommandTime = DateTime.now();
      notifyListeners();
    }
    return success;
  }

  Future<bool> testRTC(BluetoothProvider bluetoothProvider) async {
    if (!bluetoothProvider.isConnected) return false;

    bool success = await bluetoothProvider.sendCommand(RobotCommands.rtcTest);
    if (success) {
      _lastCommand = RobotCommands.rtcTest;
      _lastCommandTime = DateTime.now();
      notifyListeners();
    }
    return success;
  }

  Future<bool> getRTCTime(BluetoothProvider bluetoothProvider) async {
    if (!bluetoothProvider.isConnected) return false;

    bool success =
        await bluetoothProvider.sendCommand(RobotCommands.getRTCTime);
    if (success) {
      _lastCommand = RobotCommands.getRTCTime;
      _lastCommandTime = DateTime.now();
      notifyListeners();
    }
    return success;
  }

  Future<bool> setRTCTime(
    BluetoothProvider bluetoothProvider,
    DateTime dateTime,
  ) async {
    if (!bluetoothProvider.isConnected) return false;

    String command = RobotCommands.buildSetRTCTime(
      year: dateTime.year,
      month: dateTime.month,
      day: dateTime.day,
      hour: dateTime.hour,
      minute: dateTime.minute,
      second: dateTime.second,
    );

    bool success = await bluetoothProvider.sendCommand(command);
    if (success) {
      _lastCommand = command;
      _lastCommandTime = DateTime.now();
      notifyListeners();
    }
    return success;
  }

  Future<bool> syncRTCWithPhone(BluetoothProvider bluetoothProvider) async {
    return await setRTCTime(bluetoothProvider, DateTime.now());
  }

  void updateStatus(RobotStatus newStatus) {
    _status = newStatus;
    notifyListeners();
  }

  void clearError() {
    _status = _status.copyWith(errorMessage: null);
    notifyListeners();
  }
}
