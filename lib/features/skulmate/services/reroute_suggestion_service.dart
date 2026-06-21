import 'package:shared_preferences/shared_preferences.dart';

import 'package:prepskul/core/services/log_service.dart';
import '../models/game_model.dart';
import '../models/reroute_suggestion.dart';
import 'continue_games_service.dart';
import 'concept_mastery_service.dart';
import 'game_progress_service.dart';

/// Phase C2 — intelligent, low-frequency resurfacing (never syllabus nagging).
class RerouteSuggestionService {
  RerouteSuggestionService._();

  static const _dismissPrefix = 'skulmate_reroute_dismiss_';
  static const _weeklyShownKey = 'skulmate_reroute_weekly_shown';
  static const dismissDays = 7;
  static const maxNudgesPerWeek = 2;
  static const minHoursSincePlay = 24;
  static const minAttempts = 3;

  /// Returns at most one suggestion, or null when not truly needed.
  static Future<RerouteSuggestion?> evaluate({
    required List<GameModel> games,
    String? childId,
  }) async {
    if (games.isEmpty) return null;

    // User already has Jump back in — don't stack prompts.
    final continueItems =
        await ContinueGamesService.loadContinueItems(games, limit: 1);
    if (continueItems.isNotEmpty) return null;

    final inProgress = await GameProgressService.gameIdsWithProgress();
    if (inProgress.isNotEmpty) return null;

    if (!await _hasWeeklyBudget()) return null;

    final rows = await ConceptMasteryService.fetchMasteryCandidates(
      childId: childId,
      limit: 8,
    );
    if (rows.isEmpty) return null;

    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();

    for (final row in rows) {
      final topicId = row['topic_id'] as String? ?? '';
      if (!_isEligibleRow(row, now)) continue;
      if (_isDismissed(prefs, topicId, now)) continue;

      final gameId = row['last_game_id'] as String?;
      GameModel? game;
      if (gameId != null && gameId.isNotEmpty) {
        for (final g in games) {
          if (g.id == gameId) {
            game = g;
            break;
          }
        }
      }
      game ??= _gameForTopic(games, topicId);
      if (game == null || !game.isPlayable) continue;

      return RerouteSuggestion(
        topicId: topicId,
        gameId: game.id,
        gameTitle: game.title,
      );
    }

    return null;
  }

  static Future<void> markShown(String topicId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final week = _isoWeekKey(DateTime.now());
      final topicKey = 'skulmate_reroute_seen_${week}_$topicId';
      if (prefs.getBool(topicKey) == true) return;

      await prefs.setBool(topicKey, true);
      final storedWeek = prefs.getString(_weeklyShownKey);
      if (storedWeek == week) {
        await prefs.setInt('${_weeklyShownKey}_count', _weeklyCount(prefs) + 1);
      } else {
        await prefs.setString(_weeklyShownKey, week);
        await prefs.setInt('${_weeklyShownKey}_count', 1);
      }
    } catch (e) {
      LogService.debug('RerouteSuggestionService.markShown: $e');
    }
  }

  static Future<void> dismiss(String topicId) async {
    final prefs = await SharedPreferences.getInstance();
    final until = DateTime.now().add(const Duration(days: dismissDays));
    await prefs.setString(
      '$_dismissPrefix$topicId',
      until.toIso8601String(),
    );
  }

  static bool _isEligibleRow(Map<String, dynamic> row, DateTime now) {
    final topicId = row['topic_id'] as String? ?? '';
    if (topicId.isEmpty || topicId == 'open:general') return false;

    final attempts = (row['attempts'] as num?)?.toInt() ?? 0;
    if (attempts < minAttempts) return false;

    final weakStreak = (row['weak_streak'] as num?)?.toInt() ?? 0;
    final mastery = (row['mastery_score'] as num?)?.toDouble() ?? 1;

    final sustained =
        weakStreak >= 2 || (attempts >= 4 && mastery < 0.42);
    if (!sustained) return false;

    final lastSeenRaw = row['last_seen_at'] as String?;
    if (lastSeenRaw != null) {
      final lastSeen = DateTime.tryParse(lastSeenRaw);
      if (lastSeen != null) {
        final hours = now.difference(lastSeen).inHours;
        if (hours < minHoursSincePlay) return false;
      }
    }

    return true;
  }

  static bool _isDismissed(
    SharedPreferences prefs,
    String topicId,
    DateTime now,
  ) {
    final raw = prefs.getString('$_dismissPrefix$topicId');
    if (raw == null) return false;
    final until = DateTime.tryParse(raw);
    if (until == null) return false;
    return now.isBefore(until);
  }

  static Future<bool> _hasWeeklyBudget() async {
    final prefs = await SharedPreferences.getInstance();
    final week = _isoWeekKey(DateTime.now());
    final storedWeek = prefs.getString(_weeklyShownKey);
    if (storedWeek != week) return true;
    return _weeklyCount(prefs) < maxNudgesPerWeek;
  }

  static int _weeklyCount(SharedPreferences prefs) =>
      prefs.getInt('${_weeklyShownKey}_count') ?? 0;

  static String _isoWeekKey(DateTime dt) {
    final thursday = dt.add(Duration(days: 3 - ((dt.weekday + 6) % 7)));
    final yearStart = DateTime(thursday.year);
    final week =
        ((thursday.difference(yearStart).inDays) / 7).floor() + 1;
    return '${thursday.year}-W$week';
  }

  static GameModel? _gameForTopic(List<GameModel> games, String topicId) {
    for (final game in games) {
      if (!game.isPlayable) continue;
      if (topicId.startsWith('open:')) {
        final slug = topicId.replaceFirst('open:', '').replaceAll('-', ' ');
        if (game.title.toLowerCase().contains(slug)) return game;
      }
    }
    return null;
  }
}
