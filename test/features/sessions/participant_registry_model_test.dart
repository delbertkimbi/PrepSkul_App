import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:prepskul/features/sessions/domain/participant_state.dart';

void main() {
  group('Participant registry model', () {
    test('participant state copyWith updates selected fields', () {
      final initial = ParticipantState(uid: 10);
      final updated = initial.copyWith(
        videoMuted: true,
        audioMuted: true,
        userLeft: false,
      );

      expect(updated.uid, 10);
      expect(updated.videoMuted, isTrue);
      expect(updated.audioMuted, isTrue);
      expect(updated.userLeft, isFalse);
      expect(updated.videoReady, initial.videoReady);
    });

    test('session screen contains participant registry map', () async {
      final file = File(
        'lib/features/sessions/screens/agora_video_session_screen.dart',
      );
      final content = await file.readAsString();

      expect(
        content.contains('Map<int, ParticipantState> _participants'),
        isTrue,
        reason: 'Session screen should maintain participant registry map.',
      );
      expect(
        content.contains('_upsertParticipant('),
        isTrue,
        reason: 'Session screen should update participant registry on events.',
      );
    });
  });
}

