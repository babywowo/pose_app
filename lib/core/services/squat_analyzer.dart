import 'package:pose_app/core/models/angle_result.dart';
import 'package:pose_app/core/models/exercise_definition.dart';
import 'package:pose_app/core/models/exercise_rep.dart';
import 'package:pose_app/core/models/exercise_state.dart';
import 'package:pose_app/core/services/exercise_analyzer.dart';
import 'package:pose_app/core/services/exercise_loader.dart';
import 'package:pose_app/core/services/state_machine.dart';

/// 深蹲分析器（使用新通用架构）
class SquatAnalyzer implements ExerciseAnalyzer {
  late final ExerciseDefinition _definition;
  late final StateMachine _stateMachine;

  // EMA平滑状态（从配置加载emaAlpha）
  double _smoothedLeft = 180.0;
  double _smoothedRight = 180.0;
  late final double _emaFactor; // 从detection_layers配置加载
  bool _initialized = false; // 是否已初始化

  // 本次下蹲的最小角度
  double _minAngleDuringRep = 180.0;

  // 完成的重复记录
  final List<ExerciseRep> _reps = [];

  /// 从配置文件创建分析器
  static Future<SquatAnalyzer> create() async {
    final analyzer = SquatAnalyzer();
    analyzer._definition = await ExerciseLoader.fromYaml('assets/exercises/squat.exercise.yaml');
    analyzer._emaFactor = analyzer._definition.detectionLayers?.getTriggerEmaAlpha() ?? 1.0;
    analyzer._stateMachine = StateMachine(analyzer._definition);
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
      'minKneeAngle': _minAngleDuringRep,
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
      keyAngles: {
        'leftKnee': _smoothedLeft,
        'rightKnee': _smoothedRight,
      },
      isGoodForm: _definition.qualityRule != null
          ? _minAngleDuringRep <= _definition.qualityRule!.goodThreshold
          : false,
      feedback: '',
      timestamp: DateTime.now(),
    );
  }

  @override
  ExerciseState update(FrameAngles angles) {
    // 获取原始角度
    final leftAngle = angles.getAngleValue(JointAngleType.leftKnee);
    final rightAngle = angles.getAngleValue(JointAngleType.rightKnee);

    // 检查角度有效性：null或0视为无效输入
    final isInvalid = leftAngle == null || rightAngle == null || leftAngle <= 0 || rightAngle <= 0;

    // 如果输入无效，直接返回当前状态，不更新任何内部状态
    if (isInvalid) {
      return currentState;
    }

    // 第一次更新：直接使用原始角度初始化平滑值
    if (!_initialized) {
      _smoothedLeft = leftAngle!;
      _smoothedRight = rightAngle!;
      _initialized = true;
    } else {
      // 后续更新：应用EMA平滑
      _smoothedLeft = leftAngle! * _emaFactor + _smoothedLeft * (1 - _emaFactor);
      _smoothedRight = rightAngle! * _emaFactor + _smoothedRight * (1 - _emaFactor);
    }

    // 取平均值（用于质量判断）
    final avgAngle = (_smoothedLeft + _smoothedRight) / 2;

    // 更新最小角度
    if (avgAngle < _minAngleDuringRep) {
      _minAngleDuringRep = avgAngle;
    }

    // 构建状态机输入（传入原始左右角度，由TriggerLayer的EMA处理）
    final jointAngles = <JointAngleType, double>{
      JointAngleType.leftKnee: leftAngle,
      JointAngleType.rightKnee: rightAngle,
    };

    // 推进状态机
    final result = _stateMachine.transition(jointAngles);

    // 如果计数，记录rep
    if (result.counted) {
      final isGood = _definition.qualityRule != null
          ? _minAngleDuringRep <= _definition.qualityRule!.goodThreshold
          : false;

      _reps.add(ExerciseRep(
        exerciseType: exerciseType,
        timestamp: DateTime.now(),
        metrics: {
          'minKneeAngle': _minAngleDuringRep,
          'isGoodForm': isGood ? 1.0 : 0.0,
        },
      ));

      // 重置最小角度
      _minAngleDuringRep = 180.0;
    }

    // 计算质量评估
    final isGoodForm = _definition.qualityRule != null
        ? _minAngleDuringRep <= _definition.qualityRule!.goodThreshold
        : false;

    // 获取反馈
    final feedback = result.counted && _definition.qualityRule != null
        ? (isGoodForm
            ? _definition.qualityRule!.goodFeedback
            : _definition.qualityRule!.badFeedback)
        : result.feedback;

    // 获取阶段反馈（如果计数没有反馈）
    final phase = _definition.phases.firstWhere(
      (p) => p.id == _stateMachine.currentStateId,
    );
    final phaseFeedback = feedback.isEmpty
        ? phase.feedback
        : feedback;

    return ExerciseState(
      exerciseType: exerciseType,
      currentPhase: _stateMachine.currentStateId,
      phaseLabel: phase.label,
      repCount: result.repCount,
      keyAngles: {
        'leftKnee': _smoothedLeft,
        'rightKnee': _smoothedRight,
      },
      isGoodForm: isGoodForm,
      feedback: phaseFeedback,
      timestamp: DateTime.now(),
    );
  }

  @override
  void reset() {
    _stateMachine.reset();
    _minAngleDuringRep = 180.0;
    _smoothedLeft = 180.0;
    _smoothedRight = 180.0;
    _initialized = false;
    _reps.clear();
  }

  @override
  Map<String, double> getKeyAngles(FrameAngles angles) {
    return {
      'leftKnee': angles.getAngleValue(JointAngleType.leftKnee) ?? 0,
      'rightKnee': angles.getAngleValue(JointAngleType.rightKnee) ?? 0,
    };
  }

  @override
  List<ExerciseRep> getCompletedReps() {
    return List.unmodifiable(_reps);
  }
}
