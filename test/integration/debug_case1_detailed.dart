import 'package:pose_app/core/models/angle_result.dart';
import 'package:pose_app/core/services/squat_analyzer.dart';

void main() async {
  print('=== 调试第一个失败用例: 完整深蹲周期 ===\n');

  final analyzer = await SquatAnalyzer.create();
  analyzer.reset();

  // 辅助函数：创建FrameAngles
  FrameAngles _createFrameAngles({required double leftKnee, required double rightKnee}) {
    final angles = FrameAngles();
    angles.setAngle(JointAngleType.leftKnee, leftKnee);
    angles.setAngle(JointAngleType.rightKnee, rightKnee);
    return angles;
  }

  print('=== 步骤1: 站立阶段 (170°, 20帧) ===');
  for (var i = 0; i < 20; i++) {
    final state = analyzer.update(_createFrameAngles(leftKnee: 170, rightKnee: 170));
  }
  final state1 = analyzer.currentState;
  print('当前状态: ${state1.currentPhase}, 计数: ${state1.repCount}');
  print('预期: standing, 0');
  print('实际: ${state1.currentPhase}, ${state1.repCount}');
  print('✅ 通过' : '❌ 失败\n');

  print('=== 步骤2: 下蹲 170°→120° (每度10帧) ===');
  int transitionAngle2 = -1;
  for (var angle = 170; angle >= 120; angle--) {
    for (var i = 0; i < 10; i++) {
      final state = analyzer.update(_createFrameAngles(leftKnee: angle.toDouble(), rightKnee: angle.toDouble()));
      if (transitionAngle2 == -1 && state.currentPhase == 'descending') {
        transitionAngle2 = angle;
        print('  在角度 $angle° 时触发 standing→descending');
      }
    }
  }
  final state2 = analyzer.currentState;
  print('当前状态: ${state2.currentPhase}, 计数: ${state2.repCount}');
  print('预期: descending, 0');
  print('实际: ${state2.currentPhase}, ${state2.repCount}');
  print(state2.currentPhase == 'descending' ? '✅ 通过' : '❌ 失败');
  if (transitionAngle2 == -1) {
    print('⚠️  警告: 没有触发 standing→descending 转换!\n');
  } else {
    print('转换角度: $transitionAngle2° (阈值<150)\n');
  }

  print('=== 步骤3: 下蹲 120°→80° (每度10帧) ===');
  int transitionAngle3 = -1;
  for (var angle = 120; angle >= 80; angle--) {
    for (var i = 0; i < 10; i++) {
      final state = analyzer.update(_createFrameAngles(leftKnee: angle.toDouble(), rightKnee: angle.toDouble()));
      if (transitionAngle3 == -1 && state.currentPhase == 'bottom') {
        transitionAngle3 = angle;
        print('  在角度 $angle° 时触发 descending→bottom');
      }
    }
  }
  final state3 = analyzer.currentState;
  print('当前状态: ${state3.currentPhase}, 计数: ${state3.repCount}');
  print('预期: bottom, 0');
  print('实际: ${state3.currentPhase}, ${state3.repCount}');
  print(state3.currentPhase == 'bottom' ? '✅ 通过' : '❌ 失败');
  if (transitionAngle3 == -1) {
    print('⚠️  警告: 没有触发 descending→bottom 转换!\n');
  } else {
    print('转换角度: $transitionAngle3° (阈值<100)\n');
  }

  print('=== 步骤4: 起身 80°→120° (每度10帧) ===');
  int transitionAngle4 = -1;
  for (var angle = 80; angle <= 120; angle++) {
    for (var i = 0; i < 10; i++) {
      final state = analyzer.update(_createFrameAngles(leftKnee: angle.toDouble(), rightKnee: angle.toDouble()));
      if (transitionAngle4 == -1 && state.currentPhase == 'ascending') {
        transitionAngle4 = angle;
        print('  在角度 $angle° 时触发 bottom→ascending');
      }
    }
  }
  final state4 = analyzer.currentState;
  print('当前状态: ${state4.currentPhase}, 计数: ${state4.repCount}');
  print('预期: ascending, 0');
  print('实际: ${state4.currentPhase}, ${state4.repCount}');
  print(state4.currentPhase == 'ascending' ? '✅ 通过' : '❌ 失败');
  if (transitionAngle4 == -1) {
    print('⚠️  警告: 没有触发 bottom→ascending 转换!\n');
  } else {
    print('转换角度: $transitionAngle4° (阈值>100)\n');
  }

  print('=== 步骤5: 起身 120°→170° (每度10帧) ===');
  int transitionAngle5 = -1;
  for (var angle = 120; angle <= 170; angle++) {
    for (var i = 0; i < 10; i++) {
      final state = analyzer.update(_createFrameAngles(leftKnee: angle.toDouble(), rightKnee: angle.toDouble()));
      if (transitionAngle5 == -1 && state.currentPhase == 'standing' && state4.currentPhase != 'standing') {
        transitionAngle5 = angle;
        print('  在角度 $angle° 时触发 ascending→standing');
      }
    }
  }
  final state5 = analyzer.currentState;
  print('当前状态: ${state5.currentPhase}, 计数: ${state5.repCount}');
  print('预期: standing, 1');
  print('实际: ${state5.currentPhase}, ${state5.repCount}');
  print(state5.currentPhase == 'standing' && state5.repCount == 1 ? '✅ 通过' : '❌ 失败');
  if (transitionAngle5 == -1) {
    print('⚠️  警告: 没有触发 ascending→standing 转换!\n');
  } else {
    print('转换角度: $transitionAngle5° (阈值>160)\n');
  }

  print('=== 总结 ===');
  print('步骤2转换角度: $transitionAngle2° (期望: ≤150)');
  print('步骤3转换角度: $transitionAngle3° (期望: ≤100)');
  print('步骤4转换角度: $transitionAngle4° (期望: >100)');
  print('步骤5转换角度: $transitionAngle5° (期望: >160)');
}
