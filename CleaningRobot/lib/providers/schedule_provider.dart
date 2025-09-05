import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../models/schedule.dart';
import 'bluetooth_provider.dart';
import 'robot_control_provider.dart';

class ScheduleProvider extends ChangeNotifier {
  final List<Schedule> _schedules = [];
  Timer? _scheduleTimer;
  bool _isMonitoringSchedules = false;

  // Constructor to initialize schedule monitoring
  ScheduleProvider() {
    loadSchedules().then((_) {
      startScheduleMonitoring();
    });

    // Register callback for when Bluetooth connects
    BluetoothProvider.setScheduleSyncCallback(_onBluetoothConnected);
  }

  List<Schedule> get schedules => List.unmodifiable(_schedules);

  List<Schedule> get upcomingSchedules =>
      _schedules.where((schedule) => schedule.isUpcoming).toList()
        ..sort((a, b) => a.dateTime.compareTo(b.dateTime));

  List<Schedule> get completedSchedules =>
      _schedules.where((schedule) => schedule.isCompleted).toList()
        ..sort((a, b) => b.dateTime.compareTo(a.dateTime));

  List<Schedule> get expiredSchedules =>
      _schedules.where((schedule) => schedule.isExpired).toList()
        ..sort((a, b) => b.dateTime.compareTo(a.dateTime));

  bool get isMonitoringSchedules => _isMonitoringSchedules;

  void startScheduleMonitoring() {
    if (_isMonitoringSchedules) return;

    _isMonitoringSchedules = true;
    // Check every 10 seconds for better accuracy
    _scheduleTimer = Timer.periodic(Duration(seconds: 10), (timer) {
      _checkAndExecuteSchedules();
    });
    debugPrint('🕐 Schedule monitoring started - checking every 10 seconds');
    notifyListeners();
  }

  void stopScheduleMonitoring() {
    _scheduleTimer?.cancel();
    _scheduleTimer = null;
    _isMonitoringSchedules = false;
    notifyListeners();
  }

  // Callback when Bluetooth successfully connects
  void _onBluetoothConnected(BluetoothProvider bluetoothProvider) async {
    debugPrint('🔗 Bluetooth connected - syncing time and schedules');

    try {
      // First sync time
      await syncTimeWithArduino(bluetoothProvider);
      await Future.delayed(Duration(milliseconds: 1000));

      // Then sync all upcoming schedules
      final upcomingSchedules =
          _schedules.where((s) => !s.isCompleted && !s.isExpired).toList();
      debugPrint(
          '📅 Syncing ${upcomingSchedules.length} upcoming schedules to Arduino');

      for (final schedule in upcomingSchedules) {
        debugPrint('📤 Sending schedule ${schedule.id} to Arduino');
        await storeScheduleInArduino(schedule, bluetoothProvider);
        await Future.delayed(
            Duration(milliseconds: 500)); // Delay between schedules
      }

      debugPrint('✅ Schedule sync completed successfully');
    } catch (e) {
      debugPrint('❌ Error during schedule sync: $e');
    }
  }

  // Callback to execute automatic schedules with provider access
  static BluetoothProvider? _bluetoothProvider;
  static RobotControlProvider? _robotControlProvider;

  static void setProviders(
      BluetoothProvider? bluetooth, RobotControlProvider? robot) {
    _bluetoothProvider = bluetooth;
    _robotControlProvider = robot;
  }

  void _checkAndExecuteSchedules() {
    final now = DateTime.now();
    debugPrint('🕐 Checking schedules at ${now.toString()}');

    for (final schedule in _schedules) {
      if (!schedule.isCompleted && !schedule.isExpired) {
        // Check if the current time is at or past the scheduled time (within 60 seconds window)
        final timeDifference = now.difference(schedule.dateTime).inSeconds;
        final isTimeToExecute = timeDifference >= 0 && timeDifference <= 60;

        debugPrint(
            'Schedule ${schedule.id}: scheduled for ${schedule.dateTime}, time difference: ${timeDifference} seconds, should execute: $isTimeToExecute');

        if (isTimeToExecute) {
          debugPrint(
              '⏰ EXECUTING SCHEDULED TASK: ${schedule.id} at ${now.toString()}');
          _executeSchedule(schedule);
        }
      }
    }
    notifyListeners();
  }

