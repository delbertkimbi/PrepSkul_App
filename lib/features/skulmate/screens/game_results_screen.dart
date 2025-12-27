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

/// Screen showing game results and performance summary
class GameResultsScreen extends StatefulWidget {
  final GameModel game;
  final int score;
  final int totalQuestions;
  final int? timeTakenSeconds;
  final int? xpEarned;
  final bool isPerfectScore;

  const GameResultsScreen({
    Key? key,
    required this.game,
    required this.score,
    required this.totalQuestions,
    this.timeTakenSeconds,
    this.xpEarned,
    this.isPerfectScore = false,
  }) : super(key: key);

  @override
  State<GameResultsScreen> createState() => _GameResultsScreenState();
}

class _GameResultsScreenState extends State<GameResultsScreen>
    with TickerProviderStateMixin {
  late ConfettiController _confettiController;
  late AnimationController _scoreController;
  late Animation<double> _scoreAnimation;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
    _scoreController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _scoreAnimation = Tween<double>(begin: 0, end: widget.score.toDouble()).animate(
      CurvedAnimation(parent: _scoreController, curve: Curves.easeOut),
    );
    _scoreController.forward();
    if (widget.isPerfectScore) {
      _confettiController.play();
    }
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _scoreController.dispose();
    super.dispose();
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    if (minutes > 0) {
      return '${minutes}m ${secs}s';
    }
    return '${secs}s';
  }

  Future<void> _shareResults() async {
    try {
      final percentage = ((widget.score / widget.totalQuestions) * 100).round();
      final timeText = widget.timeTakenSeconds != null
          ? ' in ${_formatTime(widget.timeTakenSeconds!)}'
          : '';
      
      String shareText = '🎮 I just played "${widget.game.title}" on skulMate!\n\n';
      shareText += 'Score: $percentage% ($widget.score/$widget.totalQuestions)$timeText\n';
      if (widget.xpEarned != null) {
        shareText += 'XP Earned: ${widget.xpEarned}\n';
      }
      if (widget.isPerfectScore) {
        shareText += '🌟 Perfect Score!\n';
      }
      shareText += '\nPlay this game in skulMate!';
      
      await Share.share(shareText);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sharing results: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final percentage = ((widget.score / widget.totalQuestions) * 100).round();

    return Scaffold(
      backgroundColor: AppTheme.softBackground,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Results',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppTheme.textDark,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _shareResults,
            tooltip: 'Share Results',
          ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const SizedBox(height: 20),
                // Score circle
                Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: widget.isPerfectScore
                          ? [AppTheme.accentGreen, AppTheme.accentGreen.withOpacity(0.8)]
                          : [AppTheme.primaryColor, AppTheme.primaryColor.withOpacity(0.8)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: (widget.isPerfectScore ? AppTheme.accentGreen : AppTheme.primaryColor)
                            .withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedBuilder(
                          animation: _scoreAnimation,
                          builder: (context, child) {
                            return Text(
                              '${_scoreAnimation.value.round()}',
                              style: GoogleFonts.poppins(
                                fontSize: 48,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            );
                          },
                        ),
                        Text(
                          '/${widget.totalQuestions}',
                          style: GoogleFonts.poppins(
                            fontSize: 24,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // Percentage
                Text(
                  '$percentage%',
                  style: GoogleFonts.poppins(
                    fontSize: 36,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textDark,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.isPerfectScore ? 'Perfect Score! 🌟' : 'Great Job!',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textMedium,
                  ),
                ),
                const SizedBox(height: 32),
                // Stats cards
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        icon: Icons.timer,
                        label: 'Time',
                        value: widget.timeTakenSeconds != null
                            ? _formatTime(widget.timeTakenSeconds!)
                            : 'N/A',
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        icon: Icons.star,
                        label: 'XP',
                        value: '${widget.xpEarned ?? 0}',
                        color: Colors.amber,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                // Action buttons
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                        builder: (context) => GameLibraryScreen(),
                      ),
                      (route) => false,
                    );
                  },
                  icon: const Icon(Icons.library_books),
                  label: const Text('Back to Library'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Play Again'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Confetti overlay
          if (widget.isPerfectScore)
            Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: _confettiController,
                blastDirection: pi / 2,
                maxBlastForce: 5,
                minBlastForce: 2,
                emissionFrequency: 0.05,
                numberOfParticles: 20,
                gravity: 0.1,
                shouldLoop: false,
                colors: const [
                  Colors.green,
                  Colors.blue,
                  Colors.pink,
                  Colors.orange,
                  Colors.purple,
                  Colors.yellow,
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppTheme.textDark,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: AppTheme.textMedium,
            ),
          ),
        ],
      ),
    );
  }
}
