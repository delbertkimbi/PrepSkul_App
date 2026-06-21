import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/core/utils/safe_set_state.dart';

import '../l10n/skulmate_copy.dart';
import '../models/game_model.dart';
import '../models/next_stop_suggestion.dart';
import '../models/reroute_suggestion.dart';
import '../screens/game_generation_screen.dart';
import '../services/next_stop_service.dart';
import '../services/session_route_service.dart';
import '../utils/skulmate_game_router.dart';

/// Maps M2 — single "what's next" card (due → weak → continue).
class SkulMateNextStopCard extends StatefulWidget {
  final List<GameModel> games;
  final String? childId;

  const SkulMateNextStopCard({
    super.key,
    required this.games,
    this.childId,
  });

  @override
  State<SkulMateNextStopCard> createState() => _SkulMateNextStopCardState();
}

class _SkulMateNextStopCardState extends State<SkulMateNextStopCard> {
  NextStopSuggestion? _suggestion;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _evaluate();
  }

  @override
  void didUpdateWidget(SkulMateNextStopCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.games != widget.games) _evaluate();
  }

  Future<void> _evaluate() async {
    safeSetState(() => _loading = true);
    final suggestion = await NextStopService.evaluate(
      games: widget.games,
      childId: widget.childId,
    );
    safeSetState(() {
      _suggestion = suggestion;
      _loading = false;
    });
  }

  Future<void> _onDismiss() async {
    final s = _suggestion;
    if (s == null) return;
    await NextStopService.dismiss(s);
    safeSetState(() => _suggestion = null);
  }

  Future<void> _onStart(SkulMateCopy copy) async {
    final s = _suggestion;
    if (s == null) return;

    if (s.kind == NextStopKind.fromSession) {
      final sessionId = s.sessionId;
      if (sessionId != null) {
        await SessionRouteService.dismiss(sessionId);
      }
      final summary = s.sessionSummary?.trim() ?? s.subtitle ?? '';
      if (!mounted || summary.isEmpty) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => GameGenerationScreen(
            text: summary,
            topic: s.title,
            gameType: 'flashcards',
          ),
        ),
      );
      if (mounted) _evaluate();
      return;
    }

    GameModel? game;
    for (final g in widget.games) {
      if (g.id == s.gameId) {
        game = g;
        break;
      }
    }
    if (game == null || !mounted) return;

    if (s.kind == NextStopKind.weakTopic && s.topicId != null) {
      await NextStopService.markWeakShown(
        RerouteSuggestion(
          topicId: s.topicId!,
          gameId: s.gameId,
          gameTitle: s.title,
        ),
      );
    }

    if (!mounted) return;
    await SkulMateGameRouter.open(context, game);
    if (mounted) _evaluate();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _suggestion == null) return const SizedBox.shrink();

    final copy = SkulMateCopy.of(context);
    final s = _suggestion!;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppTheme.primaryColor.withValues(alpha: 0.08),
              AppTheme.primaryColor.withValues(alpha: 0.03),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppTheme.primaryColor.withValues(alpha: 0.22),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              PhosphorIcons.mapPin(),
              color: AppTheme.primaryColor,
              size: 22,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    copy.nextStopTitle,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryColor,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    copy.nextStopHeadline(s),
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textDark,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (s.subtitle != null && s.subtitle!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      s.subtitle!,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: AppTheme.textMedium,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => _onStart(copy),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      foregroundColor: AppTheme.primaryColor,
                    ),
                    child: Text(
                      copy.nextStopCta(s.kind),
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(
                Icons.close,
                size: 18,
                color: AppTheme.textMedium,
              ),
              onPressed: _onDismiss,
              tooltip: copy.rerouteNudgeDismiss,
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),
    );
  }
}
