import 'package:flutter_test/flutter_test.dart';
import 'package:pose_app/core/services/angle_calculator.dart';

void main() {
  group('EMA 平滑测试（alpha=1.0）', () {
    test('alpha=1.0 时应完全禁用平滑', () {
      // 模拟下蹲过程：170° → 120°
      var prev = 170.0;
      for (var angle = 170; angle >= 120; angle--) {
        final smoothed = AngleCalculator.smooth(prev, angle.toDouble());
        print('输入 $angle° → 平滑 $smoothed° (diff=${(smoothed - angle).abs()})');
        
        // alpha=1.0时，平滑角度应等于输入角度
        expect(smoothed, closeTo(angle.toDouble(), 0.01));
        prev = smoothed;
      }
    });

    test('alpha=1.0 时状态机阈值触发验证', () {
      // 模拟完整深蹲周期
      final phases = <String>[];
      
      // standing: 170°
      phases.add('standing');
      
      // 下蹲到150° (触发 standing→descending)
      var angle = 150.0;
      var smoothed = AngleCalculator.smooth(170.0, angle);
      if (smoothed < 150) phases.add('descending');
      print('150° 平滑后: $smoothed°, 当前阶段: ${phases.last}');
      expect(smoothed, closeTo(150.0, 0.01));
      
      // 下蹲到100° (触发 descending→bottom)
      angle = 100.0;
      smoothed = AngleCalculator.smooth(smoothed, angle);
      if (smoothed < 100) phases.add('bottom');
      print('100° 平滑后: $smoothed°, 当前阶段: ${phases.last}');
      expect(smoothed, closeTo(100.0, 0.01));
      
      // 起身到101° (触发 bottom→ascending)
      angle = 101.0;
      smoothed = AngleCalculator.smooth(smoothed, angle);
      if (smoothed > 100) phases.add('ascending');
      print('101° 平滑后: $smoothed°, 当前阶段: ${phases.last}');
      expect(smoothed, closeTo(101.0, 0.01));
      
      // 起身到160° (触发 ascending→standing 并计数)
      angle = 160.0;
      smoothed = AngleCalculator.smooth(smoothed, angle);
      if (smoothed > 160) phases.add('standing');
      print('160° 平滑后: $smoothed°, 当前阶段: ${phases.last}');
      expect(smoothed, closeTo(160.0, 0.01));
      
      // 验证阶段转换顺序
      expect(phases, ['standing', 'descending', 'bottom', 'ascending', 'standing']);
    });
  });
}
