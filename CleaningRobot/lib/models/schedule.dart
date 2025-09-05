import 'package:hive/hive.dart';

part 'schedule.g.dart';

@HiveType(typeId: 0)
enum CleaningMode {
  @HiveField(0)
  autonomous,
  @HiveField(1)
  manual,
}

@HiveType(typeId: 1)
class Schedule extends HiveObject {
  @HiveField(0)
  late String id;

  @HiveField(1)
  late DateTime dateTime;

  @HiveField(2)
  late CleaningMode mode;

  @HiveField(3)
  late bool vacuumEnabled;

  @HiveField(4)
  late bool mopEnabled;

  @HiveField(5)
  late bool pumpEnabled;

  @HiveField(6)
  late bool isCompleted;

  @HiveField(7)
  late DateTime createdAt;

  Schedule({
    required this.id,
    required this.dateTime,
    required this.mode,
    required this.vacuumEnabled,
    required this.mopEnabled,
    required this.pumpEnabled,
    this.isCompleted = false,
    DateTime? createdAt,
  }) {
    this.createdAt = createdAt ?? DateTime.now();
  }

  bool get isExpired => DateTime.now().isAfter(dateTime) && !isCompleted;
  bool get isUpcoming => DateTime.now().isBefore(dateTime) && !isCompleted;

  String get modeText =>
      mode == CleaningMode.autonomous ? 'Autonomous' : 'Manual';

  String get featuresText {
    List<String> features = [];
    if (vacuumEnabled) features.add('Vacuum');
    if (mopEnabled) features.add('Mop');
    if (pumpEnabled) features.add('Pump');
    return features.isEmpty ? 'None' : features.join(', ');
  }

  Schedule copyWith({
    String? id,
    DateTime? dateTime,
    CleaningMode? mode,
    bool? vacuumEnabled,
    bool? mopEnabled,
    bool? pumpEnabled,
    bool? isCompleted,
    DateTime? createdAt,
  }) {
    return Schedule(
      id: id ?? this.id,
      dateTime: dateTime ?? this.dateTime,
      mode: mode ?? this.mode,
      vacuumEnabled: vacuumEnabled ?? this.vacuumEnabled,
      mopEnabled: mopEnabled ?? this.mopEnabled,
      pumpEnabled: pumpEnabled ?? this.pumpEnabled,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
