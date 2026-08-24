import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prepskul/features/primar/domain/parent_phrases.dart';
import 'package:prepskul/features/primar/domain/teaching_voice.dart';
import 'package:prepskul/features/primar/services/parent_voice_store.dart';
import 'package:prepskul/features/primar/services/primar_voice.dart';

/// Parent voice is recorded playback, not synthesis — these tests guard the
/// wiring that lets praise fall through to disk when a family has recorded.
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
    for (final name in silenced) {
      binding.defaultBinaryMessenger
          .setMockMethodCallHandler(MethodChannel(name), null);
    }
  });

  test('parent voice is offered in both locales', () {
    expect(
      voicesFor('en').any((v) => v.id == 'parent' && v.kind == VoiceKind.parent),
      isTrue,
    );
    expect(
      voicesFor('fr').any((v) => v.id == 'parent' && v.kind == VoiceKind.parent),
      isTrue,
    );
  });

  test('voiceById resolves parent and falls back to guide', () {
    expect(voiceById('parent', 'en').kind, VoiceKind.parent);
    expect(voiceById('missing', 'en').id, 'guide');
    expect(voiceById('parent', 'fr').kind, VoiceKind.parent);
  });

  test('praise lines map to parent recordings, questions do not', () {
    expect(parentPhraseFor('yes'), 'well_done');
    expect(parentPhraseFor('all_done'), 'proud');
    expect(parentPhraseFor('now_you_try'), 'try_again');
    expect(parentPhraseFor('you_can_do_it'), 'take_time');
    expect(parentPhraseFor('ask_name'), isNull);
  });

  test('init with parent voice does not throw when storage is unavailable', () async {
    await expectLater(
      PrimarVoice.instance.init(locale: 'en', voiceId: 'parent'),
      completes,
    );
  });

  test('store reports no recordings in test environment', () async {
    expect(await ParentVoiceStore.instance.hasAny, isFalse);
    expect(await ParentVoiceStore.instance.recorded(), isEmpty);
  });
}
