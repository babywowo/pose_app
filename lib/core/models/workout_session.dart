import 'package:hive_flutter/hive_flutter.dart';

part 'workout_session.g.dart';

/// 单次深蹲记录
@HiveType(typeId: 0)
class SquatRep extends HiveObject {
  @HiveField(0)
  final double minKneeAngle; // 最低点膝盖角度

  @HiveField(1)
  final double maxKneeAngle; // 最高点膝盖角度

  @HiveField(2)
  final bool isGoodForm; // 是否标准

  @HiveField(3)
  final DateTime timestamp;

  SquatRep({
    required this.minKneeAngle,
    required this.maxKneeAngle,
    required this.isGoodForm,
    required this.timestamp,
  });
}

/// 一次锻炼会话
@HiveType(typeId: 1)
class WorkoutSession extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final DateTime startTime;

  @HiveField(2)
  DateTime endTime;

  @HiveField(3)
  int totalReps;

  @HiveField(4)
  int goodFormReps;

  @HiveField(5)
  double avgKneeAngle;

  @HiveField(6)
  List<SquatRep> reps;

  WorkoutSession({
    required this.id,
    required this.startTime,
    required this.endTime,
    this.totalReps = 0,
    this.goodFormReps = 0,
    this.avgKneeAngle = 0,
    List<SquatRep>? reps,
  }) : reps = reps ?? [];

  /// 达标率
  double get goodFormRate =>
      totalReps > 0 ? goodFormReps / totalReps * 100 : 0;

  /// 锻炼时长（秒）
  int get durationSeconds => endTime.difference(startTime).inSeconds;

  String get durationFormatted {
    final minutes = durationSeconds ~/ 60;
    final seconds = durationSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  factory WorkoutSession.start() {
    final now = DateTime.now();
    return WorkoutSession(
      id: now.millisecondsSinceEpoch.toString(),
      startTime: now,
      endTime: now,
    );
  }
}
