import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:prepskul/core/localization/language_service.dart';
import 'package:prepskul/core/services/log_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for text-to-speech functionality in games
class TTSService {
  static final TTSService _instance = TTSService._internal();
  factory TTSService() => _instance;
  TTSService._internal();

  FlutterTts? _flutterTts;
  bool _isInitialized = false;
  bool _isEnabled = true;
  String _currentLanguage = 'en';
  Completer<void>? _speakCompleter;
  double _ttsVolume = 1.0;
  late final double _defaultSpeechRate = kIsWeb ? 0.8 : 0.55;
  double _speechRate = kIsWeb ? 0.8 : 0.55;

  /// Initialize TTS service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      _ttsVolume = prefs.getDouble('game_tts_volume') ?? 1.0;
      _flutterTts = FlutterTts();
      
      // Set language based on user preference
      final userLanguage = LanguageService.languageCode;
      _currentLanguage = userLanguage == 'fr' ? 'fr-FR' : 'en-US';

      await _flutterTts!.setLanguage(_currentLanguage);
      await _flutterTts!.setSpeechRate(_speechRate);
      await _flutterTts!.setVolume(_ttsVolume);
      await _flutterTts!.setPitch(1.0);
      
      // Set completion handler (used by speakAndWait)
      _flutterTts!.setCompletionHandler(() {
        LogService.debug('[TTS] Speech completed');
        _speakCompleter?.complete();
        _speakCompleter = null;
      });
      
      _isInitialized = true;
      LogService.success('[TTS] Initialized with language: $_currentLanguage');
    } catch (e) {
      LogService.error('[TTS] Error initializing: $e');
      _isInitialized = false;
    }
  }

  /// Ensure TTS is ready (call init if needed)
  Future<void> ensureInitialized() async {
    if (_isInitialized) return;
    await initialize();
  }

  bool get isInitialized => _isInitialized;

  /// Speak text
  Future<void> speak(String text) async {
    if (!_isEnabled || text.isEmpty) return;
    if (!_isInitialized) await ensureInitialized();
    if (!_isInitialized) return;

    try {
      await _flutterTts!.speak(text);
      LogService.debug('[TTS] Speaking: ${text.substring(0, text.length > 50 ? 50 : text.length)}...');
    } catch (e) {
      LogService.error('[TTS] Error speaking: $e');
    }
  }

  /// Speak text and return a Future that completes when speech finishes (or after a timeout).
  /// Use this when you need to wait before advancing (e.g. wrong-answer explanation).
  Future<void> speakAndWait(String text, {Duration? timeout}) async {
    if (!_isEnabled || text.isEmpty) return;
    if (!_isInitialized) await ensureInitialized();
    if (!_isInitialized) return;

    _speakCompleter = Completer<void>();
    try {
      await _flutterTts!.speak(text);
      final t = timeout ?? Duration(
        milliseconds: (text.length * 80).clamp(2000, 15000),
      );
      await _speakCompleter!.future.timeout(t, onTimeout: () {
        _speakCompleter = null;
      });
    } catch (e) {
      _speakCompleter = null;
      if (e is TimeoutException) {
        LogService.debug('[TTS] speakAndWait timed out');
      } else {
        LogService.error('[TTS] Error speaking: $e');
      }
    }
  }

  /// Stop current speech
  Future<void> stop() async {
    if (!_isInitialized) return;

    try {
      await _flutterTts!.stop();
    } catch (e) {
      LogService.error('[TTS] Error stopping: $e');
    }
  }

  /// Pause current speech
  Future<void> pause() async {
    if (!_isInitialized) return;

    try {
      await _flutterTts!.pause();
    } catch (e) {
      LogService.error('[TTS] Error pausing: $e');
    }
  }

  /// Set language
  Future<void> setLanguage(String languageCode) async {
    if (!_isInitialized) return;

    try {
      final lang = languageCode == 'fr' ? 'fr-FR' : 'en-US';
      await _flutterTts!.setLanguage(lang);
      _currentLanguage = lang;
      LogService.debug('[TTS] Language changed to: $_currentLanguage');
    } catch (e) {
      LogService.error('[TTS] Error setting language: $e');
    }
  }

  /// Set speech rate dynamically (e.g. slower in quiz only).
  Future<void> setSpeechRate(double rate) async {
    final clamped = rate.clamp(0.35, 1.0).toDouble();
    _speechRate = clamped;
    if (!_isInitialized) return;
    try {
      await _flutterTts!.setSpeechRate(clamped);
    } catch (e) {
      LogService.error('[TTS] Error setting speech rate: $e');
    }
  }

  /// Reset speech rate back to platform default.
  Future<void> resetSpeechRate() async {
    await setSpeechRate(_defaultSpeechRate);
  }

  /// Enable/disable TTS
  void setEnabled(bool enabled) {
    _isEnabled = enabled;
    if (!enabled) {
      stop();
    }
  }

  /// Check if TTS is enabled
  bool get isEnabled => _isEnabled;

  double get volume => _ttsVolume;

  /// Set TTS voice volume multiplier (0..1).
  Future<void> setVolume(double volume) async {
    final v = volume.clamp(0.0, 1.0).toDouble();
    _ttsVolume = v;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('game_tts_volume', v);
      if (_isInitialized) {
        await _flutterTts?.setVolume(v);
      }
    } catch (e) {
      LogService.error('[TTS] Error saving volume: $e');
    }
  }

  /// Get current language
  String get currentLanguage => _currentLanguage;

  /// Dispose resources
  void dispose() {
    if (_isInitialized) {
      _flutterTts!.stop();
      _flutterTts = null;
      _isInitialized = false;
    }
  }
}



