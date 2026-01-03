// Stub for games_services on web and unsupported platforms
import 'package:prepskul/core/services/log_service.dart';

// Stub classes to match games_services API
class GamesServices {
  static Future<void> signIn() async {
    LogService.warning('🎮 [GamesServices] signIn() called but not available on this platform');
  }

  static Future<void> unlock({required Achievement achievement}) async {
    LogService.warning('🎮 [GamesServices] unlock() called but not available on this platform');
  }

  static Future<void> submitScore({required Score score}) async {
    LogService.warning('🎮 [GamesServices] submitScore() called but not available on this platform');
  }

  static Future<void> showAchievements() async {
    LogService.warning('🎮 [GamesServices] showAchievements() called but not available on this platform');
  }

  static Future<void> showLeaderboards({
    String? iOSLeaderboardID,
    String? androidLeaderboardID,
  }) async {
    LogService.warning('🎮 [GamesServices] showLeaderboards() called but not available on this platform');
  }
}

class Achievement {
  final String? androidID;
  final String? iOSID;

  Achievement({this.androidID, this.iOSID});
}

class Score {
  final String? androidLeaderboardID;
  final String? iOSLeaderboardID;
  final int value;

  Score({
    this.androidLeaderboardID,
    this.iOSLeaderboardID,
    required this.value,
  });
}