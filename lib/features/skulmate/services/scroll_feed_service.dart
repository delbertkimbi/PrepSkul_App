import '../models/game_model.dart';
import '../models/scroll_feed_item.dart';
import 'spaced_repetition_service.dart';

/// Builds the bounded queue for Scroll mode (due items first, then seed game).
class ScrollFeedService {
  ScrollFeedService._();

  static const int defaultSessionCap = 12;
  static const int masteryGateEvery = 8;

  static Future<List<ScrollFeedItem>> buildQueue({
    GameModel? seedGame,
    String? childId,
    int limit = defaultSessionCap,
  }) async {
    final seen = <String>{};
    final queue = <ScrollFeedItem>[];

    final due = await SpacedRepetitionService.fetchDueQueue(
      limit: limit,
      childId: childId,
    );

    if (due.isNotEmpty) {
      final gameIds = due.map((d) => d.gameId).toSet().toList();
      final itemMaps = await SpacedRepetitionService.loadTermDefinitions(gameIds);
      for (final row in due) {
        final key = '${row.gameId}:${row.itemIndex}';
        if (seen.contains(key)) continue;
        final item = itemMaps[key];
        if (item == null) continue;
        seen.add(key);
        queue.add(
          ScrollFeedItem(
            gameId: row.gameId,
            itemIndex: row.itemIndex,
            term: item.term,
            definition: item.definition,
            reviewRowId: row.id,
            gameTitle: row.gameTitle,
          ),
        );
        if (queue.length >= limit) return queue;
      }
    }

    if (seedGame != null) {
      for (var i = 0; i < seedGame.items.length; i++) {
        final key = '${seedGame.id}:$i';
        if (seen.contains(key)) continue;
        final raw = seedGame.items[i];
        final term = raw.term ?? raw.question ?? '';
        final definition = raw.definition ?? raw.correctAnswer?.toString() ?? '';
        if (term.isEmpty) continue;
        seen.add(key);
        queue.add(
          ScrollFeedItem(
            gameId: seedGame.id,
            itemIndex: i,
            term: term,
            definition: definition.isEmpty ? term : definition,
            gameTitle: seedGame.title,
          ),
        );
        if (queue.length >= limit) break;
      }
    }

    return queue;
  }
}
