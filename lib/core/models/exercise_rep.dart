import 'package:hive_flutter/hive_flutter.dart';

/// 动作重复记录（通用）
class ExerciseRep {
  /// 动作类型
  final String exerciseType;

  /// 时间戳
  final DateTime timestamp;

  /// 关键指标（如最小膝角、是否达标等）
  final Map<String, double> metrics;

  const ExerciseRep({
    required this.exerciseType,
    required this.timestamp,
    required this.metrics,
  });

  /// 转换为Map（Hive存储）
  Map<String, dynamic> toMap() {
    return {
      'exerciseType': exerciseType,
      'timestamp': timestamp.toIso8601String(),
      'metrics': metrics,
    };
  }

  /// 从Map创建
  factory ExerciseRep.fromMap(Map<String, dynamic> map) {
    return ExerciseRep(
      exerciseType: map['exerciseType'] as String,
      timestamp: DateTime.parse(map['timestamp'] as String),
      metrics: Map<String, double>.from(map['metrics'] as Map),
    );
  }

  /// 向后兼容：keyMetrics 别名
  Map<String, double> get keyMetrics => metrics;

  @override
  String toString() {
    return 'ExerciseRep($exerciseType, ${timestamp.toIso8601String()})';
  }
}

/// 动作重复记录适配器（Hive）
class ExerciseRepAdapter extends TypeAdapter<ExerciseRep> {
  @override
  final int typeId = 100;

  @override
  ExerciseRep read(BinaryReader reader) {
    final map = reader.readMap();
    return ExerciseRep.fromMap(
      map.map((key, value) => MapEntry(key.toString(), value)),
    );
  }

  @override
  void write(BinaryWriter writer, ExerciseRep obj) {
    writer.writeMap(obj.toMap());
  }
}
