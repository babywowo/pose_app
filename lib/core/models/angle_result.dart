/// 关节角度类型
enum JointAngleType {
  leftKnee,
  rightKnee,
  leftHip,
  rightHip,
  leftElbow,
  rightElbow,
  leftShoulder,
  rightShoulder,
}

extension JointAngleTypeExt on JointAngleType {
  String get displayName {
    switch (this) {
      case JointAngleType.leftKnee:
        return '左膝';
      case JointAngleType.rightKnee:
        return '右膝';
      case JointAngleType.leftHip:
        return '左髋';
      case JointAngleType.rightHip:
        return '右髋';
      case JointAngleType.leftElbow:
        return '左肘';
      case JointAngleType.rightElbow:
        return '右肘';
      case JointAngleType.leftShoulder:
        return '左肩';
      case JointAngleType.rightShoulder:
        return '右肩';
    }
  }
}

/// 单个关节角度结果
class AngleResult {
  final JointAngleType joint;
  final double angle; // 角度值（度）
  final bool isValid; // 是否有效（关键点置信度足够）

  const AngleResult({
    required this.joint,
    required this.angle,
    this.isValid = true,
  });

  static const AngleResult invalid = AngleResult(
    joint: JointAngleType.leftKnee,
    angle: 0,
    isValid: false,
  );

  String get formattedAngle => '${angle.toStringAsFixed(1)}°';
}

/// 一帧的完整角度分析结果
class FrameAngles {
  final Map<JointAngleType, AngleResult> angles;
  final DateTime timestamp;

  const FrameAngles({
    required this.angles,
    required this.timestamp,
  });

  AngleResult? getAngle(JointAngleType joint) => angles[joint];

  double? getAngleValue(JointAngleType joint) => angles[joint]?.angle;

  bool get isEmpty => angles.isEmpty;

  static FrameAngles empty() => FrameAngles(
        angles: {},
        timestamp: DateTime.now(),
      );
}
