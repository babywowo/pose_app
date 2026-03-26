import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pose_app/core/models/angle_result.dart';
import 'package:pose_app/core/models/pose_landmark.dart';
import 'package:pose_app/core/services/squat_analyzer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Debug: 验证状态转换阈值', () async {
    final analyzer = await SquatAnalyzer.create();
    
    print('\n=== 测试standing→descending转换（阈值<150）===');
    print('Current state: ${analyzer.currentState.currentPhase}');
    
    // 降到145°（应该触发转换）
    for (var angle = 170; angle >= 145; angle -= 5) {
      analyzer.update(_createFrameAngles(leftKnee: angle.toDouble(), rightKnee: angle.toDouble()));
    }
    
    print('After 145°: ${analyzer.currentState.currentPhase}');
    print('Left knee angle: ${analyzer.currentState.keyAngles["leftKnee"]}');
    
    if (analyzer.currentState.currentPhase == 'descending') {
      print('✓ 成功触发 standing→descending\n');
      
      // 继续降到95°（应该触发 descending→bottom）
      print('\n=== 测试descending→bottom转换（阈值<100）===');
      for (var angle = 140; angle >= 95; angle -= 5) {
        analyzer.update(_createFrameAngles(leftKnee: angle.toDouble(), rightKnee: angle.toDouble()));
      }
      
      print('After 95°: ${analyzer.currentState.currentPhase}');
      print('Left knee angle: ${analyzer.currentState.keyAngles["leftKnee"]}');
      
      if (analyzer.currentState.currentPhase == 'bottom') {
        print('✓ 成功触发 descending→bottom\n');
        
        // 起身到170°（应该触发 bottom/ascending→standing并计数）
        print('\n=== 测试回到standing并计数（阈值>160）===');
        for (var angle = 100; angle <= 170; angle += 5) {
          analyzer.update(_createFrameAngles(leftKnee: angle.toDouble(), rightKnee: angle.toDouble()));
        }
        
        print('After 170°: ${analyzer.currentState.currentPhase}');
        print('Rep count: ${analyzer.currentState.repCount}');
        
        if (analyzer.currentState.currentPhase == 'standing' && analyzer.currentState.repCount == 1) {
          print('✓ 成功完成一次深蹲计数！');
        } else {
          print('✗ 深蹲计数失败');
        }
      } else {
        print('✗ descending→bottom转换失败');
      }
    } else {
      print('✗ standing→descending转换失败');
    }
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
