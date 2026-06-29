import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';

import '../l10n/skulmate_copy.dart';
import '../models/game_model.dart';
import '../models/reroute_suggestion.dart';
import '../services/reroute_suggestion_service.dart';
import '../services/spaced_repetition_service.dart';
import '../utils/skulmate_game_router.dart';
import 'skulmate_surface_styles.dart';

/// Single optional home nudge — only when [RerouteSuggestionService] says so.
class SkulMateRerouteNudge extends StatefulWidget {
  final List<GameModel> games;
  final String? childId;

  const SkulMateRerouteNudge({
    super.key,
    required this.games,
    this.childId,
  });

  @override
  State<SkulMateRerouteNudge> createState() => _SkulMateRerouteNudgeState();
}

class _SkulMateRerouteNudgeState extends State<SkulMateRerouteNudge> {
  RerouteSuggestion? _suggestion;
  bool _loading = true;
  bool _hidden = false;
  bool _markedShown = false;

  @override
  void initState() {
    super.initState();
    _evaluate();
  }

  @override
  void didUpdateWidget(SkulMateRerouteNudge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.games != widget.games) _evaluate();
  }

  Future<void> _evaluate() async {
    try {
      final dueCount =
          await SpacedRepetitionService.dueCountToday(childId: widget.childId);
      if (dueCount > 0) {
        if (!mounted) return;
        setState(() {
          _suggestion = null;
          _loading = false;
        });
        return;
      }

      final suggestion = await RerouteSuggestionService.evaluate(
        games: widget.games,
        childId: widget.childId,
      );
      if (!mounted) return;
      setState(() {
        _suggestion = suggestion;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _suggestion = null;
        _loading = false;
      });
    }
  }

  Future<void> _dismiss() async {
    final topicId = _suggestion?.topicId;
    if (topicId != null) {
      await RerouteSuggestionService.dismiss(topicId);
    }
    if (mounted) setState(() => _hidden = true);
  }

  void _openGame() {
    final id = _suggestion?.gameId;
    if (id == null) return;
    GameModel? game;
    for (final g in widget.games) {
      if (g.id == id) {
        game = g;
        break;
      }
    }
    if (game == null) return;
    SkulMateGameRouter.open(context, game);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _hidden || _suggestion == null) {
      return const SizedBox.shrink();
    }

    if (!_markedShown) {
      _markedShown = true;
      RerouteSuggestionService.markShown(_suggestion!.topicId);
    }

    final copy = SkulMateCopy.of(context);
    final title = _suggestion!.gameTitle;

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _openGame,
          borderRadius: BorderRadius.circular(14),
          child: Ink(
            decoration: SkulMateSurfaceStyles.homeCard(radius: 14, compact: true),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(
                  Icons.replay_rounded,
                  size: 20,
                  color: AppTheme.primaryColor.withValues(alpha: 0.85),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        copy.rerouteNudgeLead,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textMedium,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textDark,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: _openGame,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    copy.rerouteNudgeAction,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _dismiss,
                  icon: const Icon(Icons.close, size: 18),
                  color: AppTheme.textMedium,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  tooltip: copy.rerouteNudgeDismiss,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
