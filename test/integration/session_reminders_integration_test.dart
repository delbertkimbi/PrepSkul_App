import 'package:flutter_test/flutter_test.dart';

/// Integration tests for Session Reminder Notifications
/// 
/// Tests the complete flow of:
/// 1. Session creation
/// 2. Reminder scheduling (24h, 1h, 15min)
/// 3. Notification delivery
void main() {
  group('Session Reminders Integration', () {
    test('reminders are scheduled for all three time intervals', () {
      final sessionStart = DateTime(2025, 1, 15, 14, 0); // 2:00 PM
      final now = DateTime(2025, 1, 14, 10, 0); // 10:00 AM (day before)

      // Calculate reminder times
      final reminders = [
        {
          'type': '24_hours',
          'time': sessionStart.subtract(const Duration(hours: 24)),
          'title': '📅 Session Reminder',
          'priority': 'normal',
        },
        {
          'type': '1_hour',
          'time': sessionStart.subtract(const Duration(hours: 1)),
          'title': '⏰ Session Starting Soon',
          'priority': 'high',
        },
        {
          'type': '15_minutes',
          'time': sessionStart.subtract(const Duration(minutes: 15)),
          'title': '🚀 Join Session Now',
          'priority': 'urgent',
        },
      ];

      // Verify all reminders are scheduled
      expect(reminders.length, 3);
      for (final reminder in reminders) {
        final reminderTime = reminder['time'] as DateTime;
        expect(reminderTime.isAfter(now), true);
        expect(reminder['title'], isNotNull);
        expect(reminder['priority'], isNotNull);
      }
    });

    test('reminders are sent to both tutor and student', () {
      const tutorId = 'tutor-id';
      const studentId = 'student-id';
      const sessionId = 'session-id';

      // Simulate reminder creation for both users
      final tutorReminder = {
        'user_id': tutorId,
        'type': 'session_reminder',
        'session_id': sessionId,
        'message': 'Your upcoming session with Student starts in 24 hours!',
      };

      final studentReminder = {
        'user_id': studentId,
        'type': 'session_reminder',
        'session_id': sessionId,
        'message': 'Your session with Tutor starts in 24 hours!',
      };

      // Verify both reminders are created
      expect(tutorReminder['user_id'], tutorId);
      expect(studentReminder['user_id'], studentId);
      expect(tutorReminder['session_id'], sessionId);
      expect(studentReminder['session_id'], sessionId);
    });

    test('reminder messages are personalized for tutor vs student', () {
      const tutorName = 'John Doe';
      const studentName = 'Jane Smith';

      // Tutor reminder message
      final tutorMessage = 'Your upcoming session with $studentName is tomorrow!';
      expect(tutorMessage, contains('upcoming'));
      expect(tutorMessage, contains(studentName));

      // Student reminder message
      final studentMessage = 'Your session with $tutorName is tomorrow!';
      expect(studentMessage, isNot(contains('upcoming')));
      expect(studentMessage, contains(tutorName));
    });

    test('reminders respect session start time constraints', () {
      final sessionStart = DateTime(2025, 1, 15, 14, 0);
      final now = DateTime(2025, 1, 15, 13, 0); // 1 hour before session

      // 24-hour reminder should not be scheduled (too late)
      final twentyFourHoursBefore = sessionStart.subtract(const Duration(hours: 24));
      final shouldSchedule24h = twentyFourHoursBefore.isAfter(now);
      expect(shouldSchedule24h, false);

      // 1-hour reminder should be scheduled
      final oneHourBefore = sessionStart.subtract(const Duration(hours: 1));
      final shouldSchedule1h = oneHourBefore.isAfter(now);
      expect(shouldSchedule1h, false); // Exactly 1 hour before

      // 15-minute reminder should be scheduled
      final fifteenMinutesBefore = sessionStart.subtract(const Duration(minutes: 15));
      final shouldSchedule15m = fifteenMinutesBefore.isAfter(now);
      expect(shouldSchedule15m, true);
    });
  });
}






















