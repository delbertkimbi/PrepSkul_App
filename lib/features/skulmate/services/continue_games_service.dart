import '../models/game_model.dart';
import '../models/skulmate_intake_models.dart';
import '../utils/game_type_visuals.dart';
import 'game_progress_service.dart';

/// Rules for the home "Jump back in" row:
/// - Max [maxItems] games (default 3).
/// - Only games with saved in-progress state (started but not finished).
/// - Completed games are excluded immediately once progress is cleared.
class ContinueGamesService {
  static const int maxItems = 3;

  static Future<List<SkulMateContinueItem>> loadContinueItems(
    List<GameModel> games, {
    int limit = maxItems,
  }) async {
    final inProgressIds = await GameProgressService.gameIdsWithProgress();
    final items = <SkulMateContinueItem>[];

    for (final game in games) {
      if (items.length >= limit) break;
      if (!game.isPlayable || !inProgressIds.contains(game.id)) continue;
      final progress = await GameProgressService.loadProgress(game.id);
      items.add(
        SkulMateContinueItem(
          gameId: game.id,
          title: game.title,
          subtitle: GameTypeVisuals.labelFor(game.gameType),
          progressPercent: 0,
          lastPlayed: progress?.savedAt ?? DateTime.now(),
        ),
      );
    }

    items.sort((a, b) => b.lastPlayed.compareTo(a.lastPlayed));
    if (items.length > limit) {
      return items.sublist(0, limit);
    }
    return items;
  }
}
