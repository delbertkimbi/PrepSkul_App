import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:confetti/confetti.dart';
import 'package:share_plus/share_plus.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/core/utils/safe_set_state.dart';
import 'dart:math';
import '../models/game_model.dart';
import '../models/game_stats_model.dart';
import '../services/game_sound_service.dart';
import '../services/game_stats_service.dart';
import 'game_library_screen.dart';
import 'quiz_game_screen.dart';

/// Screen showing game results and performance summary
class GameResultsScreen extends StatefulWidget {
  final GameModel game;
  final int score;
  final int totalQuestions;
  final int? timeTakenSeconds;
  final int? xpEarned;
  final bool isPerfectScore;
  final List<QuestionPerformance> questionBreakdown;

  const GameResultsScreen({
    Key? key,
    required this.game,
    required this.score,
    required this.totalQuestions,
    this.timeTakenSeconds,
    this.xpEarned,
    this.isPerfectScore = false,
    this.questionBreakdown = const [],
  }) : super(key: key);

  @override
  State<GameResultsScreen> createState() => _GameResultsScreenState();
}

class _GameResultsScreenState extends State<GameResultsScreen> {
  late ConfettiController _confettiController;
  final GameSoundService _soundService = GameSoundService();
  GameStats? _currentStats;  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
    _soundService.initialize();
    _loadStats();
    
    if (widget.isPerfectScore) {
      _confettiController.play();
      _soundService.playComplete();
    }
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  Future<void> _loadStats() async {
    final stats = await GameStatsService.getStats();
    safeSetState(() => _currentStats = stats);
  }

  @override
  Widget build(BuildContext context) {
    final percentage = (widget.score / widget.totalQuestions * 100).round();
    final timeText = widget.timeTakenSeconds != null
        ? '${widget.timeTakenSeconds! ~/ 60}:${(widget.timeTakenSeconds! % 60).toString().padLeft(2, '0')}'
        : 'N/A';

    return Scaffold(
      backgroundColor: AppTheme.softBackground,
      appBar: AppBar(
        title: Text('Results', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  widget.isPerfectScore ? '🎉 Perfect!' : 'Done!',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: widget.isPerfectScore ? AppTheme.accentGreen : AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(height: 12),
                // Score: percentage + fraction
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '$percentage%',
                      style: GoogleFonts.poppins(
                        fontSize: 36,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${widget.score}/${widget.totalQuestions}',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: AppTheme.textMedium,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Stats grid - 2x2 or 2x3 layout
                LayoutBuilder(
                  builder: (context, constraints) {
                    final statCards = <Widget>[
                      _buildCompactStat('Time', timeText, Icons.timer_outlined),
                      if (widget.xpEarned != null)
                        _buildCompactStat('XP', '+${widget.xpEarned}', Icons.star_outline),
                      if (_currentStats != null) ...[
                        _buildCompactStat('Total XP', '${_currentStats!.totalXP}', Icons.emoji_events_outlined),
                        _buildCompactStat('Level', '${_currentStats!.level}', Icons.military_tech),
                        _buildCompactStat('Streak', '${_currentStats!.currentStreak}d', Icons.local_fire_department_outlined),
                      ],
                    ];
                    return GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 1.8,
                      children: statCards,
                    );
                  },
                ),
                if (_currentStats != null && _currentStats!.currentStreak > 0) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppTheme.softYellowLight,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.softYellow.withOpacity(0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('🔥', style: TextStyle(fontSize: 18)),
                        const SizedBox(width: 6),
                        Text(
                          '${_currentStats!.currentStreak} day streak!',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                // Strongest / weakest topics (based on per-question performance)
                if (widget.questionBreakdown.isNotEmpty) ...[
                  const SizedBox(height: 28),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'What you did well',
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textDark,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildQuestionList(
                    widget.questionBreakdown.where((q) => q.isCorrect).toList(),
                    emptyLabel: 'We will highlight wins here when you get some questions correct.',
                  ),
                  const SizedBox(height: 20),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'What to review',
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textDark,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildQuestionList(
                    widget.questionBreakdown.where((q) => !q.isCorrect).toList(),
                    emptyLabel: 'No weak spots in this round – great job.',
                  ),
                ],
                const SizedBox(height: 28),
                if (widget.game.gameType == GameType.quiz && !widget.isPerfectScore) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      children: [
                        TextButton.icon(
                          onPressed: () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (context) => QuizGameScreen(game: widget.game),
                              ),
                            );
                          },
                          icon: Icon(Icons.refresh, size: 18, color: AppTheme.accentBlue),
                          label: Text('Try Again', style: GoogleFonts.poppins(color: AppTheme.accentBlue, fontWeight: FontWeight.w500)),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) => GameLibraryScreen(childId: null),
                          ),
                        );
                      },
                      icon: const Icon(Icons.home, size: 18),
                      label: const Text('Home'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      ),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: () {
                        Share.share(
                          'I scored $percentage% on ${widget.game.title}! 🎮',
                        );
                      },
                      icon: const Icon(Icons.share, size: 18),
                      label: const Text('Share'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primaryColor,
                        side: const BorderSide(color: AppTheme.primaryColor),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirection: pi / 2,
              maxBlastForce: 5,
              minBlastForce: 2,
              emissionFrequency: 0.05,
              numberOfParticles: 50,
              gravity: 0.1,
              colors: const [
                AppTheme.primaryColor,
                AppTheme.skyBlue,
                AppTheme.softYellow,
                AppTheme.accentGreen,
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactStat(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.softCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.softBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: AppTheme.primaryColor),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: AppTheme.textMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppTheme.textDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionList(
    List<QuestionPerformance> items, {
    required String emptyLabel,
  }) {
    if (items.isEmpty) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Text(
          emptyLabel,
          style: GoogleFonts.poppins(
            fontSize: 13,
            color: AppTheme.textMedium,
          ),
        ),
      );
    }

    final topItems = items.take(3).toList();
    return Column(
      children: topItems
          .map(
            (q) => Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.softBorder),
              ),
              child: Text(
                '• ${q.question}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: AppTheme.textDark,
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}