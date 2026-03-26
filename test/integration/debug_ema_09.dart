import 'package:flutter_test/flutter_test.dart';
import 'package:pose_app/core/services/squat_analyzer.dart';

void main() {
  testWidgets('调试EMA factor=0.9的行为', (WidgetTester tester) async {
    final analyzer = await SquatAnalyzer.create();
    analyzer.reset();

    print('=== 调试EMA平滑 factor=0.9 ===\n');

    // 下蹲到80°
    print('下蹲到80°:');
    for (var angle = 170; angle >= 80; angle -= 10) {
      for (var i = 0; i < 10; i++) {
        analyzer.update(_createAngles(angle.toDouble()));
      }
      final smoothed = analyzer.currentState.keyAngles['leftKnee'];
      final diff = (angle - smoothed!).abs();
      print('  输入: ${angle}°, 平滑后: ${smoothed.toStringAsFixed(2)}°, 差异: ${diff.toStringAsFixed(2)}°');
    }

    // 尝试从80°跳到120°
    print('\n从80°跳到120°:');
    for (var i = 0; i < 10; i++) {
      analyzer.update(_createAngles(120));
    }
    final after120 = analyzer.currentState.keyAngles['leftKnee'];
    final diff120 = (120 - after120!).abs();
    print('  输入: 120°, 平滑后: ${after120.toStringAsFixed(2)}°, 差异: ${diff120.toStringAsFixed(2)}°');
    print('  当前阶段: ${analyzer.currentState.currentPhase}');
    print('  能否触发bottom→ascending (需要>100°)? ${after120 > 100}');

    // 尝试从80°跳到130°
    print('\n从80°跳到130°:');
    analyzer.reset();
    for (var angle = 170; angle >= 80; angle -= 10) {
      for (var i = 0; i < 10; i++) {
        analyzer.update(_createAngles(angle.toDouble()));
      }
    }
    for (var i = 0; i < 10; i++) {
      analyzer.update(_createAngles(130));
    }
    final after130 = analyzer.currentState.keyAngles['leftKnee'];
    final diff130 = (130 - after130!).abs();
    print('  输入: 130°, 平滑后: ${after130.toStringAsFixed(2)}°, 差异: ${diff130.toStringAsFixed(2)}°');
    print('  当前阶段: ${analyzer.currentState.currentPhase}');
    print('  能否触发bottom→ascending (需要>100°)? ${after130 > 100}');

    // 尝试从80°跳到150°
    print('\n从80°跳到150°:');
    analyzer.reset();
    for (var angle = 170; angle >= 80; angle -= 10) {
      for (var i = 0; i < 10; i++) {
        analyzer.update(_createAngles(angle.toDouble()));
      }
    }
    for (var i = 0; i < 10; i++) {
      analyzer.update(_createAngles(150));
    }
    final after150 = analyzer.currentState.keyAngles['leftKnee'];
    final diff150 = (150 - after150!).abs();
    print('  输入: 150°, 平滑后: ${after150.toStringAsFixed(2)}°, 差异: ${diff150.toStringAsFixed(2)}°');
    print('  当前阶段: ${analyzer.currentState.currentPhase}');
    print('  能否触发bottom→ascending (需要>100°)? ${after150 > 100}');
  });
}

import 'package:pose_app/core/models/angle_result.dart';
import 'package:pose_app/core/models/joint_angle_type.dart';

FrameAngles _createAngles(double angle) {
  return FrameAngles(
    angles: {
      JointAngleType.leftKnee: AngleResult(joint: JointAngleType.leftKnee, angle: angle),
      JointAngleType.rightKnee: AngleResult(joint: JointAngleType.rightKnee, angle: angle),
    },
    timestamp: DateTime.now(),
  );
}
