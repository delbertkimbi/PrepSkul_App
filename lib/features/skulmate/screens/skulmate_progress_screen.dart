import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/core/utils/safe_set_state.dart';

import '../l10n/skulmate_copy.dart';
import '../models/game_model.dart';
import '../models/game_stats_model.dart';
import '../services/daily_challenge_service.dart';
import '../services/game_stats_service.dart';
import '../services/skulmate_service.dart';
import '../widgets/skulmate_continue_row.dart';
import '../widgets/skulmate_surface_styles.dart';
import 'friends_screen.dart';
import 'leaderboard_screen.dart';

/// Progress tab MVP: XP, streak, continue, leaderboard links.
class SkulMateProgressScreen extends StatefulWidget {
  final String? childId;

  const SkulMateProgressScreen({super.key, this.childId});

  @override
  State<SkulMateProgressScreen> createState() => _SkulMateProgressScreenState();
}

class _SkulMateProgressScreenState extends State<SkulMateProgressScreen> {
  GameStats? _stats;
  int _streak = 0;
  List<GameModel> _games = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        GameStatsService.getStats(),
        DailyChallengeService.getDailyStreak(childId: widget.childId),
        SkulMateService.getGames(childId: widget.childId),
      ]);
      if (mounted) {
        safeSetState(() {
          _stats = results[0] as GameStats;
          _streak = results[1] as int;
          _games = results[2] as List<GameModel>;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) safeSetState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final copy = SkulMateCopy.of(context);

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final stats = _stats ?? GameStats.empty();
    final levelProgress = stats.levelProgress;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: SkulMateSurfaceStyles.heroNeumorphic(radius: 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  copy.isFrench ? 'Niveau ${stats.level}' : 'Level ${stats.level}',
                  style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: levelProgress.clamp(0.0, 1.0),
                    minHeight: 8,
                    backgroundColor: Colors.white24,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${stats.totalXP} XP',
                  style: GoogleFonts.poppins(
                    color: Colors.white70,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  label: copy.isFrench ? 'Série' : 'Streak',
                  value: '$_streak',
                  icon: Icons.local_fire_department_rounded,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  label: copy.isFrench ? 'Jeux' : 'Games',
                  value: '${stats.gamesPlayed}',
                  icon: Icons.videogame_asset_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SkulMateContinueRow(games: _games),
          const SizedBox(height: 24),
          _LinkTile(
            icon: Icons.emoji_events_outlined,
            label: copy.isFrench ? 'Classement' : 'Leaderboard',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const LeaderboardScreen()),
            ),
          ),
          _LinkTile(
            icon: Icons.people_outline,
            label: copy.isFrench ? 'Amis' : 'Friends',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const FriendsScreen()),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: SkulMateSurfaceStyles.neumorphicCard(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppTheme.primaryColor, size: 22),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: AppTheme.textDark,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: AppTheme.textMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _LinkTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _LinkTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.softBorder),
            ),
            child: Row(
              children: [
                Icon(icon, color: AppTheme.primaryColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppTheme.textMedium),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
