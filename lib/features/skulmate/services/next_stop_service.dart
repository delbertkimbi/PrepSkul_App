import 'package:shared_preferences/shared_preferences.dart';

import '../models/game_model.dart';
import '../models/next_stop_suggestion.dart';
import '../models/reroute_suggestion.dart';
import 'continue_games_service.dart';
import 'reroute_suggestion_service.dart';
import 'session_route_service.dart';
import 'spaced_repetition_service.dart';

/// Priority: due review → weak topic → continue in-progress.
class NextStopService {
  NextStopService._();

  static const _dismissPrefix = 'skulmate_next_stop_dismiss_';

  static Future<NextStopSuggestion?> evaluate({
    required List<GameModel> games,
    String? childId,
  }) async {
    final sessionRoute = await SessionRouteService.evaluate(childId: childId);
    if (sessionRoute != null &&
        !await _isDismissed('session_${sessionRoute.sessionId}')) {
      final matched = _gameMatchingSubject(games, sessionRoute.subject);
      return NextStopSuggestion(
        kind: NextStopKind.fromSession,
        gameId: matched?.id ?? sessionRoute.sessionId,
        title: sessionRoute.subject.isNotEmpty
            ? sessionRoute.subject
            : sessionRoute.focusPhrase,
        subtitle: sessionRoute.focusPhrase,
        sessionId: sessionRoute.sessionId,
        sessionSummary: sessionRoute.summary,
        tutorName: sessionRoute.tutorName,
      );
    }

    if (games.isEmpty) return null;

    final due = await SpacedRepetitionService.fetchDueQueue(
      limit: 1,
      childId: childId,
    );
    if (due.isNotEmpty) {
      final item = due.first;
      if (!await _isDismissed('due_${item.id}')) {
        final game = _gameById(games, item.gameId);
        if (game != null) {
          return NextStopSuggestion(
            kind: NextStopKind.dueReview,
            gameId: game.id,
            title: game.title,
            subtitle: item.termPreview ?? item.conceptKey,
          );
        }
      }
    }

    final weak = await RerouteSuggestionService.evaluate(
      games: games,
      childId: childId,
    );
    if (weak != null && !await _isDismissed('weak_${weak.topicId}')) {
      return NextStopSuggestion(
        kind: NextStopKind.weakTopic,
        gameId: weak.gameId,
        title: weak.gameTitle,
        topicId: weak.topicId,
      );
    }

    final continueItems =
        await ContinueGamesService.loadContinueItems(games, limit: 1);
    if (continueItems.isNotEmpty) {
      final item = continueItems.first;
      if (!await _isDismissed('continue_${item.gameId}')) {
        return NextStopSuggestion(
          kind: NextStopKind.continueGame,
          gameId: item.gameId,
          title: item.title,
          subtitle: item.subtitle,
        );
      }
    }

    return null;
  }

  static Future<void> dismiss(NextStopSuggestion suggestion) async {
    final prefs = await SharedPreferences.getInstance();
    final key = switch (suggestion.kind) {
      NextStopKind.dueReview => 'due_${suggestion.gameId}',
      NextStopKind.weakTopic => 'weak_${suggestion.topicId ?? suggestion.gameId}',
      NextStopKind.continueGame => 'continue_${suggestion.gameId}',
      NextStopKind.fromSession => 'session_${suggestion.sessionId ?? suggestion.gameId}',
    };
    await prefs.setString(
      '$_dismissPrefix$key',
      DateTime.now().add(const Duration(hours: 12)).toIso8601String(),
    );
  }

  static Future<bool> _isDismissed(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_dismissPrefix$key');
    if (raw == null) return false;
    final until = DateTime.tryParse(raw);
    if (until == null) return false;
    return DateTime.now().isBefore(until);
  }

  static GameModel? _gameById(List<GameModel> games, String id) {
    for (final g in games) {
      if (g.id == id && g.isPlayable) return g;
    }
    return null;
  }

  static GameModel? _gameMatchingSubject(List<GameModel> games, String subject) {
    final needle = subject.trim().toLowerCase();
    if (needle.isEmpty) return null;
    for (final g in games) {
      if (!g.isPlayable) continue;
      final title = g.title.toLowerCase();
      final topic = g.metadata.topic?.toLowerCase() ?? '';
      if (title.contains(needle) || topic.contains(needle)) return g;
    }
    return null;
  }

  static Future<void> markWeakShown(RerouteSuggestion suggestion) {
    return RerouteSuggestionService.markShown(suggestion.topicId);
  }
}
