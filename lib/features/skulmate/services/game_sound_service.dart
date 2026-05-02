import 'dart:async';
import 'dart:convert';
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
  final AudioPlayer _matchingSfxPlayer = AudioPlayer();
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
  DateTime? _lastMusicStartAt;
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
      // Default BGM at 80% volume for a lively but balanced mix.
      _musicVolume = prefs.getDouble('game_music_volume') ?? 0.8;
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
          'audio/music/sfx_card_flip.ogg',
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
          'audio/music/sfx_card_flip.ogg',
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
        await stopMusic(force: true);
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
        await _bgmPlayer.stop();
        // Keep background tracks audible; raise fallback loop volume.
        final isBgm = normalizedPath.contains('/bgm_');
        _currentMusicBaseVolume = isBgm ? 0.09 : 0.10;
        await _bgmPlayer.setVolume(_currentMusicBaseVolume * _musicVolume);
        await _setPlayerSourceWithFallback(_bgmPlayer, normalizedPath);
        await _bgmPlayer.resume();
        _currentMusicPath = normalizedPath;
        _lastMusicStartAt = DateTime.now();
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

  Future<void> stopMusic({bool force = false}) async {
    try {
      if (!force && _lastMusicStartAt != null) {
        final elapsed = DateTime.now().difference(_lastMusicStartAt!);
        // During fast route replacement, old screen dispose can fire right after
        // the next screen starts BGM; ignore this stale stop request.
        if (elapsed < const Duration(milliseconds: 450)) {
          LogService.debug(
            '🎵 [GameSound] Ignoring stale stop request during transition '
            '(${elapsed.inMilliseconds}ms since music start)',
          );
          return;
        }
      }
      _pendingMusicForUserGesture = null;
      _currentMusicPath = null;
      _lastMusicStartAt = null;
      await _bgmPlayer.stop();
    } catch (_) {}
  }

  /// BGM can be paused/ducked by SFX, TTS, or the OS audio session (especially iOS).
  /// Call after short non-BGM playback so the loop keeps running during games.
  Future<void> resumeBgmIfNeeded() async {
    if (!_musicEnabled || !_isInitialized) return;
    if (_currentMusicPath == null) return;
    final resumed = await _ensureCurrentTrackIsPlaying();
    if (resumed) {
      // Some focus interruptions return "playing" state but keep low ducked volume.
      try {
        await _bgmPlayer.setVolume(_currentMusicBaseVolume * _musicVolume);
      } catch (_) {}
      return;
    }
    final fallbackGameType = _lastRequestedMusicGameType;
    if (fallbackGameType != null) {
      if (_lastMusicStartAt != null &&
          DateTime.now().difference(_lastMusicStartAt!) <
              const Duration(seconds: 2)) {
        return;
      }
      unawaited(playMusicForGame(fallbackGameType));
    }
  }

  /// Keep game music alive across aggressive Android audio-focus changes.
  Future<void> ensureMusicForGame(GameType gameType) async {
    if (!_musicEnabled) return;
    if (!_isInitialized) await ensureInitialized();
    if (!_isInitialized) return;
    _lastRequestedMusicGameType = gameType;
    if (_currentMusicPath != null) {
      final ok = await _ensureCurrentTrackIsPlaying();
      if (ok) return;
    }
    if (_lastMusicStartAt != null &&
        DateTime.now().difference(_lastMusicStartAt!) <
            const Duration(seconds: 3)) {
      return;
    }
    await playMusicForGame(gameType);
  }

  Future<bool> _ensureCurrentTrackIsPlaying() async {
    final currentPath = _currentMusicPath;
    if (currentPath == null) return false;
    try {
      await _bgmPlayer.setVolume(_currentMusicBaseVolume * _musicVolume);
      if (_bgmPlayer.state == PlayerState.playing) {
        // Force a no-op resume to recover from stale audio focus state on Android.
        await _bgmPlayer.resume();
        return true;
      }
      await _bgmPlayer.resume();
      if (_bgmPlayer.state == PlayerState.playing) return true;
    } catch (_) {}
    try {
      await _bgmPlayer.stop();
      await _setPlayerSourceWithFallback(_bgmPlayer, currentPath);
      await _bgmPlayer.setVolume(_currentMusicBaseVolume * _musicVolume);
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

    bool played = false;
    try {
      // Preloaded players can stall on some Android devices for rapid SFX.
      // Keep them only for long celebration sounds; use direct playback for taps/outcomes.
      final canUsePreloaded = type == SoundType.complete || type == SoundType.levelComplete;
      if (canUsePreloaded && _preloadedPlayers.containsKey(type)) {
        final player = _preloadedPlayers[type]!;
        try {
        await player
            .stop(); // Stop so rapid repeats (e.g. card flips) each play fully
        await player.seek(Duration.zero);
        await player.setVolume(_volumeFor(type));
        await player.resume();
          played = true;
        } catch (e) {
          // Preloaded player can be stale on some devices; fallback to direct candidate playback.
          LogService.warning(
            '🎵 [GameSound] Preloaded playback failed for $type: $e',
          );
        }
      }

      if (!played) {
        // Try all candidates in order so `sounds/flip.mp3` is preferred but
        // runtime decode/load failures can gracefully fallback to alternates.
        for (final candidate in _getSoundPathCandidates(type)) {
          if (!await _assetExists(candidate)) continue;
          try {
        if (type == SoundType.flip ||
            type == SoundType.cardFlip ||
            type == SoundType.piecePlace) {
          // For quick repeatable actions, force restart of the clip.
          await _audioPlayer.stop();
        }
        await _audioPlayer.setVolume(_volumeFor(type));
            await _playAssetWithFallback(_audioPlayer, candidate);
            _resolvedSoundPaths[type] = candidate;
            played = true;
            break;
          } catch (e) {
            LogService.warning(
              '🎵 [GameSound] Candidate playback failed: $candidate, error: $e',
            );
          }
        }
      }

      if (!played) {
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
        return 1.0 * _soundsVolume;
      case SoundType.correct:
      case SoundType.match:
      case SoundType.wordFound:
      case SoundType.click:
      case SoundType.piecePlace:
      case SoundType.pop:
        return 0.75 * _soundsVolume;
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

  /// Play correct answer sound with immediate, louder dedicated path.
  Future<void> playCorrect() async {
    if (!kIsWeb) {
      try {
        SystemSound.play(SystemSoundType.click);
      } catch (_) {}
    }
    await _playMatchingAssetCandidates([
      'sounds/correct.mp3',
      'sounds/match.mp3',
      'audio/music/sfx_correct_chime.ogg',
      'audio/music/sfx_streak_ping.ogg',
    ], volume: (1.0 * _soundsVolume).clamp(0.0, 1.0).toDouble());
  }

  /// Play incorrect answer sound with immediate, louder dedicated path.
  Future<void> playIncorrect() async {
    if (!kIsWeb) {
      try {
        SystemSound.play(SystemSoundType.alert);
      } catch (_) {}
    }
    await _playMatchingAssetCandidates([
      'sounds/incorrect.mp3',
      'audio/music/sfx_wrong_mute.ogg',
    ], volume: (1.0 * _soundsVolume).clamp(0.0, 1.0).toDouble());
  }

  /// Play card flip sound
  Future<void> playFlip() => _playSound(SoundType.flip);

  /// Play match success sound
  Future<void> playMatch() => _playSound(SoundType.match);

  /// Play game completion sound with low-latency behavior.
  /// Avoids delayed candidate scanning so completion SFX never arrives on a later screen.
  Future<void> playComplete() async {
    await _retryPendingMusicAfterUserGesture();
    if (!_soundsEnabled) return;
    if (!_isInitialized) await ensureInitialized();
    if (!_isInitialized) return;
    _playHaptic(SoundType.complete);
    try {
      final player = _preloadedPlayers[SoundType.complete];
      if (player != null) {
        await player.stop();
        await player.seek(Duration.zero);
        await player.setVolume(_volumeFor(SoundType.complete));
        await player.resume();
      } else {
        _playSystemFallback(SoundType.complete);
      }
    } catch (_) {
      _playSystemFallback(SoundType.complete);
    } finally {
      unawaited(resumeBgmIfNeeded());
    }
  }

  /// Play button click sound with immediate, dedicated path.
  Future<void> playClick() async {
    if (!kIsWeb) {
      try {
        SystemSound.play(SystemSoundType.click);
      } catch (_) {}
    }
    await _playMatchingAssetCandidates([
      'sounds/click.mp3',
      'sounds/flip.mp3',
      'audio/music/sfx_tap_soft.ogg',
      'audio/music/sfx_card_flip.ogg',
    ], volume: (1.0 * _soundsVolume).clamp(0.0, 1.0).toDouble());
  }

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

  /// Play a reliable, audible countdown tick for red-timer urgency.
  Future<void> playCountdownTick() async {
    if (!kIsWeb) {
      try {
        SystemSound.play(SystemSoundType.click);
      } catch (_) {}
    }
    await _playMatchingAssetCandidates([
      'sounds/click.mp3',
      'sounds/flip.mp3',
      'audio/music/sfx_tap_soft.ogg',
      'audio/music/sfx_card_flip.ogg',
      'audio/music/sfx_streak_ping.ogg',
    ], volume: (1.0 * _soundsVolume).clamp(0.0, 1.0).toDouble());
  }

  /// Play a buzzer-style sound when time runs out.
  Future<void> playCountdownBuzzer() async {
    if (!kIsWeb) {
      try {
        SystemSound.play(SystemSoundType.alert);
      } catch (_) {}
    }
    await _playSound(SoundType.incorrect);
  }

  /// Matching-specific SFX: force lively mp3 assets first.
  Future<void> playMatchingTap() async {
    // Guarantee immediate tactile tap feedback even when asset decoding lags.
    if (!kIsWeb) {
      try {
        SystemSound.play(SystemSoundType.click);
      } catch (_) {}
    }
    await _playMatchingAssetCandidates([
      'sounds/match.mp3',
      'sounds/flip.mp3',
      'sounds/click.mp3',
      'audio/music/sfx_tap_soft.ogg',
      'audio/music/sfx_card_flip.ogg',
      'audio/music/sfx_streak_ping.ogg',
    ], volume: (1.0 * _soundsVolume).clamp(0.0, 1.0).toDouble());
  }

  Future<void> playMatchingSuccess() async {
    await _playMatchingAssetCandidates([
      'sounds/match.mp3',
      'sounds/correct.mp3',
      'audio/music/sfx_streak_ping.ogg',
      'audio/music/sfx_correct_chime.ogg',
    ], volume: (1.0 * _soundsVolume).clamp(0.0, 1.0).toDouble());
  }

  Future<void> playMatchingWrong() async {
    await _playMatchingAssetCandidates([
      'sounds/incorrect.mp3',
      'audio/music/sfx_wrong_mute.ogg',
    ], volume: (0.9 * _soundsVolume).clamp(0.0, 1.0).toDouble());
  }

  Future<void> _playMatchingAssetCandidates(
    List<String> candidates, {
    required double volume,
  }) async {
    await _retryPendingMusicAfterUserGesture();
    if (!_soundsEnabled) return;
    if (!_isInitialized) await ensureInitialized();
    if (!_isInitialized) return;
    _playHaptic(SoundType.click);
    try {
      await _matchingSfxPlayer.stop();
      await _matchingSfxPlayer.setVolume(volume);
      for (final candidate in candidates) {
        if (!await _assetExists(candidate)) continue;
        try {
          await _playAssetWithFallback(_matchingSfxPlayer, candidate);
          return;
        } catch (_) {}
      }
      _playSystemFallback(SoundType.click);
    } catch (_) {
      _playSystemFallback(SoundType.click);
    } finally {
      unawaited(resumeBgmIfNeeded());
    }
  }

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
      final bytes = await _loadAssetBytes(normalizedPath);
      if (bytes != null) {
        await player.play(BytesSource(bytes));
        return;
      }
      await player.play(AssetSource(normalizedPath));
      return;
    } catch (_) {
      // Final fallback to asset source when bytes source fails unexpectedly.
      await player.play(AssetSource(normalizedPath));
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
      final bytes = await _loadAssetBytes(normalizedPath);
      if (bytes == null) rethrow;
      await player.setSource(BytesSource(bytes));
    }
  }

  Future<Uint8List?> _loadAssetBytes(String relativePath) async {
    final normalized = _normalizeAssetRelativePath(relativePath);
    final candidates = <String>[
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
    _matchingSfxPlayer.dispose();
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
