import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:prepskul/core/services/log_service.dart';

// Conditional import: Use real games_services on mobile, stub on web
// The games_services package only works on iOS/Android, not web
import 'games_services_controller_stub.dart'
    if (dart.library.io) 'games_services_controller_mobile.dart';

/// Controller for platform-specific achievements and leaderboards
/// Supports iOS Game Center and Android Play Games Services
class GamesServicesController {
  static final GamesServicesController _instance = GamesServicesController._internal();
  factory GamesServicesController() => _instance;
  GamesServicesController._internal();

  bool _isInitialized = false;
  bool _isSignedIn = false;

  /// Initialize Game Center/Play Games Services
  Future<bool> initialize() async {
    if (_isInitialized) {
      return _isSignedIn;
    }

    try {
      if (kIsWeb) {
        // Web doesn't support platform achievements
        LogService.info('🎮 [GamesServices] Web platform - platform achievements not available');
        _isInitialized = true;
        return false;
      }

      if (Platform.isIOS || Platform.isAndroid) {
        final signedIn = await signIn();
        _isInitialized = true;
        _isSignedIn = signedIn;
        return signedIn;
      }

      _isInitialized = true;
      return false;
    } catch (e) {
      LogService.error('🎮 [GamesServices] Initialization error: $e');
      _isInitialized = true;
      return false;
    }
  }

  /// Sign in to Game Center/Play Games
  Future<bool> signIn() async {
    try {
      if (kIsWeb) return false;

      await GamesServices.signIn();
      _isSignedIn = true;
      LogService.info('🎮 [GamesServices] Signed in successfully');
      return true;
    } catch (e) {
      LogService.warning('🎮 [GamesServices] Sign in error: $e');
      _isSignedIn = false;
      return false;
    }
  }

  /// Award an achievement
  /// [achievementId] - Platform-specific achievement ID
  Future<bool> awardAchievement(String achievementId) async {
    try {
      if (kIsWeb || !_isSignedIn) return false;

      if (Platform.isAndroid) {
        await GamesServices.unlock(achievement: Achievement(
          androidID: achievementId,
        ));
      } else if (Platform.isIOS) {
        await GamesServices.unlock(achievement: Achievement(
          iOSID: achievementId,
        ));
      }

      LogService.info('🎮 [GamesServices] Achievement unlocked: $achievementId');
      return true;
    } catch (e) {
      LogService.error('🎮 [GamesServices] Error awarding achievement: $e');
      return false;
    }
  }

  /// Submit score to leaderboard
  /// [leaderboardId] - Platform-specific leaderboard ID
  /// [score] - Score to submit
  Future<bool> submitLeaderboardScore(String leaderboardId, int score) async {
    try {
      if (kIsWeb || !_isSignedIn) return false;

      if (Platform.isAndroid) {
        await GamesServices.submitScore(
          score: Score(
            androidLeaderboardID: leaderboardId,
            value: score,
          ),
        );
      } else if (Platform.isIOS) {
        await GamesServices.submitScore(
          score: Score(
            iOSLeaderboardID: leaderboardId,
            value: score,
          ),
        );
      }

      LogService.info('🎮 [GamesServices] Score submitted: $score to $leaderboardId');
      return true;
    } catch (e) {
      LogService.error('🎮 [GamesServices] Error submitting score: $e');
      return false;
    }
  }

  /// Show platform achievements UI
  Future<void> showAchievements() async {
    try {
      if (kIsWeb || !_isSignedIn) return;

      await GamesServices.showAchievements();
      LogService.info('🎮 [GamesServices] Showing achievements');
    } catch (e) {
      LogService.error('🎮 [GamesServices] Error showing achievements: $e');
    }
  }

  /// Show platform leaderboard UI
  /// [leaderboardId] - Optional specific leaderboard to show
  Future<void> showLeaderboard({String? leaderboardId}) async {
    try {
      if (kIsWeb || !_isSignedIn) return;

      if (leaderboardId != null) {
        await GamesServices.showLeaderboards(
          iOSLeaderboardID: Platform.isIOS ? leaderboardId : null,
          androidLeaderboardID: Platform.isAndroid ? leaderboardId : null,
        );
      } else {
        await GamesServices.showLeaderboards();
      }
      LogService.info('🎮 [GamesServices] Showing leaderboard${leaderboardId != null ? ': $leaderboardId' : ''}');
    } catch (e) {
      LogService.error('🎮 [GamesServices] Error showing leaderboard: $e');
    }
  }

  /// Check if user is signed in
  bool get isSignedIn => _isSignedIn;

  /// Check if platform achievements are available
  bool get isAvailable => !kIsWeb && (Platform.isIOS || Platform.isAndroid);
}