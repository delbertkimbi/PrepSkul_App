import 'package:flutter/material.dart';

import '../l10n/skulmate_copy.dart';
import '../models/game_model.dart';
import '../screens/skulmate_games_screen.dart';
import '../utils/skulmate_game_router.dart';
import 'game_card.dart';
import 'skulmate_home_section_header.dart';
import 'skulmate_loading_skeletons.dart';
import 'skulmate_typography.dart';

/// My games — horizontal carousel; View all opens the saved games library.
class SkulMateHomeGamesRow extends StatefulWidget {
  final List<GameModel> games;
  final bool loading;
  final String? childId;
  final Future<void> Function()? onAfterGameOpen;

  const SkulMateHomeGamesRow({
    super.key,
    required this.games,
    this.loading = false,
    this.childId,
    this.onAfterGameOpen,
  });

  static const _rowHeight = 86.0;

  @override
  State<SkulMateHomeGamesRow> createState() => _SkulMateHomeGamesRowState();
}

class _SkulMateHomeGamesRowState extends State<SkulMateHomeGamesRow> {
  Future<void> _openAllGames() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SkulMateGamesScreen(childId: widget.childId),
      ),
    );
    await widget.onAfterGameOpen?.call();
  }

  Future<void> _openGame(GameModel game) async {
    await SkulMateGameRouter.open(context, game);
    await widget.onAfterGameOpen?.call();
  }

  @override
  Widget build(BuildContext context) {
    final copy = SkulMateCopy.of(context);
    if (!widget.loading && widget.games.isEmpty) {
      return const SizedBox.shrink();
    }
    final preview = widget.games.take(8).toList();
    final cardWidth = MediaQuery.sizeOf(context).width * 0.72;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SkulMateHomeSectionHeader(
          title: copy.myGames,
          onViewAll: widget.games.isNotEmpty && !widget.loading
              ? _openAllGames
              : null,
        ),
        const SizedBox(height: 8),
        if (widget.loading)
          SizedBox(
            height: SkulMateHomeGamesRow._rowHeight,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 2,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) => SkulMateLoadingSkeletons.homeGameCard(
                width: cardWidth.clamp(250, 310),
              ),
            ),
          )
        else if (preview.isEmpty)
          const SizedBox.shrink()
        else
          SizedBox(
            height: SkulMateHomeGamesRow._rowHeight,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              itemCount: preview.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final game = preview[index];
                return SizedBox(
                  width: cardWidth.clamp(250, 310),
                  child: GameCard(
                    game: game,
                    compact: true,
                    horizontal: true,
                    onTap: () => _openGame(game),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}