  Future<void> _executeSchedule(Schedule schedule) async {
    try {
      debugPrint('🚀 STARTING SCHEDULE EXECUTION: ${schedule.id}');

      // Check if Bluetooth is connected
      if (_bluetoothProvider != null && !_bluetoothProvider!.isConnected) {
        debugPrint(
            '❌ Bluetooth not connected - cannot execute schedule ${schedule.id}');
        return;
      }

      // Mark schedule as completed first to prevent re-execution
      schedule.isCompleted = true;
      _saveSchedules();

      // If providers are available, execute the schedule properly
      if (_bluetoothProvider != null && _robotControlProvider != null) {
        debugPrint(
            '✅ Providers available - executing schedule with robot commands');
        debugPrint(
            '📤 Bluetooth connected: ${_bluetoothProvider!.isConnected}');

        // Send schedule execution command via Bluetooth FIRST
        String jsonCommand = generateScheduleCommand(schedule);
        debugPrint('📤 SENDING SCHEDULE COMMAND: $jsonCommand');
        await _bluetoothProvider!.sendCommand(jsonCommand);

        // Wait a bit for the command to be processed
        await Future.delayed(Duration(milliseconds: 500));

        // Set robot to the appropriate mode and start if autonomous
        if (schedule.mode == CleaningMode.autonomous) {
          debugPrint('🤖 Setting autonomous mode and starting cleaning');
          await _robotControlProvider!.setAutonomousMode(_bluetoothProvider!);
          // For autonomous mode, we want the robot to actually start cleaning
          await Future.delayed(Duration(milliseconds: 300));
        } else {
          debugPrint('🎮 Setting manual mode');
          await _robotControlProvider!.setManualMode(_bluetoothProvider!);
        }

        // Configure features with delays between commands
        if (schedule.vacuumEnabled) {
          debugPrint('💨 Enabling vacuum');
          await _robotControlProvider!.setVacuum(true, _bluetoothProvider!);
          await Future.delayed(Duration(milliseconds: 200));
        }

        if (schedule.mopEnabled) {
          debugPrint('🧽 Enabling mop');
          await _robotControlProvider!.setMop(true, _bluetoothProvider!);
          await Future.delayed(Duration(milliseconds: 200));
        }

        if (schedule.pumpEnabled) {
          debugPrint('💧 Enabling pump');
          await _robotControlProvider!.setPump(true, _bluetoothProvider!);
          await Future.delayed(Duration(milliseconds: 200));
        }

        debugPrint('✅ SCHEDULE ${schedule.id} EXECUTED SUCCESSFULLY');
      } else {
        debugPrint(
            '❌ Providers not available - cannot execute schedule ${schedule.id}');
        // Revert completion status if providers not available
        schedule.isCompleted = false;
        _saveSchedules();
      }
    } catch (e) {
      debugPrint('❌ ERROR executing schedule ${schedule.id}: $e');
      // Revert completion status on error
      schedule.isCompleted = false;
      _saveSchedules();
    }
    notifyListeners();
  }

  // Method to manually execute a schedule (for testing or immediate execution)
  Future<bool> executeScheduleNow(
      String scheduleId,
      BluetoothProvider bluetoothProvider,
      RobotControlProvider robotProvider) async {
    try {
      final schedule = _schedules.firstWhere((s) => s.id == scheduleId);

      // Set robot to the appropriate mode
      if (schedule.mode == CleaningMode.autonomous) {
        await robotProvider.setAutonomousMode(bluetoothProvider);
      } else {
        await robotProvider.setManualMode(bluetoothProvider);
      }

      // Configure features
      await robotProvider.setVacuum(schedule.vacuumEnabled, bluetoothProvider);
      await robotProvider.setMop(schedule.mopEnabled, bluetoothProvider);
      await robotProvider.setPump(schedule.pumpEnabled, bluetoothProvider);

      // Send schedule execution command via Bluetooth
      String jsonCommand = generateScheduleCommand(schedule);
      await bluetoothProvider.sendCommand(jsonCommand);
      debugPrint('Sent schedule execution command: $jsonCommand');

      // Mark as completed
      schedule.isCompleted = true;
      _saveSchedules();
      notifyListeners();

      return true;
    } catch (e) {
      debugPrint('Error executing schedule immediately: $e');
      return false;
    }
  }

