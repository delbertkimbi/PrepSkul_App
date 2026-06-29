import 'package:flutter/material.dart';
import 'dart:async';
import 'package:google_fonts/google_fonts.dart';
import 'package:confetti/confetti.dart';
import 'package:share_plus/share_plus.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/core/utils/safe_set_state.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:prepskul/core/services/supabase_service.dart';
import 'dart:math';
import '../models/game_model.dart';
import '../models/game_stats_model.dart';
import '../services/game_sound_service.dart';
import '../services/game_stats_service.dart';
import 'package:prepskul/core/services/whatsapp_support_service.dart';
import '../widgets/skulmate_tutor_escalation_card.dart';
import '../widgets/skulmate_game_app_bar.dart';
import '../widgets/skulmate_companion_banner.dart';
import '../widgets/skulmate_mascot_media_widget.dart';
import '../widgets/skulmate_surface_styles.dart';
import '../utils/skulmate_navigation.dart';
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

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 3),
    );
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
    );
    unawaited(_startResultsMusicSafely());
    _loadStats();
    if (widget.isPerfectScore) {
      _confettiController.play();
      _soundService.playComplete();
    } else {
      _soundService.playClick();
    }
    _scaleController.forward();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeShowFirstGameFeedback();
    });
  }

  Future<void> _startResultsMusicSafely() async {
    await _soundService.initialize();
    if (!mounted) return;
    // Route replacement disposals can call stopMusic slightly after this screen
    // is created; retry once after a short delay so results BGM always starts.
    await _soundService.playResultsMusic();
    unawaited(
      Future<void>.delayed(const Duration(milliseconds: 220), () async {
        if (!mounted) return;
        await _soundService.playResultsMusic();
      }),
    );
  }

  String _companionMessageForScore(int percentage) {
    if (percentage >= 90) {
      return 'Legendary work. Keep this pace and you will master this topic quickly.';
    }
    if (percentage >= 70) {
      return 'Strong run! Review the weak spots below and you will level up fast.';
    }
    return 'Nice effort. Let us review the tricky parts and bounce back stronger.';
  }

  @override
  void dispose() {
    unawaited(_soundService.stopMusic(force: true));
    _confettiController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  Future<void> _loadStats() async {
    final stats = await GameStatsService.getStats();
    safeSetState(() => _currentStats = stats);
  }

  Future<void> _maybeShowFirstGameFeedback() async {
    final userId = SupabaseService.client.auth.currentUser?.id ?? 'guest';
    final prefs = await SharedPreferences.getInstance();
    final key = 'skulmate_first_feedback_shown_$userId';
    final shown = prefs.getBool(key) ?? false;
    if (shown || !mounted) return;

    await prefs.setBool(key, true);
    if (!mounted) return;
    await _showFirstGameFeedbackDialog();
  }

  Future<void> _showFirstGameFeedbackDialog() async {
    int rating = 4;
    final noteController = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: Text(
                'Quick feedback',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.softCard,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.softBorder),
                      ),
                      child: Row(
                        children: [
                          const SizedBox(
                            width: 30,
                            height: 30,
                            child: SkulMateMascotMediaWidget(
                              state: SkulMateMascotState.neutral,
                              useLandscapeFrame: false,
                              borderRadius: 999,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'SkulMate team would love your quick feedback.',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: AppTheme.textMedium,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'How was your first SkulMate game experience?',
                      style: GoogleFonts.poppins(fontSize: 13),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      children: List.generate(5, (index) {
                        final value = index + 1;
                        final selected = value == rating;
                        return ChoiceChip(
                          label: Text('$value★'),
                          selected: selected,
                          onSelected: (_) =>
                              setModalState(() => rating = value),
                        );
                      }),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: noteController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        hintText: 'What should we improve next?',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Skip', style: GoogleFonts.poppins()),
                ),
                ElevatedButton(
                  onPressed: () {
                    final note = noteController.text.trim();
                    Navigator.pop(context);
                    WhatsAppSupportService.openWhatsApp(
                      context: 'skulmate_first_feedback',
                      additionalInfo:
                          'SkulMate first completed game feedback\n'
                          'Rating: $rating/5\n'
                          'Game: ${widget.game.gameType} • ${widget.game.title}\n'
                          'Score: ${widget.score}/${widget.totalQuestions}\n'
                          '${note.isEmpty ? '' : '\nNote:\n$note'}',
                    );
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Thanks! Your feedback helps us improve.',
                          style: GoogleFonts.poppins(fontSize: 13),
                        ),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  child: Text('Submit', style: GoogleFonts.poppins()),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final percentage = (widget.score / widget.totalQuestions * 100).round();
    final companionTone = percentage >= 70
        ? CompanionTone.success
        : CompanionTone.tip;
    final (toneStart, toneEnd) = companionTone == CompanionTone.success
        ? (AppTheme.accentGreen, AppTheme.skyBlue)
        : (AppTheme.primaryColor, AppTheme.skyBlue);
    final timeText = widget.timeTakenSeconds != null
        ? '${widget.timeTakenSeconds! ~/ 60}:${(widget.timeTakenSeconds! % 60).toString().padLeft(2, '0')}'
        : 'N/A';

    return Scaffold(
      backgroundColor: AppTheme.softBackground,
      appBar: SkulMateGameAppBar(
        title: 'Game complete!',
        leading: widget.fromGenerationFlow
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  unawaited(SkulMateNavigation.exitToSkulMateHome(context));
                },
              )
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
              ),
      ),
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  toneStart.withValues(alpha: 0.14),
                  toneEnd.withValues(alpha: 0.09),
                  toneEnd.withValues(alpha: 0.05),
                  AppTheme.softBackground,
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                ScaleTransition(
                  scale: _scaleAnimation,
                  child: SkulMateCompanionBanner(
                    tone: companionTone,
                    label: widget.game.title,
                    message: widget.isPerfectScore
                        ? 'Legendary run! Keep the streak alive.'
                        : percentage >= 70
                            ? 'Great job! Keep it going.'
                            : 'Nice try - next round will be better.',
                    celebrate: percentage >= 90,                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  decoration: SkulMateSurfaceStyles.neumorphicCard(radius: 18),
                  child: Column(
                    children: [
                      Text(
                        '$percentage%',
                        style: GoogleFonts.poppins(
                          fontSize: 44,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.primaryColor,
                          height: 1.05,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${widget.score}/${widget.totalQuestions} correct',
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textMedium,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: widget.totalQuestions > 0
                              ? widget.score / widget.totalQuestions
                              : 0,
                          minHeight: 10,
                          backgroundColor: AppTheme.softBorder.withValues(alpha: 0.7),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            percentage >= 70
                                ? AppTheme.softYellow
                                : AppTheme.skyBlue,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final cards = <Widget>[
                      _buildCompactStat('Time', timeText, Icons.timer_outlined),
                      if (widget.xpEarned != null)
                        _buildCompactStat('XP', '+${widget.xpEarned}', Icons.star_outline),
                      if (_currentStats != null) ...[
                        _buildCompactStat('Total XP', '${_currentStats!.totalXP}', Icons.emoji_events_outlined),
                        _buildCompactStat('Level', '${_currentStats!.level}', Icons.military_tech),
                      ],
                    ];
                    return GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      mainAxisSpacing: 6,
                      crossAxisSpacing: 6,
                      childAspectRatio: 1.75,
                      children: cards,
                    );
                  },
                ),
                if (widget.questionBreakdown.isNotEmpty) ...[
                  const SizedBox(height: 8),
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
                  const SizedBox(height: 4),
                  _buildQuestionList(
                    widget.questionBreakdown.where((q) => !q.isCorrect).toList(),
                    emptyLabel: 'No weak spots in this round – great job.',
                    accentColor: AppTheme.skyBlue,
                  ),
                ],
                const SizedBox(height: 8),
                SkulMateTutorEscalationCard(
                  game: widget.game,
                  score: widget.score,
                  totalQuestions: widget.totalQuestions,
                ),
                if (widget.game.gameType == GameType.quiz && !widget.isPerfectScore)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
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
                        ),
                      ),
                    ),
                  ),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          if (widget.fromGenerationFlow) {
                            unawaited(
                              SkulMateNavigation.exitToSkulMateHome(context),
                            );
                          } else {
                            Navigator.pop(context);
                          }
                        },
                        icon: Icon(
                          widget.fromGenerationFlow
                              ? Icons.dashboard_customize_rounded
                              : Icons.check_rounded,
                          size: 18,
                        ),
                        label: Text(
                          widget.fromGenerationFlow ? 'Dashboard' : 'Done',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Share.share(
                            'I scored $percentage% on ${widget.game.title}! 🎮',
                          );
                        },
                        icon: const Icon(Icons.share, size: 18),
                        label: const Text('Share'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.primaryColor,
                          side: const BorderSide(color: AppTheme.skyBlue),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
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
              maxBlastForce: 6,
              minBlastForce: 2,
              emissionFrequency: 0.05,
              numberOfParticles: 60,
              gravity: 0.12,
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
      decoration: SkulMateSurfaceStyles.neumorphicCard(
        color: AppTheme.softCard,
        radius: 12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppTheme.primaryColor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: AppTheme.textMedium,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w800,
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
          style: GoogleFonts.poppins(fontSize: 13, color: AppTheme.textMedium),
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
              padding: const EdgeInsets.only(
                left: 10,
                right: 10,
                top: 8,
                bottom: 8,
              ),
              decoration: BoxDecoration(
                color: AppTheme.softCard,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.softBorder),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 4,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          accentColor,
                          AppTheme.primaryColor,
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      borderRadius: BorderRadius.circular(4),
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
