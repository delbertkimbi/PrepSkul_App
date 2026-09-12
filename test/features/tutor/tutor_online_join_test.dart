import 'package:flutter_test/flutter_test.dart';
import 'package:prepskul/features/tutor/utils/tutor_online_join.dart';

void main() {
  group('TutorOnlineJoin', () {
    test('shows Join for online scheduled sessions without a Meet link', () {
      expect(
        TutorOnlineJoin.shouldShowJoinAction(
          location: 'online',
          status: 'scheduled',
          meetLink: null,
        ),
        isTrue,
      );
    });

    test('shows Join for online in_progress sessions without a Meet link', () {
      expect(
        TutorOnlineJoin.shouldShowJoinAction(
          location: 'online',
          status: 'in_progress',
          meetLink: '',
        ),
        isTrue,
      );
    });

    test('hides Join for onsite sessions even if Meet exists', () {
      expect(
        TutorOnlineJoin.shouldShowJoinAction(
          location: 'onsite',
          status: 'scheduled',
          meetLink: 'https://meet.google.com/abc',
        ),
        isFalse,
      );
    });
  });
}
