import 'package:flutter_test/flutter_test.dart';
import 'package:prepskul/features/booking/models/booking_request_model.dart';

void main() {
  group('BookingRequest.fromTrialSession', () {
    test('maps learner_id, tutor_id, subject and times correctly', () {
      final trialJson = {
        'id': 'trial-1',
        'learner_id': 'learner-123',
        'tutor_id': 'tutor-456',
        'subject': 'ICT',
        'scheduled_date': '2025-11-25',
        'scheduled_time': '09:00:00',
        'duration_minutes': 60,
        'location': 'online',
        'status': 'pending',
        'created_at': '2025-11-20T10:00:00Z',
        'trial_fee': 0,
      };

      final studentProfile = {
        'full_name': 'Kimbi Delbert',
        'avatar_url': 'https://example.com/avatar.png',
        'user_type': 'student',
        'email': 'delbert@example.com',
      };

      final booking = BookingRequest.fromTrialSession(
        trialJson,
        studentProfile,
        null,
      );

      expect(booking.id, 'trial-1');
      expect(booking.studentId, 'learner-123');
      expect(booking.tutorId, 'tutor-456');
      expect(booking.subject, 'ICT');
      expect(booking.isTrial, true);
      expect(booking.days.length, 1);
      expect(booking.times.length, 1);
      expect(booking.location, 'online');
      expect(booking.studentName, 'Kimbi Delbert');
    });

    test('falls back to email when full_name is missing', () {
      final trialJson = {
        'id': 'trial-2',
        'learner_id': 'learner-123',
        'tutor_id': 'tutor-456',
        'subject': 'Math',
        'scheduled_date': '2025-11-25',
        'scheduled_time': '09:00:00',
        'duration_minutes': 30,
        'location': 'online',
        'status': 'pending',
        'created_at': '2025-11-20T10:00:00Z',
        'trial_fee': 0,
      };

      final studentProfile = {
        'full_name': '',
        'avatar_url': null,
        'user_type': 'student',
        'email': 'student@example.com',
      };

      final booking = BookingRequest.fromTrialSession(
        trialJson,
        studentProfile,
        null,
      );

      expect(booking.studentName, 'student@example.com');
    });
  });
}
















