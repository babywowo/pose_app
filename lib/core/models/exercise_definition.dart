import 'package:pose_app/core/models/angle_result.dart';

/// 动作定义（从YAML/JSON解析）
class ExerciseDefinition {
  /// 动作ID
  final String id;

  /// 动作显示名称
  final String name;

  /// 动作描述
  final String description;

  /// 阶段列表
  final List<ExercisePhase> phases;

  /// 转换规则列表
  final List<ExerciseTransition> transitions;

  /// 需要计算的关键关节（AngleCalculator会优先计算这些）
  final List<JointAngleType> requiredJoints;

  /// 质量评估规则
  final QualityRule? qualityRule;

  /// 聚合类型（默认使用平均值）
  final AggregationType defaultAggregation;

  /// 层次化检测配置
  final DetectionLayersConfig? detectionLayers;

  const ExerciseDefinition({
    required this.id,
    required this.name,
    required this.description,
    required this.phases,
    required this.transitions,
    required this.requiredJoints,
    this.qualityRule,
    this.defaultAggregation = AggregationType.avg,
    this.detectionLayers,
  });

  /// 根据ID获取阶段
  ExercisePhase getPhase(String phaseId) {
    return phases.firstWhere((p) => p.id == phaseId);
  }

  /// 获取初始阶段
  ExercisePhase get initialPhase => phases.first;

  /// 从YAML Map创建
  factory ExerciseDefinition.fromYaml(Map<String, dynamic> yaml) {
    return ExerciseDefinition(
      id: yaml['id'] as String,
      name: yaml['name'] as String,
      description: yaml['description'] as String,
      phases: (yaml['phases'] as List)
          .map((p) => ExercisePhase.fromYaml(
                p as Map<dynamic, dynamic>,
              ))
          .toList(),
      transitions: (yaml['transitions'] as List)
          .map((t) => ExerciseTransition.fromYaml(
                t as Map<dynamic, dynamic>,
              ))
          .toList(),
      requiredJoints: (yaml['required_joints'] as List)
          .map((j) => _parseJointAngle(j as String))
          .toList(),
      qualityRule: yaml.containsKey('quality_rule')
          ? QualityRule.fromYaml(
              yaml['quality_rule'] as Map<dynamic, dynamic>,
            )
          : null,
      defaultAggregation: yaml.containsKey('aggregation')
          ? _parseAggregation(yaml['aggregation'] as String)
          : AggregationType.avg,
      detectionLayers: yaml.containsKey('detection_layers')
          ? DetectionLayersConfig.fromYaml(
              yaml['detection_layers'] as Map<dynamic, dynamic>,
            )
          : null,
    );
  }

  /// 解析关节角度类型字符串（支持驼峰和下划线命名）
  static JointAngleType _parseJointAngle(String str) {
    switch (str.toLowerCase()) {
      case 'left_knee':
      case 'leftknee':
        return JointAngleType.leftKnee;
      case 'right_knee':
      case 'rightknee':
        return JointAngleType.rightKnee;
      case 'left_elbow':
      case 'leftelbow':
        return JointAngleType.leftElbow;
      case 'right_elbow':
      case 'rightelbow':
        return JointAngleType.rightElbow;
      case 'left_hip':
      case 'lefthip':
        return JointAngleType.leftHip;
      case 'right_hip':
      case 'righthip':
        return JointAngleType.rightHip;
      case 'left_shoulder':
      case 'leftshoulder':
        return JointAngleType.leftShoulder;
      case 'right_shoulder':
      case 'rightshoulder':
        return JointAngleType.rightShoulder;
      default:
        throw ArgumentError('Unknown joint angle: $str');
    }
  }

  /// 解析聚合类型字符串
  static AggregationType _parseAggregation(String str) {
    switch (str.toLowerCase()) {
      case 'left':
        return AggregationType.left;
      case 'right':
        return AggregationType.right;
      case 'avg':
      case 'average':
        return AggregationType.avg;
      default:
        throw ArgumentError('Unknown aggregation type: $str');
    }
  }
}

/// 动作阶段
class ExercisePhase {
  /// 阶段ID
  final String id;

  /// 阶段显示名称
  final String label;

  /// 阶段反馈文案
  final String feedback;

