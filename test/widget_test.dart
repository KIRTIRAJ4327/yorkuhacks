import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:safe_path_york/app.dart';

void main() {
  testWidgets('SafePath app smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      const ProviderScope(
        child: SafePathApp(),
      ),
    );

    // Verify splash screen loads
    expect(find.byType(MaterialApp), findsOneWidget);
    
    // Wait for splash screen timer and navigation
    await tester.pumpAndSettle(const Duration(seconds: 3));
    
    // App should have navigated past splash
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