  // Method to create a schedule execution command without executing it
  String generateScheduleCommand(Schedule schedule) {
    Map<String, dynamic> scheduleCommand = {
      "a": "sc", // "action": "schedule" -> "a": "sc"
      "t": schedule.mode == CleaningMode.autonomous
          ? "a"
          : "m", // "mode" -> "t", "auto"/"man" -> "a"/"m"
      "f": {
        // "features" -> "f"
        "v": schedule.vacuumEnabled ? 1 : 0,
        "m": schedule.mopEnabled ? 1 : 0,
        "p": schedule.pumpEnabled ? 1 : 0
      },
      "start": schedule.mode == CleaningMode.autonomous
          ? 1
          : 0, // Auto-start for autonomous mode
      "id": schedule.id.length > 6
          ? schedule.id.substring(0, 6)
          : schedule.id // Limit ID length
    };

    return jsonEncode(scheduleCommand);
  }

  // Method to create a schedule storage command for Arduino
  String generateScheduleStorageCommand(Schedule schedule) {
    Map<String, dynamic> storageCommand = {
      "a": "sc", // "action": "schedule" -> "a": "sc"
      "id": schedule.id.length > 6
          ? schedule.id.substring(0, 6)
          : schedule.id, // Limit ID length
      "t": schedule.mode == CleaningMode.autonomous
          ? "a"
          : "m", // "mode" -> "t", "auto"/"man" -> "a"/"m"
      "f": {
        // "features" -> "f"
        "v": schedule.vacuumEnabled ? 1 : 0,
        "m": schedule.mopEnabled ? 1 : 0,
        "p": schedule.pumpEnabled ? 1 : 0
      },
      "store":
          1, // Flag to indicate this is for storage, not immediate execution
      "y": schedule.dateTime.year,
      "mo": schedule.dateTime.month,
      "d": schedule.dateTime.day,
      "h": schedule.dateTime.hour,
      "mi": schedule.dateTime.minute,
    };

    return jsonEncode(storageCommand);
  }

  // Method to create time synchronization command
  String generateTimeSyncCommand() {
    final now = DateTime.now();
    Map<String, dynamic> syncCommand = {
      "a": "rtc", // "action": "rtc"
      "cmd": "sync", // "command": "sync"
      "y": now.year,
      "mo": now.month,
      "d": now.day,
      "h": now.hour,
      "mi": now.minute,
      "s": now.second,
    };

    return jsonEncode(syncCommand);
  }

  // Send time sync to Arduino
  Future<bool> syncTimeWithArduino(BluetoothProvider bluetoothProvider) async {
    if (!bluetoothProvider.isConnected) {
      debugPrint('❌ Cannot sync time - Bluetooth not connected');
      return false;
    }

    try {
      String syncCommand = generateTimeSyncCommand();
      debugPrint('📤 Sending time sync command: $syncCommand');
      await bluetoothProvider.sendCommand(syncCommand);
      debugPrint('✅ Time sync command sent successfully');
      return true;
    } catch (e) {
      debugPrint('❌ Error sending time sync: $e');
      return false;
    }
  }

  // Send schedule storage to Arduino
  Future<bool> storeScheduleInArduino(
      Schedule schedule, BluetoothProvider bluetoothProvider) async {
    if (!bluetoothProvider.isConnected) {
      debugPrint('❌ Cannot store schedule - Bluetooth not connected');
      return false;
    }

    try {
      // First sync time with Arduino
      await syncTimeWithArduino(bluetoothProvider);
      await Future.delayed(Duration(milliseconds: 500));

      // Then send schedule storage command
      String storageCommand = generateScheduleStorageCommand(schedule);
      debugPrint('📤 Sending schedule storage command: $storageCommand');
      await bluetoothProvider.sendCommand(storageCommand);
      debugPrint('✅ Schedule storage command sent successfully');
      return true;
    } catch (e) {
      debugPrint('❌ Error sending schedule storage: $e');
      return false;
    }
  }

