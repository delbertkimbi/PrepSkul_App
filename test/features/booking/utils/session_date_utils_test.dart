import 'package:flutter_test/flutter_test.dart';
import 'package:prepskul/features/booking/models/trial_session_model.dart';
import 'package:prepskul/features/booking/utils/session_date_utils.dart';

/// Unit tests for SessionDateUtils (session expiry, upcoming, pay button, time until session).
void main() {
  TrialSession _session({
    required DateTime scheduledDate,
    required String scheduledTime,
    String status = 'pending',
    String paymentStatus = 'unpaid',
  }) {
    return TrialSession.fromJson({
      'id': 'test-id',
      'tutor_id': 'tutor-1',
      'learner_id': 'learner-1',
      'requester_id': 'learner-1',
      'subject': 'Math',
      'scheduled_date': scheduledDate.toIso8601String().split('T')[0],
      'scheduled_time': scheduledTime,
      'duration_minutes': 60,
      'location': 'online',
      'trial_fee': 5000.0,
      'status': status,
      'payment_status': paymentStatus,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  group('SessionDateUtils', () {
    test('isSessionExpired returns true when session date/time is in the past', () {
      final past = DateTime.now().subtract(const Duration(hours: 1));
      final session = _session(
        scheduledDate: past,
        scheduledTime: '${past.hour.toString().padLeft(2, '0')}:${past.minute.toString().padLeft(2, '0')}',
      );
      expect(SessionDateUtils.isSessionExpired(session), isTrue);
    });

    test('isSessionExpired returns false when session date/time is in the future', () {
      final future = DateTime.now().add(const Duration(days: 1));
      final session = _session(
        scheduledDate: future,
        scheduledTime: '14:00',
      );
      expect(SessionDateUtils.isSessionExpired(session), isFalse);
    });

    test('isSessionUpcoming returns true when session is in the future', () {
      final future = DateTime.now().add(const Duration(days: 1));
      final session = _session(
        scheduledDate: future,
        scheduledTime: '14:00',
      );
      expect(SessionDateUtils.isSessionUpcoming(session), isTrue);
    });

    test('isSessionUpcoming returns false when session is in the past', () {
      final past = DateTime.now().subtract(const Duration(hours: 1));
      final session = _session(
        scheduledDate: past,
        scheduledTime: '${past.hour.toString().padLeft(2, '0')}:00',
      );
      expect(SessionDateUtils.isSessionUpcoming(session), isFalse);
    });

    test('getTimeUntilSession returns "Expired" for past session', () {
      final past = DateTime.now().subtract(const Duration(hours: 1));
      final session = _session(
        scheduledDate: past,
        scheduledTime: '${past.hour.toString().padLeft(2, '0')}:00',
      );
      expect(SessionDateUtils.getTimeUntilSession(session), 'Expired');
    });

    test('getTimeUntilSession returns non-empty string for future session', () {
      final future = DateTime.now().add(const Duration(days: 1));
      final session = _session(
        scheduledDate: future,
        scheduledTime: '14:00',
      );
      final result = SessionDateUtils.getTimeUntilSession(session);
      expect(result, isNotEmpty);
      expect(result, isNot('Expired'));
    });

    test('shouldShowPayNowButton returns false for pending session', () {
      final future = DateTime.now().add(const Duration(days: 1));
      final session = _session(
        scheduledDate: future,
        scheduledTime: '14:00',
        status: 'pending',
        paymentStatus: 'unpaid',
      );
      expect(SessionDateUtils.shouldShowPayNowButton(session), isFalse);
    });

    test('shouldShowPayNowButton returns false for already paid session', () {
      final future = DateTime.now().add(const Duration(days: 1));
      final session = _session(
        scheduledDate: future,
        scheduledTime: '14:00',
        status: 'approved',
        paymentStatus: 'paid',
      );
      expect(SessionDateUtils.shouldShowPayNowButton(session), isFalse);
    });

    test('shouldShowPayNowButton returns false for expired session', () {
      final past = DateTime.now().subtract(const Duration(hours: 1));
      final session = _session(
        scheduledDate: past,
        scheduledTime: '${past.hour.toString().padLeft(2, '0')}:00',
        status: 'approved',
        paymentStatus: 'unpaid',
      );
      expect(SessionDateUtils.shouldShowPayNowButton(session), isFalse);
    });

    test('shouldShowPayNowButton returns true for approved unpaid upcoming session', () {
      final future = DateTime.now().add(const Duration(days: 1));
      final session = _session(
        scheduledDate: future,
        scheduledTime: '14:00',
        status: 'approved',
        paymentStatus: 'unpaid',
      );
      expect(SessionDateUtils.shouldShowPayNowButton(session), isTrue);
    });

    test('getSessionDateTime combines date and time correctly', () {
      final date = DateTime(2025, 2, 10);
      final session = _session(
        scheduledDate: date,
        scheduledTime: '14:30',
      );
      final dt = SessionDateUtils.getSessionDateTime(session);
      expect(dt.year, 2025);
      expect(dt.month, 2);
      expect(dt.day, 10);
      expect(dt.hour, 14);
      expect(dt.minute, 30);
    });
  });
}
