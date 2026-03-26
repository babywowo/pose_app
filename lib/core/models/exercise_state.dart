/// 动作状态快照（通用，不绑定具体动作）
class ExerciseState {
  /// 动作类型标识
  final String exerciseType;

  /// 当前阶段ID
  final String currentPhase;

  /// 阶段显示名称
  final String phaseLabel;

  /// 当前计数
  final int repCount;

  /// 关键关节角度（关节ID→角度值）
  final Map<String, double> keyAngles;

  /// 当前动作是否达标
  final bool isGoodForm;

  /// 反馈文案
  final String feedback;

  /// 时间戳
  final DateTime timestamp;

  const ExerciseState({
    required this.exerciseType,
    required this.currentPhase,
    required this.phaseLabel,
    required this.repCount,
    required this.keyAngles,
    required this.isGoodForm,
    required this.feedback,
    required this.timestamp,
  });

  /// 创建初始状态
  static ExerciseState initial({
    required String exerciseType,
    String initialPhase = 'idle',
    String phaseLabel = '未开始',
  }) {
    return ExerciseState(
      exerciseType: exerciseType,
      currentPhase: initialPhase,
      phaseLabel: phaseLabel,
      repCount: 0,
      keyAngles: {},
      isGoodForm: false,
      feedback: '准备开始',
      timestamp: DateTime.now(),
    );
  }

  /// 复制并更新
  ExerciseState copyWith({
    String? exerciseType,
    String? currentPhase,
    String? phaseLabel,
    int? repCount,
    Map<String, double>? keyAngles,
    bool? isGoodForm,
    String? feedback,
    DateTime? timestamp,
  }) {
    return ExerciseState(
      exerciseType: exerciseType ?? this.exerciseType,
      currentPhase: currentPhase ?? this.currentPhase,
      phaseLabel: phaseLabel ?? this.phaseLabel,
      repCount: repCount ?? this.repCount,
      keyAngles: keyAngles ?? this.keyAngles,
      isGoodForm: isGoodForm ?? this.isGoodForm,
      feedback: feedback ?? this.feedback,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  @override
  String toString() {
    return 'ExerciseState($exerciseType, $currentPhase, reps=$repCount)';
  }
}
