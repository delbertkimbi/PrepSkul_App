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
  bool _isGenerating = true;
  String _status = 'Generating your game...';
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
        _status = 'Analyzing content...';
      });

      final game = await SkulMateService.generateGame(
        fileUrl: widget.fileUrl,
        text: widget.text,
        childId: widget.childId,
      );

      safeSetState(() {
        _generatedGame = game;
        _isGenerating = false;
        _status = 'Game ready!';
      });

      // Navigate to appropriate game screen
      if (mounted) {
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
          default:
            gameScreen = QuizGameScreen(game: game);
        }

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => gameScreen),
        );
      }
    } catch (e) {
      LogService.error('Error generating game: $e');
      safeSetState(() {
        _isGenerating = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.softBackground,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Generating Game',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: AppTheme.textDark,
          ),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isGenerating)
                const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                )
              else if (_error != null)
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Colors.red[300],
                )
              else
                Icon(
                  Icons.check_circle,
                  size: 64,
                  color: AppTheme.accentGreen,
                ),
              const SizedBox(height: 24),
              Text(
                _error ?? _status,
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: _error != null ? Colors.red : AppTheme.textDark,
                ),
                textAlign: TextAlign.center,
              ),
              if (_error != null) ...[
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text('Go Back'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
