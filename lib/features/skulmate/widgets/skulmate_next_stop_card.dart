import 'package:flutter/material.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/core/utils/safe_set_state.dart';

import '../l10n/skulmate_copy.dart';
import '../models/game_model.dart';
import '../models/next_stop_suggestion.dart';
import '../models/reroute_suggestion.dart';
import '../services/next_stop_service.dart';
import '../services/session_route_service.dart';
import '../services/skulmate_intake_coordinator.dart';
import '../utils/skulmate_game_router.dart';
import 'skulmate_mascot_media_widget.dart';
import 'skulmate_surface_styles.dart';
import 'skulmate_typography.dart';

/// Single friendly "pick up where you left off" card — only when truly resumable.
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
    try {
      final suggestion = await NextStopService.evaluate(
        games: widget.games,
        childId: widget.childId,
      );
      safeSetState(() {
        _suggestion = suggestion;
        _loading = false;
      });
    } catch (_) {
      safeSetState(() {
        _suggestion = null;
        _loading = false;
      });
    }
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
    await NextStopService.dismiss(s);
    safeSetState(() => _suggestion = null);

    if (s.kind == NextStopKind.fromSession) {
      final sessionId = s.sessionId;
      if (sessionId != null) {
        await SessionRouteService.dismiss(sessionId);
      }
      final summary = s.sessionSummary?.trim() ?? s.subtitle ?? '';
      if (!mounted || summary.isEmpty) return;
      await SkulMateIntakeCoordinator.startFromSessionSummary(
        context,
        summary: summary,
        topicHint: s.title,
        childId: widget.childId,
      );
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
  }

  Color _accentFor(NextStopKind kind) {
    switch (kind) {
      case NextStopKind.continueGame:
        return AppTheme.skyBlue;
      case NextStopKind.dueReview:
        return AppTheme.accentGreen;
      case NextStopKind.weakTopic:
        return AppTheme.accentOrange;
      case NextStopKind.fromSession:
        return AppTheme.accentPurple;
    }
  }

  String? _progressLine(NextStopSuggestion s) {
    if (s.kind != NextStopKind.continueGame) return s.subtitle;
    if (s.currentIndex != null &&
        s.totalItems != null &&
        s.totalItems! > 0) {
      return 'Question ${s.currentIndex! + 1} of ${s.totalItems}';
    }
    return s.subtitle;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _suggestion == null) return const SizedBox.shrink();

    final copy = SkulMateCopy.of(context);
    final s = _suggestion!;
    final accent = _accentFor(s.kind);
    final progressLine = _progressLine(s);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius:
              BorderRadius.circular(SkulMateSurfaceStyles.homeCardRadius),
          onTap: () => _onStart(copy),
          child: Ink(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius:
                  BorderRadius.circular(SkulMateSurfaceStyles.homeCardRadius),
              border: Border.all(color: accent.withValues(alpha: 0.45)),
              boxShadow: SkulMateSurfaceStyles.homeCardShadow(compact: true),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
              child: Row(
                children: [
                  SizedBox(
                    width: 40,
                    height: 40,
                    child: SkulMateMascotMediaWidget(
                      state: SkulMateMascotState.encouraging,
                      width: 40,
                      height: 40,
                      showFrame: false,
                      preferStaticImage: true,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.route_rounded,
                              size: 14,
                              color: accent,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              copy.nextStopTitle,
                              style: SkulMateTypography.nextStopEyebrow(
                                color: accent,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          copy.nextStopHeadline(s),
                          style: SkulMateTypography.cardTitle(size: 14),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (progressLine != null &&
                            progressLine.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            progressLine,
                            style: SkulMateTypography.cardMeta(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: accent.withValues(alpha: 0.25),
                            ),
                          ),
                          child: Text(
                            copy.nextStopCta(s.kind),
                            style: SkulMateTypography.chipLabel(color: accent),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: AppTheme.textMedium.withValues(alpha: 0.8),
                    ),
                    onPressed: _onDismiss,
                    tooltip: copy.rerouteNudgeDismiss,
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
