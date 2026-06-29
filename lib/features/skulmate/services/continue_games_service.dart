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
    final items = <SkulMateContinueItem>[];

    for (final game in games) {
      if (items.length >= limit) break;
      if (!game.isPlayable) continue;
      final progress = await GameProgressService.loadProgress(game.id);
      if (progress == null) continue;
      if (!GameProgressService.isResumable(progress, game.items.length)) {
        continue;
      }
      items.add(
        SkulMateContinueItem(
          gameId: game.id,
          title: game.title,
          subtitle: GameTypeVisuals.labelFor(game.gameType),
          progressPercent: GameProgressService.progressPercent(
            progress,
            game.items.length,
          ),
          lastPlayed: progress.savedAt,
          currentIndex: progress.currentIndex,
          totalItems: game.items.length,
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