  /// 进入该阶段的条件（可选，用于守卫）
  final List<JointCondition>? conditions;

  const ExercisePhase({
    required this.id,
    required this.label,
    required this.feedback,
    this.conditions,
  });

  /// 从YAML Map创建
  factory ExercisePhase.fromYaml(Map<dynamic, dynamic> yaml) {
    return ExercisePhase(
      id: yaml['id'] as String,
      label: yaml['label'] as String,
      feedback: yaml['feedback'] as String,
      conditions: yaml.containsKey('conditions')
          ? (yaml['conditions'] as List)
              .map((c) => JointCondition.fromYaml(
                    c as Map<dynamic, dynamic>,
                  ))
              .toList()
          : null,
    );
  }
}

/// 关节条件（用于状态守卫和转换触发）
class JointCondition {
  /// 关节类型
  final JointAngleType joint;

  /// 最小角度
  final double? min;

  /// 最大角度
  final double? max;

  /// 比较操作符
  final String operator; // '<', '>', 'between'

  /// 聚合类型（左/右/平均）
  final AggregationType aggregation;

  const JointCondition({
    required this.joint,
    this.min,
    this.max,
    required this.operator,
    this.aggregation = AggregationType.avg,
  });

  /// 验证角度是否满足条件
  /// 支持的操作符和参数：
  /// - '<':  value < max  (要求提供max)
  /// - '>':  value > min  (要求提供min)
  /// - 'between': value >= min && value <= max (要求同时提供min和max)
  /// - '>=': value >= min (要求提供min)
  /// - '<=': value <= max (要求提供max)
  bool check(double value) {
    switch (operator) {
      case '<':
        // value < max (例如膝角<150°开始下蹲)
        if (max == null) {
          throw ArgumentError('Operator "<" requires "max" parameter');
        }
        return value < max!;
      case '>':
        // value > min (例如膝角>100°开始起身)
        if (min == null) {
          throw ArgumentError('Operator ">" requires "min" parameter');
        }
        return value > min!;
      case 'between':
        // min <= value <= max
        if (min == null || max == null) {
          throw ArgumentError('Operator "between" requires both "min" and "max" parameters');
        }
        return value >= min! && value <= max!;
      case '>=':
        // value >= min
        if (min == null) {
          throw ArgumentError('Operator ">=" requires "min" parameter');
        }
        return value >= min!;
      case '<=':
        // value <= max
        if (max == null) {
          throw ArgumentError('Operator "<=" requires "max" parameter');
        }
        return value <= max!;
      default:
        return false;
    }
  }

  /// 从YAML Map创建
  factory JointCondition.fromYaml(Map<dynamic, dynamic> yaml) {
    return JointCondition(
      joint: ExerciseDefinition._parseJointAngle(yaml['joint'] as String),
      min: yaml.containsKey('min') ? (yaml['min'] as num).toDouble() : null,
      max: yaml.containsKey('max') ? (yaml['max'] as num).toDouble() : null,
      operator: yaml['operator'] as String,
      aggregation: yaml.containsKey('aggregation')
          ? _parseAggregation(yaml['aggregation'] as String)
          : AggregationType.avg,
    );
  }

  /// 解析聚合类型字符串
  static AggregationType _parseAggregation(String str) {
    switch (str.toLowerCase()) {
      case 'left':
        return AggregationType.left;
      case 'right':
        return AggregationType.right;
      case 'avg':
      case 'average':
        return AggregationType.avg;
      default:
        throw ArgumentError('Unknown aggregation type: $str');
    }
  }

  @override
  String toString() {
    return 'JointCondition($joint, $operator, min=$min, max=$max)';
  }
}

/// 聚合类型（处理左右对称关节）
enum AggregationType {
  left,
  right,
  avg,
}

extension AggregationTypeExt on AggregationType {
  String get displayName {
    switch (index) {
      case 0:
        return '左侧';
      case 1:
        return '右侧';
      case 2:
        return '平均';
      default:
        return '';
    }
  }
}

/// 状态转换规则
class ExerciseTransition {
  /// 源阶段ID
  final String fromState;

  /// 目标阶段ID
  final String toState;

  /// 触发条件列表（所有条件必须AND）
  final List<JointCondition> triggers;

  /// 此转换是否触发计数（+1）
  final bool shouldCountRep;

