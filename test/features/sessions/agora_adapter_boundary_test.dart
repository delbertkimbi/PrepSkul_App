import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:prepskul/features/sessions/rtc/agora_adapter.dart';

void main() {
  group('Agora adapter boundary', () {
    test('normalized rtc event models are constructible', () {
      const join = RtcJoinSuccess(uid: 42, channelId: 'abc');
      const joined = RtcUserJoined(55);
      const offline = RtcUserOffline(55);
      const error = RtcErrorEvent('boom');

      expect(join.uid, 42);
      expect(join.channelId, 'abc');
      expect(joined.uid, 55);
      expect(offline.uid, 55);
      expect(error.message, 'boom');
    });

    test('video session screen does not directly call Agora engine methods', () async {
      final file = File(
        'lib/features/sessions/screens/agora_video_session_screen.dart',
      );
      final content = await file.readAsString();

      const forbiddenCalls = <String>[
        '.engine!.setupLocalVideo(',
        '.engine!.startPreview(',
        '.engine!.muteLocalVideoStream(',
        '.engine!.muteLocalAudioStream(',
        '.engine!.joinChannel(',
        '.engine!.leaveChannel(',
        '.engine!.registerEventHandler(',
      ];

      for (final call in forbiddenCalls) {
        expect(
          content.contains(call),
          isFalse,
          reason: 'UI must not directly call engine API: $call',
        );
      }
    });
  });
}

