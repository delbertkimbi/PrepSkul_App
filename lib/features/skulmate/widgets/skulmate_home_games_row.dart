import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';

import '../l10n/skulmate_copy.dart';
import '../models/game_model.dart';
import '../utils/skulmate_game_router.dart';
import 'game_card.dart';
import 'skulmate_home_section_header.dart';

/// My games — horizontal carousel by default; View all expands to a vertical list.
class SkulMateHomeGamesRow extends StatefulWidget {
  final List<GameModel> games;
  final bool loading;

  const SkulMateHomeGamesRow({
    super.key,
    required this.games,
    this.loading = false,
  });

  static const _rowHeight = 94.0;

  @override
  State<SkulMateHomeGamesRow> createState() => _SkulMateHomeGamesRowState();
}

class _SkulMateHomeGamesRowState extends State<SkulMateHomeGamesRow> {
  bool _expanded = false;

  void _toggleExpanded() {
    setState(() => _expanded = !_expanded);
  }

  @override
  Widget build(BuildContext context) {
    final copy = SkulMateCopy.of(context);
    final preview = widget.games.take(8).toList();
    final cardWidth = MediaQuery.sizeOf(context).width * 0.72;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SkulMateHomeSectionHeader(
          title: copy.myGames,
          onViewAll: widget.games.isNotEmpty && !widget.loading
              ? _toggleExpanded
              : null,
          viewAllLabel: _expanded ? copy.showLess : copy.viewAll,
        ),
        const SizedBox(height: 8),
        if (widget.loading)
          const SizedBox(
            height: SkulMateHomeGamesRow._rowHeight,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          )
        else if (preview.isEmpty)
          Text(
            copy.isFrench
                ? 'Importe des notes pour créer ton premier jeu.'
                : 'Upload notes to create your first game.',
            style: GoogleFonts.poppins(
              color: AppTheme.textMedium,
              fontSize: 14,
            ),
          )
        else if (_expanded)
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: preview.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final game = preview[index];
              return GameCard(
                game: game,
                compact: true,
                onTap: () => SkulMateGameRouter.open(context, game),
              );
            },
          )
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
                    onTap: () => SkulMateGameRouter.open(context, game),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}
