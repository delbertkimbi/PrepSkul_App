import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prepskul/features/notifications/widgets/notification_item.dart';
import 'package:prepskul/core/theme/app_theme.dart';

/// Widget tests for NotificationItem - UI Refinements
/// 
/// Tests that verify the professional UI refinements:
/// - Improved padding and spacing
/// - Softer shadows
/// - Better typography
/// - Refined action buttons
void main() {
  group('NotificationItem - UI Refinements', () {
    testWidgets('notification card should have refined padding (18px)', (WidgetTester tester) async {
      final notification = {
        'id': 'test-id',
        'title': 'Test Notification',
        'message': 'Test message',
        'created_at': DateTime.now().toIso8601String(),
        'is_read': false,
        'priority': 'normal',
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NotificationItem(
              notification: notification,
            ),
          ),
        ),
      );

      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(NotificationItem),
          matching: find.byType(Container),
        ).first,
      );

      // Check padding is 18 (EdgeInsets.all(18))
      final padding = container.padding as EdgeInsets;
      expect(padding.left, 18.0);
      expect(padding.top, 18.0);
      expect(padding.right, 18.0);
      expect(padding.bottom, 18.0);
    });

    testWidgets('notification card should have softer shadows', (WidgetTester tester) async {
      final notification = {
        'id': 'test-id',
        'title': 'Test Notification',
        'message': 'Test message',
        'created_at': DateTime.now().toIso8601String(),
        'is_read': false,
        'priority': 'normal',
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NotificationItem(
              notification: notification,
            ),
          ),
        ),
      );

      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(NotificationItem),
          matching: find.byType(Container),
        ).first,
      );

      final decoration = container.decoration as BoxDecoration;
      final boxShadow = decoration.boxShadow;

      expect(boxShadow, isNotNull);
      expect(boxShadow!.length, greaterThan(0));
      
      // Verify shadow properties (softer: opacity 0.03, blur 6, offset (0, 1))
      final shadow = boxShadow.first;
      expect(shadow.color.opacity, lessThanOrEqualTo(0.03));
      expect(shadow.blurRadius, 6.0);
      expect(shadow.offset, const Offset(0, 1));
    });

    testWidgets('notification card should have refined border radius (14px)', (WidgetTester tester) async {
      final notification = {
        'id': 'test-id',
        'title': 'Test Notification',
        'message': 'Test message',
        'created_at': DateTime.now().toIso8601String(),
        'is_read': false,
        'priority': 'normal',
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NotificationItem(
              notification: notification,
            ),
          ),
        ),
      );

      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(NotificationItem),
          matching: find.byType(Container),
        ).first,
      );

      final decoration = container.decoration as BoxDecoration;
      final borderRadius = decoration.borderRadius as BorderRadius;

      expect(borderRadius, isNotNull);
      expect(borderRadius.topLeft.x, 14.0);
      expect(borderRadius.topLeft.y, 14.0);
    });

    testWidgets('notification title should have letter spacing', (WidgetTester tester) async {
      final notification = {
        'id': 'test-id',
        'title': 'Test Notification',
        'message': 'Test message',
        'created_at': DateTime.now().toIso8601String(),
        'is_read': false,
        'priority': 'normal',
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NotificationItem(
              notification: notification,
            ),
          ),
        ),
      );

      final titleText = find.text('Test Notification');
      expect(titleText, findsOneWidget);

      final textWidget = tester.widget<Text>(titleText);
      final textStyle = textWidget.style;

      expect(textStyle, isNotNull);
      // Letter spacing should be -0.2 for titles
      expect(textStyle!.letterSpacing, -0.2);
    });

    testWidgets('notification should not display green checkmark emojis', (WidgetTester tester) async {
      final notification = {
        'id': 'test-id',
        'title': 'Booking Approved', // Should not have ✅
        'message': 'Test message',
        'created_at': DateTime.now().toIso8601String(),
        'is_read': false,
        'priority': 'normal',
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NotificationItem(
              notification: notification,
            ),
          ),
        ),
      );

      // Verify title is displayed
      expect(find.text('Booking Approved'), findsOneWidget);
      
      // Verify no checkmark emoji is displayed
      expect(find.textContaining('✅'), findsNothing);
    });
  });
}

