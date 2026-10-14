import 'package:flutter_test/flutter_test.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:prepskul/features/skulmate/services/skulmate_tutor_voice_service.dart';
import 'package:prepskul/features/skulmate/services/tts_service.dart';

class TestSpeech extends Fake implements SpeechToText {
  bool available = true;
  bool starts = true;
  bool listening = false;
  SpeechErrorListener? errorCallback;
  SpeechStatusListener? statusCallback;
  SpeechResultListener? resultCallback;
  String? usedLocale;

  @override
  bool get isListening => listening;
  @override
  Future<bool> initialize({
    SpeechErrorListener? onError,
    SpeechStatusListener? onStatus,
    dynamic debugLogging = false,
    Duration finalTimeout = const Duration(seconds: 2),
    List<SpeechConfigOption>? options,
  }) async {
    errorCallback = onError;
    statusCallback = onStatus;
    return available;
  }

  @override
  Future<List<LocaleName>> locales() async => [
    LocaleName('fr_CA', 'French'),
    LocaleName('en_GB', 'English'),
  ];
  @override
  Future<void> listen({
    SpeechResultListener? onResult,
    Duration? listenFor,
    Duration? pauseFor,
    String? localeId,
    SpeechSoundLevelChange? onSoundLevelChange,
    dynamic cancelOnError = false,
    dynamic partialResults = true,
    dynamic onDevice = false,
    ListenMode listenMode = ListenMode.confirmation,
    dynamic sampleRate = 0,
    SpeechListenOptions? listenOptions,
  }) async {
    resultCallback = onResult;
    usedLocale = listenOptions?.localeId;
    listening = starts;
    if (listening) statusCallback?.call('listening');
  }

  @override
  Future<void> stop() async {
    listening = false;
  }

  @override
  Future<void> cancel() async {
    listening = false;
  }
}

class TestTts extends Fake implements TTSService {
  @override
  Future<void> ensureInitialized() async {}
  @override
  Future<void> stop() async {}
}

void main() {
  late TestSpeech recognizer;
  late SkulMateTutorVoiceService voice;
  setUp(() {
    recognizer = TestSpeech();
    voice = SkulMateTutorVoiceService.forTesting(
      recognizer: recognizer,
      speech: TestTts(),
    );
  });
  tearDown(() async {
    await voice.endSession();
  });

  test(
    'failed activation stays idle and muted instead of claiming to listen',
    () async {
      recognizer.starts = false;
      await voice.startAlwaysOn(locale: 'en', onUtterance: (_) {});
      expect(voice.state.value, TutorVoiceState.idle);
      expect(voice.privacyMute, isTrue);
      expect(voice.lastError, isNotNull);
    },
  );
  test('unavailable recognition has a recoverable error', () async {
    recognizer.available = false;
    await voice.startAlwaysOn(locale: 'en', onUtterance: (_) {});
    expect(voice.state.value, TutorVoiceState.idle);
    expect(voice.lastError, 'speech_unavailable');
    expect(voice.privacyMute, isTrue);
  });
  test('uses an available locale and forwards a short final answer', () async {
    final utterances = <String>[];
    await voice.startAlwaysOn(locale: 'fr', onUtterance: utterances.add);
    expect(recognizer.usedLocale, 'fr_CA');
    expect(voice.state.value, TutorVoiceState.recording);
    recognizer.resultCallback?.call(
      SpeechRecognitionResult.fromJson({
        'alternates': [
          {'recognizedWords': 'oui', 'confidence': 1.0},
        ],
        'resultType': 2,
      }),
    );
    expect(utterances, ['oui']);
  });
  test(
    'permission denial stops listening and retry can start a new session',
    () async {
      await voice.startAlwaysOn(locale: 'en', onUtterance: (_) {});
      recognizer.listening = false;
      recognizer.errorCallback?.call(
        SpeechRecognitionError('error_permission', true),
      );
      expect(voice.privacyMute, isTrue);
      expect(voice.state.value, TutorVoiceState.idle);
      await voice.startAlwaysOn(locale: 'en', onUtterance: (_) {});
      expect(voice.isListening, isTrue);
      expect(voice.lastError, isNull);
    },
  );
}
