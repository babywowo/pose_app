import 'dart:math' as math;
import 'package:flutter/painting.dart';

/// MediaPipe Pose 33 个关键点枚举
enum PoseLandmarkType {
  nose,
  leftEyeInner,
  leftEye,
  leftEyeOuter,
  rightEyeInner,
  rightEye,
  rightEyeOuter,
  leftEar,
  rightEar,
  mouthLeft,
  mouthRight,
  leftShoulder,
  rightShoulder,
  leftElbow,
  rightElbow,
  leftWrist,
  rightWrist,
  leftPinky,
  rightPinky,
  leftIndex,
  rightIndex,
  leftThumb,
  rightThumb,
  leftHip,
  rightHip,
  leftKnee,
  rightKnee,
  leftAnkle,
  rightAnkle,
  leftHeel,
  rightHeel,
  leftFootIndex,
  rightFootIndex,
}

/// 单个关键点数据
class PoseLandmark {
  final PoseLandmarkType type;
  final double x; // 归一化坐标 [0, 1]
  final double y; // 归一化坐标 [0, 1]
  final double z; // 深度（相对）
  final double likelihood; // 可信度 [0, 1]

  const PoseLandmark({
    required this.type,
    required this.x,
    required this.y,
    required this.z,
    required this.likelihood,
  });

  /// 是否可靠（可信度阈值）
  bool get isReliable => likelihood > 0.5;

  /// 转为屏幕坐标
  Offset toScreenOffset(double screenWidth, double screenHeight) {
    return Offset(x * screenWidth, y * screenHeight);
  }
}

/// 完整姿态帧数据
class PoseFrame {
  final List<PoseLandmark> landmarks;
  final DateTime timestamp;

  const PoseFrame({
    required this.landmarks,
    required this.timestamp,
  });

  /// 根据类型获取关键点
  PoseLandmark? getLandmark(PoseLandmarkType type) {
    try {
      return landmarks.firstWhere((l) => l.type == type);
    } catch (_) {
      return null;
    }
  }

  bool get isEmpty => landmarks.isEmpty;
}

/// 骨骼连线定义（用于绘制骨架）
const List<List<PoseLandmarkType>> kBoneConnections = [
  // 躯干
  [PoseLandmarkType.leftShoulder, PoseLandmarkType.rightShoulder],
  [PoseLandmarkType.leftShoulder, PoseLandmarkType.leftHip],
  [PoseLandmarkType.rightShoulder, PoseLandmarkType.rightHip],
  [PoseLandmarkType.leftHip, PoseLandmarkType.rightHip],
  // 左臂
  [PoseLandmarkType.leftShoulder, PoseLandmarkType.leftElbow],
  [PoseLandmarkType.leftElbow, PoseLandmarkType.leftWrist],
  // 右臂
  [PoseLandmarkType.rightShoulder, PoseLandmarkType.rightElbow],
  [PoseLandmarkType.rightElbow, PoseLandmarkType.rightWrist],
  // 左腿
  [PoseLandmarkType.leftHip, PoseLandmarkType.leftKnee],
  [PoseLandmarkType.leftKnee, PoseLandmarkType.leftAnkle],
  // 右腿
  [PoseLandmarkType.rightHip, PoseLandmarkType.rightKnee],
  [PoseLandmarkType.rightKnee, PoseLandmarkType.rightAnkle],
];

/// Offset 扩展
extension OffsetExt on Offset {
  double distanceTo(Offset other) {
    final ddx = dx - other.dx;
    final ddy = dy - other.dy;
    return math.sqrt(ddx * ddx + ddy * ddy);
  }
}