  /// 计数时的反馈文案
  final String? onRepFeedback;

  const ExerciseTransition({
    required this.fromState,
    required this.toState,
    required this.triggers,
    this.shouldCountRep = false,
    this.onRepFeedback,
  });

  /// 从YAML Map创建
  factory ExerciseTransition.fromYaml(Map<dynamic, dynamic> yaml) {
    return ExerciseTransition(
      fromState: yaml['from'] as String,
      toState: yaml['to'] as String,
      triggers: (yaml['triggers'] as List)
          .map((t) => JointCondition.fromYaml(
                t as Map<dynamic, dynamic>,
              ))
          .toList(),
      shouldCountRep: yaml.containsKey('should_count_rep') ? (yaml['should_count_rep'] as bool) : false,
      onRepFeedback: yaml.containsKey('on_rep_feedback')
          ? yaml['on_rep_feedback'] as String
          : null,
    );
  }

  @override
  String toString() {
    return 'Transition($fromState → $toState, count=$shouldCountRep)';
  }
}

/// 质量评估规则
class QualityRule {
  /// 主要关节（用于判断动作质量）
  final JointAngleType primaryJoint;

  /// 达标阈值
  final double goodThreshold;

  /// 达标反馈
  final String goodFeedback;

  /// 未达标反馈
  final String badFeedback;

  /// 阈值比较类型（小于达标或大于达标）
  final QualityType qualityType;

  const QualityRule({
    required this.primaryJoint,
    required this.goodThreshold,
    required this.goodFeedback,
    required this.badFeedback,
    this.qualityType = QualityType.lessThanOrEqual,
  });

  /// 从YAML Map创建
  factory QualityRule.fromYaml(Map<dynamic, dynamic> yaml) {
    return QualityRule(
      primaryJoint: ExerciseDefinition._parseJointAngle(
        yaml['primary_joint'] as String,
      ),
      goodThreshold: (yaml['good_threshold'] as num).toDouble(),
      goodFeedback: yaml['good_feedback'] as String,
      badFeedback: yaml['bad_feedback'] as String,
      qualityType: yaml.containsKey('quality_type')
          ? _parseQualityType(yaml['quality_type'] as String)
          : QualityType.lessThanOrEqual,
    );
  }

  /// 解析质量判断类型（支持驼峰和下划线命名）
  static QualityType _parseQualityType(String str) {
    switch (str.toLowerCase()) {
      case 'less_than_or_equal':
      case 'lessthanorequal':
      case '<=':
        return QualityType.lessThanOrEqual;
      case 'greater_than_or_equal':
      case 'greaterthanorequal':
      case '>=':
        return QualityType.greaterThanOrEqual;
      default:
        throw ArgumentError('Unknown quality type: $str');
    }
  }

  /// 判断是否达标
  bool isGood(double value) {
    switch (qualityType) {
      case QualityType.lessThanOrEqual:
        return value <= goodThreshold;
      case QualityType.greaterThanOrEqual:
        return value >= goodThreshold;
    }
  }
}

/// 质量判断类型
enum QualityType {
  lessThanOrEqual,  // 小于等于达标（如深蹲膝角≤90°）
  greaterThanOrEqual, // 大于等于达标
}

/// 层次化检测配置
class DetectionLayersConfig {
  /// 第一层：触发机制配置
  final TriggerLayerConfig? trigger;

  /// 第二层：稳定性检测配置
  final StabilityLayerConfig? stability;

  /// 第三层：过渡平滑配置
  final TransitionLayerConfig? transition;

  const DetectionLayersConfig({
    this.trigger,
    this.stability,
    this.transition,
  });

  /// 从YAML Map创建
  factory DetectionLayersConfig.fromYaml(Map<dynamic, dynamic> yaml) {
    return DetectionLayersConfig(
      trigger: yaml.containsKey('trigger')
          ? TriggerLayerConfig.fromYaml(
              yaml['trigger'] as Map<dynamic, dynamic>,
            )
          : null,
      stability: yaml.containsKey('stability')
          ? StabilityLayerConfig.fromYaml(
              yaml['stability'] as Map<dynamic, dynamic>,
            )
          : null,
      transition: yaml.containsKey('transition')
          ? TransitionLayerConfig.fromYaml(
              yaml['transition'] as Map<dynamic, dynamic>,
            )
          : null,
    );
  }

