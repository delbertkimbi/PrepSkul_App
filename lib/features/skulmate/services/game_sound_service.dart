import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:prepskul/core/services/log_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for managing game sound effects
class GameSoundService {
  static final GameSoundService _instance = GameSoundService._internal();
  factory GameSoundService() => _instance;
  GameSoundService._internal();

  final AudioPlayer _audioPlayer = AudioPlayer();
  final Map<SoundType, AudioPlayer> _preloadedPlayers = {};
  bool _soundsEnabled = true;
  bool _isInitialized = false;

  /// Initialize sound service and load preferences
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      _soundsEnabled = prefs.getBool('game_sounds_enabled') ?? true;
      _isInitialized = true;
      
      // Preload common sounds for smoother playback
      if (_soundsEnabled) {
        await _preloadSounds();
      }
      
      LogService.info('🎵 [GameSound] Initialized - Sounds ${_soundsEnabled ? "enabled" : "disabled"}');
    } catch (e) {
      LogService.error('🎵 [GameSound] Error initializing: $e');
      _soundsEnabled = false; // Disable on error
    }
  }

  /// Preload common sounds for faster playback
  Future<void> _preloadSounds() async {
    try {
      // Preload most commonly used sounds
      final commonSounds = [
        SoundType.correct,
        SoundType.incorrect,
        SoundType.flip,
        SoundType.match,
        SoundType.complete,
      ];
      
      for (final soundType in commonSounds) {
        try {
          final player = AudioPlayer();
          final soundPath = _getSoundPath(soundType);
          if (soundPath != null) {
            await player.setSource(AssetSource(soundPath));
            _preloadedPlayers[soundType] = player;
          }
        } catch (e) {
          // Skip preloading if sound file doesn't exist
        }
      }
    } catch (e) {
      // Preloading is optional, continue without it
    }
  }

  String? _getSoundPath(SoundType type) {
    switch (type) {
      case SoundType.correct:
        return 'sounds/correct.mp3';
      case SoundType.incorrect:
        return 'sounds/incorrect.mp3';
      case SoundType.flip:
        return 'sounds/flip.mp3';
      case SoundType.match:
        return 'sounds/match.mp3';
      case SoundType.complete:
        return 'sounds/complete.mp3';
      case SoundType.click:
        return 'sounds/click.mp3';
      case SoundType.pop:
        return 'sounds/pop.mp3';
      case SoundType.wordFound:
        return 'sounds/wordFound.mp3';
      case SoundType.piecePlace:
        return 'sounds/piecePlace.mp3';
      case SoundType.cardFlip:
        return 'sounds/flip.mp3';
      case SoundType.levelComplete:
        return 'sounds/complete.mp3';
    }
  }

  /// Ensure sound service is ready
  Future<void> ensureInitialized() async {
    if (_isInitialized) return;
    await initialize();
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
  /// Uses asset sounds when available, falls back to haptic + system click when assets missing
  Future<void> _playSound(SoundType type) async {
    if (!_soundsEnabled) return;
    if (!_isInitialized) await ensureInitialized();
    if (!_isInitialized) return;

    // Always provide haptic feedback for key events (works even without sound files)
    _playHaptic(type);

    try {
      // Use preloaded player if available
      if (_preloadedPlayers.containsKey(type)) {
        final player = _preloadedPlayers[type]!;
        await player.stop(); // Stop so rapid repeats (e.g. card flips) each play fully
        await player.seek(Duration.zero);
        await player.resume();
        return;
      }

      // Otherwise use main player
      final soundPath = _getSoundPath(type);
      if (soundPath != null) {
        await _audioPlayer.play(AssetSource(soundPath));
      }
    } catch (e) {
      // Fallback: system click when assets are missing
      if (type == SoundType.flip || type == SoundType.click || type == SoundType.cardFlip ||
          type == SoundType.match || type == SoundType.correct || type == SoundType.complete) {
        SystemSound.play(SystemSoundType.click);
      } else if (type == SoundType.incorrect) {
        SystemSound.play(SystemSoundType.alert);
      }
    }
  }

  void _playHaptic(SoundType type) {
    try {
      switch (type) {
        case SoundType.correct:
        case SoundType.match:
        case SoundType.complete:
          HapticFeedback.mediumImpact();
          break;
        case SoundType.incorrect:
          HapticFeedback.heavyImpact();
          break;
        case SoundType.flip:
        case SoundType.cardFlip:
        case SoundType.click:
          HapticFeedback.selectionClick();
          break;
        case SoundType.pop:
        case SoundType.wordFound:
        case SoundType.piecePlace:
          HapticFeedback.lightImpact();
          break;
        case SoundType.levelComplete:
          HapticFeedback.mediumImpact();
          break;
      }
    } catch (_) {}
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

  /// Play card flip sound (alias for flip)
  Future<void> playCardFlip() => _playSound(SoundType.cardFlip);

  /// Play level complete sound (alias for complete)
  Future<void> playLevelComplete() => _playSound(SoundType.levelComplete);

  /// Dispose resources
  void dispose() {
    _audioPlayer.dispose();
    for (final player in _preloadedPlayers.values) {
      player.dispose();
    }
    _preloadedPlayers.clear();
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
  cardFlip,
  levelComplete,
}
