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
import '../services/character_selection_service.dart';
import 'package:prepskul/core/services/whatsapp_support_service.dart';
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
    _soundService.initialize();
    unawaited(_soundService.playResultsMusic());
    _loadStats();
    _loadCharacter();
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

  Future<void> _loadCharacter() async {
    final character = await CharacterSelectionService.getSelectedCharacter();
    if (mounted) safeSetState(() => _character = character);
  }

  @override
  void dispose() {
    unawaited(_soundService.stopMusic());
    _confettiController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  /// Short display name (first name only) for character
  String _characterShortName(dynamic character) {
    if (character == null) return '';
    try {
      final name =
          character.name as String? ?? character.displayName as String? ?? '';
      return name.trim().isEmpty ? '' : name.trim().split(RegExp(r'\s+')).first;
    } catch (_) {
      return '';
    }
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
    final timeText = widget.timeTakenSeconds != null
        ? '${widget.timeTakenSeconds! ~/ 60}:${(widget.timeTakenSeconds! % 60).toString().padLeft(2, '0')}'
        : 'N/A';

    return Scaffold(
      backgroundColor: AppTheme.softBackground,
      appBar: AppBar(
        title: Text(
          'Game complete!',
          style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white ),
        ),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: widget.fromGenerationFlow
            ? IconButton(
                icon: const Icon(Icons.close),
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
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.primaryColor.withOpacity(0.12),
                  AppTheme.accentPurple.withOpacity(0.08),
                  AppTheme.softBackground,
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.primaryColor,
                        AppTheme.skyBlue,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.textDark.withOpacity(0.16),
                        blurRadius: 12,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      if (_character != null)
                        ScaleTransition(
                          scale: _scaleAnimation,
                          child: ClipOval(
                            child: Container(
                              width: 64,
                              height: 64,
                              color: Colors.white.withOpacity(0.16),
                              child: Center(
                                child: SkulMateCharacterWidget(
                                  character: _character,
                                  size: 52,
                                  animated: true,
                                  showName: false,
                                ),
                              ),
                            ),
                          ),
                        )
                      else
                        const Icon(Icons.videogame_asset_rounded,
                            color: Colors.white, size: 52),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.game.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.isPerfectScore
                                  ? 'Legendary run! 🏆'
                                  : percentage >= 70
                                      ? 'Great job! Keep it going.'
                                      : 'Nice try — next round will be better.',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.white.withOpacity(0.92),
                              ),
                            ),
                            if (_character != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  _characterShortName(_character),
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    color: Colors.white.withOpacity(0.92),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.textDark.withOpacity(0.08),
                        blurRadius: 10,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Text(
                        '$percentage%',
                        style: GoogleFonts.poppins(
                          fontSize: 34,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${widget.score}/${widget.totalQuestions} correct',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: AppTheme.textMedium,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: widget.totalQuestions > 0
                              ? widget.score / widget.totalQuestions
                              : 0,
                          minHeight: 8,
                          backgroundColor: AppTheme.softBorder.withOpacity(0.7),
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
                const SizedBox(height: 12),
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
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 1.9,
                      children: cards,
                    );
                  },
                ),
                if (widget.questionBreakdown.isNotEmpty) ...[
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
                    accentColor: AppTheme.skyBlue,
                  ),
                ],
                const SizedBox(height: 16),
                if (widget.game.gameType == GameType.quiz && !widget.isPerfectScore)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
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
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const GameLibraryScreen(
                                childId: null,
                                initialTab: 1,
                              ),
                            ),
                            (route) => false,
                          );
                        },
                        icon: const Icon(Icons.dashboard_customize_rounded, size: 18),
                        label: const Text('Dashboard'),
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
