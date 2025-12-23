import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/core/utils/safe_set_state.dart';
import 'package:prepskul/core/services/log_service.dart';
import '../services/skulmate_service.dart';
import '../models/game_model.dart';
import 'quiz_game_screen.dart';
import 'flashcard_game_screen.dart';
import 'matching_game_screen.dart';
import 'fill_blank_game_screen.dart';

/// Screen showing game generation progress
class GameGenerationScreen extends StatefulWidget {
  final String? fileUrl;
  final String? text;
  final String? childId;

  const GameGenerationScreen({
    Key? key,
    this.fileUrl,
    this.text,
    this.childId,
  }) : super(key: key);

  @override
  State<GameGenerationScreen> createState() => _GameGenerationScreenState();
}

class _GameGenerationScreenState extends State<GameGenerationScreen> {
  bool _isGenerating = false;
  String _status = 'Preparing...';
  GameModel? _generatedGame;
  String? _error;

  @override
  void initState() {
    super.initState();
    _generateGame();
  }

  Future<void> _generateGame() async {
    try {
      safeSetState(() {
        _isGenerating = true;
        _status = 'Analyzing your notes...';
        _error = null;
      });

      // Generate game
      final game = await SkulMateService.generateGameHttp(
        fileUrl: widget.fileUrl,
        text: widget.text,
        childId: widget.childId,
        gameType: 'auto', // Let AI decide best game type
      );

      safeSetState(() {
        _generatedGame = game;
        _isGenerating = false;
        _status = 'Game ready!';
      });

      // Navigate to appropriate game screen
      if (mounted) {
        _navigateToGame(game);
      }
    } catch (e) {
      LogService.error('🎮 [skulMate] Error generating game: $e');
      safeSetState(() {
        _isGenerating = false;
        _error = e.toString().replaceAll('Exception: ', '');
        _status = 'Error';
      });
    }
  }

  void _navigateToGame(GameModel game) {
    Widget gameScreen;
    switch (game.gameType) {
      case GameType.quiz:
        gameScreen = QuizGameScreen(game: game);
        break;
      case GameType.flashcards:
        gameScreen = FlashcardGameScreen(game: game);
        break;
      case GameType.matching:
        gameScreen = MatchingGameScreen(game: game);
        break;
      case GameType.fillBlank:
        gameScreen = FillBlankGameScreen(game: game);
        break;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => gameScreen),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.softBackground,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.textDark),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Generating Game',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppTheme.textDark,
          ),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_error == null) ...[
                // Loading animation
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.primaryColor,
                        AppTheme.primaryColor.withOpacity(0.7),
                      ],
                    ),
                  ),
                  child: _isGenerating
                      ? const Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            strokeWidth: 3,
                          ),
                        )
                      : const Icon(
                          Icons.check_circle,
                          size: 60,
                          color: Colors.white,
                        ),
                ),
                const SizedBox(height: 32),
                Text(
                  _status,
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textDark,
                  ),
                ),
                const SizedBox(height: 16),
                if (_isGenerating)
                  Text(
                    'skulMate is analyzing your notes and creating an interactive game for you...',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: AppTheme.textMedium,
                    ),
                    textAlign: TextAlign.center,
                  ),
              ] else ...[
                // Error state
                const Icon(
                  Icons.error_outline,
                  size: 80,
                  color: Colors.red,
                ),
                const SizedBox(height: 24),
                Text(
                  'Error Generating Game',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textDark,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _error ?? 'Unknown error occurred',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: AppTheme.textMedium,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _generateGame,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                  ),
                  child: Text(
                    'Try Again',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

