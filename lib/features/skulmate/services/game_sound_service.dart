import 'package:audioplayers/audioplayers.dart';
import 'package:prepskul/core/services/log_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for managing game sound effects
class GameSoundService {
  static final GameSoundService _instance = GameSoundService._internal();
  factory GameSoundService() => _instance;
  GameSoundService._internal();

  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _soundsEnabled = true;
  bool _isInitialized = false;

  /// Initialize sound service and load preferences
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      _soundsEnabled = prefs.getBool('game_sounds_enabled') ?? true;
      _isInitialized = true;
      LogService.info('🎵 [GameSound] Initialized - Sounds ${_soundsEnabled ? "enabled" : "disabled"}');
    } catch (e) {
      LogService.error('🎵 [GameSound] Error initializing: $e');
      _soundsEnabled = false; // Disable on error
    }
  }

  /// Check if sounds are enabled
  bool get soundsEnabled => _soundsEnabled;

  /// Toggle sounds on/off
  Future<void> toggleSounds(bool enabled) async {
    _soundsEnabled = enabled;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('game_sounds_enabled', enabled);
      LogService.info('🎵 [GameSound] Sounds ${enabled ? "enabled" : "disabled"}');
    } catch (e) {
      LogService.error('🎵 [GameSound] Error saving preference: $e');
    }
  }

  /// Play a sound effect
  /// Uses built-in system sounds for cross-platform compatibility
  Future<void> _playSound(SoundType type) async {
    if (!_soundsEnabled || !_isInitialized) return;

    try {
      // Use system sounds that work across platforms
      // These are simple beep-like sounds that don't require asset files
      switch (type) {
        case SoundType.correct:
          // Play a success/positive sound
          await _audioPlayer.play(AssetSource('sounds/correct.mp3'));
          break;
        case SoundType.incorrect:
          // Play an error/negative sound
          await _audioPlayer.play(AssetSource('sounds/incorrect.mp3'));
          break;
        case SoundType.flip:
          // Play a card flip sound
          await _audioPlayer.play(AssetSource('sounds/flip.mp3'));
          break;
        case SoundType.match:
          // Play a match success sound
          await _audioPlayer.play(AssetSource('sounds/match.mp3'));
          break;
        case SoundType.complete:
          // Play a completion/celebration sound
          await _audioPlayer.play(AssetSource('sounds/complete.mp3'));
          break;
        case SoundType.click:
          // Play a button click sound
          await _audioPlayer.play(AssetSource('sounds/click.mp3'));
          break;
      }
    } catch (e) {
      // Silently fail - sounds are optional
      // LogService.debug('🎵 [GameSound] Could not play sound: $e');
    }
  }

  /// Play correct answer sound
  Future<void> playCorrect() => _playSound(SoundType.correct);

  /// Play incorrect answer sound
  Future<void> playIncorrect() => _playSound(SoundType.incorrect);

  /// Play card flip sound
  Future<void> playFlip() => _playSound(SoundType.flip);

  /// Play match success sound
  Future<void> playMatch() => _playSound(SoundType.match);

  /// Play game completion sound
  Future<void> playComplete() => _playSound(SoundType.complete);

  /// Play button click sound
  Future<void> playClick() => _playSound(SoundType.click);

  /// Dispose resources
  void dispose() {
    _audioPlayer.dispose();
  }
}

/// Types of sound effects
enum SoundType {
  correct,
  incorrect,
  flip,
  match,
  complete,
  click,
}

