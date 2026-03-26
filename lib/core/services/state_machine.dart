import 'package:pose_app/core/models/angle_result.dart';
import 'package:pose_app/core/models/exercise_definition.dart';
import 'package:pose_app/core/services/detection_layers/trigger_layer.dart';

/// 通用状态机引擎
class StateMachine {
  final ExerciseDefinition definition;
  final TriggerLayer _triggerLayer;

  String _currentStateId = '';
  int _repCount = 0;
  final Map<String, double> _repMetrics = {}; // 本次动作的关键指标

  StateMachine(this.definition)
      : _triggerLayer = TriggerLayer(
          emaAlpha: definition.detectionLayers?.getTriggerEmaAlpha() ?? 1.0,
        ) {
    _currentStateId = definition.phases.first.id;
  }

  /// 输入角度值，推进状态机
  StateTransitionResult transition(Map<JointAngleType, double> angles) {
    // 查找当前阶段的所有转换规则
    final transitions = definition.transitions
        .where((t) => t.fromState == _currentStateId)
        .toList();

    // 检查每个转换的触发条件
    for (final trans in transitions) {
      if (_checkConditions(trans.triggers, angles)) {
        // 执行转换
        final previousState = _currentStateId;
        _currentStateId = trans.toState;

        // 记录关键指标（最小值/最大值）
        _recordMetrics(angles, previousState, trans.toState);

        // 检查是否计数
        bool counted = false;
        if (trans.shouldCountRep) {
          _repCount++;
          counted = true;
        }

        return StateTransitionResult(
          previousState: previousState,
          newState: _currentStateId,
          counted: counted,
          repCount: _repCount,
          feedback: trans.onRepFeedback ?? _getPhaseFeedback(_currentStateId),
        );
      }
    }

    // 无转换发生
    return StateTransitionResult.noTransition(
      newState: _currentStateId,
      repCount: _repCount,
    );
  }

  /// 验证条件是否满足
  bool _checkConditions(List<JointCondition> conditions, Map<JointAngleType, double> angles) {
    if (conditions.isEmpty) return false;

    for (final cond in conditions) {
      // 执行聚合逻辑
      final value = _executeAggregation(cond.joint, cond.aggregation, angles);
      if (value == null) return false;

      // 直接使用Cond的check方法（不做额外平滑）
      // 注意：EMA平滑已在SquatAnalyzer中完成（factor=1.0=无平滑）
      if (!cond.check(value)) {
        return false;
      }
    }
    return true;
  }

  /// 执行聚合逻辑
  double? _executeAggregation(JointAngleType joint, AggregationType aggType, Map<JointAngleType, double> angles) {
    switch (aggType) {
      case AggregationType.left:
        return angles[joint];
      case AggregationType.right:
        return angles[joint];
      case AggregationType.avg:
        // 对于对称关节（如leftKnee），计算left和right的平均值
        final symmetricJoint = _getSymmetricJoint(joint);
        final value1 = angles[joint];
        final value2 = angles[symmetricJoint];
        if (value1 == null || value2 == null) return value1;
        return (value1 + value2) / 2;
    }
  }

  /// 获取对称关节
  JointAngleType _getSymmetricJoint(JointAngleType joint) {
    switch (joint) {
      case JointAngleType.leftKnee:
        return JointAngleType.rightKnee;
      case JointAngleType.rightKnee:
        return JointAngleType.leftKnee;
      case JointAngleType.leftHip:
        return JointAngleType.rightHip;
      case JointAngleType.rightHip:
        return JointAngleType.leftHip;
      default:
        return joint; // 默认返回自己
    }
  }

  /// 聚合左右关节角度（对称关节）
  double? aggregateSymmetricJoint(JointAngleType leftJoint, JointAngleType rightJoint, AggregationType aggType, Map<JointAngleType, double> angles) {
    final leftValue = angles[leftJoint];
    final rightValue = angles[rightJoint];

    if (leftValue == null || rightValue == null) return null;

    switch (aggType.index) {
      case 0:
        return leftValue;
      case 1:
        return rightValue;
      case 2:
        return (leftValue + rightValue) / 2;
      default:
        return null;
    }
  }

  /// 记录关键指标（最小值/最大值）
  void _recordMetrics(Map<JointAngleType, double> angles, String from, String to) {
    // 根据阶段转换记录关键指标
    // 例如：descending→bottom 时记录膝角最小值
    // 这些规则可以硬编码或配置化

    if (definition.qualityRule != null) {
      final primaryJoint = definition.qualityRule!.primaryJoint;
      // 注意：qualityRule没有aggregation属性，我们假设使用avg
      final value = _executeAggregation(primaryJoint, AggregationType.avg, angles);

      if (value != null) {
        // 简单逻辑：记录本次动作的最小值
        if (_repMetrics['minValue'] == null || value < (_repMetrics['minValue']!)) {
          _repMetrics['minValue'] = value;
        }
        if (_repMetrics['maxValue'] == null || value > (_repMetrics['maxValue']!)) {
          _repMetrics['maxValue'] = value;
        }
      }
    }
  }

  /// 获取当前指标
  Map<String, double> get currentMetrics => Map.from(_repMetrics);

  /// 重置指标（开始新动作时调用）
  void resetMetrics() {
    _repMetrics.clear();
  }

  /// 获取阶段反馈文案
  String _getPhaseFeedback(String stateId) {
    try {
      return definition.phases.firstWhere(
        (p) => p.id == stateId,
      ).feedback;
    } catch (e) {
      return '';
    }
  }

  /// 重置状态机
  void reset() {
    _currentStateId = definition.phases.first.id;
    _repCount = 0;
    _repMetrics.clear();
  }

  String get currentStateId => _currentStateId;
  int get repCount => _repCount;
}

/// 状态转换结果
class StateTransitionResult {
  final String? previousState;
  final String newState;
  final bool counted;
  final int repCount;
  final String feedback;

  const StateTransitionResult({
    required this.newState,
    required this.repCount,
    required this.feedback,
    this.previousState,
    required this.counted,
  });

  const StateTransitionResult.noTransition({
    required this.newState,
    required this.repCount,
  })  : previousState = null,
        counted = false,
        feedback = '';

  bool get hasTransition => previousState != null;

  @override
  String toString() {
    return 'StateTransitionResult($previousState → $newState, counted=$counted)';
  }
}
