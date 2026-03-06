import 'package:shared_preferences/shared_preferences.dart';
import '../models/game_model.dart';
import '../../../core/services/log_service.dart';

/// Daily challenge: one focused set per day per learner.
/// Picks a deterministic "today's game" from the library and tracks completion.
class DailyChallengeService {
  static const String _keyPrefix = 'daily_challenge_';
  static const String _keyCompletedPrefix = 'daily_completed_';
  static const String _keyStreakPrefix = 'daily_streak_';

  /// Storage key for completion (date + childId so parent/child are separate).
  static String _completionKey(String dateYmd, [String? childId]) {
    final suffix = childId ?? 'me';
    return '$_keyCompletedPrefix${dateYmd}_$suffix';
  }

  static String _streakKey([String? childId]) {
    final suffix = childId ?? 'me';
    return '$_keyStreakPrefix$suffix';
  }

  /// Current date as YYYY-MM-DD (UTC) for consistent keys.
  static String _todayYmd() {
    final now = DateTime.now().toUtc();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  /// Pick today's challenge game from [games]. Prefers quiz (playable); deterministic by date.
  /// Returns null if no playable quiz (or no games).
  static GameModel? getTodayChallengeGame(List<GameModel> games, {String? childId}) {
    final playableQuizzes = games
        .where((g) => g.gameType == GameType.quiz && g.isPlayable && (g.items.length) >= 3)
        .toList();
    if (playableQuizzes.isEmpty) return null;

    final seed = _todayYmd().hashCode + (childId ?? 'me').hashCode;
    final index = seed.abs() % playableQuizzes.length;
    return playableQuizzes[index];
  }

  /// Mark today's daily challenge as completed for this user/child.
  static Future<void> markCompleteForToday({String? childId}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = _todayYmd();
      await prefs.setBool(_completionKey(today, childId), true);

      // Update streak: consecutive days completed
      final streakKey = _streakKey(childId);
      final prevStreak = prefs.getInt(streakKey) ?? 0;
      final lastCompleted = prefs.getString('${_keyPrefix}last_${childId ?? 'me'}') ?? '';

      // If last completed was yesterday, increment streak; else set to 1
      final yesterday = _yesterdayYmd();
      if (lastCompleted == yesterday) {
        await prefs.setInt(streakKey, prevStreak + 1);
      } else if (lastCompleted != today) {
        await prefs.setInt(streakKey, 1);
      }
      await prefs.setString('${_keyPrefix}last_${childId ?? 'me'}', today);
      LogService.debug('Daily challenge marked complete for $today (streak: ${prevStreak + 1})');
    } catch (e) {
      LogService.warning('DailyChallengeService.markCompleteForToday: $e');
    }
  }

  static String _yesterdayYmd() {
    final t = DateTime.now().toUtc().subtract(const Duration(days: 1));
    return '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';
  }

  /// Whether the user has completed today's daily challenge.
  static Future<bool> isCompletedToday({String? childId}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_completionKey(_todayYmd(), childId)) ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Current daily-challenge streak (consecutive days completed).
  static Future<int> getDailyStreak({String? childId}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(_streakKey(childId)) ?? 0;
    } catch (_) {
      return 0;
    }
  }
}
