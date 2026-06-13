import '../models/game_model.dart';
import '../models/skulmate_intake_models.dart';
import '../utils/game_type_visuals.dart';
import 'game_progress_service.dart';
import 'skulmate_service.dart';

/// Loads recently played games for the Continue row.
class ContinueGamesService {
  static const int defaultLimit = 6;
  static const int lookbackDays = 7;

  static Future<List<SkulMateContinueItem>> loadContinueItems(
    List<GameModel> games, {
    int limit = defaultLimit,
  }) async {
    final cutoff = DateTime.now().subtract(const Duration(days: lookbackDays));
    final inProgressIds = await GameProgressService.gameIdsWithProgress();
    final items = <SkulMateContinueItem>[];
    final seen = <String>{};

    for (final game in games) {
      if (!game.isPlayable || seen.contains(game.id)) continue;
      if (!inProgressIds.contains(game.id)) continue;
      seen.add(game.id);
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

    for (final game in games) {
      if (!game.isPlayable || seen.contains(game.id)) continue;
      final stats = await SkulMateService.getGameStats(game.id);
      final lastPlayed = stats['lastPlayed'] as DateTime?;
      if (lastPlayed == null || !lastPlayed.isAfter(cutoff)) continue;
      seen.add(game.id);

      items.add(
        SkulMateContinueItem(
          gameId: game.id,
          title: game.title,
          subtitle: GameTypeVisuals.labelFor(game.gameType),
          progressPercent:
              (stats['bestScorePercentage'] as num?)?.toDouble() ?? 0,
          lastPlayed: lastPlayed,
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
