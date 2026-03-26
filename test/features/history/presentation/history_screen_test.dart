import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pose_app/features/history/presentation/history_screen.dart';
import 'package:pose_app/core/providers/pose_providers.dart';

void main() {
  group('HistoryScreen Widget测试', () {
    testWidgets('HistoryScreen应正确渲染', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: HistoryScreen(),
          ),
        ),
      );

      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.text('历史记录'), findsOneWidget);
    });

    testWidgets('空状态应显示提示', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: HistoryScreen(),
          ),
        ),
      );

      // 查找空状态提示
      expect(find.textContaining('暂无'), findsWidgets);
    });

    testWidgets('会话卡片应正确显示', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: HistoryScreen(),
          ),
        ),
      );

      // 在空状态下不应该有卡片
      expect(find.byType(Card), findsNothing);
    });
  });
}
