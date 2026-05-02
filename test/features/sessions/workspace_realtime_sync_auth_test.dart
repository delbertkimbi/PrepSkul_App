import 'package:flutter_test/flutter_test.dart';
import 'package:prepskul/features/sessions/services/workspace_realtime_sync.dart';

void main() {
  group('isAuthorizedWorkspaceBroadcast', () {
    test('allows learner to accept tutor packets', () {
      expect(
        isAuthorizedWorkspaceBroadcast(
          fromUserId: 'tutor-1',
          currentUserId: 'learner-2',
          tutorUserId: 'tutor-1',
        ),
        isTrue,
      );
    });

    test('blocks spoofed non-tutor sender', () {
      expect(
        isAuthorizedWorkspaceBroadcast(
          fromUserId: 'random',
          currentUserId: 'learner-2',
          tutorUserId: 'tutor-1',
        ),
        isFalse,
      );
    });

    test('blocks echo from self', () {
      expect(
        isAuthorizedWorkspaceBroadcast(
          fromUserId: 'tutor-1',
          currentUserId: 'tutor-1',
          tutorUserId: 'tutor-1',
        ),
        isFalse,
      );
    });

    test('blocks missing sender', () {
      expect(
        isAuthorizedWorkspaceBroadcast(
          fromUserId: null,
          currentUserId: 'learner-2',
          tutorUserId: 'tutor-1',
        ),
        isFalse,
      );
    });
  });
}
