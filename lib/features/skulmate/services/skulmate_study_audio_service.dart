import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/game_model.dart';
import 'game_sound_service.dart';

/// Owner tokens for ref-counted study BGM (hub, scroll, tutor can overlap in stack).
abstract final class SkulMateStudyAudioOwner {
  static const deckHub = 'deck_hub';
  static const scrollFeed = 'scroll_feed';
  static const tutorSession = 'tutor_session';
}

/// Listen/read + ambient BGM for deck hub, scroll feed, and AI tutor study.
class SkulMateStudyAudioService {
  SkulMateStudyAudioService._();

  static final SkulMateStudyAudioService instance = SkulMateStudyAudioService._();

  static const _listenModeKey = 'skulmate_study_listen_mode';

  final FlutterTts _tts = FlutterTts();
  final GameSoundService _sounds = GameSoundService();
  final Set<String> _ambienceOwners = {};
  bool _ttsReady = false;
  bool _listenMode = false;
  Timer? _fallbackHighlightTimer;
  int _fallbackWordIndex = 0;
  List<_WordSpan> _fallbackWords = const [];

  bool get listenMode => _listenMode;
  bool get musicEnabled => _sounds.musicEnabled;
  bool get soundsEnabled => _sounds.soundsEnabled;

  Future<void> ensureReady() async {
    await _sounds.initialize();
    if (_ttsReady) return;
    await _tts.setSpeechRate(0.48);
    await _tts.setVolume(1.0);
    _tts.setCompletionHandler(_onSpeakComplete);
    _tts.setCancelHandler(_onSpeakComplete);
    _ttsReady = true;
    final prefs = await SharedPreferences.getInstance();
    _listenMode = prefs.getBool(_listenModeKey) ?? false;
  }

  void _onSpeakComplete() {
    _fallbackHighlightTimer?.cancel();
    _fallbackHighlightTimer = null;
  }

  /// Acquire looping study BGM. Multiple screens may hold a token; music stops
  /// only when every owner has released.
  Future<void> acquireStudyAmbience(String owner) async {
    await ensureReady();
    final wasEmpty = _ambienceOwners.isEmpty;
    _ambienceOwners.add(owner);
    if (wasEmpty && _sounds.musicEnabled) {
      await _sounds.playMusicForGame(GameType.flashcards);
    }
  }

  /// Release a study BGM token. Stops music when no owners remain.
  Future<void> releaseStudyAmbience(String owner) async {
    _ambienceOwners.remove(owner);
    if (_ambienceOwners.isEmpty) {
      await _sounds.stopMusic();
      await stopSpeaking();
    }
  }

  Future<void> startStudyAmbience() =>
      acquireStudyAmbience(SkulMateStudyAudioOwner.deckHub);

  Future<void> stopStudyAmbience() =>
      releaseStudyAmbience(SkulMateStudyAudioOwner.deckHub);

  Future<void> setListenMode(bool enabled) async {
    _listenMode = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_listenModeKey, enabled);
    if (!enabled) await stopSpeaking();
  }

  Future<void> toggleListenMode() => setListenMode(!_listenMode);

  Future<void> toggleMusic() async {
    await ensureReady();
    await _sounds.toggleMusic(!_sounds.musicEnabled);
    if (_sounds.musicEnabled && _ambienceOwners.isNotEmpty) {
      await _sounds.playMusicForGame(GameType.flashcards);
    }
  }

  Future<void> toggleSounds(bool enabled) async {
    await ensureReady();
    await _sounds.toggleSounds(enabled);
  }

  Future<void> registerUserGesture() async {
    await ensureReady();
    await _sounds.registerUserGesture();
  }

  Future<void> speakExplanation(
    String text, {
    void Function(int start, int end)? onProgress,
    VoidCallback? onComplete,
  }) async {
    if (!_listenMode || text.trim().isEmpty) return;
    await speakWithHighlight(
      text,
      onProgress: onProgress,
      onComplete: onComplete,
    );
  }

  /// Read-aloud for scroll listen slides (always available).
  Future<void> speakScrollText(String text) async {
    if (text.trim().isEmpty) return;
    await ensureReady();
    await stopSpeaking();
    await _sounds.duckBgmForSpeech();
    await _tts.speak(text.trim());
  }

  /// TTS with word-range callbacks for read-along highlighting.
  Future<void> speakWithHighlight(
    String text, {
    void Function(int start, int end)? onProgress,
    VoidCallback? onComplete,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    await ensureReady();
    await stopSpeaking();
    await _sounds.duckBgmForSpeech();

    var usedNativeProgress = false;

    _tts.setProgressHandler((_, start, end, __) {
      usedNativeProgress = true;
      onProgress?.call(start, end);
    });

    void complete() {
      _fallbackHighlightTimer?.cancel();
      _fallbackHighlightTimer = null;
      onComplete?.call();
      unawaited(_sounds.resumeBgmIfNeeded());
    }

    _tts.setCompletionHandler(() {
      complete();
      _tts.setCompletionHandler(_onSpeakComplete);
    });

    _fallbackWords = _splitWords(trimmed);
    _fallbackWordIndex = 0;

    if (onProgress != null && _fallbackWords.isNotEmpty) {
      _fallbackHighlightTimer = Timer.periodic(
        const Duration(milliseconds: 280),
        (timer) {
          if (usedNativeProgress) return;
          if (_fallbackWordIndex >= _fallbackWords.length) {
            timer.cancel();
            return;
          }
          final word = _fallbackWords[_fallbackWordIndex++];
          onProgress(word.start, word.end);
        },
      );
    }

    await _tts.speak(trimmed);
  }

  Future<void> stopSpeaking() async {
    _fallbackHighlightTimer?.cancel();
    _fallbackHighlightTimer = null;
    _fallbackWordIndex = 0;
    _fallbackWords = const [];
    await _tts.stop();
  }

  List<_WordSpan> _splitWords(String text) {
    final words = <_WordSpan>[];
    final pattern = RegExp(r'\S+');
    for (final match in pattern.allMatches(text)) {
      words.add(_WordSpan(match.start, match.end));
    }
    return words;
  }
}

class _WordSpan {
  final int start;
  final int end;

  const _WordSpan(this.start, this.end);
}
