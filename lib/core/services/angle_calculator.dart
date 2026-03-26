import 'dart:math' as math;
import 'package:flutter/painting.dart';
import 'package:pose_app/core/models/angle_result.dart';
import 'package:pose_app/core/models/pose_landmark.dart';

/// 关节角度计算器
/// 使用余弦定理：angle = arccos((AB·AC) / (|AB|·|AC|))
class AngleCalculator {
  const AngleCalculator();

  /// 计算三点之间的角度，顶点为 B
  /// [a]、[b]、[c] 均为归一化坐标 Offset
  static double calculateAngle(Offset a, Offset b, Offset c) {
    final ab = Offset(a.dx - b.dx, a.dy - b.dy);
    final cb = Offset(c.dx - b.dx, c.dy - b.dy);

    final dot = ab.dx * cb.dx + ab.dy * cb.dy;
    final magAB = math.sqrt(ab.dx * ab.dx + ab.dy * ab.dy);
    final magCB = math.sqrt(cb.dx * cb.dx + cb.dy * cb.dy);

    if (magAB < 1e-6 || magCB < 1e-6) return 0;

    final cosValue = (dot / (magAB * magCB)).clamp(-1.0, 1.0);
    return math.acos(cosValue) * 180 / math.pi;
  }

  /// 从姿态帧计算所有关节角度
  FrameAngles calculate(PoseFrame frame) {
    if (frame.isEmpty) return FrameAngles.empty();

    final angles = <JointAngleType, AngleResult>{};

    void tryCalc(
      JointAngleType joint,
      PoseLandmarkType a,
      PoseLandmarkType b, // 顶点
      PoseLandmarkType c,
    ) {
      final la = frame.getLandmark(a);
      final lb = frame.getLandmark(b);
      final lc = frame.getLandmark(c);

      if (la == null || lb == null || lc == null) return;
      if (!la.isReliable || !lb.isReliable || !lc.isReliable) return;

      final angle = calculateAngle(
        Offset(la.x, la.y),
        Offset(lb.x, lb.y),
        Offset(lc.x, lc.y),
      );

      angles[joint] = AngleResult(joint: joint, angle: angle);
    }

    // 膝盖：髋 - 膝 - 踝
    tryCalc(JointAngleType.leftKnee, PoseLandmarkType.leftHip,
        PoseLandmarkType.leftKnee, PoseLandmarkType.leftAnkle);
    tryCalc(JointAngleType.rightKnee, PoseLandmarkType.rightHip,
        PoseLandmarkType.rightKnee, PoseLandmarkType.rightAnkle);

    // 髋：肩 - 髋 - 膝
    tryCalc(JointAngleType.leftHip, PoseLandmarkType.leftShoulder,
        PoseLandmarkType.leftHip, PoseLandmarkType.leftKnee);
    tryCalc(JointAngleType.rightHip, PoseLandmarkType.rightShoulder,
        PoseLandmarkType.rightHip, PoseLandmarkType.rightKnee);

    // 肘：肩 - 肘 - 腕
    tryCalc(JointAngleType.leftElbow, PoseLandmarkType.leftShoulder,
        PoseLandmarkType.leftElbow, PoseLandmarkType.leftWrist);
    tryCalc(JointAngleType.rightElbow, PoseLandmarkType.rightShoulder,
        PoseLandmarkType.rightElbow, PoseLandmarkType.rightWrist);

    // 肩：肘 - 肩 - 髋
    tryCalc(JointAngleType.leftShoulder, PoseLandmarkType.leftElbow,
        PoseLandmarkType.leftShoulder, PoseLandmarkType.leftHip);
    tryCalc(JointAngleType.rightShoulder, PoseLandmarkType.rightElbow,
        PoseLandmarkType.rightShoulder, PoseLandmarkType.rightHip);

    return FrameAngles(angles: angles, timestamp: frame.timestamp);
  }

  /// EMA 平滑（α ≈ 0.3 效果好）
  static double smooth(double prev, double current, {double alpha = 0.3}) {
    return alpha * current + (1 - alpha) * prev;
  }
}
