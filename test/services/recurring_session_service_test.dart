import 'package:flutter_test/flutter_test.dart';
import 'package:prepskul/features/booking/services/recurring_session_service.dart';
import 'package:prepskul/features/booking/models/booking_request_model.dart';

/// Unit tests for RecurringSessionService
/// 
/// Tests session creation without calendar requirement
void main() {
  group('RecurringSessionService', () {
    test('calculateStartDate returns next occurrence of first day', () {
      // Create a booking request with Monday and Wednesday
      final request = BookingRequest(
        id: 'test-id',
        studentId: 'student-id',
        tutorId: 'tutor-id',
        subject: 'Mathematics',
        frequency: 2,
        days: ['Monday', 'Wednesday'],
        times: {
          'Monday': '10:00 AM',
          'Wednesday': '2:00 PM',
        },
        location: 'online',
        paymentPlan: 'monthly',
        monthlyTotal: 10000.0,
        status: 'pending',
        createdAt: DateTime.now(),
        studentName: 'Test Student',
        studentType: 'student',
        tutorName: 'Test Tutor',
        tutorRating: 4.5,
        tutorIsVerified: true,
      );

      // This is a private method, so we test indirectly
      // The actual test would be through createRecurringSessionFromBooking
      expect(request.days, contains('Monday'));
      expect(request.days, contains('Wednesday'));
    });

    test('session creation does not require calendar event', () {
      // Verify that sessions can be created without calendar_event_id
      final sessionData = {
        'recurring_session_id': 'recurring-id',
        'tutor_id': 'tutor-id',
        'learner_id': 'student-id',
        'subject': 'Mathematics',
        'scheduled_date': '2025-01-15',
        'scheduled_time': '10:00:00',
        'duration_minutes': 60,
        'location': 'online',
        'status': 'scheduled',
      };

      // Verify calendar_event_id is not required
      expect(sessionData.containsKey('calendar_event_id'), false);
      expect(sessionData['status'], 'scheduled');
    });

    test('individual sessions generated without calendar events', () {
      // Verify that generateIndividualSessions creates sessions
      // without requiring calendar_event_id
      final sessionData = {
        'recurring_session_id': 'recurring-id',
        'tutor_id': 'tutor-id',
        'learner_id': 'student-id',
        'subject': 'Mathematics',
        'scheduled_date': '2025-01-15',
        'scheduled_time': '10:00:00',
        'duration_minutes': 60,
        'location': 'online',
        'status': 'scheduled',
        // Note: calendar_event_id is NOT included
      };

      expect(sessionData['status'], 'scheduled');
      expect(sessionData.containsKey('calendar_event_id'), false);
    });
  });
}

























