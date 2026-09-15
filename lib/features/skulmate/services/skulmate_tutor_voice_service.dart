import 'package:flutter/foundation.dart';
import 'package:prepskul/features/skulmate/services/tts_service.dart';
import 'package:speech_to_text/speech_to_text.dart';

enum TutorVoiceState { idle, recording, thinking, speaking }

/// Student talk + tutor speech. Signup role does not change the voice loop.
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

  Future<void> prepare() async {
    await _tts.ensureInitialized();
    try {
      _sttReady = await _stt.initialize();
    } catch (_) {
      _sttReady = false;
    }
  }

  Future<bool> startListening({String locale = 'en'}) async {
    if (!_sttReady) await prepare();
    if (!_sttReady) return false;
    _heard = '';
    state.value = TutorVoiceState.recording;
    await _stt.listen(
      localeId: locale.startsWith('fr') ? 'fr_FR' : 'en_NG',
      onResult: (result) {
        _heard = result.recognizedWords;
      },
    );
    return true;
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

  Future<void> speakTutor(String text) async {
    if (text.trim().isEmpty) return;
    state.value = TutorVoiceState.speaking;
    try {
      await _tts.speakAndWait(text);
    } finally {
      if (state.value == TutorVoiceState.speaking) {
        state.value = TutorVoiceState.idle;
      }
    }
  }

  Future<void> interrupt() async {
    await stopListening();
    await _tts.stop();
    state.value = TutorVoiceState.idle;
  }
}
