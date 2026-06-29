import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:table_calendar/table_calendar.dart';

import '../l10n/skulmate_copy.dart';
import '../models/game_stats_model.dart';
import '../services/game_stats_service.dart';
import '../services/learner_topic_progress_service.dart';
import '../services/skulmate_service.dart';
import '../screens/skulmate_games_screen.dart';
import '../widgets/skulmate_loading_skeletons.dart';
import '../widgets/skulmate_surface_styles.dart';

/// Full-screen learner progress: streak hero, activity calendar, topic mastery.
class SkulMateProgressScreen extends StatefulWidget {
  final String? childId;

  const SkulMateProgressScreen({super.key, this.childId});

  @override
  State<SkulMateProgressScreen> createState() => _SkulMateProgressScreenState();
}

class _SkulMateProgressScreenState extends State<SkulMateProgressScreen> {
  GameStats? _stats;
  List<LearnerTopicProgress> _topics = [];
  Map<DateTime, int> _activityByDate = {};
  bool _loading = true;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime.now();
    _load();
  }

  Future<void> _load() async {
    final copy = SkulMateCopy.read(context);
    final results = await Future.wait([
      GameStatsService.getStats(),
      LearnerTopicProgressService.fetchTopics(
        childId: widget.childId,
        french: copy.isFrench,
      ),
      SkulMateService.getActivityByDate(childId: widget.childId),
    ]);
    if (!mounted) return;
    setState(() {
      _stats = results[0] as GameStats;
      _topics = results[1] as List<LearnerTopicProgress>;
      _activityByDate = results[2] as Map<DateTime, int>;
      _loading = false;
    });
  }

  int _sessionsOnDay(DateTime day) {
    for (final entry in _activityByDate.entries) {
      if (isSameDay(entry.key, day)) return entry.value;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final copy = SkulMateCopy.of(context);
    final stats = _stats ?? GameStats.empty();
    final now = DateTime.now();
    final firstDay = DateTime(now.year - 1, now.month, now.day);
    final lastDay = DateTime(now.year, now.month, now.day);

    return Scaffold(
      backgroundColor: AppTheme.softBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.softBackground,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.textDark),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          copy.myProgressTitle,
          style: GoogleFonts.poppins(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: AppTheme.textDark,
          ),
        ),
        centerTitle: true,
      ),
      body: _loading
          ? SkulMateLoadingSkeletons.progressScreen()
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                children: [
                  _StreakHeroCard(stats: stats, copy: copy),
                  const SizedBox(height: 14),
                  _XpLevelCard(stats: stats, copy: copy),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _MiniStatCard(
                          icon: Icons.sports_esports_outlined,
                          label: copy.progressGamesLabel,
                          value: '${stats.gamesPlayed}',
                          subtitle: copy.progressAccuracy(stats.accuracy),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _MiniStatCard(
                          icon: Icons.bolt_rounded,
                          label: copy.progressXpLabel,
                          value: '${stats.totalXP}',
                          subtitle: copy.progressLevelLabel(stats.level),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    copy.progressActivityTitle,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textDark,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    decoration: SkulMateSurfaceStyles.homeCard(radius: 16),
                    child: TableCalendar(
                      firstDay: firstDay,
                      lastDay: lastDay,
                      focusedDay: _focusedDay.isBefore(firstDay)
                          ? firstDay
                          : _focusedDay.isAfter(lastDay)
                              ? lastDay
                              : _focusedDay,
                      selectedDayPredicate: (day) =>
                          _selectedDay != null && isSameDay(_selectedDay!, day),
                      onDaySelected: (selectedDay, focusedDay) {
                        setState(() {
                          _selectedDay = selectedDay;
                          _focusedDay = focusedDay;
                        });
                      },
                      onPageChanged: (focusedDay) {
                        setState(() => _focusedDay = focusedDay);
                      },
                      eventLoader: (day) {
                        final count = _sessionsOnDay(day);
                        return count > 0 ? List.filled(count.clamp(1, 3), 'game') : [];
                      },
                      calendarFormat: CalendarFormat.month,
                      availableCalendarFormats: const {
                        CalendarFormat.month: 'Month',
                      },
                      headerStyle: HeaderStyle(
                        formatButtonVisible: false,
                        titleCentered: true,
                        titleTextStyle: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textDark,
                        ),
                        leftChevronIcon: const Icon(
                          Icons.chevron_left_rounded,
                          color: AppTheme.textDark,
                        ),
                        rightChevronIcon: const Icon(
                          Icons.chevron_right_rounded,
                          color: AppTheme.textDark,
                        ),
                      ),
                      calendarStyle: CalendarStyle(
                        outsideDaysVisible: false,
                        todayDecoration: BoxDecoration(
                          color: AppTheme.skyBlue.withValues(alpha: 0.35),
                          shape: BoxShape.circle,
                        ),
                        todayTextStyle: GoogleFonts.poppins(
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textDark,
                        ),
                        selectedDecoration: const BoxDecoration(
                          color: AppTheme.primaryColor,
                          shape: BoxShape.circle,
                        ),
                        selectedTextStyle: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                        markerSize: 5,
                        markerMargin: const EdgeInsets.symmetric(horizontal: 0.5),
                        markersMaxCount: 3,
                        markerDecoration: BoxDecoration(
                          color: AppTheme.primaryColor.withValues(alpha: 0.75),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                  if (_selectedDay != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      copy.progressSessionsOnDay(_sessionsOnDay(_selectedDay!)),
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: AppTheme.textMedium,
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
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
                    ..._topics.map((t) => _TopicTile(copy: copy, topic: t)),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                SkulMateGamesScreen(childId: widget.childId),
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
                ],
              ),
            ),
    );
  }
}

class _StreakHeroCard extends StatelessWidget {
  final GameStats stats;
  final SkulMateCopy copy;

  const _StreakHeroCard({required this.stats, required this.copy});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
      decoration: BoxDecoration(
        gradient: AppTheme.stitchYellowGradient,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.55),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.local_fire_department_rounded,
              size: 36,
              color: Colors.orange.shade700,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  copy.progressStreakLabel,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textDark.withValues(alpha: 0.75),
                  ),
                ),
                Text(
                  '${stats.currentStreak}',
                  style: GoogleFonts.poppins(
                    fontSize: 40,
                    fontWeight: FontWeight.w800,
                    height: 1,
                    color: AppTheme.textDark,
                  ),
                ),
                Text(
                  copy.progressBestStreak(stats.bestStreak),
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: AppTheme.textDark.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _XpLevelCard extends StatelessWidget {
  final GameStats stats;
  final SkulMateCopy copy;

  const _XpLevelCard({required this.stats, required this.copy});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: SkulMateSurfaceStyles.homeCard(radius: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                copy.progressLevelLabel(stats.level),
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textDark,
                ),
              ),
              const Spacer(),
              Text(
                '${stats.totalXP} XP',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: stats.levelProgress,
              minHeight: 8,
              backgroundColor: AppTheme.neutral200,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            copy.progressXpToNext(stats.xpForNextLevel),
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

class _MiniStatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? subtitle;

  const _MiniStatCard({
    required this.icon,
    required this.label,
    required this.value,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: SkulMateSurfaceStyles.homeCard(radius: 14),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.primaryColor, size: 20),
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
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textDark,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
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

class _TopicTile extends StatelessWidget {
  final SkulMateCopy copy;
  final LearnerTopicProgress topic;

  const _TopicTile({required this.copy, required this.topic});

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

  @override
  Widget build(BuildContext context) {
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
}
