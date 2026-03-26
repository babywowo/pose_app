import 'package:flutter_test/flutter_test.dart';
import 'package:pose_app/core/services/squat_analyzer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('调试: shouldCountRep标志', () {
    test('检查所有转换的shouldCountRep值', () async {
      final analyzer = await SquatAnalyzer.create();
      
      print('\n=== 所有转换及其shouldCountRep值 ===\n');
      
      for (var i = 0; i < analyzer.definition.transitions.length; i++) {
        final trans = analyzer.definition.transitions[i];
        print('$i. ${trans.fromState} → ${trans.toState}');
        print('   shouldCountRep: ${trans.shouldCountRep}');
        print('   triggers: ${trans.triggers}');
        print('');
      }
    });
  });
}
