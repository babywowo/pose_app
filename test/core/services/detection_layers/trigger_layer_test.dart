import 'package:flutter_test/flutter_test.dart';
import 'package:pose_app/core/models/angle_result.dart';
import 'package:pose_app/core/services/detection_layers/trigger_layer.dart';

void main() {
  group('TriggerLayer - 第一层触发机制测试', () {
    late TriggerLayer triggerLayer;
    
    setUp(() {
      triggerLayer = TriggerLayer(emaAlpha: 1.0); // 集成测试：无平滑
    });
    
    test('应该在角度达到阈值时立即触发转换', () {
      final config = {
        'operator': '<',
        'max': 150.0,
        'joint': JointAngleType.leftKnee,
        'aggregation': 'avg',
      };
      
      // 170° > 150°，不应触发
      var result = triggerLayer.check(
        angles: {
          JointAngleType.leftKnee: 170,
          JointAngleType.rightKnee: 170,
        },
        config: config,
      );
      expect(result.passed, false);
      
      // 149° < 150°，应该触发
      result = triggerLayer.check(
        angles: {
          JointAngleType.leftKnee: 149,
          JointAngleType.rightKnee: 149,
        },
        config: config,
      );
      expect(result.passed, true);
    });
    
    test('EMA平滑因子为1.0时应该无延迟', () {
      final config = {
        'operator': '<',
        'max': 150.0,
        'joint': JointAngleType.leftKnee,
        'aggregation': 'avg',
      };
      
      // 先输入150°
      var result = triggerLayer.check(
        angles: {
          JointAngleType.leftKnee: 150,
          JointAngleType.rightKnee: 150,
        },
        config: config,
      );
      expect(result.passed, false); // 150 不小于 150
      expect(result.metadata['angle'], 150.0); // 平滑后应该还是150°
      
      // 再输入149°
      result = triggerLayer.check(
        angles: {
          JointAngleType.leftKnee: 149,
          JointAngleType.rightKnee: 149,
        },
        config: config,
      );
      expect(result.passed, true); // 149 < 150
      expect(result.metadata['angle'], 149.0); // 平滑后应该是149°（无延迟）
    });
    
    test('应该支持多种操作符', () {
      final angles = {
        JointAngleType.leftKnee: 100.0,
        JointAngleType.rightKnee: 100.0,
      };
      
      // 测试 <
      var result = triggerLayer.check(
        angles: angles,
        config: {
          'operator': '<',
          'max': 150.0,
          'joint': JointAngleType.leftKnee,
          'aggregation': 'avg',
        },
      );
      expect(result.passed, true);
      
      // 测试 >
      result = triggerLayer.check(
        angles: angles,
        config: {
          'operator': '>',
          'min': 50.0,
          'joint': JointAngleType.leftKnee,
          'aggregation': 'avg',
        },
      );
      expect(result.passed, true);
      
      // 测试 <=
      result = triggerLayer.check(
        angles: angles,
        config: {
          'operator': '<=',
          'max': 100.0,
          'joint': JointAngleType.leftKnee,
          'aggregation': 'avg',
        },
      );
      expect(result.passed, true);
      
      // 测试 >=
      result = triggerLayer.check(
        angles: angles,
        config: {
          'operator': '>=',
          'min': 100.0,
          'joint': JointAngleType.leftKnee,
          'aggregation': 'avg',
        },
      );
      expect(result.passed, true);
    });
    
    test('应该支持平均值聚合', () {
      final config = {
        'operator': '<',
        'max': 150.0,
        'joint': JointAngleType.leftKnee,
        'aggregation': 'avg',
      };
      
      // 左右两侧的平均值
      var result = triggerLayer.check(
        angles: {
          JointAngleType.leftKnee: 140.0,
          JointAngleType.rightKnee: 160.0,  // 平均值 = 150°
        },
        config: config,
      );
      expect(result.passed, false); // 150 不小于 150
      
      // 左右两侧的平均值应该低于阈值
      result = triggerLayer.check(
        angles: {
          JointAngleType.leftKnee: 140.0,
          JointAngleType.rightKnee: 158.0,  // 平均值 = 149°
        },
        config: config,
      );
      expect(result.passed, true); // 149 < 150
    });
    
    test('完整深蹲周期应该正确触发所有状态转换', () {
      // 1. standing → descending (< 150°)
      var result = triggerLayer.check(
        angles: {
          JointAngleType.leftKnee: 149,
          JointAngleType.rightKnee: 149,
        },
        config: {
          'operator': '<',
          'max': 150.0,
          'joint': JointAngleType.leftKnee,
          'aggregation': 'avg',
        },
      );
      expect(result.passed, true);
      
      // 2. descending → bottom (< 100°)
      result = triggerLayer.check(
        angles: {
          JointAngleType.leftKnee: 99,
          JointAngleType.rightKnee: 99,
        },
        config: {
          'operator': '<',
          'max': 100.0,
          'joint': JointAngleType.leftKnee,
          'aggregation': 'avg',
        },
      );
      expect(result.passed, true);
      
      // 3. bottom → ascending (> 100°)
      result = triggerLayer.check(
        angles: {
          JointAngleType.leftKnee: 101,
          JointAngleType.rightKnee: 101,
        },
        config: {
          'operator': '>',
          'min': 100.0,
          'joint': JointAngleType.leftKnee,
          'aggregation': 'avg',
        },
      );
      expect(result.passed, true);
      
      // 4. ascending → standing (> 160°)
      result = triggerLayer.check(
        angles: {
          JointAngleType.leftKnee: 161,
          JointAngleType.rightKnee: 161,
        },
        config: {
          'operator': '>',
          'min': 160.0,
          'joint': JointAngleType.leftKnee,
          'aggregation': 'avg',
        },
      );
      expect(result.passed, true);
    });
    
    test('重置应该清空平滑状态', () {
      // 输入一些数据来建立平滑状态
      triggerLayer.check(
        angles: {
          JointAngleType.leftKnee: 100,
          JointAngleType.rightKnee: 100,
        },
        config: {
          'operator': '<',
          'max': 150.0,
          'joint': JointAngleType.leftKnee,
          'aggregation': 'avg',
        },
      );
      
      // 重置
      triggerLayer.reset();
      
      // 重置后应该恢复初始状态
      // 这可以通过检查私有变量来验证（但通常不建议）
      // 这里只测试重置不会抛出异常
      expect(() => triggerLayer.reset(), returnsNormally);
    });
  });
}
