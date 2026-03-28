import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:prepskul/core/services/log_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/game_model.dart';

/// Service for managing game sound effects
class GameSoundService {
  static final GameSoundService _instance = GameSoundService._internal();
  factory GameSoundService() => _instance;
  GameSoundService._internal();

  final AudioPlayer _audioPlayer = AudioPlayer();
  final AudioPlayer _bgmPlayer = AudioPlayer();
  final Map<SoundType, AudioPlayer> _preloadedPlayers = {};
  final Map<SoundType, String?> _resolvedSoundPaths = {};
  bool _soundsEnabled = true;
  bool _musicEnabled = true;
  // Volume multipliers (0..1). Applied on top of base per-sound/music volumes.
  double _soundsVolume = 1.0;
  double _musicVolume = 1.0;
  bool _isInitialized = false;
  String? _currentMusicPath;
  double _currentMusicBaseVolume = 0.06;
  GameType? _lastRequestedMusicGameType;
  List<String>? _bundledAudioTracksCache;
  GameType? _pendingMusicForUserGesture;
  bool _gestureHookInstalled = false;
  void Function(PointerEvent)? _globalPointerRoute;

  /// Initialize sound service and load preferences
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      _soundsEnabled = prefs.getBool('game_sounds_enabled') ?? true;
      _musicEnabled = prefs.getBool('game_music_enabled') ?? true;
      _soundsVolume = prefs.getDouble('game_sounds_volume') ?? 1.0;
      _musicVolume = prefs.getDouble('game_music_volume') ?? 1.0;
      _isInitialized = true;

      // Preload common sounds for smoother playback
      if (_soundsEnabled) {
        await _preloadSounds();
      }

