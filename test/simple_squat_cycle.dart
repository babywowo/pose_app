import 'package:flutter_test/flutter_test.dart';
import 'package:pose_app/core/models/angle_result.dart';
import 'package:pose_app/core/services/exercise_analyzer.dart';
import 'package:pose_app/core/services/squat_analyzer.dart';

void main() {
  test('单个深蹲周期测试', () async {
    final analyzer = await SquatAnalyzer.create();

    print('\n=== 单个深蹲周期测试 ===\n');

    // 1. 站立 (170° x 20帧)
    print('阶段1: 站立 170° x 20帧');
    for (var i = 0; i < 20; i++) {
      analyzer.update(FrameAngles(
        angles: {
          JointAngleType.leftKnee: AngleResult(joint: JointAngleType.leftKnee, angle: 170),
          JointAngleType.rightKnee: AngleResult(joint: JointAngleType.rightKnee, angle: 170),
        },
        timestamp: DateTime.now(),
      ));
    }
    print('结果: 状态=${analyzer.currentState.currentPhase}, 计数=${analyzer.currentState.repCount}');
    print('期望: 状态=standing, 计数=0');

    // 2. 下蹲到120°
    print('\n阶段2: 下蹲到 120°');
    for (var angle = 170; angle >= 120; angle--) {
      for (var i = 0; i < 10; i++) {
        analyzer.update(FrameAngles(
          angles: {
            JointAngleType.leftKnee: AngleResult(joint: JointAngleType.leftKnee, angle: angle.toDouble()),
            JointAngleType.rightKnee: AngleResult(joint: JointAngleType.rightKnee, angle: angle.toDouble()),
          },
          timestamp: DateTime.now(),
        ));
      }
    }
    print('结果: 状态=${analyzer.currentState.currentPhase}, 计数=${analyzer.currentState.repCount}');
    print('期望: 状态=descending, 计数=0');

    expect(analyzer.currentState.currentPhase, 'descending');
    expect(analyzer.currentState.repCount, 0);
  });
}
