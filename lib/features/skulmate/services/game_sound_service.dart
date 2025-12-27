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
  /// Uses system notification sounds or fails gracefully
  Future<void> _playSound(SoundType type) async {
    if (!_soundsEnabled || !_isInitialized) return;

    try {
      // Try to play system notification sounds
      // These work on most platforms without requiring asset files
      String? soundPath;
      switch (type) {
        case SoundType.correct:
          // Try system success sound first, fallback to asset
          soundPath = 'sounds/correct.mp3';
          break;
        case SoundType.incorrect:
          soundPath = 'sounds/incorrect.mp3';
          break;
        case SoundType.flip:
          soundPath = 'sounds/flip.mp3';
          break;
        case SoundType.match:
          soundPath = 'sounds/match.mp3';
          break;
        case SoundType.complete:
          soundPath = 'sounds/complete.mp3';
          break;
        case SoundType.click:
          soundPath = 'sounds/click.mp3';
          break;
        case SoundType.pop:
          soundPath = 'sounds/pop.mp3';
          break;
        case SoundType.wordFound:
          soundPath = 'sounds/wordFound.mp3';
          break;
        case SoundType.piecePlace:
          soundPath = 'sounds/piecePlace.mp3';
          break;
      }
      
      if (soundPath != null) {
        await _audioPlayer.play(AssetSource(soundPath));
      }
    } catch (e) {
      // Silently fail - sounds are optional and enhance UX but aren't critical
      // Games will work perfectly fine without sound files
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

  /// Play bubble pop sound
  Future<void> playPop() => _playSound(SoundType.pop);

  /// Play word found sound
  Future<void> playWordFound() => _playSound(SoundType.wordFound);

  /// Play piece placement sound
  Future<void> playPiecePlace() => _playSound(SoundType.piecePlace);

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
  pop,
  wordFound,
  piecePlace,
}
