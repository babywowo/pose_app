import 'package:flutter_test/flutter_test.dart';
import 'package:pose_app/core/models/angle_result.dart';
import 'package:pose_app/core/services/squat_analyzer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('调试EMA平滑行为', () async {
    final analyzer = await SquatAnalyzer.create();

    print('\n=== 测试EMA平滑 ===');
    print('初始状态: ${analyzer.currentState.currentPhase}');
    print('初始角度: ${analyzer.currentState.keyAngles}');

    // 从170°降到140°
    for (var angle = 170; angle >= 140; angle -= 2) {
      final state = analyzer.update(_createFrameAngles(leftKnee: angle.toDouble(), rightKnee: angle.toDouble()));
      if (angle % 10 == 0) {
        print('输入角度: $angle°, 平滑后: ${state.keyAngles["leftKnee"]?.toStringAsFixed(2)}°, 状态: ${state.currentPhase}');
      }
    }

    // 从140°降到80°
    for (var angle = 140; angle >= 80; angle -= 2) {
      final state = analyzer.update(_createFrameAngles(leftKnee: angle.toDouble(), rightKnee: angle.toDouble()));
      if (angle % 10 == 0) {
        print('输入角度: $angle°, 平滑后: ${state.keyAngles["leftKnee"]?.toStringAsFixed(2)}°, 状态: ${state.currentPhase}');
      }
    }

    // 从80°升到170°
    for (var angle = 80; angle <= 170; angle += 2) {
      final state = analyzer.update(_createFrameAngles(leftKnee: angle.toDouble(), rightKnee: angle.toDouble()));
      if (angle % 20 == 0) {
        print('输入角度: $angle°, 平滑后: ${state.keyAngles["leftKnee"]?.toStringAsFixed(2)}°, 状态: ${state.currentPhase}, 计数: ${state.repCount}');
      }
    }

    print('\n=== 最终状态 ===');
    print('最终角度: ${analyzer.currentState.keyAngles}');
    print('最终状态: ${analyzer.currentState.currentPhase}');
    print('最终计数: ${analyzer.currentState.repCount}');
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
