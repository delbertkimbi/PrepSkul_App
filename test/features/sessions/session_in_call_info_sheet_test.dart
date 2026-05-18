import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:prepskul/features/sessions/services/session_profile_service.dart';
import 'package:prepskul/features/sessions/widgets/session_in_call_info_sheet.dart';

void main() {
  testWidgets('Lesson info sheet lists roster and role context', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  showSessionInCallInfoSheet(
                    context: context,
                    sessionId:
                        '11111111-2222-3333-4444-555555555555',
                    userRole: 'tutor',
                    localProfile: const <String, dynamic>{
                      'full_name': 'Tutor Ada',
                    },
                    remoteProfile: const <String, dynamic>{
                      'full_name': 'Learner Bee',
                    },
                    booking: const SessionBookingSummary(
                      subject: 'Mathematics',
                      scheduledDisplay: 'Mon, Jan 15 · 3:30 PM',
                      durationMinutes: 60,
                      status: 'in_progress',
                      isTrial: false,
                    ),
                    timeRemaining: const Duration(minutes: 12, seconds: 5),
                    onOpenConnectionHelp: () {},
                  );
                },
                child: const Text('Open'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Lesson info'), findsOneWidget);
    expect(find.text('Mathematics'), findsOneWidget);
    expect(find.text('Tutor Ada'), findsWidgets);
  });

  test('sessionScheduledDisplayFromParts parses ISO-like roster fields', () {
    final parsed = sessionScheduledDisplayFromParts('2026-05-03', '14:30:00');
    expect(parsed, isNotEmpty);
    expect(parsed, contains('·'));

    expect(
      sessionScheduledDisplayFromParts('x', 'y'),
      'x · y',
    );
  });
}
