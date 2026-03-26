import 'package:flutter_test/flutter_test.dart';
import 'package:pose_app/core/models/angle_result.dart';
import 'package:pose_app/core/models/exercise_definition.dart';
import 'package:pose_app/core/services/squat_analyzer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('调试: JointCondition.check()方法', () {
    test('验证>操作符的行为', () async {
      final analyzer = await SquatAnalyzer.create();
      
      // 找到bottom->ascending的转换
      final transition = analyzer.definition.transitions
          .firstWhere((t) => t.fromState == 'bottom' && t.toState == 'ascending');
      
      print('\n转换: ${transition.fromState} → ${transition.toState}');
      print('triggers数量: ${transition.triggers.length}');
      
      for (var i = 0; i < transition.triggers.length; i++) {
        final cond = transition.triggers[i];
        print('\nTrigger $i:');
        print('  joint: ${cond.joint}');
        print('  operator: ${cond.operator}');
        print('  min: ${cond.min}');
        print('  max: ${cond.max}');
        print('  aggregation: ${cond.aggregation}');
        
        // 测试check方法
        print('\n  测试check方法:');
        for (var value in [80.0, 99.0, 100.0, 101.0, 120.0]) {
          final result = cond.check(value);
          print('    check($value) = $result');
        }
      }
    });
  });
}
