import 'package:flutter_test/flutter_test.dart';
import 'package:pose_app/core/models/angle_result.dart';
import 'package:pose_app/core/models/exercise_definition.dart';
import 'package:pose_app/core/services/state_machine.dart';
import 'package:pose_app/core/services/exercise_loader.dart';

void main() {
  test('调试状态机转换', () async {
    final definition = await ExerciseLoader.fromYaml('assets/exercises/squat.exercise.yaml');
    final stateMachine = StateMachine(definition);

    print('\n=== 状态机转换测试 ===');

    // 模拟角度变化: bottom→ascending
    final angles = <JointAngleType, double>{
      JointAngleType.leftKnee: 120.0, // 应该触发bottom→ascending (>100)
      JointAngleType.rightKnee: 120.0,
    };

    print('当前状态: ${stateMachine.currentStateId}');
    print('输入角度: leftKnee=${angles[JointAngleType.leftKnee]}');
    print('期望转换: bottom → ascending');

    final result = stateMachine.transition(angles);

    print('实际转换: ${result.previousState} → ${result.newState}');
    print('计数: ${result.repCount}');
    print('状态是否改变: ${result.previousState != result.newState}');
  });
}
