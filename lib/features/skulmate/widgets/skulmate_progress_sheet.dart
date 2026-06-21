import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';

import '../l10n/skulmate_copy.dart';
import '../models/game_stats_model.dart';
import '../services/game_stats_service.dart';
import '../services/learner_topic_progress_service.dart';
import '../screens/skulmate_games_screen.dart';
import 'skulmate_sheet_scaffold.dart';
import 'skulmate_surface_styles.dart';

/// Learner revision stats + topic mastery map (Maps M1 — Where am I?).
class SkulMateProgressSheet extends StatefulWidget {
  final String? childId;

  const SkulMateProgressSheet({super.key, this.childId});

  static Future<void> show(BuildContext context, {String? childId}) {
    return SkulMateSheetScaffold.show<void>(
      context,
      child: SkulMateProgressSheet(childId: childId),
    );
  }

  @override
  State<SkulMateProgressSheet> createState() => _SkulMateProgressSheetState();
}

class _SkulMateProgressSheetState extends State<SkulMateProgressSheet> {
  GameStats? _stats;
  List<LearnerTopicProgress> _topics = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final results = await Future.wait([
      GameStatsService.getStats(),
      LearnerTopicProgressService.fetchTopics(
        childId: widget.childId,
        french: SkulMateCopy.read(context).isFrench,
      ),
    ]);
    if (mounted) {
      setState(() {
        _stats = results[0] as GameStats;
        _topics = results[1] as List<LearnerTopicProgress>;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final copy = SkulMateCopy.of(context);
    final stats = _stats ?? GameStats.empty();

    return SkulMateSheetScaffold(
      title: copy.myProgressTitle,
      showWandIcon: false,
      maxHeightFactor: 0.72,
      body: _loading
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _statTile(
                    Icons.bolt_rounded,
                    copy.progressXpLabel,
                    '${stats.totalXP} XP',
                    subtitle: copy.progressLevelLabel(stats.level),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _statTile(
                          Icons.local_fire_department_rounded,
                          copy.progressStreakLabel,
                          '${stats.currentStreak}',
                          subtitle: copy.progressBestStreak(stats.bestStreak),
                          compact: true,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _statTile(
                          Icons.sports_esports_outlined,
                          copy.progressGamesLabel,
                          '${stats.gamesPlayed}',
                          subtitle: copy.progressAccuracy(stats.accuracy),
                          compact: true,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    copy.progressTopicsTitle,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textDark,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_topics.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: SkulMateSurfaceStyles.homeCard(radius: 12),
                      child: Text(
                        copy.progressTopicsEmpty,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: AppTheme.textMedium,
                          height: 1.4,
                        ),
                      ),
                    )
                  else
                    ..._topics.map((t) => _topicTile(copy, t)),
                ],
              ),
            ),
      footer: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SkulMateGamesScreen(childId: widget.childId),
              ),
            );
          },
          style: SkulMateSurfaceStyles.sheetPrimaryButton(),
          child: Text(
            copy.myGames,
            style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _topicTile(SkulMateCopy copy, LearnerTopicProgress topic) {
    final color = _bandColor(topic.band);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: SkulMateSurfaceStyles.homeCard(radius: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  topic.label,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textDark,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '${topic.masteryPercent}%',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: topic.masteryPercent / 100,
              minHeight: 6,
              backgroundColor: AppTheme.neutral200,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            copy.progressMasteryBandLabel(topic.band),
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: AppTheme.textMedium,
            ),
          ),
        ],
      ),
    );
  }

  Color _bandColor(String band) {
    switch (band) {
      case 'solid':
        return AppTheme.accentGreen;
      case 'building':
        return AppTheme.primaryColor;
      default:
        return Colors.orange.shade700;
    }
  }

  Widget _statTile(
    IconData icon,
    String label,
    String value, {
    String? subtitle,
    bool compact = false,
  }) {
    return Container(
      padding: EdgeInsets.all(compact ? 12 : 14),
      decoration: SkulMateSurfaceStyles.homeCard(radius: 14),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.primaryColor, size: compact ? 20 : 24),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: AppTheme.textMedium,
                  ),
                ),
                Text(
                  value,
                  style: GoogleFonts.poppins(
                    fontSize: compact ? 16 : 18,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textDark,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: AppTheme.textMedium,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
