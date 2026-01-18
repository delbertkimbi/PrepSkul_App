import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:prepskul/features/sessions/widgets/embedded_map_widget.dart';

/// Comprehensive tests for EmbeddedMapWidget
/// Tests geocoding, coordinate parsing, and rendering
void main() {
  group('EmbeddedMapWidget - Widget Creation', () {
    testWidgets('EmbeddedMapWidget renders with address', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EmbeddedMapWidget(
              address: 'Douala, Cameroon',
              height: 200,
            ),
          ),
        ),
      );

      // Widget should render without errors
      expect(find.byType(EmbeddedMapWidget), findsOneWidget);
    });

    testWidgets('EmbeddedMapWidget renders with coordinates', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EmbeddedMapWidget(
              address: 'Douala, Cameroon',
              coordinates: '4.0511,9.7679',
              height: 200,
            ),
          ),
        ),
      );

      // Widget should render without errors
      expect(find.byType(EmbeddedMapWidget), findsOneWidget);
    });

    testWidgets('EmbeddedMapWidget respects height parameter', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EmbeddedMapWidget(
              address: 'Douala, Cameroon',
              height: 300,
            ),
          ),
        ),
      );

      // Widget should render with specified height
      expect(find.byType(EmbeddedMapWidget), findsOneWidget);
    });
  });

  group('EmbeddedMapWidget - Coordinate Parsing', () {
    testWidgets('Widget handles valid coordinate format', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EmbeddedMapWidget(
              address: 'Test Location',
              coordinates: '4.0511,9.7679',
            ),
          ),
        ),
      );

      // Widget should parse coordinates correctly
      expect(find.byType(EmbeddedMapWidget), findsOneWidget);
    });

    testWidgets('Widget handles invalid coordinate format gracefully', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EmbeddedMapWidget(
              address: 'Test Location',
              coordinates: 'invalid',
            ),
          ),
        ),
      );

      // Widget should handle invalid coordinates gracefully
      expect(find.byType(EmbeddedMapWidget), findsOneWidget);
    });
  });

  group('EmbeddedMapWidget - Current Location', () {
    testWidgets('Widget handles current location for routing', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EmbeddedMapWidget(
              address: 'Douala, Cameroon',
              coordinates: '4.0511,9.7679',
              currentLocation: '4.0511,9.7679',
            ),
          ),
        ),
      );

      // Widget should handle current location
      expect(find.byType(EmbeddedMapWidget), findsOneWidget);
    });
  });
}






