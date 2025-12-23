import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import '../models/game_model.dart';
import '../services/game_sound_service.dart';
import 'game_library_screen.dart';

/// Screen showing game results and performance summary
class GameResultsScreen extends StatefulWidget {
  final GameModel game;
  final int score;
  final int totalQuestions;
  final int? timeTakenSeconds;

  const GameResultsScreen({
    Key? key,
    required this.game,
    required this.score,
    required this.totalQuestions,
    this.timeTakenSeconds,
  }) : super(key: key);

  @override
  State<GameResultsScreen> createState() => _GameResultsScreenState();
}

class _GameResultsScreenState extends State<GameResultsScreen> {
  final GameSoundService _soundService = GameSoundService();
  bool _hasPlayedSound = false;

  @override
  void initState() {
    super.initState();
    _soundService.initialize();
    // Play completion sound once when screen loads
    if (!_hasPlayedSound) {
      _soundService.playComplete();
      _hasPlayedSound = true;
    }
  }

  double get _percentage => (widget.score / widget.totalQuestions) * 100;

  String get _performanceText {
    if (_percentage >= 90) return 'Excellent! 🌟';
    if (_percentage >= 70) return 'Great Job! 🎉';
    if (_percentage >= 50) return 'Good Effort! 👍';
    return 'Keep Practicing! 💪';
  }

  Color get _performanceColor {
    if (_percentage >= 90) return AppTheme.accentGreen;
    if (_percentage >= 70) return Colors.blue;
    if (_percentage >= 50) return Colors.orange;
    return Colors.red;
  }

  String _formatTime(int? seconds) {
    if (seconds == null) return 'N/A';
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    if (minutes > 0) {
      return '${minutes}m ${secs}s';
    }
    return '${secs}s';
  }

  @override
  Widget build(BuildContext context) {
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
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Performance circle
            Center(
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      _performanceColor,
                      _performanceColor.withOpacity(0.7),
                    ],
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${_percentage.toInt()}%',
                        style: GoogleFonts.poppins(
                          fontSize: 36,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        '$_performanceText',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            // Stats cards
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    icon: Icons.check_circle,
                    label: 'Correct',
                    value: '${widget.score}',
                    color: AppTheme.accentGreen,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    icon: Icons.cancel,
                    label: 'Incorrect',
                    value: '${widget.totalQuestions - widget.score}',
                    color: Colors.red,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildStatCard(
              icon: Icons.timer,
              label: 'Time Taken',
              value: _formatTime(widget.timeTakenSeconds),
              color: AppTheme.primaryColor,
              fullWidth: true,
            ),
            const SizedBox(height: 32),
            // Action buttons
            ElevatedButton(
              onPressed: () {
                // Navigate back to game library
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const GameLibraryScreen(),
                  ),
                  (route) => route.isFirst,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Back to Games',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () {
                // Play again - navigate to appropriate game screen
                Navigator.pop(context);
              },
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Play Again',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    bool fullWidth = false,
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
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
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

