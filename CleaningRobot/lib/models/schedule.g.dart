// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'schedule.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ScheduleAdapter extends TypeAdapter<Schedule> {
  @override
  final int typeId = 1;

  @override
  Schedule read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Schedule(
      id: fields[0] as String,
      dateTime: fields[1] as DateTime,
      mode: fields[2] as CleaningMode,
      vacuumEnabled: fields[3] as bool,
      mopEnabled: fields[4] as bool,
      pumpEnabled: fields[5] as bool,
      isCompleted: fields[6] as bool,
      createdAt: fields[7] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, Schedule obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.dateTime)
      ..writeByte(2)
      ..write(obj.mode)
      ..writeByte(3)
      ..write(obj.vacuumEnabled)
      ..writeByte(4)
      ..write(obj.mopEnabled)
      ..writeByte(5)
      ..write(obj.pumpEnabled)
      ..writeByte(6)
      ..write(obj.isCompleted)
      ..writeByte(7)
      ..write(obj.createdAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ScheduleAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class CleaningModeAdapter extends TypeAdapter<CleaningMode> {
  @override
  final int typeId = 0;

  @override
  CleaningMode read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return CleaningMode.autonomous;
      case 1:
        return CleaningMode.manual;
      default:
        return CleaningMode.autonomous;
    }
  }

  @override
  void write(BinaryWriter writer, CleaningMode obj) {
    switch (obj) {
      case CleaningMode.autonomous:
        writer.writeByte(0);
        break;
      case CleaningMode.manual:
        writer.writeByte(1);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CleaningModeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