  void addSchedule(Schedule schedule) {
    _schedules.add(schedule);
    _saveSchedules();
    notifyListeners();

    // Also store the schedule in Arduino if Bluetooth is connected
    if (_bluetoothProvider != null && _bluetoothProvider!.isConnected) {
      debugPrint('🔗 Storing schedule in Arduino: ${schedule.id}');
      storeScheduleInArduino(schedule, _bluetoothProvider!).then((success) {
        if (success) {
          debugPrint(
              '✅ Schedule successfully stored in Arduino: ${schedule.id}');
        } else {
          debugPrint('❌ Failed to store schedule in Arduino: ${schedule.id}');
        }
      }).catchError((error) {
        debugPrint('❌ Error storing schedule in Arduino: $error');
      });
    } else {
      debugPrint(
          '⚠️ Bluetooth not connected - schedule only stored locally: ${schedule.id}');
    }
  }

  void updateSchedule(Schedule schedule) {
    final index = _schedules.indexWhere((s) => s.id == schedule.id);
    if (index != -1) {
      _schedules[index] = schedule;
      _saveSchedules();
      notifyListeners();
    }
  }

  void deleteSchedule(String scheduleId) {
    _schedules.removeWhere((schedule) => schedule.id == scheduleId);
    _saveSchedules();
    notifyListeners();
  }

  void markScheduleCompleted(String scheduleId) {
    final schedule = _schedules.firstWhere(
      (s) => s.id == scheduleId,
      orElse: () => throw Exception('Schedule not found'),
    );
    schedule.isCompleted = true;
    _saveSchedules();
    notifyListeners();
  }

  void markScheduleExpired(String scheduleId) {
    // Schedule automatically becomes expired if current time > schedule time and not completed
    _saveSchedules();
    notifyListeners();
  }

  Schedule? getNextSchedule() {
    final upcoming = upcomingSchedules;
    return upcoming.isNotEmpty ? upcoming.first : null;
  }

  Future<void> _saveSchedules() async {
    // Using Hive for local storage
    try {
      final box = await Hive.openBox<Schedule>('schedules');
      await box.clear();
      await box.addAll(_schedules);
      debugPrint('💾 Saved ${_schedules.length} schedules to storage');
    } catch (e) {
      debugPrint('Error saving schedules: $e');
    }
  }

  Future<void> loadSchedules() async {
    try {
      final box = await Hive.openBox<Schedule>('schedules');
      _schedules.clear();
      _schedules.addAll(box.values);
      debugPrint('📂 Loaded ${_schedules.length} schedules from storage');
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading schedules: $e');
    }
  }

  void clearExpiredSchedules() {
    _schedules.removeWhere((schedule) => schedule.isExpired);
    _saveSchedules();
    notifyListeners();
  }

  void clearCompletedSchedules() {
    _schedules.removeWhere((schedule) => schedule.isCompleted);
    _saveSchedules();
    notifyListeners();
  }

  // Generate a unique ID for new schedules
  String _generateId() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }

  Schedule createSchedule({
    required DateTime dateTime,
    required CleaningMode mode,
    required bool vacuumEnabled,
    required bool mopEnabled,
    required bool pumpEnabled,
  }) {
    return Schedule(
      id: _generateId(),
      dateTime: dateTime,
      mode: mode,
      vacuumEnabled: vacuumEnabled,
      mopEnabled: mopEnabled,
      pumpEnabled: pumpEnabled,
    );
  }

  @override
  void dispose() {
    stopScheduleMonitoring();
    super.dispose();
  }

  // Debug method to test schedule execution manually
  void testScheduleExecution() {
    debugPrint('🧪 MANUAL SCHEDULE CHECK TRIGGERED');
    _checkAndExecuteSchedules();
  }

  // Method to check if there are any schedules in the next 5 minutes (for debugging)
  List<Schedule> getUpcomingInNext5Minutes() {
    final now = DateTime.now();
    final next5Minutes = now.add(Duration(minutes: 5));

    return _schedules.where((schedule) {
      return !schedule.isCompleted &&
          !schedule.isExpired &&
          schedule.dateTime.isAfter(now) &&
          schedule.dateTime.isBefore(next5Minutes);
    }).toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
  }
}
