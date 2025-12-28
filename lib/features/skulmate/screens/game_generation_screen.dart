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
  final String? imageUrl;
  final String? text;
  final String? childId;
  final String? difficulty;
  final String? topic;
  final int? numQuestions;

  const GameGenerationScreen({
    Key? key,
    this.fileUrl,
    this.imageUrl,
    this.text,
    this.childId,
    this.difficulty,
    this.topic,
    this.numQuestions,
  }) : super(key: key);

  @override
  State<GameGenerationScreen> createState() => _GameGenerationScreenState();
}

class _GameGenerationScreenState extends State<GameGenerationScreen>
    with SingleTickerProviderStateMixin {
  bool _isGenerating = true;
  String _status = 'Generating your game...';
  GameModel? _generatedGame;
  String? _error;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
    
    _rotationAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.linear,
      ),
    );
    
    _generateGame();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _generateGame() async {
    try {
      safeSetState(() {
        _isGenerating = true;
        _status = 'Analyzing content...';
      });

      final game = await SkulMateService.generateGame(
        fileUrl: widget.fileUrl,
        imageUrl: widget.imageUrl,
        text: widget.text,
        childId: widget.childId,
        difficulty: widget.difficulty,
        topic: widget.topic,
        numQuestions: widget.numQuestions,
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
      
      // Parse error message to be user-friendly
      String errorMessage = 'We couldn\'t create your game right now.';
      String errorDetails = '';
      
      final errorStr = e.toString().toLowerCase();
      
      if (errorStr.contains('fileurl') || errorStr.contains('text is required')) {
        errorMessage = 'Please provide content to generate a game.';
        errorDetails = 'Upload a document, image, or enter text to continue.';
      } else if (errorStr.contains('network') || errorStr.contains('connection')) {
        errorMessage = 'Connection problem.';
        errorDetails = 'Please check your internet connection and try again.';
      } else if (errorStr.contains('timeout')) {
        errorMessage = 'Request took too long.';
        errorDetails = 'Please try again. If this continues, the server may be busy.';
      } else if (errorStr.contains('server error') || errorStr.contains('500')) {
        errorMessage = 'Server error.';
        errorDetails = 'Our servers are having issues. Please try again in a few moments.';
      } else if (errorStr.contains('400') || errorStr.contains('bad request')) {
        errorMessage = 'Invalid request.';
        errorDetails = 'Please make sure you\'ve uploaded a valid file or entered text.';
      } else {
        // Extract a more user-friendly message if possible
        final match = RegExp(r'Exception: (.+)').firstMatch(e.toString());
        if (match != null && !match.group(1)!.toLowerCase().contains('exception')) {
          errorDetails = match.group(1)!;
        } else {
          errorDetails = 'Please try again or contact support if the problem persists.';
        }
      }
      
      safeSetState(() {
        _isGenerating = false;
        _error = errorDetails.isNotEmpty 
            ? '$errorMessage\n\n$errorDetails'
            : errorMessage;
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
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.primaryColor.withOpacity(0.05),
              AppTheme.accentGreen.withOpacity(0.05),
            ],
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_isGenerating) ...[
                  // Animated icon with pulsing effect
                  AnimatedBuilder(
                    animation: _animationController,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _scaleAnimation.value,
                        child: Transform.rotate(
                          angle: _rotationAnimation.value * 2 * 3.14159,
                          child: Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  AppTheme.primaryColor.withOpacity(0.2),
                                  AppTheme.accentGreen.withOpacity(0.2),
                                ],
                              ),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.primaryColor.withOpacity(0.3),
                                  blurRadius: 20,
                                  spreadRadius: 5,
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.auto_awesome,
                              size: 60,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 40),
                  Text(
                    _status,
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textDark,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'This may take a few moments...',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      color: AppTheme.textMedium,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),
                  // Progress indicator
                  SizedBox(
                    width: 200,
                    child: LinearProgressIndicator(
                      backgroundColor: AppTheme.textLight.withOpacity(0.2),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppTheme.primaryColor,
                      ),
                      minHeight: 4,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ] else if (_error != null) ...[
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Colors.red[300],
                ),
                const SizedBox(height: 24),
                Text(
                  _error!,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.red,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  ),
                  child: const Text('Go Back'),
                ),
              ] else ...[
                Icon(
                  Icons.check_circle,
                  size: 64,
                  color: AppTheme.accentGreen,
                ),
                const SizedBox(height: 24),
                Text(
                  _status,
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.accentGreen,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
