import 'package:flutter/foundation.dart';
import 'package:prepskul/features/skulmate/services/tts_service.dart';
import 'package:speech_to_text/speech_to_text.dart';

enum TutorVoiceState { idle, recording, thinking, speaking }

/// Always-on student talk + tutor speech. No tap to start talking.
class SkulMateTutorVoiceService {
  SkulMateTutorVoiceService._();

  static final SkulMateTutorVoiceService instance =
      SkulMateTutorVoiceService._();

  final SpeechToText _stt = SpeechToText();
  final TTSService _tts = TTSService();
  final ValueNotifier<TutorVoiceState> state = ValueNotifier<TutorVoiceState>(
    TutorVoiceState.idle,
  );

  bool _sttReady = false;
  String _heard = '';
  bool voiceOut = true;
  bool _alwaysOn = false;
  bool _speaking = false;
  int _sessionGeneration = 0;
  bool privacyMute = false;
  void Function(String text)? _onUtterance;
  String _locale = 'en';

  Future<void> prepare() async {
    await _tts.ensureInitialized();
    try {
      _sttReady = await _stt.initialize(
        onError: (_) {
          if (_alwaysOn && !privacyMute && !_speaking) {
            Future<void>.delayed(const Duration(milliseconds: 400), _restart);
          }
        },
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') {
            if (_alwaysOn && !privacyMute && !_speaking) {
              Future<void>.delayed(const Duration(milliseconds: 200), _restart);
            }
          }
        },
      );
    } catch (_) {
      _sttReady = false;
    }
  }

  Future<void> startAlwaysOn({
    required String locale,
    required void Function(String text) onUtterance,
  }) async {
    final generation = ++_sessionGeneration;
    _locale = locale;
    _onUtterance = onUtterance;
    _alwaysOn = true;
    privacyMute = false;
    if (!_sttReady) await prepare();
    if (generation != _sessionGeneration) return;
    await _restart();
  }

  Future<void> _restart() async {
    if (!_alwaysOn || privacyMute || !_sttReady || _speaking ||
        state.value == TutorVoiceState.thinking) {
      return;
    }
    if (_stt.isListening) return;
    _heard = '';
    state.value = TutorVoiceState.recording;
    try {
      await _stt.listen(
        listenOptions: SpeechListenOptions(
          localeId: _locale.startsWith('fr') ? 'fr_FR' : 'en_NG',
          pauseFor: const Duration(milliseconds: 1400),
          listenFor: const Duration(minutes: 8),
          partialResults: true,
          listenMode: ListenMode.dictation,
        ),
        onResult: (result) {
          _heard = result.recognizedWords;
          if (state.value == TutorVoiceState.speaking &&
              result.recognizedWords.trim().split(RegExp(r'\s+')).length >= 2) {
            _tts.stop();
          }
          if (result.finalResult && _heard.trim().length >= 4) {
            final text = _heard.trim();
            _heard = '';
            _onUtterance?.call(text);
          }
        },
      );
    } catch (_) {
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
