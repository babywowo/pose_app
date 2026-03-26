import 'package:pose_app/core/models/angle_result.dart';
import 'package:pose_app/core/models/exercise_definition.dart';
import 'package:pose_app/core/models/exercise_rep.dart';
import 'package:pose_app/core/models/exercise_state.dart';
import 'package:pose_app/core/services/exercise_analyzer.dart';
import 'package:pose_app/core/services/exercise_loader.dart';
import 'package:pose_app/core/services/state_machine.dart';

/// 通用动作分析器（支持任何基于YAML配置的动作）
/// 适用于深蹲、俯卧撑等需要单个关键关节角度检测的动作
class GenericExerciseAnalyzer implements ExerciseAnalyzer {
  late final ExerciseDefinition _definition;
  late final StateMachine _stateMachine;

  // EMA平滑状态
  final Map<JointAngleType, double> _smoothedAngles = {};
  late final double _emaFactor;
  bool _initialized = false;

  // 本次动作的关键指标
  double _minPrimaryAngle = 180.0;
  double _maxPrimaryAngle = 0.0;

  // 完成的重复记录
  final List<ExerciseRep> _reps = [];

  /// 从配置文件创建分析器
  static Future<GenericExerciseAnalyzer> create(String yamlPath) async {
    final analyzer = GenericExerciseAnalyzer();
    analyzer._definition = await ExerciseLoader.fromYaml(yamlPath);
    analyzer._emaFactor = analyzer._definition.detectionLayers?.getTriggerEmaAlpha() ?? 1.0;
    analyzer._stateMachine = StateMachine(analyzer._definition);

    // 初始化平滑角度为180度
    for (final joint in analyzer._definition.requiredJoints) {
      analyzer._smoothedAngles[joint] = 180.0;
    }

    return analyzer;
  }

  @override
  String get exerciseType => _definition.id;

  @override
  ExerciseDefinition get definition => _definition;

  @override
  int get repCount => _stateMachine.repCount;

  @override
  Map<String, double> get keyMetrics {
    return {
      'minPrimaryAngle': _minPrimaryAngle,
      'maxPrimaryAngle': _maxPrimaryAngle,
    };
  }

  @override
  List<ExerciseRep> get reps => List.unmodifiable(_reps);

  @override
  ExerciseState get currentState {
    final phase = _definition.phases.firstWhere(
      (p) => p.id == _stateMachine.currentStateId,
    );
    return ExerciseState(
      exerciseType: exerciseType,
      currentPhase: _stateMachine.currentStateId,
      phaseLabel: phase.label,
      repCount: repCount,
      keyAngles: Map.from(_smoothedAngles),
      isGoodForm: _definition.qualityRule != null
          ? _isGoodForm(_definition.qualityRule!.goodThreshold)
          : false,
      feedback: '',
      timestamp: DateTime.now(),
    );
  }

  @override
  ExerciseState update(FrameAngles angles) {
    // 检查所有必需关节是否有效
    final requiredAngles = <JointAngleType, double>{};
    for (final joint in _definition.requiredJoints) {
      final angle = angles.getAngleValue(joint);
      if (angle == null || angle <= 0) {
        return currentState; // 无效输入，返回当前状态
      }
      requiredAngles[joint] = angle;
    }

    // 第一次更新：直接使用原始角度初始化平滑值
    if (!_initialized) {
      for (final entry in requiredAngles.entries) {
        _smoothedAngles[entry.key] = entry.value;
      }
      _initialized = true;
    } else {
      // 后续更新：应用EMA平滑
      for (final entry in requiredAngles.entries) {
        final smoothed = _smoothedAngles[entry.key]!;
        _smoothedAngles[entry.key] =
            entry.value * _emaFactor + smoothed * (1 - _emaFactor);
      }
    }

    // 更新最小/最大角度
    final primaryJoint = _definition.qualityRule?.primaryJoint ??
        _definition.requiredJoints.first;
    final currentPrimaryAngle = _smoothedAngles[primaryJoint] ?? 180.0;

    _minPrimaryAngle = _minPrimaryAngle < currentPrimaryAngle
        ? _minPrimaryAngle
        : currentPrimaryAngle;
    _maxPrimaryAngle = _maxPrimaryAngle > currentPrimaryAngle
        ? _maxPrimaryAngle
        : currentPrimaryAngle;

    // 调用状态机的transition方法
    final previousRepCount = _stateMachine.repCount;
    final result = _stateMachine.transition(_smoothedAngles);
    final currentRepCount = result.repCount;

    // 如果完成了新的rep，记录它
    if (currentRepCount > previousRepCount) {
      _reps.add(ExerciseRep(
        exerciseType: exerciseType,
        metrics: {
          'minPrimaryAngle': _minPrimaryAngle,
          'maxPrimaryAngle': _maxPrimaryAngle,
          'isGoodForm': _isGoodForm(_definition.qualityRule?.goodThreshold ?? 0) ? 1.0 : 0.0,
        },
        timestamp: DateTime.now(),
      ));

      // 重置指标
      _minPrimaryAngle = 180.0;
      _maxPrimaryAngle = 0.0;
    }

    return currentState;
  }

  @override
  void reset() {
    _stateMachine.reset();
    _reps.clear();
    _minPrimaryAngle = 180.0;
    _maxPrimaryAngle = 0.0;
    _initialized = false;
  }

  void resetCount() {
    _stateMachine.reset();
    _reps.clear();
    _minPrimaryAngle = 180.0;
    _maxPrimaryAngle = 0.0;
  }

  /// 判断动作是否达标
  bool _isGoodForm(double goodThreshold) {
    final qualityRule = _definition.qualityRule;
    if (qualityRule == null) return false;

    switch (qualityRule.qualityType) {
      case QualityType.lessThanOrEqual:
        return _minPrimaryAngle <= goodThreshold;
      case QualityType.greaterThanOrEqual:
        return _minPrimaryAngle >= goodThreshold;
    }
  }

  /// 获取已完成的重复次数（带详细信息）
  @override
  List<ExerciseRep> getCompletedReps() => List.unmodifiable(_reps);

  /// 获取关键角度值（用于调试）
  @override
  Map<String, double> getKeyAngles(FrameAngles angles) {
    return _smoothedAngles.map(
      (joint, value) => MapEntry(
        joint.toString().split('.').last,
        value,
      ),
    );
  }
}
