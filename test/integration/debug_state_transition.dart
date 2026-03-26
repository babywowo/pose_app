import 'package:flutter_test/flutter_test.dart';
import 'package:pose_app/core/services/squat_analyzer.dart';
import 'package:pose_app/core/models/angle_result.dart';
import 'package:pose_app/core/models/joint_angle_type.dart';

void main() {
  testWidgets('调试状态机转换', (WidgetTester tester) async {
    final analyzer = await SquatAnalyzer.create();
    analyzer.reset();

    print('=== 调试状态机转换 ===\n');

    // 1. 站立（170°）
    print('1. 站立（170° x 20帧）:');
    for (var i = 0; i < 20; i++) {
      analyzer.update(_createAngles(170));
    }
    print('   当前状态: ${analyzer.currentState.currentPhase}');
    print('   计数: ${analyzer.currentState.repCount}');

    // 2. 下蹲到120°（应该触发standing→descending）
    print('\n2. 下蹲到120°:');
    for (var angle = 170; angle >= 120; angle -= 5) {
      for (var i = 0; i < 10; i++) {
        analyzer.update(_createAngles(angle.toDouble()));
      }
    }
    print('   当前状态: ${analyzer.currentState.currentPhase}');
    print('   计数: ${analyzer.currentState.repCount}');
    print('   期望: descending, 实际: ${analyzer.currentState.currentPhase == "descending" ? "✓" : "✗"}');

    // 3. 下蹲到80°（应该触发descending→bottom）
    print('\n3. 下蹲到80°:');
    for (var angle = 120; angle >= 80; angle -= 5) {
      for (var i = 0; i < 10; i++) {
        analyzer.update(_createAngles(angle.toDouble()));
      }
    }
    print('   当前状态: ${analyzer.currentState.currentPhase}');
    print('   计数: ${analyzer.currentState.repCount}');
    print('   期望: bottom, 实际: ${analyzer.currentState.currentPhase == "bottom" ? "✓" : "✗"}');

    // 4. 起身到120°（应该触发bottom→ascending）
    print('\n4. 起身到120°:');
    for (var angle = 80; angle <= 120; angle += 5) {
      for (var i = 0; i < 10; i++) {
        analyzer.update(_createAngles(angle.toDouble()));
      }
    }
    print('   当前状态: ${analyzer.currentState.currentPhase}');
    print('   计数: ${analyzer.currentState.repCount}');
    print('   期望: ascending, 实际: ${analyzer.currentState.currentPhase == "ascending" ? "✓" : "✗"}');

    // 5. 起身到170°（应该触发ascending→standing并计数）
    print('\n5. 起身到170°:');
    for (var angle = 120; angle <= 170; angle += 5) {
      for (var i = 0; i < 10; i++) {
        analyzer.update(_createAngles(angle.toDouble()));
      }
    }
    print('   当前状态: ${analyzer.currentState.currentPhase}');
    print('   计数: ${analyzer.currentState.repCount}');
    print('   期望: standing, 实际: ${analyzer.currentState.currentPhase == "standing" ? "✓" : "✗"}');
    print('   期望计数: 1, 实际: ${analyzer.currentState.repCount == 1 ? "✓" : "✗"}');
  });
}

FrameAngles _createAngles(double angle) {
  return FrameAngles(
    angles: {
      JointAngleType.leftKnee: AngleResult(joint: JointAngleType.leftKnee, angle: angle),
      JointAngleType.rightKnee: AngleResult(joint: JointAngleType.rightKnee, angle: angle),
    },
    timestamp: DateTime.now(),
  );
}
