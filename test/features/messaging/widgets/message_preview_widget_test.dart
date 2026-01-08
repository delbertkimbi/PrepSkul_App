import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:prepskul/features/messaging/widgets/message_preview_widget.dart';

void main() {
  group('MessagePreviewWidget', () {
    testWidgets('should display warning when message has flags', (WidgetTester tester) async {
      final flags = [
        {
          'type': 'phone_number',
          'severity': 'high',
          'detected': '+237 612345678',
          'reason': 'Phone number detected',
        }
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MessagePreviewWidget(
              flags: flags,
              warnings: ['Phone number detected'],
              willBlock: false,
            ),
          ),
        ),
      );

      expect(find.text('Message Warning'), findsOneWidget);
      expect(find.text('Phone number detected'), findsOneWidget);
    });

    testWidgets('should display blocked message when willBlock is true', (WidgetTester tester) async {
      final flags = [
        {
          'type': 'payment_request',
          'severity': 'critical',
          'detected': 'pay outside',
          'reason': 'Payment bypass detected',
        }
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MessagePreviewWidget(
              flags: flags,
              warnings: ['Payment bypass detected'],
              willBlock: true,
            ),
          ),
        ),
      );

      expect(find.text('Message Blocked'), findsOneWidget);
      expect(find.text('Edit Message'), findsOneWidget);
    });

    testWidgets('should show edit and send anyway buttons when not blocked', (WidgetTester tester) async {
      final flags = [
        {
          'type': 'spam',
          'severity': 'low',
          'detected': 'repeated',
          'reason': 'Spam detected',
        }
      ];

      bool editCalled = false;
      bool sendCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MessagePreviewWidget(
              flags: flags,
              warnings: ['Spam detected'],
              willBlock: false,
              onEdit: () => editCalled = true,
              onSendAnyway: () => sendCalled = true,
            ),
          ),
        ),
      );

      expect(find.text('Edit'), findsOneWidget);
      expect(find.text('Send Anyway'), findsOneWidget);

      await tester.tap(find.text('Edit'));
      expect(editCalled, true);

      await tester.tap(find.text('Send Anyway'));
      expect(sendCalled, true);
    });

    testWidgets('should not display when flags are empty', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MessagePreviewWidget(
              flags: [],
              warnings: [],
              willBlock: false,
            ),
          ),
        ),
      );

      expect(find.text('Message Warning'), findsNothing);
      expect(find.text('Message Blocked'), findsNothing);
    });
  });
}

