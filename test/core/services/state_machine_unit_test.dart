import 'package:flutter_test/flutter_test.dart';
import 'package:pose_app/core/models/angle_result.dart';
import 'package:pose_app/core/models/exercise_definition.dart';
import 'package:pose_app/core/services/state_machine.dart';
import 'package:pose_app/core/services/exercise_loader.dart';

void main() {
  test('直接测试StateMachine逻辑', () async {
    final definition = await ExerciseLoader.fromYaml('assets/exercises/squat.exercise.yaml');
    final stateMachine = StateMachine(definition);

    print('\n=== StateMachine单元测试 ===\n');

    // 测试1: 站立 -> 下蹲 (avg=140, 应触发 <150)
    print('测试1: standing -> descending');
    var angles = <JointAngleType, double>{
      JointAngleType.leftKnee: 140.0,
      JointAngleType.rightKnee: 140.0,
    };
    var result = stateMachine.transition(angles);
    print('  输入角度: left=140, right=140');
    print('  当前状态: ${stateMachine.currentStateId}');
    print('  期望状态: descending');
    print('  测试通过: ${stateMachine.currentStateId == 'descending'}');
    expect(stateMachine.currentStateId, 'descending');

    // 测试2: 下蹲 -> 底部 (avg=80, 应触发 <100)
    print('\n测试2: descending -> bottom');
    angles = <JointAngleType, double>{
      JointAngleType.leftKnee: 80.0,
      JointAngleType.rightKnee: 80.0,
    };
    result = stateMachine.transition(angles);
    print('  输入角度: left=80, right=80');
    print('  当前状态: ${stateMachine.currentStateId}');
    print('  期望状态: bottom');
    print('  测试通过: ${stateMachine.currentStateId == 'bottom'}');
    expect(stateMachine.currentStateId, 'bottom');

    // 测试3: 底部 -> 起身 (avg=120, 应触发 >100)
    print('\n测试3: bottom -> ascending');
    angles = <JointAngleType, double>{
      JointAngleType.leftKnee: 120.0,
      JointAngleType.rightKnee: 120.0,
    };
    result = stateMachine.transition(angles);
    print('  输入角度: left=120, right=120');
    print('  当前状态: ${stateMachine.currentStateId}');
    print('  期望状态: ascending');
    print('  测试通过: ${stateMachine.currentStateId == 'ascending'}');
    expect(stateMachine.currentStateId, 'ascending');

    // 测试4: 起身 -> 站立 (avg=170, 应触发 >160并计数)
    print('\n测试4: ascending -> standing (应计数)');
    angles = <JointAngleType, double>{
      JointAngleType.leftKnee: 170.0,
      JointAngleType.rightKnee: 170.0,
    };
    result = stateMachine.transition(angles);
    print('  输入角度: left=170, right=170');
    print('  当前状态: ${stateMachine.currentStateId}');
    print('  期望状态: standing');
    print('  期望计数: 1');
    print('  实际计数: ${stateMachine.repCount}');
    print('  测试通过: ${stateMachine.currentStateId == 'standing' && stateMachine.repCount == 1}');
    expect(stateMachine.currentStateId, 'standing');
    expect(stateMachine.repCount, 1);
  });
}