  /// 获取触发层EMA因子（默认1.0）
  double getTriggerEmaAlpha() {
    return trigger?.config?.emaAlpha ?? 1.0;
  }
}

/// 第一层：触发机制配置
class TriggerLayerConfig {
  /// 是否启用
  final bool enabled;

  /// 触发层详细配置
  final TriggerConfig? config;

  const TriggerLayerConfig({
    required this.enabled,
    this.config,
  });

  /// 从YAML Map创建
  factory TriggerLayerConfig.fromYaml(Map<dynamic, dynamic> yaml) {
    return TriggerLayerConfig(
      enabled: yaml['enabled'] as bool? ?? true,
      config: yaml.containsKey('config')
          ? TriggerConfig.fromYaml(
              yaml['config'] as Map<dynamic, dynamic>,
            )
          : null,
    );
  }
}

/// 触发层详细配置
class TriggerConfig {
  /// EMA平滑因子（1.0 = 无平滑，0.3 = 中等平滑）
  final double emaAlpha;

  const TriggerConfig({
    required this.emaAlpha,
  });

  /// 从YAML Map创建
  factory TriggerConfig.fromYaml(Map<dynamic, dynamic> yaml) {
    return TriggerConfig(
      emaAlpha: (yaml['ema_alpha'] as num?)?.toDouble() ?? 1.0,
    );
  }
}

/// 第二层：稳定性检测配置
class StabilityLayerConfig {
  /// 是否启用
  final bool enabled;

  /// 稳定性层详细配置
  final StabilityConfig? config;

  const StabilityLayerConfig({
    required this.enabled,
    this.config,
  });

  /// 从YAML Map创建
  factory StabilityLayerConfig.fromYaml(Map<dynamic, dynamic> yaml) {
    return StabilityLayerConfig(
      enabled: yaml['enabled'] as bool? ?? false,
      config: yaml.containsKey('config')
          ? StabilityConfig.fromYaml(
              yaml['config'] as Map<dynamic, dynamic>,
            )
          : null,
    );
  }
}

/// 稳定性层详细配置
class StabilityConfig {
  /// 最小持续时间（毫秒）
  final int minDurationMs;

  /// 允许的波动范围（度）
  final int tolerance;

  /// 检查窗口大小（帧数）
  final int windowSize;

  const StabilityConfig({
    required this.minDurationMs,
    required this.tolerance,
    required this.windowSize,
  });

  /// 从YAML Map创建
  factory StabilityConfig.fromYaml(Map<dynamic, dynamic> yaml) {
    return StabilityConfig(
      minDurationMs: (yaml['min_duration_ms'] as int?) ?? 500,
      tolerance: (yaml['tolerance'] as int?) ?? 5,
      windowSize: (yaml['window_size'] as int?) ?? 30,
    );
  }
}

/// 第三层：过渡平滑配置
class TransitionLayerConfig {
  /// 是否启用
  final bool enabled;

  /// 过渡层详细配置
  final TransitionConfig? config;

  const TransitionLayerConfig({
    required this.enabled,
    this.config,
  });

  /// 从YAML Map创建
  factory TransitionLayerConfig.fromYaml(Map<dynamic, dynamic> yaml) {
    return TransitionLayerConfig(
      enabled: yaml['enabled'] as bool? ?? false,
      config: yaml.containsKey('config')
          ? TransitionConfig.fromYaml(
              yaml['config'] as Map<dynamic, dynamic>,
            )
          : null,
    );
  }
}

/// 过渡层详细配置
class TransitionConfig {
  /// 平滑度阈值（每帧最大变化角度）
  final int smoothnessThreshold;

  /// 评估窗口（前后各N帧）
  final int evaluationWindow;

  const TransitionConfig({
    required this.smoothnessThreshold,
    required this.evaluationWindow,
  });

  /// 从YAML Map创建
  factory TransitionConfig.fromYaml(Map<dynamic, dynamic> yaml) {
    return TransitionConfig(
      smoothnessThreshold: (yaml['smoothness_threshold'] as int?) ?? 10,
      evaluationWindow: (yaml['evaluation_window'] as int?) ?? 20,
    );
  }
}
