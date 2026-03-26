import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pose_app/app.dart';

void main() {
  testWidgets('PoseApp smoke test - renders without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: PoseApp()),
    );
    // Verify bottom navigation is present
    expect(find.byType(NavigationBar), findsOneWidget);
  });
}
