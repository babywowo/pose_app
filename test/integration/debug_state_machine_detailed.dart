import 'package:flutter_test/flutter_test.dart';
import 'package:pose_app/core/models/angle_result.dart';
import 'package:pose_app/core/models/exercise_definition.dart';
import 'package:pose_app/core/services/state_machine.dart';
import 'package:pose_app/core/services/exercise_loader.dart';

void main() {
  test('详细调试状态机转换', () async {
    final definition = await ExerciseLoader.fromYaml('assets/exercises/squat.exercise.yaml');
    final stateMachine = StateMachine(definition);

    print('\n=== 状态机详细调试 ===');
    print('当前状态: ${stateMachine.currentStateId}');
    print('阈值配置:');
    for (final trans in definition.transitions) {
      print('  ${trans.fromState} → ${trans.toState}');
      for (final trig in trans.triggers) {
        print('    ${trig.joint} ${trig.operator} ${trig.min}-${trig.max}');
      }
    }

    // 测试1: 站立 -> 下蹲 (angle < 150)
    print('\n--- 测试1: 站立 -> 下蹲 ---');
    var angles = <JointAngleType, double>{
      JointAngleType.leftKnee: 140.0,
      JointAngleType.rightKnee: 140.0,
    };
    print('输入角度: avg=140 (应触发 <150)');
    var result = stateMachine.transition(angles);
    print('结果: ${stateMachine.currentStateId} (期望: descending)');

    // 测试2: 下蹲 -> 最低点 (angle < 100)
    print('\n--- 测试2: 下蹲 -> 最低点 ---');
    angles = <JointAngleType, double>{
      JointAngleType.leftKnee: 80.0,
      JointAngleType.rightKnee: 80.0,
    };
    print('输入角度: avg=80 (应触发 <100)');
    result = stateMachine.transition(angles);
    print('结果: ${stateMachine.currentStateId} (期望: bottom)');

    // 测试3: 最低点 -> 起身 (angle > 100)
    print('\n--- 测试3: 最低点 -> 起身 ---');
    angles = <JointAngleType, double>{
      JointAngleType.leftKnee: 120.0,
      JointAngleType.rightKnee: 120.0,
    };
    print('输入角度: avg=120 (应触发 >100)');
    result = stateMachine.transition(angles);
    print('结果: ${stateMachine.currentStateId} (期望: ascending)');

    // 测试4: 起身 -> 站立 (angle > 160)
    print('\n--- 测试4: 起身 -> 站立 ---');
    angles = <JointAngleType, double>{
      JointAngleType.leftKnee: 170.0,
      JointAngleType.rightKnee: 170.0,
    };
    print('输入角度: avg=170 (应触发 >160)');
    result = stateMachine.transition(angles);
    print('结果: ${stateMachine.currentStateId} (期望: standing, 计数应+1)');
    print('最终计数: ${stateMachine.repCount} (期望: 1)');
  });
}
