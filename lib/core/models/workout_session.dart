import 'package:hive_flutter/hive_flutter.dart';
import 'package:pose_app/core/models/exercise_rep.dart';

part 'workout_session.g.dart';

/// 单次深蹲记录（保持向后兼容，标记为废弃）
@Deprecated('Use ExerciseRep instead')
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

  /// 从通用ExerciseRep创建
  factory SquatRep.fromExerciseRep(ExerciseRep rep) {
    return SquatRep(
      minKneeAngle: rep.keyMetrics['minKneeAngle'] ?? 0,
      maxKneeAngle: rep.keyMetrics['maxKneeAngle'] ?? 0,
      isGoodForm: (rep.keyMetrics['isGoodForm'] ?? 0) > 0.5,
      timestamp: rep.timestamp,
    );
  }
}

/// 一次锻炼会话（扩展为通用）
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

  // 通用字段
  @HiveField(7)
  final String exerciseType; // 动作类型：'squat', 'pushup'...

  @HiveField(8)
  final Map<String, dynamic> stats; // 通用统计数据

  WorkoutSession({
    required this.id,
    required this.startTime,
    required this.endTime,
    this.totalReps = 0,
    this.goodFormReps = 0,
    this.avgKneeAngle = 0,
    List<SquatRep>? reps,
    this.exerciseType = 'squat', // 默认深蹲（向后兼容）
    Map<String, dynamic>? stats,
  })  : reps = reps ?? [],
        stats = stats ?? {} {
    // 向后兼容：如果是旧数据，自动填充exerciseType
    if (exerciseType.isEmpty) {
      // 无法自动填充，使用默认值
    }
  }

  /// 达标率
  double get goodFormRate =>
      totalReps > 0 ? goodFormReps / totalReps * 100 : 0;

  /// 获取统计（优先通用stats，否则返回旧字段）
  Map<String, dynamic> getStats() {
    if (stats.isNotEmpty) return stats;

    // 向后兼容：返回旧字段
    return {
      'totalReps': totalReps,
      'goodReps': goodFormReps,
      'avgKneeAngle': avgKneeAngle,
      'goodRate': goodFormRate,
    };
  }

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
