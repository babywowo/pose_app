import 'package:flutter_test/flutter_test.dart';
import 'package:pose_app/core/models/angle_result.dart';
import 'package:pose_app/core/services/exercise_analyzer.dart';
import 'package:pose_app/core/services/squat_analyzer_debug.dart';

void main() {
  test('调试分析器：完整深蹲周期', () async {
    final analyzer = await SquatAnalyzerDebug.create();

    print('\n=== 调试完整深蹲周期 ===\n');

    // 1. 站立阶段 (170°, 20帧)
    print('--- 阶段1: 站立 (170° × 20帧) ---');
    for (var i = 0; i < 20; i++) {
      analyzer.update(_createFrameAngles(leftKnee: 170, rightKnee: 170));
    }
    print('站立完成，当前阶段: ${analyzer.currentState.currentPhase}');
    expect(analyzer.currentState.currentPhase, 'standing');
    expect(analyzer.currentState.repCount, 0);

    // 2. 下蹲到120° (170°→120°, 每角度10帧)
    print('\n--- 阶段2: 下蹲 (170°→120°) ---');
    for (var angle = 170; angle >= 120; angle--) {
      for (var i = 0; i < 10; i++) {
        analyzer.update(_createFrameAngles(leftKnee: angle.toDouble(), rightKnee: angle.toDouble()));
      }
    }
    print('下蹲到120°完成，当前阶段: ${analyzer.currentState.currentPhase}');
    expect(analyzer.currentState.currentPhase, 'descending');
    expect(analyzer.currentState.repCount, 0);

    // 3. 下蹲到80° (120°→80°, 每角度10帧)
    print('\n--- 阶段3: 继续下蹲 (120°→80°) ---');
    for (var angle = 120; angle >= 80; angle--) {
      for (var i = 0; i < 10; i++) {
        analyzer.update(_createFrameAngles(leftKnee: angle.toDouble(), rightKnee: angle.toDouble()));
      }
    }
    print('下蹲到80°完成，当前阶段: ${analyzer.currentState.currentPhase}');
    expect(analyzer.currentState.currentPhase, 'bottom');
    expect(analyzer.currentState.repCount, 0);

    // 4. 起身到120° (80°→120°, 每角度10帧)
    print('\n--- 阶段4: 起身 (80°→120°) ---');
    for (var angle = 80; angle <= 120; angle++) {
      for (var i = 0; i < 10; i++) {
        analyzer.update(_createFrameAngles(leftKnee: angle.toDouble(), rightKnee: angle.toDouble()));
      }
    }
    print('起身到120°完成，当前阶段: ${analyzer.currentState.currentPhase}');
    expect(analyzer.currentState.currentPhase, 'ascending');
    expect(analyzer.currentState.repCount, 0);

    // 5. 起身到170° (120°→170°, 每角度10帧)
    print('\n--- 阶段5: 起身到站立 (120°→170°) ---');
    for (var angle = 120; angle <= 170; angle++) {
      for (var i = 0; i < 10; i++) {
        analyzer.update(_createFrameAngles(leftKnee: angle.toDouble(), rightKnee: angle.toDouble()));
      }
    }
    print('起身到170°完成，当前阶段: ${analyzer.currentState.currentPhase}');
    expect(analyzer.currentState.currentPhase, 'standing');
    expect(analyzer.currentState.repCount, 1);

    print('\n=== 测试完成 ===');
  });

  FrameAngles _createFrameAngles({required double leftKnee, required double rightKnee}) {
    return FrameAngles(
      angles: {
        JointAngleType.leftKnee: leftKnee,
        JointAngleType.rightKnee: rightKnee,
      },
    );
  }
}
