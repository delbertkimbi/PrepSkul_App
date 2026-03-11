import 'dart:async';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:prepskul/core/localization/language_service.dart';
import 'package:prepskul/core/services/log_service.dart';

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

  /// Initialize TTS service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _flutterTts = FlutterTts();
      
      // Set language based on user preference
      final userLanguage = LanguageService.languageCode;
      _currentLanguage = userLanguage == 'fr' ? 'fr-FR' : 'en-US';
      
      await _flutterTts!.setLanguage(_currentLanguage);
      await _flutterTts!.setSpeechRate(0.5); // Normal speed (0.5 = platform default, 1.0 = faster)
      await _flutterTts!.setVolume(1.0);
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

  /// Enable/disable TTS
  void setEnabled(bool enabled) {
    _isEnabled = enabled;
    if (!enabled) {
      stop();
    }
  }

  /// Check if TTS is enabled
  bool get isEnabled => _isEnabled;

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



