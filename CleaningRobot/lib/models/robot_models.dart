import 'dart:convert';

class RobotCommands {
  // Ultra-short movement commands (≤20 bytes for BLE compatibility)
  static String forward =
      jsonEncode({"a": "mv", "d": "f"}); // {"a":"mv","d":"f"} = 16 bytes
  static String backward =
      jsonEncode({"a": "mv", "d": "b"}); // {"a":"mv","d":"b"} = 16 bytes
  static String left =
      jsonEncode({"a": "mv", "d": "l"}); // {"a":"mv","d":"l"} = 16 bytes
  static String right =
      jsonEncode({"a": "mv", "d": "r"}); // {"a":"mv","d":"r"} = 16 bytes
  static String stop =
      jsonEncode({"a": "mv", "d": "s"}); // {"a":"mv","d":"s"} = 16 bytes

  // Ultra-short feature commands (≤20 bytes)
  static String vacuumOn =
      jsonEncode({"a": "v", "s": 1}); // {"a":"v","s":1} = 14 bytes
  static String vacuumOff =
      jsonEncode({"a": "v", "s": 0}); // {"a":"v","s":0} = 14 bytes
  static String mopOn =
      jsonEncode({"a": "mp", "s": 1}); // {"a":"mp","s":1} = 15 bytes
  static String mopOff =
      jsonEncode({"a": "mp", "s": 0}); // {"a":"mp","s":0} = 15 bytes
  static String pumpOn =
      jsonEncode({"a": "p", "s": 1}); // {"a":"p","s":1} = 14 bytes
  static String pumpOff =
      jsonEncode({"a": "p", "s": 0}); // {"a":"p","s":0} = 14 bytes

  // Ultra-short test commands
  static String ledTest =
      jsonEncode({"a": "t", "c": "led"}); // {"a":"t","c":"led"} = 17 bytes
  static String rtcTest =
      jsonEncode({"a": "t", "c": "rtc"}); // {"a":"t","c":"rtc"} = 17 bytes

  // RTC commands (BLE compatible)
  static String getRTCTime =
      jsonEncode({"a": "rtc", "cmd": "time"}); // 23 bytes - will be chunked

  // Build RTC set time command
  static String buildSetRTCTime({
    required int year,
    required int month,
    required int day,
    required int hour,
    required int minute,
    required int second,
  }) {
    // This will be chunked since it's longer than 20 bytes
    return jsonEncode({
      "a": "rtc",
      "cmd": "set",
      "y": year,
      "mo": month,
      "d": day,
      "h": hour,
      "mi": minute,
      "s": second,
    });
  }

  // Ultra-short mode commands
  static String autonomousMode =
      jsonEncode({"a": "o", "t": "a"}); // {"a":"o","t":"a"} = 15 bytes
  static String manualMode =
      jsonEncode({"a": "o", "t": "m"}); // {"a":"o","t":"m"} = 15 bytes

  // Ultra-short status commands
  static String getStatus = jsonEncode({"a": "s"}); // {"a":"s"} = 9 bytes
  static String emergency = jsonEncode({"a": "e"}); // {"a":"e"} = 9 bytes

  // Legacy longer commands (kept for compatibility, but chunked when sent)
  static String forwardLong = jsonEncode({"action": "move", "direction": "f"});
  static String backwardLong = jsonEncode({"action": "move", "direction": "b"});
  static String leftLong = jsonEncode({"action": "move", "direction": "l"});
  static String rightLong = jsonEncode({"action": "move", "direction": "r"});
  static String stopLong = jsonEncode({"action": "move", "direction": "s"});

