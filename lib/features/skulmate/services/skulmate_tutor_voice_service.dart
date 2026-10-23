import 'package:flutter/foundation.dart';
import 'package:prepskul/features/skulmate/services/tts_service.dart';
import 'package:speech_to_text/speech_to_text.dart';

enum TutorVoiceState { idle, recording, thinking, speaking }

/// Learner speech and tutor audio. Web listening begins with a microphone tap.
class SkulMateTutorVoiceService {
  SkulMateTutorVoiceService._() : _stt = SpeechToText(), _tts = TTSService();

  @visibleForTesting
  SkulMateTutorVoiceService.forTesting({
    required SpeechToText recognizer,
    required TTSService speech,
  }) : _stt = recognizer,
       _tts = speech;

  static final SkulMateTutorVoiceService instance =
      SkulMateTutorVoiceService._();

  final SpeechToText _stt;
  final TTSService _tts;
  final ValueNotifier<TutorVoiceState> state = ValueNotifier<TutorVoiceState>(
    TutorVoiceState.idle,
  );

  bool _sttReady = false;
  String _heard = '';
  bool voiceOut = true;
  bool _alwaysOn = false;
  bool _speaking = false;
  int _sessionGeneration = 0;
  bool privacyMute = true;
  String? lastError;
  int _recognitionErrors = 0;
  bool get isListening => _stt.isListening;
  void Function(String text)? _onUtterance;
  String _locale = 'en';
  String _recognitionLocale = 'en-US';

  Future<void> prepare() async {
    // Input permission must not wait on output voice initialization.
    try {
      _sttReady = await _stt.initialize(
        onError: (error) {
          lastError = error.errorMsg;
          state.value = TutorVoiceState.idle;
          _recognitionErrors += 1;
          final denied = RegExp(
            r'permission|not_allowed|audio_capture|language_not_supported|not_available',
            caseSensitive: false,
          ).hasMatch(error.errorMsg);
          if (denied || _recognitionErrors >= 3) {
            _alwaysOn = false;
            privacyMute = true;
            return;
          }
          if (_alwaysOn && !privacyMute && !_speaking) {
            Future<void>.delayed(const Duration(milliseconds: 400), _restart);
          }
        },
        onStatus: (status) {
          if (status == 'listening' &&
              _alwaysOn &&
              !privacyMute &&
              !_speaking) {
            state.value = TutorVoiceState.recording;
          }
          if (status == 'done' || status == 'notListening') {
            if (state.value == TutorVoiceState.recording) {
              state.value = TutorVoiceState.idle;
            }
            if (_alwaysOn && !privacyMute && !_speaking) {
              Future<void>.delayed(const Duration(milliseconds: 200), _restart);
            }
          }
        },
      );
    } catch (_) {
      _sttReady = false;
    }
    if (!_sttReady) {
      lastError = 'speech_unavailable';
      privacyMute = true;
      state.value = TutorVoiceState.idle;
    }
  }

  Future<void> startAlwaysOn({
    required String locale,
    required void Function(String text) onUtterance,
  }) async {
    final generation = ++_sessionGeneration;
    lastError = null;
    _recognitionErrors = 0;
    _locale = locale;
    _onUtterance = onUtterance;
    _alwaysOn = true;
    privacyMute = false;
    if (!_sttReady) await prepare();
    if (generation != _sessionGeneration) return;
    _recognitionLocale = locale.startsWith('fr') ? 'fr-FR' : 'en-US';
    if (_sttReady) {
      try {
        final available = await _stt.locales();
        final matches = available.where(
          (item) => item.localeId
              .replaceAll('_', '-')
              .toLowerCase()
              .startsWith(locale.startsWith('fr') ? 'fr-' : 'en-'),
        );
        if (matches.isNotEmpty) _recognitionLocale = matches.first.localeId;
      } catch (_) {
        /* Use the requested language's standard browser locale. */
      }
    }
    if (generation != _sessionGeneration) return;
    await _restart();
  }

