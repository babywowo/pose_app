// GENERATED CODE - manually written (no code gen)
// ignore_for_file: type=lint

part of 'workout_session.dart';

// **************************************************************************
// TypeAdapterGenerator - Manual
// **************************************************************************

class SquatRepAdapter extends TypeAdapter<SquatRep> {
  @override
  final int typeId = 0;

  @override
  SquatRep read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SquatRep(
      minKneeAngle: fields[0] as double,
      maxKneeAngle: fields[1] as double,
      isGoodForm: fields[2] as bool,
      timestamp: fields[3] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, SquatRep obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.minKneeAngle)
      ..writeByte(1)
      ..write(obj.maxKneeAngle)
      ..writeByte(2)
      ..write(obj.isGoodForm)
      ..writeByte(3)
      ..write(obj.timestamp);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SquatRepAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;

  @override
  int get hashCode => typeId.hashCode;
}

class WorkoutSessionAdapter extends TypeAdapter<WorkoutSession> {
  @override
  final int typeId = 1;

  @override
  WorkoutSession read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return WorkoutSession(
      id: fields[0] as String,
      startTime: fields[1] as DateTime,
      endTime: fields[2] as DateTime,
      totalReps: fields[3] as int,
      goodFormReps: fields[4] as int,
      avgKneeAngle: fields[5] as double,
      reps: (fields[6] as List).cast<SquatRep>(),
    );
  }

  @override
  void write(BinaryWriter writer, WorkoutSession obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.startTime)
      ..writeByte(2)
      ..write(obj.endTime)
      ..writeByte(3)
      ..write(obj.totalReps)
      ..writeByte(4)
      ..write(obj.goodFormReps)
      ..writeByte(5)
      ..write(obj.avgKneeAngle)
      ..writeByte(6)
      ..write(obj.reps);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WorkoutSessionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;

  @override
  int get hashCode => typeId.hashCode;
}
