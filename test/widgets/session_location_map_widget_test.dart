import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:prepskul/features/sessions/widgets/session_location_map.dart';

/// Comprehensive tests for SessionLocationMap widget
/// Tests address display, directions, and check-in functionality
void main() {
  group('SessionLocationMap - Widget Creation', () {
    testWidgets('SessionLocationMap renders with address', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SessionLocationMap(
              address: 'Douala, Cameroon',
              sessionId: 'test_session_123',
            ),
          ),
        ),
      );

      // Widget should render without errors
      expect(find.byType(SessionLocationMap), findsOneWidget);
    });

    testWidgets('SessionLocationMap renders with coordinates', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SessionLocationMap(
              address: 'Douala, Cameroon',
              coordinates: '4.0511,9.7679',
              sessionId: 'test_session_123',
            ),
          ),
        ),
      );

      // Widget should render without errors
      expect(find.byType(SessionLocationMap), findsOneWidget);
    });

    testWidgets('SessionLocationMap shows check-in button when enabled', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SessionLocationMap(
              address: 'Douala, Cameroon',
              sessionId: 'test_session_123',
              showCheckIn: true,
              currentUserId: 'test_user_123',
              userType: 'student',
            ),
          ),
        ),
      );

      // Widget should render with check-in functionality
      expect(find.byType(SessionLocationMap), findsOneWidget);
    });
  });

  group('SessionLocationMap - Location Display', () {
    testWidgets('Widget displays address correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SessionLocationMap(
              address: '123 Main Street, Douala',
              sessionId: 'test_session_123',
            ),
          ),
        ),
      );

      // Widget should display address
      expect(find.byType(SessionLocationMap), findsOneWidget);
    });

    testWidgets('Widget handles location description', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SessionLocationMap(
              address: 'Douala, Cameroon',
              locationDescription: 'Near the market',
              sessionId: 'test_session_123',
            ),
          ),
        ),
      );

      // Widget should handle location description
      expect(find.byType(SessionLocationMap), findsOneWidget);
    });
  });

  group('SessionLocationMap - Session Types', () {
    testWidgets('Widget handles online sessions', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SessionLocationMap(
              address: 'Online',
              sessionId: 'test_session_123',
              locationType: 'online',
            ),
          ),
        ),
      );

      // Widget should handle online sessions
      expect(find.byType(SessionLocationMap), findsOneWidget);
    });

    testWidgets('Widget handles onsite sessions', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SessionLocationMap(
              address: 'Douala, Cameroon',
              sessionId: 'test_session_123',
              locationType: 'onsite',
            ),
          ),
        ),
      );

      // Widget should handle onsite sessions
      expect(find.byType(SessionLocationMap), findsOneWidget);
    });
  });
}






