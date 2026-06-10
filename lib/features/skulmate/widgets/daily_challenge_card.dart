import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/core/widgets/premium_promo_card_shell.dart';
import 'package:prepskul/features/skulmate/models/game_model.dart';
import 'package:prepskul/features/skulmate/services/daily_challenge_service.dart';
import 'package:shimmer/shimmer.dart';

/// Card for "Today's Challenge" – one focused set per day. User-specific (or child-specific).
class DailyChallengeCard extends StatefulWidget {
  final List<GameModel> games;
  final String? childId;
  final int? currentStreak;
  final bool compact;
  final VoidCallback onRefresh;
  final void Function(GameModel game, {bool isDailyChallenge}) onPlay;

  const DailyChallengeCard({
    super.key,
    required this.games,
    this.childId,
    this.currentStreak,
    this.compact = false,
    required this.onRefresh,
    required this.onPlay,
  });

  @override
  State<DailyChallengeCard> createState() => _DailyChallengeCardState();
}

class _DailyChallengeCardState extends State<DailyChallengeCard> {
  bool _completedToday = false;
  int _dailyStreak = 0;
  bool _loading = true;
  bool _hiddenToday = false;
  GameModel? _todayGame;

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  Future<void> _loadState() async {
    setState(() => _loading = true);
    final completed = await DailyChallengeService.isCompletedToday(
      childId: widget.childId,
    );
    final streak = await DailyChallengeService.getDailyStreak(
      childId: widget.childId,
    );
    final hidden = await DailyChallengeService.isHiddenToday(
      childId: widget.childId,
    );
    final todayGame = await DailyChallengeService.getTodayChallengeGame(
      widget.games,
      childId: widget.childId,
    );
    if (mounted) {
      setState(() {
        _completedToday = completed;
        _dailyStreak = streak;
        _hiddenToday = hidden;
        _todayGame = todayGame;
        _loading = false;
      });
    }
  }

  Future<void> _dismissForToday() async {
    await DailyChallengeService.hideForToday(childId: widget.childId);
    if (mounted) {
      setState(() => _hiddenToday = true);
    }
    widget.onRefresh();
  }

  @override
  void didUpdateWidget(DailyChallengeCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.games != widget.games) _loadState();
  }

  @override
  Widget build(BuildContext context) {
    final cardHeight = widget.compact ? 88.0 : 108.0;
    final outerPadding = widget.compact
        ? EdgeInsets.zero
        : const EdgeInsets.fromLTRB(16, 8, 16, 12);

    if (_loading) {
      return Container(
        margin: outerPadding,
        height: cardHeight,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.softBorder),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child: Shimmer.fromColors(
            baseColor: AppTheme.neutral200,
            highlightColor: Colors.white,
            period: const Duration(milliseconds: 1200),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          height: 14,
                          width: 160,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          height: 12,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final todayGame = _todayGame;
    final hasChallenge = todayGame != null;

    if (_completedToday && _hiddenToday) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: outerPadding,
      child: PremiumPromoCardShell(
        height: cardHeight,
        radius: 16,
        accent: AppTheme.skyBlue,
        padding: EdgeInsets.all(widget.compact ? 12 : 14),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: hasChallenge && !_completedToday
                ? () => widget.onPlay(todayGame, isDailyChallenge: true)
                : null,
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  right: -18,
                  top: -18,
                  child: CircleAvatar(
                    radius: 44,
                    backgroundColor: Colors.white.withValues(alpha: 0.06),
                  ),
                ),
                Row(
                  children: [
                    Container(
                      width: widget.compact ? 44 : 48,
                      height: widget.compact ? 44 : 48,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        _completedToday
                            ? Icons.check_circle_rounded
                            : Icons.today_rounded,
                        size: widget.compact ? 22 : 26,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(width: widget.compact ? 10 : 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _completedToday
                                ? 'Done for today'
                                : 'Today\'s Challenge',
                            style: GoogleFonts.poppins(
                              fontSize: widget.compact ? 14 : 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            hasChallenge
                                ? (_completedToday
                                    ? 'Come back tomorrow for a new challenge.'
                                    : todayGame.title)
                                : 'Create a quiz to unlock daily challenges.',
                            style: GoogleFonts.poppins(
                              fontSize: widget.compact ? 11 : 13,
                              color: Colors.white.withValues(alpha: 0.95),
                              height: 1.25,
                            ),
                            maxLines: widget.compact ? 1 : 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (_dailyStreak > 0 && !widget.compact) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(
                                  Icons.local_fire_department,
                                  size: 16,
                                  color: Colors.amber[200],
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '$_dailyStreak day streak',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.amber[100],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (hasChallenge && !_completedToday)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primaryColor.withValues(alpha: 0.12),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          'Play',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ),
                  ],
                ),
                if (_completedToday)
                  Positioned(
                    top: -10,
                    right: -10,
                    child: IconButton(
                      tooltip: 'Hide for today',
                      icon: Icon(
                        Icons.close_rounded,
                        color: Colors.white.withValues(alpha: 0.92),
                      ),
                      onPressed: _dismissForToday,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
