import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pose_app/core/models/angle_result.dart';
import 'package:pose_app/core/services/squat_analyzer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SquatAnalyzer analyzer;

  setUp(() async {
    analyzer = await SquatAnalyzer.create();
  });

  tearDown(() {});

  group('调试: 深蹲周期步骤4失败', () {
    test('只执行到步骤4,详细观察状态转换', () async {
      analyzer.reset();

      FrameAngles _createFrameAngles({required double leftKnee, required double rightKnee}) {
        return FrameAngles(
          angles: {
            JointAngleType.leftKnee: AngleResult(joint: JointAngleType.leftKnee, angle: leftKnee),
            JointAngleType.rightKnee: AngleResult(joint: JointAngleType.rightKnee, angle: rightKnee),
          },
          timestamp: DateTime.now(),
        );
      }

      print('\n=== 步骤1: 站立阶段 (170°, 20帧) ===');
      for (var i = 0; i < 20; i++) {
        analyzer.update(_createFrameAngles(leftKnee: 170, rightKnee: 170));
      }
      print('当前状态: ${analyzer.currentState.currentPhase}, 计数: ${analyzer.currentState.repCount}');

      print('\n=== 步骤2: 下蹲 170°→120° ===');
      for (var angle = 170; angle >= 120; angle--) {
        for (var i = 0; i < 10; i++) {
          analyzer.update(_createFrameAngles(leftKnee: angle.toDouble(), rightKnee: angle.toDouble()));
        }
      }
      print('当前状态: ${analyzer.currentState.currentPhase}, 计数: ${analyzer.currentState.repCount}');

      print('\n=== 步骤3: 下蹲 120°→80° ===');
      for (var angle = 120; angle >= 80; angle--) {
        for (var i = 0; i < 10; i++) {
          analyzer.update(_createFrameAngles(leftKnee: angle.toDouble(), rightKnee: angle.toDouble()));
        }
      }
      print('当前状态: ${analyzer.currentState.currentPhase}, 计数: ${analyzer.currentState.repCount}');

      print('\n=== 步骤4: 起身 80°→120°,详细观察每一度 ===');
      for (var angle = 80; angle <= 120; angle++) {
        String phaseBefore = analyzer.currentState.currentPhase;
        for (var i = 0; i < 10; i++) {
          analyzer.update(_createFrameAngles(leftKnee: angle.toDouble(), rightKnee: angle.toDouble()));
        }
        String phaseAfter = analyzer.currentState.currentPhase;
        if (phaseBefore != phaseAfter) {
          print('  角度 $angle°: $phaseBefore → $phaseAfter');
        }
      }
      print('最终状态: ${analyzer.currentState.currentPhase}, 计数: ${analyzer.currentState.repCount}');
      print('期望状态: ascending, 计数: 0');
      
      expect(analyzer.currentState.currentPhase, 'ascending');
      expect(analyzer.currentState.repCount, 0);
    });
  });
}
