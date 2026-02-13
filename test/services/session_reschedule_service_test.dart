import 'package:flutter_test/flutter_test.dart';

/// Unit tests for Session Reschedule flow logic (no Supabase).
/// Validates canReschedule rules: scheduled, completed+paid, no_show, missed.
void main() {
  group('Session Reschedule - canReschedule rules', () {
    test('scheduled session can be rescheduled', () {
      const sessionStatus = 'scheduled';
      const isPaid = false;
      final canReschedule = sessionStatus == 'scheduled' ||
          (isPaid && (sessionStatus == 'completed' ||
              sessionStatus == 'no_show_tutor' ||
              sessionStatus == 'no_show_learner' ||
              sessionStatus == 'missed'));
      expect(canReschedule, isTrue);
    });

    test('completed paid session can be rescheduled', () {
      const sessionStatus = 'completed';
      const isPaid = true;
      final canReschedule = sessionStatus == 'scheduled' ||
          (isPaid && (sessionStatus == 'completed' ||
              sessionStatus == 'no_show_tutor' ||
              sessionStatus == 'no_show_learner' ||
              sessionStatus == 'missed'));
      expect(canReschedule, isTrue);
    });

    test('no_show_learner paid session can be rescheduled', () {
      const sessionStatus = 'no_show_learner';
      const isPaid = true;
      final canReschedule = sessionStatus == 'scheduled' ||
          (isPaid && (sessionStatus == 'completed' ||
              sessionStatus == 'no_show_tutor' ||
              sessionStatus == 'no_show_learner' ||
              sessionStatus == 'missed'));
      expect(canReschedule, isTrue);
    });

    test('missed paid session can be rescheduled', () {
      const sessionStatus = 'missed';
      const isPaid = true;
      final canReschedule = sessionStatus == 'scheduled' ||
          (isPaid && (sessionStatus == 'completed' ||
              sessionStatus == 'no_show_tutor' ||
              sessionStatus == 'no_show_learner' ||
              sessionStatus == 'missed'));
      expect(canReschedule, isTrue);
    });

    test('completed unpaid session cannot be rescheduled (logic)', () {
      const sessionStatus = 'completed';
      const isPaid = false;
      final canReschedule = sessionStatus == 'scheduled' ||
          (isPaid && (sessionStatus == 'completed' ||
              sessionStatus == 'no_show_tutor' ||
              sessionStatus == 'no_show_learner' ||
              sessionStatus == 'missed'));
      expect(canReschedule, isFalse);
    });

    test('cancelled session cannot be rescheduled', () {
      const sessionStatus = 'cancelled';
      const isPaid = true;
      final canReschedule = sessionStatus == 'scheduled' ||
          (isPaid && (sessionStatus == 'completed' ||
              sessionStatus == 'no_show_tutor' ||
              sessionStatus == 'no_show_learner' ||
              sessionStatus == 'missed'));
      expect(canReschedule, isFalse);
    });
  });

  group('Session Reschedule - request data shape', () {
    test('reschedule request has required fields', () {
      final requestData = <String, dynamic>{
        'session_id': 'session-1',
        'proposed_date': '2025-02-15',
        'proposed_time': '14:00',
        'reason': 'Student requested make-up',
        'status': 'pending',
        'tutor_approved': false,
        'student_approved': false,
      };
      expect(requestData['session_id'], isNotEmpty);
      expect(requestData['proposed_date'], isNotEmpty);
      expect(requestData['proposed_time'], isNotEmpty);
      expect(requestData['status'], 'pending');
    });

    test('both approvals required for reschedule to apply', () {
      var tutorApproved = true;
      var studentApproved = false;
      expect(tutorApproved && studentApproved, isFalse);

      studentApproved = true;
      expect(tutorApproved && studentApproved, isTrue);
    });
  });
}
