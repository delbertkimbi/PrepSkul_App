import 'package:flutter/material.dart';

import '../l10n/skulmate_copy.dart';
import '../models/game_model.dart';
import '../models/skulmate_intake_models.dart';
import '../services/continue_games_service.dart';
import '../services/game_progress_service.dart';
import '../services/skulmate_intake_coordinator.dart';
import '../utils/skulmate_game_router.dart';
import 'game_card.dart';
import 'skulmate_home_section_header.dart';

/// Horizontal Jump back in row — expands inline like My games.
class SkulMateContinueRow extends StatefulWidget {
  final List<GameModel> games;

  const SkulMateContinueRow({
    super.key,
    required this.games,
  });

  static const _rowHeight = 94.0;

  @override
  State<SkulMateContinueRow> createState() => _SkulMateContinueRowState();
}

class _SkulMateContinueRowState extends State<SkulMateContinueRow> {
  List<SkulMateContinueItem> _items = [];
  Map<String, GameProgress> _progressByGame = {};
  bool _loading = true;
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(SkulMateContinueRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.games != widget.games) _load();
  }

  Future<void> _load() async {
    final items = await ContinueGamesService.loadContinueItems(widget.games);
    final progress = <String, GameProgress>{};
    for (final item in items) {
      final p = await GameProgressService.loadProgress(item.gameId);
      if (p != null) progress[item.gameId] = p;
    }
    if (mounted) {
      setState(() {
        _items = items;
        _progressByGame = progress;
        _loading = false;
      });
    }
  }

  void _toggleExpanded() {
    setState(() => _expanded = !_expanded);
  }

  String? _subtitleFor(String gameId, GameModel game) {
    final progress = _progressByGame[gameId];
    if (progress == null) return null;
    final total = game.items.length;
    if (total <= 0) return 'In progress';
    final step = (progress.currentIndex + 1).clamp(1, total);
    return 'Resume · $step/$total';
  }

  @override
  Widget build(BuildContext context) {
    final copy = SkulMateCopy.of(context);
    if (_loading || _items.isEmpty) return const SizedBox.shrink();

    final preview = _items.take(ContinueGamesService.maxItems).toList();
    final cardWidth = MediaQuery.sizeOf(context).width * 0.72;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SkulMateHomeSectionHeader(
          title: copy.jumpBackIn,
          onViewAll: _toggleExpanded,
          viewAllLabel: _expanded ? copy.showLess : copy.viewAll,
        ),
        const SizedBox(height: 8),
        if (_expanded)
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: preview.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final item = preview[index];
              final game = widget.games.firstWhere(
                (g) => g.id == item.gameId,
                orElse: () => widget.games.first,
              );
              return GameCard(
                game: game,
                compact: true,
                subtitleOverride: _subtitleFor(item.gameId, game),
                onTap: () => SkulMateGameRouter.open(context, game),
              );
            },
          )
        else
          SizedBox(
            height: SkulMateContinueRow._rowHeight,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              itemCount: preview.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final item = preview[index];
                final game = widget.games.firstWhere(
                  (g) => g.id == item.gameId,
                  orElse: () => widget.games.first,
                );
                return SizedBox(
                  width: cardWidth.clamp(250, 310),
                  child: GameCard(
                    game: game,
                    compact: true,
                    horizontal: true,
                    subtitleOverride: _subtitleFor(item.gameId, game),
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

Future<void> submitTypedTopic(
  BuildContext context,
  String topic, {
  String? childId,
}) async {
  final trimmed = topic.trim();
  if (trimmed.isEmpty) return;
  await SkulMateIntakeCoordinator.start(
    context,
    SkulMateIntakePayload(
      source: SkulMateIntakeSource.typedTopic,
      topicHint: trimmed,
      childId: childId,
    ),
  );
}
