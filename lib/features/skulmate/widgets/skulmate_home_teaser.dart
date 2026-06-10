import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/features/skulmate/models/game_model.dart';
import 'package:prepskul/features/skulmate/services/daily_challenge_service.dart';
import 'package:prepskul/features/skulmate/widgets/skulmate_surface_styles.dart';

/// Compact daily SkulMate challenge teaser for the home screen.
class SkulMateHomeTeaser extends StatefulWidget {
  final List<GameModel> games;
  final String? childId;
  final void Function(GameModel game, {bool isDailyChallenge}) onPlay;
  final VoidCallback? onOpenLibrary;

  const SkulMateHomeTeaser({
    super.key,
    required this.games,
    this.childId,
    required this.onPlay,
    this.onOpenLibrary,
  });

  @override
  State<SkulMateHomeTeaser> createState() => _SkulMateHomeTeaserState();
}

class _SkulMateHomeTeaserState extends State<SkulMateHomeTeaser> {
  bool _loading = true;
  bool _completed = false;
  bool _hidden = false;
  int _streak = 0;
  GameModel? _todayGame;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(SkulMateHomeTeaser oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.games != widget.games) _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final completed = await DailyChallengeService.isCompletedToday(childId: widget.childId);
    final hidden = await DailyChallengeService.isHiddenToday(childId: widget.childId);
    final streak = await DailyChallengeService.getDailyStreak(childId: widget.childId);
    final today = await DailyChallengeService.getTodayChallengeGame(
      widget.games,
      childId: widget.childId,
    );
    if (mounted) {
      setState(() {
        _completed = completed;
        _hidden = hidden;
        _streak = streak;
        _todayGame = today;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Container(
        height: 120,
        decoration: BoxDecoration(
          color: AppTheme.neutral100,
          borderRadius: BorderRadius.circular(16),
        ),
      );
    }

    if (_completed && _hidden) return const SizedBox.shrink();

    final hasGame = _todayGame != null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: hasGame && !_completed
            ? () => widget.onPlay(_todayGame!, isDailyChallenge: true)
            : widget.onOpenLibrary,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: SkulMateSurfaceStyles.heroNeumorphic(radius: 16),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        _completed ? Icons.check_circle_rounded : Icons.bolt_rounded,
                        color: Colors.white,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _completed ? 'Daily challenge complete' : 'SkulMate daily game',
                            style: GoogleFonts.poppins(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            hasGame
                                ? (_completed
                                    ? 'Nice work — streak saved for today'
                                    : _todayGame!.title)
                                : 'Open SkulMate to play or create a quiz',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    if (_streak > 0) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.local_fire_department, size: 14, color: Colors.amber[200]),
                            const SizedBox(width: 3),
                            Text(
                              '$_streak',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
                if (hasGame && !_completed) ...[
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => widget.onPlay(_todayGame!, isDailyChallenge: true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppTheme.primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Play today\'s game',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ] else if (widget.onOpenLibrary != null) ...[
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: widget.onOpenLibrary,
                      child: Text(
                        'Browse games',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