      await _bgmPlayer.setReleaseMode(ReleaseMode.loop);
      // Keep BGM deliberately soft so it doesn't fight TTS/voice.
      _currentMusicBaseVolume = 0.06;
      await _bgmPlayer.setVolume(_currentMusicBaseVolume * _musicVolume);
      _installGlobalGestureHook();
      final discoveredTracks = await _discoverBundledAudioTracks();
      LogService.info(
        '🎵 [GameSound] Bundled audio tracks discovered: ${discoveredTracks.length}',
      );
      LogService.info(
        '🎵 [GameSound] Initialized - Sounds ${_soundsEnabled ? "enabled" : "disabled"}, Music ${_musicEnabled ? "enabled" : "disabled"}',
      );
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
        SoundType.cardFlip,
        SoundType.match,
        SoundType.complete,
      ];

      for (final soundType in commonSounds) {
        try {
          final player = AudioPlayer();
          final soundPath = await _resolveSoundPath(soundType);
          if (soundPath != null) {
            await _setPlayerSourceWithFallback(player, soundPath);
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
    final resolved = _resolvedSoundPaths[type];
    if (resolved != null) return resolved;
    final candidates = _getSoundPathCandidates(type);
    if (candidates.isEmpty) return null;
    return candidates.first;
  }

  List<String> _getSoundPathCandidates(SoundType type) {
    switch (type) {
      case SoundType.correct:
        return const [
          'sounds/correct.mp3',
          'audio/music/sfx_correct_chime.ogg',
        ];
      case SoundType.incorrect:
        return const ['sounds/incorrect.mp3', 'audio/music/sfx_wrong_mute.ogg'];
      case SoundType.flip:
        return const [
          'sounds/flip.mp3',
          'sounds/cardFlip.mp3',
          'audio/music/flip.mp3', // backward compatibility fallback
        ];
      case SoundType.match:
        return const ['sounds/match.mp3', 'audio/music/sfx_streak_ping.ogg'];
      case SoundType.complete:
        return const [
          'sounds/complete.mp3',
          'audio/music/sfx_victory_short.ogg',
        ];
      case SoundType.click:
        return const ['sounds/click.mp3', 'audio/music/sfx_tap_soft.ogg'];
      case SoundType.pop:
        return const ['sounds/pop.mp3', 'audio/music/sfx_tap_soft.ogg'];
      case SoundType.wordFound:
        return const [
          'sounds/wordFound.mp3',
          'audio/music/sfx_streak_ping.ogg',
        ];
      case SoundType.piecePlace:
        return const ['sounds/piecePlace.mp3', 'sounds/flip.mp3'];
      case SoundType.cardFlip:
        return const [
          'sounds/flip.mp3',
          'sounds/cardFlip.mp3',
          'audio/music/flip.mp3', // backward compatibility fallback
        ];
      case SoundType.levelComplete:
        return const [
          'sounds/levelComplete.mp3',
          'audio/music/sfx_level_up.ogg',
        ];
    }
  }

  Future<bool> _assetExists(String relativePath) async {
    final normalized = _normalizeAssetRelativePath(relativePath);
    final candidates = <String>{
      'assets/assets/$normalized',
      'assets/$normalized',
      normalized,
      relativePath.trim(),
    };
    for (final candidate in candidates) {
      try {
        await rootBundle.load(candidate);
        return true;
      } catch (_) {}
    }
    return false;
  }

  String _normalizeAssetRelativePath(String path) {
    var normalized = path.trim();
    while (normalized.startsWith('assets/')) {
      normalized = normalized.substring('assets/'.length);
    }
    return normalized;
  }

  Future<String?> _resolveFirstExistingPath(List<String> candidates) async {
    for (final candidate in candidates) {
      if (await _assetExists(candidate)) return candidate;
    }
    return null;
  }

  Future<String?> _resolveSoundPath(SoundType type) async {
    if (_resolvedSoundPaths.containsKey(type)) return _resolvedSoundPaths[type];
    final resolved = await _resolveFirstExistingPath(
      _getSoundPathCandidates(type),
    );
    _resolvedSoundPaths[type] = resolved;
    return resolved;
  }

  /// Ensure sound service is ready
  Future<void> ensureInitialized() async {
    if (_isInitialized) return;
    await initialize();
  }

  /// Check if sounds are enabled
  bool get soundsEnabled => _soundsEnabled;
  bool get musicEnabled => _musicEnabled;
  double get soundsVolume => _soundsVolume;
  double get musicVolume => _musicVolume;

  /// Toggle sounds on/off
  Future<void> toggleSounds(bool enabled) async {
    _soundsEnabled = enabled;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('game_sounds_enabled', enabled);
      LogService.info(
        '🎵 [GameSound] Sounds ${enabled ? "enabled" : "disabled"}',
      );
    } catch (e) {
      LogService.error('🎵 [GameSound] Error saving preference: $e');
    }
  }

  /// Toggle background music on/off
  Future<void> toggleMusic(bool enabled) async {
    _musicEnabled = enabled;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('game_music_enabled', enabled);
      if (!enabled) {
        await stopMusic();
      }
      LogService.info(
        '🎵 [GameSound] Music ${enabled ? "enabled" : "disabled"}',
      );
    } catch (e) {
      LogService.error('🎵 [GameSound] Error saving music preference: $e');
    }
  }

  /// Set SFX volume multiplier (0..1).
  Future<void> setSoundsVolume(double volume) async {
    final v = volume.clamp(0.0, 1.0).toDouble();
    _soundsVolume = v;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('game_sounds_volume', v);
      LogService.info('🎵 [GameSound] Sounds volume ${v.toStringAsFixed(2)}');
    } catch (e) {
      LogService.error('🎵 [GameSound] Error saving sounds volume: $e');
    }
  }

  /// Set BGM volume multiplier (0..1).
  Future<void> setMusicVolume(double volume) async {
    final v = volume.clamp(0.0, 1.0).toDouble();
    _musicVolume = v;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('game_music_volume', v);
      await _bgmPlayer.setVolume(_currentMusicBaseVolume * _musicVolume);
      LogService.info('🎵 [GameSound] Music volume ${v.toStringAsFixed(2)}');
    } catch (e) {
      LogService.error('🎵 [GameSound] Error saving music volume: $e');
    }
  }

  List<String> _musicCandidatesForGameType(GameType gameType) {
    switch (gameType) {
      case GameType.simulation:
      case GameType.mystery:
      case GameType.escapeRoom:
        return const [
          'audio/music/bgm_adventure_loop.ogg',
          'audio/music/bgm_focus_loop.ogg',
          'audio/music/bgm_results_soft_loop.ogg',
        ];
      default:
        return const [
          'audio/music/bgm_focus_loop.ogg',
          'audio/music/bgm_adventure_loop.ogg',
          'audio/music/bgm_results_soft_loop.ogg',
        ];
    }
  }

  Future<List<String>> _discoverBundledAudioTracks() async {
    if (_bundledAudioTracksCache != null) return _bundledAudioTracksCache!;
    try {
      Map<String, dynamic>? decoded;
      for (final manifestName in const [
        'AssetManifest.json',
        'AssetManifest.bin.json',
      ]) {
        try {
          final manifestRaw = await rootBundle.loadString(manifestName);
          final parsed = jsonDecode(manifestRaw);
          if (parsed is Map<String, dynamic>) {
            decoded = parsed;
            break;
          }
          if (parsed is Map) {
            decoded = parsed.cast<String, dynamic>();
            break;
          }
        } catch (_) {
          // Try next manifest format.
        }
      }
      if (decoded == null) {
        _bundledAudioTracksCache = const [];
        return _bundledAudioTracksCache!;
      }
      final keys = decoded.keys.cast<String>();
      final tracks = keys
          .where(
            (k) =>
                // Only consider files under audio/music/ (BGM zone).
                k.startsWith('assets/audio/music/') &&
                // Avoid SFX-like naming even if they exist under audio/music/.
                !k.toLowerCase().contains('sfx_') &&
                !k.toLowerCase().contains('click') &&
                !k.toLowerCase().contains('tap') &&
                !k.toLowerCase().contains('flip') &&
                (k.toLowerCase().endsWith('.ogg') ||
                    k.toLowerCase().endsWith('.mp3') ||
                    k.toLowerCase().endsWith('.wav')),
          )
          .map((k) => k.replaceFirst('assets/', ''))
          .toList();
      _bundledAudioTracksCache = tracks;
      return tracks;
    } catch (_) {
      _bundledAudioTracksCache = const [];
      return _bundledAudioTracksCache!;
    }
  }

  Future<List<String>> _resolvedMusicCandidates(GameType gameType) async {
    final preferred = _musicCandidatesForGameType(gameType);
    final discovered = await _discoverBundledAudioTracks();
    final ordered = <String>[];

    void addTrack(String p) {
      if (!ordered.contains(p)) ordered.add(p);
    }

    for (final p in preferred) {
      addTrack(p);
    }

    // Add discovered tracks from assets/audio/* as dynamic fallback in manifest order.
    for (final p in discovered) {
      addTrack(p);
    }

    return ordered;
  }

  Future<bool> _playFirstWorkingMusic(List<String> candidates) async {
    for (final path in candidates) {
      try {
        final normalizedPath = _normalizeAssetRelativePath(path);
        if (_currentMusicPath == normalizedPath) {
          final resumed = await _ensureCurrentTrackIsPlaying();
          if (resumed) return true;
        }
        await _bgmPlayer.stop();
        // Keep background tracks audible; raise fallback loop volume.
        final isBgm = normalizedPath.contains('/bgm_');
        _currentMusicBaseVolume = isBgm ? 0.09 : 0.10;
        await _bgmPlayer.setVolume(_currentMusicBaseVolume * _musicVolume);
        await _setPlayerSourceWithFallback(_bgmPlayer, normalizedPath);
        await _bgmPlayer.resume();
        _currentMusicPath = normalizedPath;
        LogService.info('🎵 [GameSound] Playing music track: $normalizedPath');
        return true;
      } catch (e) {
        LogService.warning(
          '🎵 [GameSound] Music candidate failed: $path, error: $e',
        );
        // Try next candidate when current asset fails to decode/load.
      }
    }
    return false;
  }

  /// Play looping in-game music by game type.
  Future<void> playMusicForGame(GameType gameType) async {
    if (!_musicEnabled) return;
    if (!_isInitialized) await ensureInitialized();
    if (!_isInitialized) return;
    _lastRequestedMusicGameType = gameType;
    _pendingMusicForUserGesture = gameType;

    final ok = await _playFirstWorkingMusic(
      await _resolvedMusicCandidates(gameType),
    );
    if (!ok) {
      LogService.error(
        '🎵 [GameSound] Failed to play music loop: no playable asset found',
      );
      // Keep pending on web/browser autoplay restrictions, so we can retry on next user tap.
      return;
    }
    _pendingMusicForUserGesture = null;
  }

  /// Play looping results music.
  Future<void> playResultsMusic() async {
    if (!_musicEnabled) return;
    if (!_isInitialized) await ensureInitialized();
    if (!_isInitialized) return;

    // Web autoplay often blocks until user interaction.
    // Keep a pending value so we can retry after the next tap.
    _pendingMusicForUserGesture = GameType.quiz;

    final ok = await _playFirstWorkingMusic([
      'audio/music/bgm_results_soft_loop.ogg',
      ...await _resolvedMusicCandidates(GameType.quiz),
    ]);
    if (!ok) {
      LogService.error(
        '🎵 [GameSound] Failed to play results music: no playable asset found',
      );
      return;
    }

    _pendingMusicForUserGesture = null;
  }

  Future<void> stopMusic() async {
    try {
      _pendingMusicForUserGesture = null;
      _currentMusicPath = null;
      await _bgmPlayer.stop();
    } catch (_) {}
  }

  /// BGM can be paused/ducked by SFX, TTS, or the OS audio session (especially iOS).
  /// Call after short non-BGM playback so the loop keeps running during games.
  Future<void> resumeBgmIfNeeded() async {
    if (!_musicEnabled || !_isInitialized) return;
    if (_currentMusicPath == null) return;
    final resumed = await _ensureCurrentTrackIsPlaying();
    if (resumed) return;
    final fallbackGameType = _lastRequestedMusicGameType;
    if (fallbackGameType != null) {
      unawaited(playMusicForGame(fallbackGameType));
    }
  }

  Future<bool> _ensureCurrentTrackIsPlaying() async {
    final currentPath = _currentMusicPath;
    if (currentPath == null) return false;
    try {
      if (_bgmPlayer.state == PlayerState.playing) return true;
      await _bgmPlayer.resume();
      if (_bgmPlayer.state == PlayerState.playing) return true;
    } catch (_) {}
    try {
      await _setPlayerSourceWithFallback(_bgmPlayer, currentPath);
      await _bgmPlayer.resume();
      return _bgmPlayer.state == PlayerState.playing;
    } catch (_) {
      return false;
    }
  }

  /// Play a sound effect
  /// Uses asset sounds when available, falls back to haptic + system click when assets missing
  Future<void> _playSound(SoundType type) async {
    // On web, BGM can be blocked until first user gesture.
    // Any SFX trigger usually comes from a gesture, so retry pending BGM first.
    await _retryPendingMusicAfterUserGesture();
    if (!_soundsEnabled) return;
    if (!_isInitialized) await ensureInitialized();
    if (!_isInitialized) return;

    // Always provide haptic feedback for key events (works even without sound files)
    _playHaptic(type);

    try {
      // Use preloaded player if available
      if (_preloadedPlayers.containsKey(type)) {
        final player = _preloadedPlayers[type]!;
        await player
            .stop(); // Stop so rapid repeats (e.g. card flips) each play fully
        await player.seek(Duration.zero);
        await player.setVolume(_volumeFor(type));
        await player.resume();
        return;
      }

      // Otherwise use main player
      final soundPath = await _resolveSoundPath(type);
      if (soundPath != null) {
        if (type == SoundType.flip ||
            type == SoundType.cardFlip ||
            type == SoundType.piecePlace) {
          // For quick repeatable actions, force restart of the clip.
          await _audioPlayer.stop();
        }
        await _audioPlayer.setVolume(_volumeFor(type));
        await _playAssetWithFallback(_audioPlayer, soundPath);
      } else {
        _playSystemFallback(type);
      }
    } catch (e) {
      // Fallback: system click/alert when assets are missing
      _playSystemFallback(type);
    } finally {
      unawaited(resumeBgmIfNeeded());
    }
  }

  void _playSystemFallback(SoundType type) {
    if (kIsWeb) return;
    if (type == SoundType.flip ||
        type == SoundType.click ||
        type == SoundType.cardFlip ||
        type == SoundType.match ||
        type == SoundType.correct ||
        type == SoundType.complete ||
        type == SoundType.pop ||
        type == SoundType.wordFound ||
        type == SoundType.piecePlace ||
        type == SoundType.levelComplete) {
      SystemSound.play(SystemSoundType.click);
      return;
    }
    if (type == SoundType.incorrect) {
      SystemSound.play(SystemSoundType.alert);
    }
  }

  double _volumeFor(SoundType type) {
    switch (type) {
      case SoundType.complete:
      case SoundType.levelComplete:
        return 0.8 * _soundsVolume;
      case SoundType.correct:
      case SoundType.match:
      case SoundType.wordFound:
      case SoundType.click:
      case SoundType.piecePlace:
      case SoundType.pop:
        return 0.55 * _soundsVolume;
      case SoundType.flip:
      case SoundType.cardFlip:
        return 1.0 * _soundsVolume;
      case SoundType.incorrect:
        return 0.5 * _soundsVolume;
    }
  }

  void _playHaptic(SoundType type) {
    if (kIsWeb) return;
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

  /// Play a soft countdown tick (reuse click sound)
  Future<void> playCountdownTick() => _playSound(SoundType.click);

  /// Play a buzzer-style sound when time runs out (reuse incorrect/haptic)
  Future<void> playCountdownBuzzer() => _playSound(SoundType.incorrect);

  /// Explicitly call this from any UI tap handler if needed.
  Future<void> registerUserGesture() => _retryPendingMusicAfterUserGesture();

  Future<void> _retryPendingMusicAfterUserGesture() async {
    if (!_musicEnabled) return;
    final pending = _pendingMusicForUserGesture;
    if (pending == null || _currentMusicPath != null) return;
    unawaited(playMusicForGame(pending));
  }

  Future<void> _playAssetWithFallback(
    AudioPlayer player,
    String relativePath,
  ) async {
    final normalizedPath = _normalizeAssetRelativePath(relativePath);
    try {
      await player.play(AssetSource(normalizedPath));
      return;
    } catch (_) {
      try {
        await player.play(AssetSource('assets/$normalizedPath'));
        return;
      } catch (_) {}
      // Fallback to bytes source when asset file descriptor/data source fails.
      final bytes = await _loadAssetBytes(normalizedPath);
      if (bytes == null) rethrow;
      await player.play(BytesSource(bytes));
    }
  }

  Future<void> _setPlayerSourceWithFallback(
    AudioPlayer player,
    String relativePath,
  ) async {
    final normalizedPath = _normalizeAssetRelativePath(relativePath);
    try {
      await player.setSource(AssetSource(normalizedPath));
      return;
    } catch (_) {
      try {
        await player.setSource(AssetSource('assets/$normalizedPath'));
        return;
      } catch (_) {}
      final bytes = await _loadAssetBytes(normalizedPath);
      if (bytes == null) rethrow;
      await player.setSource(BytesSource(bytes));
    }
  }

  Future<Uint8List?> _loadAssetBytes(String relativePath) async {
    final normalized = _normalizeAssetRelativePath(relativePath);
    final candidates = <String>[
      'assets/assets/$normalized',
      'assets/$normalized',
      normalized,
      relativePath.trim(),
    ];
    try {
      for (final candidate in candidates) {
        try {
          final data = await rootBundle.load(candidate);
          return data.buffer.asUint8List();
        } catch (_) {}
      }
      throw Exception('Unable to load any candidate for $relativePath');
    } catch (e) {
      LogService.warning(
        '🎵 [GameSound] Could not load asset bytes for $relativePath: $e',
      );
      return null;
    }
  }

  void _installGlobalGestureHook() {
    if (_gestureHookInstalled) return;
    _globalPointerRoute = (PointerEvent event) {
      if (event is PointerDownEvent) {
        unawaited(_retryPendingMusicAfterUserGesture());
      }
    };
    GestureBinding.instance.pointerRouter.addGlobalRoute(_globalPointerRoute!);
    _gestureHookInstalled = true;
  }

  /// Dispose resources
  void dispose() {
    if (_gestureHookInstalled && _globalPointerRoute != null) {
      GestureBinding.instance.pointerRouter.removeGlobalRoute(
        _globalPointerRoute!,
      );
      _gestureHookInstalled = false;
      _globalPointerRoute = null;
    }
    _audioPlayer.dispose();
    _bgmPlayer.dispose();
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
