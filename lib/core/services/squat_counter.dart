import 'package:pose_app/core/models/angle_result.dart';
import 'package:pose_app/core/models/workout_session.dart';

/// 深蹲动作阶段
enum SquatPhase {
  standing, // 站立（膝角 > 160°）
  descending, // 下蹲中
  bottom, // 最低点（膝角 < 100°）
  ascending, // 起身中
}

/// 深蹲计数状态快照
class SquatCounterState {
  final int repCount;
  final SquatPhase phase;
  final double leftKneeAngle;
  final double rightKneeAngle;
  final bool isGoodForm;
  final String feedback;

  const SquatCounterState({
    required this.repCount,
    required this.phase,
    required this.leftKneeAngle,
    required this.rightKneeAngle,
    required this.isGoodForm,
    required this.feedback,
  });

  static const SquatCounterState initial = SquatCounterState(
    repCount: 0,
    phase: SquatPhase.standing,
    leftKneeAngle: 180,
    rightKneeAngle: 180,
    isGoodForm: false,
    feedback: '站立准备',
  );
}

/// 深蹲计数器
class SquatCounter {
  // 阈值参数
  static const double _standThreshold = 160.0; // 大于此角度 = 站立
  static const double _squatThreshold = 100.0; // 小于此角度 = 深蹲底部
  static const double _goodFormMax = 90.0; // 达标深蹲：膝角 ≤ 90°

  SquatPhase _phase = SquatPhase.standing;
  int _repCount = 0;
  double _minAngleDuringRep = 180.0; // 记录本次下蹲最小角度

  // EMA 平滑后的角度
  double _smoothedLeft = 180.0;
  double _smoothedRight = 180.0;

  final List<SquatRep> _reps = [];
  List<SquatRep> get reps => List.unmodifiable(_reps);
  int get repCount => _repCount;

  /// 输入一帧角度，更新计数状态
  SquatCounterState update(FrameAngles angles) {
    final leftAngle =
        angles.getAngleValue(JointAngleType.leftKnee) ?? _smoothedLeft;
    final rightAngle =
        angles.getAngleValue(JointAngleType.rightKnee) ?? _smoothedRight;

    // EMA 平滑
    _smoothedLeft = leftAngle * 0.3 + _smoothedLeft * 0.7;
    _smoothedRight = rightAngle * 0.3 + _smoothedRight * 0.7;

    // 取双腿平均值判断动作
    final avgAngle = (_smoothedLeft + _smoothedRight) / 2;

    _updatePhase(avgAngle);

    if (avgAngle < _minAngleDuringRep) {
      _minAngleDuringRep = avgAngle;
    }

    final isGoodForm = _minAngleDuringRep <= _goodFormMax;
    final feedback = _buildFeedback(avgAngle, isGoodForm);

    return SquatCounterState(
      repCount: _repCount,
      phase: _phase,
      leftKneeAngle: _smoothedLeft,
      rightKneeAngle: _smoothedRight,
      isGoodForm: isGoodForm,
      feedback: feedback,
    );
  }

  void _updatePhase(double angle) {
    switch (_phase) {
      case SquatPhase.standing:
        if (angle < _standThreshold) {
          _phase = SquatPhase.descending;
          _minAngleDuringRep = angle;
        }
        break;

      case SquatPhase.descending:
        if (angle < _squatThreshold) {
          _phase = SquatPhase.bottom;
        } else if (angle > _standThreshold) {
          // 没蹲下就站起来，不计数
          _phase = SquatPhase.standing;
          _minAngleDuringRep = 180;
        }
        break;

      case SquatPhase.bottom:
        // 修复：直接站起来也可以计数（不强制经过 ASC 阶段）
        if (angle > _standThreshold) {
          // 快速起身：直接从底部跳到站立，计数 +1
          _repCount++;
          final isGood = _minAngleDuringRep <= _goodFormMax;
          _reps.add(SquatRep(
            minKneeAngle: _minAngleDuringRep,
            maxKneeAngle: angle,
            isGoodForm: isGood,
            timestamp: DateTime.now(),
          ));
          _phase = SquatPhase.standing;
          _minAngleDuringRep = 180;
        } else if (angle > _squatThreshold) {
          // 慢速起身：进入 ASC 阶段
          _phase = SquatPhase.ascending;
        }
        break;

      case SquatPhase.ascending:
        if (angle > _standThreshold) {
          // 完成一次深蹲（从 ASC 过来的）
          _repCount++;
          final isGood = _minAngleDuringRep <= _goodFormMax;
          _reps.add(SquatRep(
            minKneeAngle: _minAngleDuringRep,
            maxKneeAngle: angle,
            isGoodForm: isGood,
            timestamp: DateTime.now(),
          ));
          _phase = SquatPhase.standing;
          _minAngleDuringRep = 180;
        } else if (angle < _squatThreshold) {
          // 再次下蹲
          _phase = SquatPhase.bottom;
        }
        break;
    }
  }

  String _buildFeedback(double angle, bool isGoodForm) {
    switch (_phase) {
      case SquatPhase.standing:
        return '站立准备，开始下蹲';
      case SquatPhase.descending:
        final remaining = (angle - _squatThreshold).toStringAsFixed(0);
        return '继续下蹲 ($remaining° 到底部)';
      case SquatPhase.bottom:
        return isGoodForm ? '✓ 深度到位！' : '再深一点 (目标 ≤ 90°)';
      case SquatPhase.ascending:
        return '起身中…';
    }
  }

  void reset() {
    _phase = SquatPhase.standing;
    _repCount = 0;
    _minAngleDuringRep = 180;
    _smoothedLeft = 180;
    _smoothedRight = 180;
    _reps.clear();
  }
}
