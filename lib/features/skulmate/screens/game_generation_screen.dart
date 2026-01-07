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
import 'word_guessing_game_screen.dart';
import 'game_library_screen.dart';

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
    with TickerProviderStateMixin {
  bool _isGenerating = true;
  String _status = 'Generating your game...';
  GameModel? _generatedGame;
  String? _error;
  String? _errorTitle;
  String? _errorDetails;
  late AnimationController _animationController;
  AnimationController? _pulseController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;
  Animation<double>? _pulseAnimation;
  double _progress = 0.0;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
    
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    
    _scaleAnimation = Tween<double>(begin: 0.9, end: 1.1).animate(
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
    
    _pulseAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(
        parent: _pulseController!,
        curve: Curves.easeInOut,
      ),
    );
    
    _simulateProgress();
    _generateGame();
  }

  void _simulateProgress() {
    // Simulate progress updates (keep text fixed to avoid jumpiness)
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted && _isGenerating) {
        safeSetState(() => _progress = 0.2);
      }
    });
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted && _isGenerating) {
        safeSetState(() => _progress = 0.5);
      }
    });
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted && _isGenerating) {
        safeSetState(() => _progress = 0.8);
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _pulseController?.dispose();
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
            // Use word guessing game for fill_blank games
            gameScreen = WordGuessingGameScreen(game: game);
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
      
      // Parse structured error message (format: "Title\n\nDetails")
      String errorTitle = 'We couldn\'t create your game right now.';
      String errorDetails = '';
      
      final errorStr = e.toString();
      
      // Check if error already has structured format (title\n\ndetails)
      if (errorStr.contains('\n\n')) {
        final parts = errorStr.split('\n\n');
        errorTitle = parts[0].replaceAll('Exception: ', '').trim();
        errorDetails = parts.length > 1 ? parts.sublist(1).join('\n\n') : '';
      } else {
        // Parse unstructured errors
        final lowerError = errorStr.toLowerCase();
        
        if (lowerError.contains('fileurl') || lowerError.contains('text is required')) {
          errorTitle = 'Please provide content to generate a game.';
          errorDetails = 'Upload a document, image, or enter text to continue.';
        } else if (lowerError.contains('api endpoint not found') || lowerError.contains('404')) {
          errorTitle = 'Service unavailable';
          errorDetails = 'The game generation service may not be available. Please check your connection and try again.';
        } else if (lowerError.contains('network') || lowerError.contains('connection') || lowerError.contains('failed host lookup')) {
          errorTitle = 'Connection problem';
          errorDetails = 'Please check your internet connection and try again.';
        } else if (lowerError.contains('timeout') || lowerError.contains('took too long')) {
          errorTitle = 'Request took too long';
          errorDetails = 'The request is taking longer than expected. Please try again.';
        } else if (lowerError.contains('server error') || lowerError.contains('500')) {
          errorTitle = 'Server error';
          errorDetails = 'Our servers are having issues. Please try again in a few moments.';
        } else if (lowerError.contains('400') || lowerError.contains('bad request') || lowerError.contains('invalid')) {
          errorTitle = 'Invalid request';
          errorDetails = 'Please make sure you\'ve uploaded a valid file or entered text.';
        } else if (lowerError.contains('invalid response format') || lowerError.contains('html')) {
          errorTitle = 'Service error';
          errorDetails = 'The server returned an unexpected response. Please try again or contact support.';
        } else {
          // Extract message from exception
          final match = RegExp(r'Exception: (.+)').firstMatch(errorStr);
          if (match != null) {
            final message = match.group(1)!;
            if (!message.toLowerCase().contains('exception')) {
              errorTitle = message;
            }
          }
          if (errorDetails.isEmpty) {
            errorDetails = 'Please try again or contact support if the problem persists.';
          }
        }
      }
      
      // Split error into title and details
      final errorParts = errorDetails.isNotEmpty 
          ? '$errorTitle\n\n$errorDetails'
          : errorTitle;
      final parts = errorParts.split('\n\n');
      
      safeSetState(() {
        _isGenerating = false;
        _error = errorParts;
        _errorTitle = parts[0];
        _errorDetails = parts.length > 1 ? parts.sublist(1).join('\n\n') : null;
        _progress = 0.0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.softBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Generating Game',
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppTheme.primaryColor.withOpacity(0.1),
              Colors.white,
            ],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_isGenerating) ...[
                  // Animated icon with multiple effects
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      // Pulsing background circles
                      AnimatedBuilder(
                        animation: _pulseController ?? _animationController,
                        builder: (context, child) {
                          final pulseValue = _pulseAnimation?.value ?? 1.0;
                          return Container(
                            width: 140 + (40 * pulseValue),
                            height: 140 + (40 * pulseValue),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppTheme.primaryColor.withOpacity(0.1 * pulseValue),
                            ),
                          );
                        },
                      ),
                      // Rotating icon
                      AnimatedBuilder(
                        animation: _animationController,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _scaleAnimation.value,
                            child: Transform.rotate(
                              angle: _rotationAnimation.value * 2 * 3.14159,
                              child: Container(
                                width: 100,
                                height: 100,
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppTheme.primaryColor.withOpacity(0.4),
                                      blurRadius: 20,
                                      spreadRadius: 5,
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  Icons.auto_awesome_rounded,
                                  size: 50,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  Text(
                    _status,
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textDark,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'This may take a few moments...',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: AppTheme.textMedium,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  // Progress indicator with percentage
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: _progress,
                            backgroundColor: Colors.grey[200],
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppTheme.primaryColor,
                            ),
                            minHeight: 8,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${(_progress * 100).toInt()}%',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: AppTheme.textMedium,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else if (_error != null) ...[
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.red[200]!),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.red[50],
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.error_outline_rounded,
                            size: 48,
                            color: Colors.red[400],
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          _errorTitle ?? 'Error',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textDark,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        if (_errorDetails != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            _errorDetails!,
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: AppTheme.textMedium,
                              height: 1.5,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                },
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(color: AppTheme.primaryColor),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: Text(
                                  'Go Back',
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.primaryColor,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () {
                                  safeSetState(() {
                                    _isGenerating = true;
                                    _error = null;
                                    _errorTitle = null;
                                    _errorDetails = null;
                                    _progress = 0.0;
                                    _status = 'Analyzing content...';
                                  });
                                  _simulateProgress();
                                  _generateGame();
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primaryColor,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  elevation: 0,
                                ),
                                child: Text(
                                  'Try Again',
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.accentGreen.withOpacity(0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppTheme.accentGreen.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.check_circle_rounded,
                            size: 48,
                            color: AppTheme.accentGreen,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          _status,
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textDark,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                },
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(color: AppTheme.primaryColor),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: Text(
                                  'Upload Another',
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.primaryColor,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () {
                                  Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          GameLibraryScreen(childId: widget.childId),
                                    ),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primaryColor,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  elevation: 0,
                                ),
                                child: Text(
                                  'View Games',
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