  Future<void> _restart() async {
    if (!_alwaysOn ||
        privacyMute ||
        !_sttReady ||
        _speaking ||
        state.value == TutorVoiceState.thinking) {
      return;
    }
    if (_stt.isListening) return;
    _heard = '';
    try {
      await _stt.listen(
        listenOptions: SpeechListenOptions(
          localeId: _recognitionLocale,
          pauseFor: const Duration(milliseconds: 1400),
          listenFor: const Duration(minutes: 8),
          partialResults: true,
          listenMode: ListenMode.dictation,
        ),
        onResult: (result) {
          _heard = result.recognizedWords;
          if (_heard.trim().isNotEmpty) _recognitionErrors = 0;
          if (state.value == TutorVoiceState.speaking &&
              result.recognizedWords.trim().split(RegExp(r'\s+')).length >= 2) {
            _tts.stop();
          }
          if (result.finalResult && _heard.trim().isNotEmpty) {
            final text = _heard.trim();
            _heard = '';
            _onUtterance?.call(text);
          }
        },
      );
      if (_stt.isListening && _alwaysOn && !privacyMute) {
        state.value = TutorVoiceState.recording;
      } else if (!_stt.isListening) {
        // Browser recognition starts asynchronously after listen() returns.
        await Future<void>.delayed(const Duration(milliseconds: 900));
        if (!_alwaysOn || privacyMute) return;
        if (_stt.isListening) {
          state.value = TutorVoiceState.recording;
          return;
        }
        lastError ??= 'speech_not_started';
        privacyMute = true;
        _alwaysOn = false;
        state.value = TutorVoiceState.idle;
      }
    } catch (_) {
      lastError = 'speech_not_started';
      privacyMute = true;
      _alwaysOn = false;
      state.value = TutorVoiceState.idle;
    }
  }

  Future<void> setPrivacyMute(bool mute) async {
    privacyMute = mute;
    if (mute) {
      _alwaysOn = false;
      await stopListening();
      return;
    }
    _alwaysOn = true;
    await _restart();
  }

  Future<bool> startListening({String locale = 'en'}) async {
    await startAlwaysOn(locale: locale, onUtterance: _onUtterance ?? (_) {});
    return _stt.isListening;
  }

  Future<String?> stopListening() async {
    try {
      if (_stt.isListening) await _stt.stop();
    } catch (_) {}
    final text = _heard.trim();
    _heard = '';
    if (state.value == TutorVoiceState.recording) {
      state.value = TutorVoiceState.idle;
    }
    return text.isEmpty ? null : text;
  }

  void setThinking() {
    state.value = TutorVoiceState.thinking;
    // Cancel recognition while processing so it cannot submit another utterance.
    if (_stt.isListening) _stt.cancel();
  }

  Future<void> speakTutor(String text, {bool keepListening = true}) async {
    if (!voiceOut) {
      state.value = TutorVoiceState.idle;
      if (keepListening) await _restart();
      return;
    }
    if (text.trim().isEmpty) return;
    _speaking = true;
    if (_stt.isListening) {
      try {
        await _stt.stop();
      } catch (_) {}
    }
    void reflectPlayback() {
      if (_speaking && _tts.speaking.value) {
        state.value = TutorVoiceState.speaking;
      }
    }

    _tts.speaking.addListener(reflectPlayback);
    try {
      await _tts.ensureInitialized();
      await _tts.setLanguage(_locale.startsWith('fr') ? 'fr' : 'en');
      await _tts.speakAndWait(text);
    } finally {
      _tts.speaking.removeListener(reflectPlayback);
      _speaking = false;
      state.value = TutorVoiceState.idle;
      if (keepListening && _alwaysOn && _sttReady && !privacyMute) {
        await _restart();
      } else if (state.value == TutorVoiceState.speaking) {
        state.value = TutorVoiceState.idle;
      }
    }
  }

  Future<void> interrupt() async {
    await _tts.stop();
    state.value = TutorVoiceState.idle;
    if (!privacyMute && _alwaysOn) {
      _speaking = false;
      await _restart();
      return;
    }
    await stopListening();
    state.value = TutorVoiceState.idle;
  }

  /// End this screen's voice session before disposing its UI callbacks.
  Future<void> endSession() async {
    ++_sessionGeneration;
    _alwaysOn = false;
    privacyMute = true;
    _onUtterance = null;
    _speaking = false;
    await _tts.stop();
    await stopListening();
    state.value = TutorVoiceState.idle;
  }
}
