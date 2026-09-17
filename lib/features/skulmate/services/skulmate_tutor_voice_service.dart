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
  final ValueNotifier<TutorVoiceState> state =
      ValueNotifier<TutorVoiceState>(TutorVoiceState.idle);

  bool _sttReady = false;
  String _heard = '';
  bool voiceOut = true;
  bool _alwaysOn = false;
  bool privacyMute = false;
  void Function(String text)? _onUtterance;
  String _locale = 'en';

  Future<void> prepare() async {
    await _tts.ensureInitialized();
    try {
      _sttReady = await _stt.initialize(
        onError: (_) {
          if (_alwaysOn && !privacyMute) {
            Future<void>.delayed(const Duration(milliseconds: 400), _restart);
          }
        },
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') {
            if (_alwaysOn && !privacyMute) {
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
    _locale = locale;
    _onUtterance = onUtterance;
    _alwaysOn = true;
    privacyMute = false;
    if (!_sttReady) await prepare();
    await _restart();
  }

  Future<void> _restart() async {
    if (!_alwaysOn || privacyMute || !_sttReady) return;
    if (_stt.isListening) return;
    _heard = '';
    state.value = TutorVoiceState.recording;
    try {
      await _stt.listen(
        localeId: _locale.startsWith('fr') ? 'fr_FR' : 'en_NG',
        pauseFor: const Duration(milliseconds: 1400),
        listenFor: const Duration(minutes: 8),
        partialResults: true,
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

  void setThinking() => state.value = TutorVoiceState.thinking;

  Future<void> speakTutor(String text, {bool keepListening = true}) async {
    if (!voiceOut) return;
    if (text.trim().isEmpty) return;
    state.value = TutorVoiceState.speaking;
    try {
      if (keepListening && _sttReady && !_stt.isListening && !privacyMute) {
        await _restart();
      }
      await _tts.speakAndWait(text);
    } finally {
      if (state.value == TutorVoiceState.speaking) {
        state.value = privacyMute ? TutorVoiceState.idle : TutorVoiceState.recording;
      }
    }
  }

  Future<void> interrupt() async {
    await _tts.stop();
    if (!privacyMute && _alwaysOn) {
      state.value = TutorVoiceState.recording;
      return;
    }
    await stopListening();
    state.value = TutorVoiceState.idle;
  }
}
