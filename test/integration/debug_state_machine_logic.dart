import 'package:flutter_test/flutter_test.dart';
import 'package:pose_app/core/models/angle_result.dart';
import 'package:pose_app/core/services/squat_analyzer.dart';
import 'package:pose_app/core/services/state_machine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('深度调试: 状态机转换逻辑', () {
    test('直接测试StateMachine的transition方法', () async {
      final analyzer = await SquatAnalyzer.create();
      final stateMachine = StateMachine(analyzer.definition);

      FrameAngles _createFrameAngles({required double leftKnee, required double rightKnee}) {
        return FrameAngles(
          angles: {
            JointAngleType.leftKnee: AngleResult(joint: JointAngleType.leftKnee, angle: leftKnee),
            JointAngleType.rightKnee: AngleResult(joint: JointAngleType.rightKnee, angle: rightKnee),
          },
          timestamp: DateTime.now(),
        );
      }

      print('\n=== 测试bottom→ascending转换 ===');
      print('当前状态: ${stateMachine.currentStateId}');
      print('期望转换: bottom → ascending, 触发条件: angle > 100');

      // 手动设置状态为bottom
      // 通过多次update让状态机进入bottom
      for (var i = 0; i < 10; i++) {
        analyzer.update(_createFrameAngles(leftKnee: 80, rightKnee: 80));
      }
      print('\n手动设置bottom状态后,当前状态: ${analyzer.currentState.currentPhase}');

      // 现在测试从80°到120°,看看哪个角度触发转换
      print('\n=== 测试角度80°→120° ===');
      for (var angle = 80; angle <= 120; angle++) {
        final angles = <JointAngleType, double>{
          JointAngleType.leftKnee: angle.toDouble(),
          JointAngleType.rightKnee: angle.toDouble(),
        };

        // 获取角度值
        final value = (angles[JointAngleType.leftKnee]! + angles[JointAngleType.rightKnee]!) / 2;
        
        // 检查条件
        final condition = analyzer.definition.transitions
            .firstWhere((t) => t.fromState == 'bottom' && t.toState == 'ascending')
            .triggers
            .first;
        
        final result = condition.check(value);
        
        print('  角度 $angle°: avg=$value, 检查>${condition.min}: $result, 当前状态: ${analyzer.currentState.currentPhase}');
        
        // 更新状态机
        analyzer.update(_createFrameAngles(leftKnee: angle.toDouble(), rightKnee: angle.toDouble()));
        
        if (analyzer.currentState.currentPhase == 'ascending') {
          print('  ✓✓✓ 触发了转换! ✓✓✓');
          break;
        }
      }

      print('\n最终状态: ${analyzer.currentState.currentPhase}');
    });
  });
}
