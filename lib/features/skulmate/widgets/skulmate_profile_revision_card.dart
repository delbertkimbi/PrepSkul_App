import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:prepskul/core/theme/app_theme.dart';

import '../l10n/skulmate_copy.dart';
import '../models/game_stats_model.dart';
import '../screens/skulmate_games_screen.dart';
import '../screens/skulmate_plans_screen.dart';
import '../services/game_stats_service.dart';
import '../services/skulmate_credits_service.dart';
import 'skulmate_surface_styles.dart';

/// Revision stats on Profile — white card, color on icons & buttons only.
class SkulMateProfileRevisionCard extends StatefulWidget {
  const SkulMateProfileRevisionCard({super.key});

  @override
  State<SkulMateProfileRevisionCard> createState() =>
      _SkulMateProfileRevisionCardState();
}

class _SkulMateProfileRevisionCardState
    extends State<SkulMateProfileRevisionCard> {
  GameStats? _stats;
  int _credits = 0;
  String? _planTier;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final stats = await GameStatsService.getStats();
    final credits = await SkulmateCreditsService.fetchBalance();
    final tier = await SkulmateCreditsService.fetchActivePlanTier();
    if (mounted) {
      setState(() {
        _stats = stats;
        _credits = credits;
        _planTier = tier;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final copy = SkulMateCopy.of(context);
    final stats = _stats ?? GameStats.empty();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: SkulMateSurfaceStyles.homeCard(radius: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              PhosphorIcon(
                PhosphorIcons.sparkleFill,
                color: AppTheme.primaryColor,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  copy.profileRevisionSection,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textDark,
                  ),
                ),
              ),
              if (_planTier != null) _planTierBadge(_planTier!),
            ],
          ),
          if (_credits > 0) ...[
            const SizedBox(height: 6),
            Text(
              copy.paywallCreditsBalance(_credits),
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: AppTheme.textMedium,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              _miniStat(copy.progressStreakLabel, '${stats.currentStreak}'),
              _miniStat('XP', '${stats.totalXP}'),
              _miniStat(copy.progressGamesLabel, '${stats.gamesPlayed}'),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const SkulMateGamesScreen(),
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.textDark,
                    side: BorderSide(
                      color: AppTheme.softBorder.withValues(alpha: 0.95),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    copy.profileViewGames,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const SkulmatePlansScreen(),
                      ),
                    ).then((_) => _load());
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    copy.profileCreditsCta,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _planTierBadge(String tier) {
    final isPro = tier.toLowerCase() == 'pro';
    final isElite = tier.toLowerCase() == 'elite';
    final color = isPro || isElite
        ? const Color(0xFFC9A227)
        : AppTheme.primaryColor;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        tier,
        style: GoogleFonts.poppins(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _miniStat(String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppTheme.primaryColor,
            ),
          ),
          Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: AppTheme.textMedium,
            ),
          ),
        ],
      ),
    );
  }
}
