import 'package:flutter_test/flutter_test.dart';
import 'package:prepskul/features/booking/models/trial_session_model.dart';

/// NOTE:
/// These are lightweight unit-style tests that exercise the core
/// trial logic without hitting real external APIs.
/// For now we only validate pure Dart behaviour (status guards, model helpers).

void main() {
  group('TrialSession model', () {
    TrialSession _buildTrial({required String time}) {
      return TrialSession(
        id: 't1',
        tutorId: 'tutor',
        learnerId: 'learner',
        requesterId: 'learner',
        subject: 'Math',
        scheduledDate: DateTime(2025, 1, 1),
        scheduledTime: time,
        durationMinutes: 60,
        location: 'online',
        trialFee: 0,
        createdAt: DateTime(2025, 1, 1),
      );
    }

    test('formattedTime converts 14:00 to 2:00 PM', () {
      expect(_buildTrial(time: '14:00').formattedTime, '2:00 PM');
    });

    test('formattedTime handles midnight and noon correctly', () {
      expect(_buildTrial(time: '00:30').formattedTime, '12:30 AM');
      expect(_buildTrial(time: '12:15').formattedTime, '12:15 PM');
    });

    test('formattedTime formats morning hour with no leading zero', () {
      expect(_buildTrial(time: '09:05').formattedTime, '9:05 AM');
    });

    test('toJson / fromJson roundtrip preserves core fields', () {
      final original = _buildTrial(time: '10:00');
      final json = original.toJson();
      final copy = TrialSession.fromJson(json);

      expect(copy.id, original.id);
      expect(copy.tutorId, original.tutorId);
      expect(copy.learnerId, original.learnerId);
      expect(copy.subject, original.subject);
      expect(copy.scheduledDate, original.scheduledDate);
      expect(copy.scheduledTime, original.scheduledTime);
      expect(copy.durationMinutes, original.durationMinutes);
      expect(copy.location, original.location);
      expect(copy.trialFee, original.trialFee);
    });
  });

  // Higher level integration-like tests for TrialSessionService / MeetService
  // (create → approve → pay → generate meet) will be added separately
  // using mock Supabase and HTTP clients.
}


