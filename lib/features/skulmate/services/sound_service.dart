import 'package:audioplayers/audioplayers.dart';
import 'package:prepskul/core/services/log_service.dart';
import 'package:flutter/services.dart';

/// Service for game sound effects
class SoundService {
  static final SoundService _instance = SoundService._internal();
  factory SoundService() => _instance;
  SoundService._internal();

  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isEnabled = true;
  double _volume = 0.7;

  /// Initialize sound service
  Future<void> initialize() async {
    try {
      await _audioPlayer.setReleaseMode(ReleaseMode.stop);
      LogService.success('[Sound] Service initialized');
    } catch (e) {
      LogService.error('[Sound] Error initializing: $e');
    }
  }

  /// Play sound effect from asset
  Future<void> playSound(String assetPath) async {
    if (!_isEnabled) return;

    try {
      await _audioPlayer.play(AssetSource(assetPath));
      LogService.debug('[Sound] Playing: $assetPath');
    } catch (e) {
      LogService.error('[Sound] Error playing sound: $e');
    }
  }

  /// Play correct answer sound
  Future<void> playCorrect() async {
    await playSound('sounds/correct.mp3');
  }

  /// Play incorrect answer sound
  Future<void> playIncorrect() async {
    await playSound('sounds/incorrect.mp3');
  }

  /// Play card flip sound
  Future<void> playFlip() async {
    await playSound('sounds/flip.mp3');
  }

  /// Play button click sound
  Future<void> playClick() async {
    await playSound('sounds/click.mp3');
  }

  /// Play level completion sound
  Future<void> playLevelComplete() async {
    await playSound('sounds/level_complete.mp3');
  }

  /// Play word completion sound
  Future<void> playWordComplete() async {
    await playSound('sounds/word_complete.mp3');
  }

  /// Play celebration sound
  Future<void> playCelebration() async {
    await playSound('sounds/celebration.mp3');
  }

  /// Enable/disable sounds
  void setEnabled(bool enabled) {
    _isEnabled = enabled;
  }

  /// Set volume (0.0 to 1.0)
  Future<void> setVolume(double volume) async {
    _volume = volume.clamp(0.0, 1.0);
    await _audioPlayer.setVolume(_volume);
  }

  /// Get current volume
  double get volume => _volume;

  /// Check if sounds are enabled
  bool get isEnabled => _isEnabled;

  /// Dispose resources
  void dispose() {
    _audioPlayer.dispose();
  }
}





