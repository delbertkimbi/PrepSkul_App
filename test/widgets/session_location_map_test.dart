import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prepskul/features/sessions/widgets/session_location_map.dart';

/// Widget tests for SessionLocationMap
void main() {
  testWidgets('renders location information', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SessionLocationMap(
            address: '123 Main Street, Yaoundé, Cameroon',
            sessionId: 'test-session-123',
          ),
        ),
      ),
    );

    expect(find.text('123 Main Street, Yaoundé, Cameroon'), findsOneWidget);
    expect(find.text('Session Location'), findsOneWidget);
  });

  testWidgets('has View Map button', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SessionLocationMap(
            address: '123 Main Street',
            sessionId: 'test-session-123',
          ),
        ),
      ),
    );

    expect(find.text('View Map'), findsOneWidget);
  });

  testWidgets('has Directions button', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SessionLocationMap(
            address: '123 Main Street',
            sessionId: 'test-session-123',
          ),
        ),
      ),
    );

    expect(find.text('Directions'), findsOneWidget);
  });
}
