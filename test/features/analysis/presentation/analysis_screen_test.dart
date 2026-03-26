import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pose_app/features/analysis/presentation/analysis_screen.dart';
import 'package:pose_app/core/providers/pose_providers.dart';

void main() {
  group('AnalysisScreen Widget测试', () {
    testWidgets('AnalysisScreen应正确渲染', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: AnalysisScreen(),
          ),
        ),
      );

      // 验证关键组件存在
      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.text('深蹲分析'), findsOneWidget);
    });

    testWidgets('初始状态下计数器应显示0', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: AnalysisScreen(),
          ),
        ),
      );

      // 查找计数器文本（假设有"0"或"计数"相关文本）
      expect(find.textContaining('0'), findsWidgets);
    });

    testWidgets('开始分析按钮应存在且可点击', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: AnalysisScreen(),
          ),
        ),
      );

      // 查找开始/停止按钮
      final button = find.byType(ElevatedButton).first;
      expect(button, findsOneWidget);

      // 点击按钮
      await tester.tap(button);
      await tester.pump();
    });

    testWidgets('重置按钮应存在', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: AnalysisScreen(),
          ),
        ),
      );

      // 查找重置按钮
      expect(find.byIcon(Icons.refresh), findsOneWidget);
    });

    testWidgets('角度显示区域应存在', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: AnalysisScreen(),
          ),
        ),
      );

      // 查找角度相关文本
      expect(find.textContaining('°'), findsWidgets);
    });

    testWidgets('反馈区域应存在', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: AnalysisScreen(),
          ),
        ),
      );

      // 查找反馈文本区域
      expect(find.textContaining('准备'), findsWidgets);
    });
  });
}
