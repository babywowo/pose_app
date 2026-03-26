import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pose_app/core/models/angle_result.dart';
import 'package:pose_app/core/models/pose_landmark.dart';
import 'package:pose_app/core/services/squat_analyzer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Debug: 看看状态机初始化和转换', () async {
    final analyzer = await SquatAnalyzer.create();
    print('Initial state: ${analyzer.currentState.currentPhase}, repCount: ${analyzer.currentState.repCount}');

    // 站立状态，膝角170
    for (var i = 0; i < 10; i++) {
      analyzer.update(_createFrameAngles(leftKnee: 170, rightKnee: 170));
    }
    print('After standing at 170°: ${analyzer.currentState.currentPhase}, repCount: ${analyzer.currentState.repCount}');
    print('Left knee angle: ${analyzer.currentState.keyAngles["leftKnee"]}');

    // 下蹲到160
    for (var i = 0; i < 5; i++) {
      analyzer.update(_createFrameAngles(leftKnee: 160, rightKnee: 160));
    }
    print('After 160°: ${analyzer.currentState.currentPhase}, repCount: ${analyzer.currentState.repCount}');
    print('Left knee angle: ${analyzer.currentState.keyAngles["leftKnee"]}');
  });
}

FrameAngles _createFrameAngles({
  required double leftKnee,
  required double rightKnee,
}) {
  return FrameAngles(
    angles: {
      JointAngleType.leftKnee: AngleResult(joint: JointAngleType.leftKnee, angle: leftKnee),
      JointAngleType.rightKnee: AngleResult(joint: JointAngleType.rightKnee, angle: rightKnee),
    },
    timestamp: DateTime.now(),
  );
}
