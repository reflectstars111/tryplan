// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'plan_event.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PlanEventAdapter extends TypeAdapter<PlanEvent> {
  @override
  final int typeId = 0;

  @override
  PlanEvent read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PlanEvent(
      id: fields[0] as String?,
      title: fields[1] as String,
      startTime: fields[2] as DateTime?,
      endTime: fields[3] as DateTime?,
      location: fields[4] as String?,
      isImportant: fields[5] as bool,
      isUrgent: fields[6] as bool,
      isCompleted: fields[7] as bool,
      sortOrder: fields[8] as int,
      isHabit: fields[9] as bool,
      streakDates: (fields[10] as List?)?.cast<DateTime>(),
      habitExceptions: (fields[11] as Map?)?.map((dynamic k, dynamic v) =>
          MapEntry(k as String, (v as Map).cast<String, DateTime?>())),
      isCountdown: fields[12] as bool,
      deadline: fields[13] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, PlanEvent obj) {
    writer
      ..writeByte(14)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.startTime)
      ..writeByte(3)
      ..write(obj.endTime)
      ..writeByte(4)
      ..write(obj.location)
      ..writeByte(5)
      ..write(obj.isImportant)
      ..writeByte(6)
      ..write(obj.isUrgent)
      ..writeByte(7)
      ..write(obj.isCompleted)
      ..writeByte(8)
      ..write(obj.sortOrder)
      ..writeByte(9)
      ..write(obj.isHabit)
      ..writeByte(10)
      ..write(obj.streakDates)
      ..writeByte(11)
      ..write(obj.habitExceptions)
      ..writeByte(12)
      ..write(obj.isCountdown)
      ..writeByte(13)
      ..write(obj.deadline);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlanEventAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
