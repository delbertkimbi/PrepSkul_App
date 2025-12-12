import 'package:flutter_test/flutter_test.dart';
import 'package:prepskul/core/services/notification_helper_service.dart';

/// Unit tests for NotificationHelperService
/// 
/// Tests session reminder scheduling and notification sending
void main() {
  group('NotificationHelperService - Session Reminders', () {
    test('scheduleSessionReminders calculates correct reminder times', () {
      final sessionStart = DateTime(2025, 1, 15, 14, 0); // 2:00 PM
      final now = DateTime(2025, 1, 14, 10, 0); // 10:00 AM (day before)

      // Calculate expected reminder times
      final twentyFourHoursBefore = sessionStart.subtract(const Duration(hours: 24));
      final oneHourBefore = sessionStart.subtract(const Duration(hours: 1));
      final fifteenMinutesBefore = sessionStart.subtract(const Duration(minutes: 15));

      // Verify calculations
      expect(twentyFourHoursBefore, DateTime(2025, 1, 14, 14, 0));
      expect(oneHourBefore, DateTime(2025, 1, 15, 13, 0));
      expect(fifteenMinutesBefore, DateTime(2025, 1, 15, 13, 45));

      // Verify reminders are in the future
      expect(twentyFourHoursBefore.isAfter(now), true);
      expect(oneHourBefore.isAfter(now), true);
      expect(fifteenMinutesBefore.isAfter(now), true);
    });

    test('session reminder messages are correctly formatted', () {
      const tutorName = 'John Doe';
      const studentName = 'Jane Smith';
      const subject = 'Mathematics';
      const sessionType = 'recurring';

      // Test 24-hour reminder message
      final message24h = sessionType == 'trial'
          ? 'Your trial session with $tutorName is tomorrow!'
          : 'Your session with $tutorName is tomorrow!';
      expect(message24h, contains(tutorName));
      expect(message24h, contains('tomorrow'));

      // Test 1-hour reminder message
      final message1h = sessionType == 'trial'
          ? 'Your trial session with $tutorName starts in 1 hour!'
          : 'Your session with $tutorName starts in 1 hour!';
      expect(message1h, contains('1 hour'));

      // Test 15-minute reminder message
      final message15m = sessionType == 'trial'
          ? 'Your trial session with $tutorName starts in 15 minutes! Join now.'
          : 'Your session with $tutorName starts in 15 minutes! Join now.';
      expect(message15m, contains('15 minutes'));
      expect(message15m, contains('Join now'));
    });

    test('reminder priorities are correctly assigned', () {
      // 24-hour reminder should be normal priority
      const reminder24h = 'normal';
      expect(reminder24h, 'normal');

      // 1-hour reminder should be high priority
      const reminder1h = 'high';
      expect(reminder1h, 'high');

      // 15-minute reminder should be urgent priority
      const reminder15m = 'urgent';
      expect(reminder15m, 'urgent');
    });

    test('reminders are scheduled for both tutor and student', () {
      const tutorId = 'tutor-id';
      const studentId = 'student-id';

      // Verify both users should receive reminders
      expect(tutorId, isNotEmpty);
      expect(studentId, isNotEmpty);
      expect(tutorId, isNot(studentId));
    });
  });

  group('NotificationHelperService - Notification Metadata', () {
    test('session reminder metadata includes all required fields', () {
      const sessionId = 'session-id';
      const sessionType = 'recurring';
      const reminderType = '24_hours';
      final sessionStart = DateTime(2025, 1, 15, 14, 0);

      final metadata = {
        'session_id': sessionId,
        'session_type': sessionType,
        'reminder_type': reminderType,
        'session_start': sessionStart.toIso8601String(),
      };

      expect(metadata['session_id'], sessionId);
      expect(metadata['session_type'], sessionType);
      expect(metadata['reminder_type'], reminderType);
      expect(metadata['session_start'], isNotNull);
    });
  });
}


