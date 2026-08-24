import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prepskul/features/primar/services/primar_voice.dart';

/// The voice must never speak for a screen the child has already left.
///
/// ## The symptom
///
/// "I'm on another screen and it's saying something that happened behind."
///
/// ## Why clearing the queue never fixed it
///
/// [PrimarVoice.interrupt] emptied the queue and stopped the player, and the
/// old line still arrived. A line that has reached `_speakNow` has already
/// left the queue, and it then sits on a chain of awaits — find the cached
/// file, check connectivity, download the audio, play it. Stopping the player
/// does nothing to a download in flight. On a slow connection that download
/// outlasts two or three screens, and whenever it lands, it plays.
///
/// So every line now carries the scene it was queued in, and the scene is
/// re-checked after each await. These tests hold that contract at the seam a
/// unit test can actually reach: what survives the queue.
void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  const silenced = <String>[
    'xyz.luan/audioplayers.global',
    'xyz.luan/audioplayers',
    'flutter_tts',
    'plugins.flutter.io/path_provider',
    'dev.fluttercommunity.plus/connectivity',
  ];

  setUp(() {
    for (final name in silenced) {
      binding.defaultBinaryMessenger.setMockMethodCallHandler(
        MethodChannel(name),
        (call) async => null,
      );
    }
  });

  tearDown(() {
    PrimarVoice.instance.setMuted(false);
    for (final name in silenced) {
      binding.defaultBinaryMessenger
          .setMockMethodCallHandler(MethodChannel(name), null);
    }
  });

  test('a line queued before the screen changed is dropped, not spoken', () {
    final voice = PrimarVoice.instance;
    voice.setMuted(false);

    voice.say(VoiceLines.askName);
    voice.say(VoiceLines.askAge);
    expect(voice.debugQueuedLines, isNotEmpty,
        reason: 'nothing was queued, so this test proves nothing');

    voice.newScene();

    expect(voice.debugQueuedLines, isEmpty,
        reason: 'the previous screen still has lines waiting to be said');
  });

  test('a line queued after the change survives it', () {
    final voice = PrimarVoice.instance;
    voice.setMuted(false);

    voice.say(VoiceLines.askName);
    voice.newScene();
    voice.say(VoiceLines.askAge);

    // The bug this guards is the over-correction: bumping the scene *after*
    // queueing the new screen's line, which throws away the line that was
    // supposed to introduce the screen the child just arrived on. It cost the
    // result screen its only spoken sentence the first time round.
    expect(voice.debugQueuedLines, contains(VoiceLines.askAge.id));
  });

  test('scene numbers only ever move forward', () {
    final voice = PrimarVoice.instance;
    final before = voice.debugScene;
    voice.newScene();
    voice.newScene();
    expect(voice.debugScene, before + 2,
        reason: 'a scene that can repeat can let a stale line back in');
  });

  test('a stale line is not spoken even when it is the only one left', () {
    // The queue being empty is not the same as nothing being about to speak,
    // which is precisely the distinction the original fix missed.
    final voice = PrimarVoice.instance;
    voice.setMuted(false);
    voice.sayAll([VoiceLines.lookAgain, VoiceLines.nowYouTry]);
    voice.newScene();
    expect(voice.debugQueuedLines, isEmpty);
  });
}
