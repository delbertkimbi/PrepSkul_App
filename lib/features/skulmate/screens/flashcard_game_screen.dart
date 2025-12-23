import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/core/utils/safe_set_state.dart';
import '../models/game_model.dart';
import '../services/skulmate_service.dart';
import '../services/game_sound_service.dart';
import 'game_results_screen.dart';

/// Flashcard game screen with flip animation
class FlashcardGameScreen extends StatefulWidget {
  final GameModel game;

  const FlashcardGameScreen({Key? key, required this.game}) : super(key: key);

  @override
  State<FlashcardGameScreen> createState() => _FlashcardGameScreenState();
}

class _FlashcardGameScreenState extends State<FlashcardGameScreen>
    with SingleTickerProviderStateMixin {
  int _currentCardIndex = 0;
  bool _isFlipped = false;
  final Map<int, bool> _knownCards = {}; // cardIndex -> isKnown
  int _score = 0;
  DateTime? _startTime;
  late AnimationController _flipController;
  late Animation<double> _flipAnimation;
  final GameSoundService _soundService = GameSoundService();

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();
    _soundService.initialize();
    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _flipAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _flipController.dispose();
    super.dispose();
  }

  void _flipCard() {
    if (_flipController.isAnimating) return;

    if (_isFlipped) {
      _flipController.reverse();
    } else {
      _flipController.forward();
      _soundService.playFlip();
    }
    safeSetState(() {
      _isFlipped = !_isFlipped;
    });
  }

  void _markAsKnown(bool isKnown) {
    safeSetState(() {
      _knownCards[_currentCardIndex] = isKnown;
      if (isKnown) {
        _score++;
        _soundService.playCorrect();
      } else {
        _soundService.playIncorrect();
      }
    });

    // Move to next card
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        _nextCard();
      }
    });
  }

  void _nextCard() {
    if (_currentCardIndex < widget.game.items.length - 1) {
      safeSetState(() {
        _currentCardIndex++;
        _isFlipped = false;
        _flipController.reset();
      });
    } else {
      _finishGame();
    }
  }

  void _previousCard() {
    if (_currentCardIndex > 0) {
      safeSetState(() {
        _currentCardIndex--;
        _isFlipped = false;
        _flipController.reset();
      });
    }
  }

  Future<void> _finishGame() async {
    final endTime = DateTime.now();
    final timeTaken = _startTime != null
        ? endTime.difference(_startTime!).inSeconds
        : null;

    // Save session
    try {
      await SkulMateService.saveGameSession(
        gameId: widget.game.id,
        score: _score,
        totalQuestions: widget.game.items.length,
        correctAnswers: _score,
        timeTakenSeconds: timeTaken,
        answers: _knownCards.map((key, value) => MapEntry(key.toString(), value)),
      );
    } catch (e) {
      print('Error saving game session: $e');
    }

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => GameResultsScreen(
            game: widget.game,
            score: _score,
            totalQuestions: widget.game.items.length,
            timeTakenSeconds: timeTaken,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final card = widget.game.items[_currentCardIndex];
    final progress = (_currentCardIndex + 1) / widget.game.items.length;

    return Scaffold(
      backgroundColor: AppTheme.softBackground,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          widget.game.title,
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppTheme.textDark,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Known: $_score/${widget.game.items.length}',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.primaryColor,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Progress bar
          LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
            minHeight: 4,
          ),
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Card counter
                    Text(
                      'Card ${_currentCardIndex + 1} of ${widget.game.items.length}',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: AppTheme.textMedium,
                      ),
                    ),
                    const SizedBox(height: 32),
                    // Flashcard
                    GestureDetector(
                      onTap: _flipCard,
                      child: AnimatedBuilder(
                        animation: _flipAnimation,
                        builder: (context, child) {
                          final angle = _flipAnimation.value * 3.14159; // π
                          final isFront = _flipAnimation.value < 0.5;

                          return Transform(
                            alignment: Alignment.center,
                            transform: Matrix4.identity()
                              ..setEntry(3, 2, 0.001)
                              ..rotateY(angle),
                            child: isFront
                                ? _buildCardFront(card)
                                : _buildCardBack(card),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 32),
                    // Action buttons
                    if (_isFlipped) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _markAsKnown(false),
                              icon: const Icon(Icons.close),
                              label: const Text('Don\'t Know'),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _markAsKnown(true),
                              icon: const Icon(Icons.check),
                              label: const Text('I Know This'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.accentGreen,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      Text(
                        'Tap card to flip',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: AppTheme.textMedium,
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    // Navigation
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_currentCardIndex > 0)
                          IconButton(
                            onPressed: _previousCard,
                            icon: const Icon(Icons.arrow_back),
                            tooltip: 'Previous',
                          ),
                        const SizedBox(width: 16),
                        if (_currentCardIndex < widget.game.items.length - 1)
                          IconButton(
                            onPressed: _nextCard,
                            icon: const Icon(Icons.arrow_forward),
                            tooltip: 'Next',
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardFront(GameItem card) {
    return Container(
      width: double.infinity,
      height: 300,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryColor,
            AppTheme.primaryColor.withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Center(
        child: Text(
          card.term ?? '',
          style: GoogleFonts.poppins(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildCardBack(GameItem card) {
    return Container(
      width: double.infinity,
      height: 300,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Center(
        child: Text(
          card.definition ?? '',
          style: GoogleFonts.poppins(
            fontSize: 18,
            color: AppTheme.textDark,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