  // Schedule execution command builder (BLE compatible ≤20 bytes)
  static String buildScheduleCommand({
    required String scheduleId,
    required String mode, // "a" for auto or "m" for manual
    required bool vacuum,
    required bool mop,
    bool pump = false,
  }) {
    return jsonEncode({
      "a": "sc",
      "id": scheduleId.length > 6
          ? scheduleId.substring(0, 6)
          : scheduleId, // Limit ID length for BLE
      "t": mode.substring(0, 1), // Just first character
      "f": {
        "v": vacuum ? 1 : 0,
        "m": mop ? 1 : 0,
        "p": pump ? 1 : 0,
      },
    });
  }

  // Custom command builder (ultra-short format)
  static String buildCustomCommand({
    required String action,
    Map<String, dynamic>? parameters,
  }) {
    Map<String, dynamic> command = {
      "a": action.substring(0, 1)
    }; // Abbreviate action
    if (parameters != null) {
      // Abbreviate parameter keys to single characters where possible
      Map<String, dynamic> shortParams = {};
      parameters.forEach((key, value) {
        String shortKey = key.length > 1 ? key.substring(0, 1) : key;
        shortParams[shortKey] = value;
      });
      command.addAll(shortParams);
    }
    return jsonEncode(command);
  }

  // Ultra-short multi-feature command builder
  static String buildMultiCommand({
    String? direction,
    bool? vacuum,
    bool? mop,
    bool? pump,
  }) {
    Map<String, dynamic> command = {"a": "mu"}; // "multi" abbreviated to "mu"

    if (direction != null) {
      // Convert direction to single character
      String shortDir;
      switch (direction.toLowerCase()) {
        case 'forward':
          shortDir = 'f';
          break;
        case 'backward':
          shortDir = 'b';
          break;
        case 'left':
          shortDir = 'l';
          break;
        case 'right':
          shortDir = 'r';
          break;
        case 'stop':
          shortDir = 's';
          break;
        default:
          shortDir = direction.substring(
              0, 1); // Use first character if already abbreviated
      }
      command["d"] = shortDir; // "direction" -> "d"
    }

    if (vacuum != null) {
      command["v"] = vacuum ? 1 : 0;
    }

    if (mop != null) {
      command["m"] = mop ? 1 : 0;
    }

    if (pump != null) {
      command["p"] = pump ? 1 : 0;
    }

    return jsonEncode(command);
  }
}

enum RobotState {
  idle,
  moving,
  cleaning,
  autonomous,
  manual,
  error,
  disconnected,
}

enum BluetoothConnectionState {
  disconnected,
  connecting,
  connected,
  error,
}

class RobotStatus {
  final RobotState state;
  final bool vacuumActive;
  final bool mopActive;
  final bool pumpActive;
  final int batteryLevel;
  final String? errorMessage;

  const RobotStatus({
    required this.state,
    required this.vacuumActive,
    required this.mopActive,
    required this.pumpActive,
    required this.batteryLevel,
    this.errorMessage,
  });

  factory RobotStatus.initial() {
    return const RobotStatus(
      state: RobotState.disconnected,
      vacuumActive: false,
      mopActive: false,
      pumpActive: false,
      batteryLevel: 0,
    );
  }

  RobotStatus copyWith({
    RobotState? state,
    bool? vacuumActive,
    bool? mopActive,
    bool? pumpActive,
    int? batteryLevel,
    String? errorMessage,
  }) {
    return RobotStatus(
      state: state ?? this.state,
      vacuumActive: vacuumActive ?? this.vacuumActive,
      mopActive: mopActive ?? this.mopActive,
      pumpActive: pumpActive ?? this.pumpActive,
      batteryLevel: batteryLevel ?? this.batteryLevel,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  String get stateText {
    switch (state) {
      case RobotState.idle:
        return 'Idle';
      case RobotState.moving:
        return 'Moving';
      case RobotState.cleaning:
        return 'Cleaning';
      case RobotState.autonomous:
        return 'Autonomous Mode';
      case RobotState.manual:
        return 'Manual Mode';
      case RobotState.error:
        return 'Error';
      case RobotState.disconnected:
        return 'Disconnected';
    }
  }
}
