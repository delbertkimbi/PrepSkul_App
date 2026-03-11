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
import '../services/character_selection_service.dart';
import '../widgets/skulmate_character_widget.dart';
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
  /// When true, back button goes to game library (dashboard) instead of previous screen.
  final bool fromGenerationFlow;

  const GameResultsScreen({
    Key? key,
    required this.game,
    required this.score,
    required this.totalQuestions,
    this.timeTakenSeconds,
    this.xpEarned,
    this.isPerfectScore = false,
    this.questionBreakdown = const [],
    this.fromGenerationFlow = false,
  }) : super(key: key);

  @override
  State<GameResultsScreen> createState() => _GameResultsScreenState();
}

class _GameResultsScreenState extends State<GameResultsScreen>
    with SingleTickerProviderStateMixin {
  late ConfettiController _confettiController;
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;
  final GameSoundService _soundService = GameSoundService();
  GameStats? _currentStats;
  dynamic _character;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
    );
    _soundService.initialize();
    _loadStats();
    _loadCharacter();
    if (widget.isPerfectScore) {
      _confettiController.play();
      _soundService.playComplete();
    } else {
      _soundService.playClick();
    }
    _scaleController.forward();
  }

  Future<void> _loadCharacter() async {
    final character = await CharacterSelectionService.getSelectedCharacter();
    if (mounted) safeSetState(() => _character = character);
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  /// Short display name (first name only) for character
  String _characterShortName(dynamic character) {
    if (character == null) return '';
    try {
      final name = character.name as String? ?? character.displayName as String? ?? '';
      return name.trim().isEmpty ? '' : name.trim().split(RegExp(r'\s+')).first;
    } catch (_) {
      return '';
    }
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
        title: Text('Results', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600)),
        backgroundColor: AppTheme.softBackground,
        elevation: 0,
        foregroundColor: AppTheme.textDark,
        leading: widget.fromGenerationFlow
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const GameLibraryScreen(initialTab: 1),
                    ),
                    (route) => false,
                  );
                },
              )
            : null,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Header: compact, soft tint (no big white block)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.primaryColor.withOpacity(0.06),
                        AppTheme.accentPurple.withOpacity(0.04),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    children: [
                      if (_character != null)
                        ScaleTransition(
                          scale: _scaleAnimation,
                          child: ClipOval(
                            child: Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor.withOpacity(0.08),
                                border: Border.all(
                                  color: AppTheme.primaryColor.withOpacity(0.25),
                                  width: 2,
                                ),
                              ),
                              child: Center(
                                child: SkulMateCharacterWidget(
                                  character: _character,
                                  size: 48,
                                  animated: true,
                                  showName: false,
                                ),
                              ),
                            ),
                          ),
                        ),
                      if (_character != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          _characterShortName(_character),
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textDark,
                          ),
                        ),
                      ],
                      const SizedBox(height: 4),
                      Text(
                        widget.isPerfectScore
                            ? 'Perfect score!'
                            : percentage >= 70
                                ? 'Quiz complete'
                                : 'Keep practicing',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.textMedium,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // Score card - compact, soft background
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    color: AppTheme.softCard,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.softBorder),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Score',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textMedium,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            '$percentage%',
                            style: GoogleFonts.poppins(
                              fontSize: 32,
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
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: widget.totalQuestions > 0
                              ? widget.score / widget.totalQuestions
                              : 0,
                          minHeight: 6,
                          backgroundColor: AppTheme.softBorder,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            percentage >= 70 ? AppTheme.accentGreen : AppTheme.primaryColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                // Stats grid - tighter
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
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      childAspectRatio: 1.9,
                      children: statCards,
                    );
                  },
                ),
                if (_currentStats != null && _currentStats!.currentStreak > 0) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                // What you did well / What to review - compact cards
                if (widget.questionBreakdown.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'What you did well',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textDark,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  _buildQuestionList(
                    widget.questionBreakdown.where((q) => q.isCorrect).toList(),
                    emptyLabel: 'We will highlight wins here when you get some questions correct.',
                    accentColor: AppTheme.accentGreen,
                  ),
                  const SizedBox(height: 14),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'What to review',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textDark,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  _buildQuestionList(
                    widget.questionBreakdown.where((q) => !q.isCorrect).toList(),
                    emptyLabel: 'No weak spots in this round – great job.',
                    accentColor: AppTheme.accentBlue,
                  ),
                ],
                const SizedBox(height: 18),
                // Primary: Play again when quiz and not perfect; secondary: Home, Share
                if (widget.game.gameType == GameType.quiz && !widget.isPerfectScore)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) => QuizGameScreen(
                                game: widget.game,
                                fromGenerationFlow: widget.fromGenerationFlow,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.refresh, size: 20),
                        label: const Text('Play again'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 2,
                        ),
                      ),
                    ),
                  ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const GameLibraryScreen(childId: null, initialTab: 1),
                          ),
                          (route) => false,
                        );
                      },
                      icon: const Icon(Icons.home, size: 18),
                      label: const Text('Home'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
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
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.softCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.softBorder),
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
          const SizedBox(height: 2),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 14,
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
    Color accentColor = AppTheme.primaryColor,
  }) {
    if (items.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.softCard,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.softBorder),
        ),
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
              padding: const EdgeInsets.only(left: 10, right: 10, top: 8, bottom: 8),
              decoration: BoxDecoration(
                color: AppTheme.softCard,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.softBorder),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 3,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: accentColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                    constraints: const BoxConstraints(minHeight: 28),
                  ),
                  Expanded(
                    child: Text(
                      q.question,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: AppTheme.textDark,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}