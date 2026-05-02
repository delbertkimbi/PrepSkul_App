import 'package:flutter_test/flutter_test.dart';
import 'package:prepskul/features/sessions/domain/stream_priority_policy.dart';

void main() {
  group('StreamPriorityPolicy', () {
    const policy = StreamPriorityPolicy();

    test('uses first remote as spotlight when none is set', () {
      final result = policy.decide(
        remoteUids: {101, 202},
        speakingUids: const {},
        currentSpotlightUid: null,
      );

      expect(result.spotlightUid, isNotNull);
      expect(result.highPriorityUids.length, 1);
      expect(result.lowPriorityUids.length, 1);
    });

    test('promotes active speaker to spotlight', () {
      final result = policy.decide(
        remoteUids: {101, 202, 303},
        speakingUids: {303},
        currentSpotlightUid: 101,
      );

      expect(result.spotlightUid, 303);
      expect(result.highPriorityUids, {303});
      expect(result.lowPriorityUids, {101, 202});
    });

    test('keeps spotlight valid if current spotlight leaves', () {
      final result = policy.decide(
        remoteUids: {202, 303},
        speakingUids: const {},
        currentSpotlightUid: 101,
      );

      expect(result.spotlightUid, isNot(101));
      expect(result.highPriorityUids.length, 1);
      expect(result.lowPriorityUids.length, 1);
    });

    test('pins gallery tile first in HIGH then adds spotlight when different', () {
      final result = policy.decide(
        remoteUids: {10, 20, 30},
        speakingUids: const {30},
        currentSpotlightUid: 10,
        pinnedRemoteUid: 20,
      );

      expect(result.spotlightUid, 30);
      expect(result.highPriorityUids, {20, 30});
      expect(result.lowPriorityUids, {10});
    });

    test('ignores pinned UID when not in remote set', () {
      final result = policy.decide(
        remoteUids: {101, 202},
        speakingUids: const {202},
        currentSpotlightUid: 101,
        pinnedRemoteUid: 999,
      );

      expect(result.spotlightUid, 202);
      expect(result.highPriorityUids, {202});
      expect(result.lowPriorityUids, {101});
    });

    test('maxHighStreams caps ordered HIGH list (pinned wins)', () {
      final result = policy.decide(
        remoteUids: {1, 2, 3},
        speakingUids: const {3},
        currentSpotlightUid: 2,
        pinnedRemoteUid: 1,
        maxHighStreams: 1,
      );

      expect(result.spotlightUid, 3);
      expect(result.highPriorityUids, {1});
      expect(result.lowPriorityUids, {2, 3});
    });
  });
}

