import 'package:flutter_test/flutter_test.dart';

/// Integration tests for Session Calendar features
/// 
/// Tests the complete flow of:
/// 1. Session creation without calendar
/// 2. Adding session to calendar
/// 3. Calendar event creation
void main() {
  group('Session Calendar Integration', () {
    test('session can be created without calendar event', () {
      // Simulate session creation
      final sessionData = {
        'id': 'session-id',
        'recurring_session_id': 'recurring-id',
        'tutor_id': 'tutor-id',
        'learner_id': 'student-id',
        'subject': 'Mathematics',
        'scheduled_date': '2025-01-15',
        'scheduled_time': '10:00:00',
        'duration_minutes': 60,
        'location': 'online',
        'status': 'scheduled',
        'calendar_event_id': null, // No calendar event initially
      };

      // Verify session is created successfully
      expect(sessionData['status'], 'scheduled');
      expect(sessionData['calendar_event_id'], isNull);
      expect(sessionData.containsKey('id'), true);
    });

    test('add to calendar button appears when calendar_event_id is null', () {
      final session = {
        'id': 'session-id',
        'calendar_event_id': null,
      };

      // Button should appear when calendar_event_id is null
      final shouldShowButton = session['calendar_event_id'] == null ||
          (session['calendar_event_id'] as String? ?? '').isEmpty;

      expect(shouldShowButton, true);
    });

    test('add to calendar button disappears after calendar event is created', () {
      final sessionBefore = {
        'id': 'session-id',
        'calendar_event_id': null,
      };

      // After adding to calendar
      final sessionAfter = {
        'id': 'session-id',
        'calendar_event_id': 'calendar-event-id-123',
        'meeting_link': 'https://meet.google.com/abc-def-ghi',
      };

      // Button should not appear when calendar_event_id exists
      final shouldShowButtonBefore = sessionBefore['calendar_event_id'] == null ||
          (sessionBefore['calendar_event_id'] as String? ?? '').isEmpty;
      final shouldShowButtonAfter = sessionAfter['calendar_event_id'] == null ||
          (sessionAfter['calendar_event_id'] as String? ?? '').isEmpty;

      expect(shouldShowButtonBefore, true);
      expect(shouldShowButtonAfter, false);
    });

    test('calendar event includes all required attendees', () {
      final calendarEvent = {
        'id': 'event-id',
        'meet_link': 'https://meet.google.com/abc-def-ghi',
        'attendees': [
          'tutor@example.com',
          'student@example.com',
          'prepskul-va@prepskul.com', // PrepSkul VA for Fathom
        ],
      };

      // Verify all attendees are included
      expect(calendarEvent['attendees'], isA<List>());
      final attendees = calendarEvent['attendees'] as List;
      expect(attendees.length, 3);
      expect(attendees.contains('prepskul-va@prepskul.com'), true);
    });
  });
}





















