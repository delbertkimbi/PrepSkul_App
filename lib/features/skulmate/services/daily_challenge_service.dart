import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/game_model.dart';
import '../../../core/services/log_service.dart';

/// Daily challenge: one focused set per day per learner.
/// Picks a deterministic "today's game" from the library and tracks completion.
class DailyChallengeService {
  static const String _keyPrefix = 'daily_challenge_';
  static const String _keyCompletedPrefix = 'daily_completed_';
  static const String _keyStreakPrefix = 'daily_streak_';
  static const String _keyHiddenPrefix = 'daily_hidden_';
  static const String _keyRecentChallengesPrefix = 'daily_recent_challenges_';
  static const String _keyTodayChallengeIdPrefix = 'daily_today_challenge_id_';

  /// Storage key for completion (date + childId so parent/child are separate).
  static String _completionKey(String dateYmd, [String? childId]) {
    final suffix = childId ?? 'me';
    return '$_keyCompletedPrefix${dateYmd}_$suffix';
  }

  static String _streakKey([String? childId]) {
    final suffix = childId ?? 'me';
    return '$_keyStreakPrefix$suffix';
  }

  /// Current date as YYYY-MM-DD in local time (matches user day boundaries).
  static String _todayYmd() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  static String _hiddenKey(String dateYmd, [String? childId]) {
    final suffix = childId ?? 'me';
    return '$_keyHiddenPrefix${dateYmd}_$suffix';
  }

  static String _todayChallengeIdKey([String? childId]) {
    final suffix = childId ?? 'me';
    return '$_keyTodayChallengeIdPrefix$suffix';
  }

  static String _recentChallengesKey([String? childId]) {
    final suffix = childId ?? 'me';
    return '$_keyRecentChallengesPrefix$suffix';
  }

  static DateTime? _parseYmd(String ymd) {
    final parts = ymd.split('-');
    if (parts.length != 3) return null;
    final y = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final d = int.tryParse(parts[2]);
    if (y == null || m == null || d == null) return null;
    return DateTime(y, m, d);
  }

  /// Pick today's challenge game from [games], avoiding repeats from last 14 days.
  /// Returns null if no valid challenge is available, so UI can prompt the user
  /// to create a new quiz game.
  static Future<GameModel?> getTodayChallengeGame(
    List<GameModel> games, {
    String? childId,
  }) async {
    final playableQuizzes = games
        .where((g) => g.gameType == GameType.quiz && g.isPlayable && (g.items.length) >= 3)
        .toList();
    if (playableQuizzes.isEmpty) return null;

    final today = _todayYmd();
    final prefs = await SharedPreferences.getInstance();
    final suffix = childId ?? 'me';

    // Keep today's pick stable once selected.
    final pinned = prefs.getString(_todayChallengeIdKey(childId));
    if (pinned != null && pinned.isNotEmpty) {
      try {
        final pinnedParts = pinned.split('|');
        if (pinnedParts.length == 2 && pinnedParts[0] == today) {
          final pinnedId = pinnedParts[1];
          for (final game in playableQuizzes) {
            if (game.id == pinnedId) return game;
          }
        }
      } catch (_) {}
    }

    // Load and prune recent challenge history (rolling 14 days).
    final rawHistory = prefs.getString(_recentChallengesKey(childId));
    final history = <String, String>{};
    if (rawHistory != null && rawHistory.isNotEmpty) {
      try {
        final dynamic decoded = jsonDecode(rawHistory);
        if (decoded is Map) {
          for (final entry in decoded.entries) {
            final key = entry.key.toString();
            final value = entry.value?.toString() ?? '';
            if (value.isNotEmpty) history[key] = value;
          }
        }
      } catch (_) {}
    }

    final cutoff = DateTime.now().subtract(const Duration(days: 14));
    history.removeWhere((k, _) {
      final parsed = _parseYmd(k);
      return parsed == null || parsed.isBefore(DateTime(cutoff.year, cutoff.month, cutoff.day));
    });

    final recentIds = history.values.toSet();
    final eligible = playableQuizzes.where((g) => !recentIds.contains(g.id)).toList();
    if (eligible.isEmpty) {
      await prefs.setString(_recentChallengesKey(childId), jsonEncode(history));
      await prefs.remove(_todayChallengeIdKey(childId));
      LogService.info(
        'Daily challenge: no eligible game for $suffix (all used in last 14 days)',
      );
      return null;
    }

    final seed = today.hashCode + suffix.hashCode;
    final index = seed.abs() % eligible.length;
    final selected = eligible[index];
    history[today] = selected.id;
    await prefs.setString(_recentChallengesKey(childId), jsonEncode(history));
    await prefs.setString(_todayChallengeIdKey(childId), '$today|${selected.id}');
    return selected;
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
    final t = DateTime.now().subtract(const Duration(days: 1));
    return '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';
  }

  static Future<void> hideForToday({String? childId}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_hiddenKey(_todayYmd(), childId), true);
    } catch (_) {}
  }

  static Future<bool> isHiddenToday({String? childId}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_hiddenKey(_todayYmd(), childId)) ?? false;
    } catch (_) {
      return false;
    }
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
