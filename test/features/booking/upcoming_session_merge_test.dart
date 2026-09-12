import 'package:flutter_test/flutter_test.dart';
import 'package:prepskul/features/booking/utils/upcoming_session_merge.dart';

void main() {
  group('UpcomingSessionMerge', () {
    test('treats PGRST204 missing individual_session_id as a column fallback', () {
      const error =
          "PostgrestException(message: Could not find the 'individual_session_id' column of 'session_participants' in the schema cache, code: PGRST204)";
      expect(
        UpcomingSessionMerge.isMissingParticipantColumnError(error),
        isTrue,
      );
    });

    test('reads session_id or individual_session_id from participant rows', () {
      expect(
        UpcomingSessionMerge.sessionIdFromParticipantRow({
          'session_id': 'abc',
        }),
        'abc',
      );
      expect(
        UpcomingSessionMerge.sessionIdFromParticipantRow({
          'individual_session_id': 'def',
        }),
        'def',
      );
    });

    test('keeps future scheduled sessions in the upcoming merge', () {
      final now = DateTime(2026, 9, 12, 12);
      final included = UpcomingSessionMerge.includeInUpcomingList(
        {
          'status': 'scheduled',
          'scheduled_date': '2026-09-13',
          'scheduled_time': '10:00:00',
        },
        now: now,
        parseStart: (session) => DateTime.parse(
          '${session['scheduled_date']}T${session['scheduled_time']}',
        ),
      );
      expect(included, isTrue);
    });

    test('keeps in_progress sessions that have not ended as upcoming', () {
      final now = DateTime.now();
      final start = now.add(const Duration(minutes: 5));
      final date =
          '${start.year.toString().padLeft(4, '0')}-${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')}';
      final time =
          '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}:00';
      final included = UpcomingSessionMerge.includeInUpcomingList(
        {
          'status': 'in_progress',
          'session_started_at': null,
          'scheduled_date': date,
          'scheduled_time': time,
          'duration_minutes': 60,
        },
        now: now,
      );
      expect(included, isTrue);
    });
  });
}
