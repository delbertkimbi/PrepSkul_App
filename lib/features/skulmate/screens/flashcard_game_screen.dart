import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:confetti/confetti.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/core/utils/safe_set_state.dart';
import 'package:prepskul/core/services/log_service.dart';
import 'dart:math';
import '../models/game_model.dart';
import '../models/game_stats_model.dart';
import '../services/skulmate_service.dart';
import '../services/game_sound_service.dart';
import '../services/tts_service.dart';
import '../services/game_stats_service.dart';
import '../services/character_selection_service.dart';
import '../widgets/skulmate_character_widget.dart';
import 'game_results_screen.dart';

/// Flashcard game screen with flip animation
class FlashcardGameScreen extends StatefulWidget {
  final GameModel game;

  const FlashcardGameScreen({Key? key, required this.game}) : super(key: key);

  @override
  State<FlashcardGameScreen> createState() => _FlashcardGameScreenState();
}

class _FlashcardGameScreenState extends State<FlashcardGameScreen>
    with TickerProviderStateMixin {
  int _currentCardIndex = 0;
  bool _isFlipped = false;
  final Map<int, bool> _knownCards = {}; // cardIndex -> isKnown
  int _score = 0;
  int _currentStreak = 0;
  int _xpEarned = 0;
  DateTime? _startTime;
  late AnimationController _flipController;
  late Animation<double> _flipAnimation;
  late AnimationController _progressController;
  late Animation<double> _progressAnimation;
  late AnimationController _swipeController;
  late Animation<Offset> _swipeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;
  final GameSoundService _soundService = GameSoundService();
  final TTSService _ttsService = TTSService();
  late ConfettiController _confettiController;
  dynamic _character; // Will be SkulMateCharacter
  GameStats? _currentStats;
  bool _isTTSEnabled = true;
  
  // Swipe mechanics
  double _dragPosition = 0;
  bool _isDragging = false;
  Offset _dragOffset = Offset.zero;
  
  // Card stack - show next 2 cards
  static const int _stackSize = 3;

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();
    _soundService.initialize();
    _ttsService.initialize();
    _confettiController = ConfettiController(duration: const Duration(seconds: 2));
    // Speak first card term
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted && _isTTSEnabled) {
        _speakCurrentCard();
      }
    });
    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _flipAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOut),
    );
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _progressAnimation = Tween<double>(begin: 0, end: 0).animate(
      CurvedAnimation(parent: _progressController, curve: Curves.easeOut),
    );
    _swipeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _swipeAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(2, 0), // Default right swipe
    ).animate(CurvedAnimation(
      parent: _swipeController,
      curve: Curves.easeOut,
    ));
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.8).animate(
      CurvedAnimation(parent: _swipeController, curve: Curves.easeOut),
    );
    _rotationAnimation = Tween<double>(begin: 0, end: 0.2).animate(
      CurvedAnimation(parent: _swipeController, curve: Curves.easeOut),
    );
    _loadCharacter();
    _loadStats();
  }

  @override
  void dispose() {
    _flipController.dispose();
    _ttsService.dispose();
    _progressController.dispose();
    _swipeController.dispose();
    _confettiController.dispose();
    super.dispose();
  }
  
  void _handleSwipe(bool isKnown) {
    if (_swipeController.isAnimating) return;
    
    // Set swipe direction
    _swipeAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: Offset(isKnown ? 2 : -2, 0), // Right for known, left for unknown
    ).animate(CurvedAnimation(
      parent: _swipeController,
      curve: Curves.easeOut,
    ));
    
    _soundService.playFlip();
    _swipeController.forward().then((_) {
      _markAsKnown(isKnown);
      _swipeController.reset();
    });
  }
  
  void _onPanUpdate(DragUpdateDetails details) {
    if (!_isFlipped) return; // Only allow swipe when card is flipped
    
    setState(() {
      _isDragging = true;
      _dragOffset += details.delta;
      _dragPosition = _dragOffset.dx;
    });
  }
  
  void _onPanEnd(DragEndDetails details) {
    if (!_isDragging) return;
    
    final swipeThreshold = 100.0;
    final velocity = details.velocity.pixelsPerSecond.dx;
    
    if (_dragPosition.abs() > swipeThreshold || velocity.abs() > 500) {
      // Swipe detected
      if (_dragPosition > 0 || velocity > 500) {
        // Swipe right - I know this
        _handleSwipe(true);
      } else {
        // Swipe left - Don't know
        _handleSwipe(false);
      }
    } else {
      // Snap back
      setState(() {
        _dragPosition = 0;
        _dragOffset = Offset.zero;
        _isDragging = false;
      });
    }
  }

  Future<void> _loadStats() async {
    final stats = await GameStatsService.getStats();
    safeSetState(() {
      _currentStats = stats;
      _currentStreak = stats.currentStreak;
    });
  }

  Future<void> _loadCharacter() async {
    final character = await CharacterSelectionService.getSelectedCharacter();
    safeSetState(() {
      _character = character;
    });
  }

  void _flipCard() {
    if (_flipController.isAnimating) return;

    if (_isFlipped) {
      _flipController.reverse();
      // Speak term when flipping back
      if (_isTTSEnabled) {
        _speakCurrentCard();
      }
    } else {
      _flipController.forward();
      _soundService.playFlip();
      // Speak definition when flipped
      if (_isTTSEnabled) {
        final card = widget.game.items[_currentCardIndex];
        final definition = card.definition ?? '';
        if (definition.isNotEmpty) {
          _ttsService.speak(definition);
        }
      }
    }
    safeSetState(() {
      _isFlipped = !_isFlipped;
    });
  }

  void _speakCurrentCard() {
    if (!_isTTSEnabled) return;
    final card = widget.game.items[_currentCardIndex];
    final term = card.term ?? '';
    if (term.isNotEmpty) {
      _ttsService.speak(term);
    }
  }

  void _markAsKnown(bool isKnown) {
    // Calculate XP with streak multiplier
    int baseXP = 10;
    int streakMultiplier = _currentStreak > 0 ? (1 + (_currentStreak ~/ 3)) : 1;
    int xpForThisCard = baseXP * streakMultiplier;
    
    safeSetState(() {
      _knownCards[_currentCardIndex] = isKnown;
      if (isKnown) {
        _score++;
        _currentStreak++;
        _xpEarned += xpForThisCard;
        _soundService.playCorrect();
        // Trigger confetti
        _confettiController.play();
      } else {
        _currentStreak = 0; // Reset streak on wrong answer
        _soundService.playIncorrect();
      }
      _dragPosition = 0;
      _dragOffset = Offset.zero;
      _isDragging = false;
    });

    // Update progress bar animation
    final newProgress = (_currentCardIndex + 1) / widget.game.items.length;
    _progressAnimation = Tween<double>(
      begin: _progressAnimation.value,
      end: newProgress,
    ).animate(CurvedAnimation(
      parent: _progressController,
      curve: Curves.easeOut,
    ));
    _progressController.forward(from: 0);

    // Show feedback with XP
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Text(
              isKnown ? 'Great! 🎉' : 'Keep practicing!',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
            if (isKnown) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '+10 XP',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
              if (_currentStreak > 1) ...[
                const SizedBox(width: 4),
                Text(
                  '🔥 $_currentStreak',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ],
          ],
        ),
        backgroundColor: isKnown ? AppTheme.accentGreen : Colors.orange,
        duration: const Duration(seconds: 2),
      ),
    );

    // Move to next card
    Future.delayed(const Duration(milliseconds: 2000), () {
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
        _dragPosition = 0;
        _dragOffset = Offset.zero;
        _isDragging = false;
      });
      // Speak next card
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted && _isTTSEnabled) {
          _speakCurrentCard();
        }
      });
      // Animate progress bar
      final newProgress = (_currentCardIndex + 1) / widget.game.items.length;
      _progressAnimation = Tween<double>(
        begin: _progressAnimation.value,
        end: newProgress,
      ).animate(CurvedAnimation(
        parent: _progressController,
        curve: Curves.easeOut,
      ));
      _progressController.forward(from: 0);
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

    final isPerfectScore = _score == widget.game.items.length;

    // Calculate bonus XP
    int bonusXP = 0;
    if (isPerfectScore) bonusXP += 50;
    if (timeTaken != null && timeTaken < 120) bonusXP += 25;
    final totalXP = _xpEarned + bonusXP;

    // Update game stats
    try {
      await GameStatsService.addGameResult(
        correctAnswers: _score,
        totalQuestions: widget.game.items.length,
        timeTakenSeconds: timeTaken ?? 0,
        isPerfectScore: isPerfectScore,
      );
    } catch (e) {
      LogService.error('🎮 [Flashcard] Error updating game stats: $e');
    }

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
      LogService.error('🎮 [Flashcard] Error saving game session: $e');
    }

    // Play completion sound
    await _soundService.playComplete();
    
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => GameResultsScreen(
            game: widget.game,
            score: _score,
            totalQuestions: widget.game.items.length,
            timeTakenSeconds: timeTaken,
            xpEarned: totalXP,
            isPerfectScore: isPerfectScore,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final card = widget.game.items[_currentCardIndex];

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
          IconButton(
            icon: Icon(
              _isTTSEnabled ? Icons.volume_up : Icons.volume_off,
              color: AppTheme.textDark,
            ),
            onPressed: () {
              safeSetState(() {
                _isTTSEnabled = !_isTTSEnabled;
                _ttsService.setEnabled(_isTTSEnabled);
              });
            },
          ),
          if (_currentStreak > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.orange, width: 1.5),
                ),
                child: Row(
                  children: [
                    const Text('🔥', style: TextStyle(fontSize: 16)),
                    const SizedBox(width: 4),
                    Text(
                      '$_currentStreak',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.orange[800],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Known: $_score/${widget.game.items.length}',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryColor,
                  ),
                ),
                if (_xpEarned > 0)
                  Text(
                    '$_xpEarned XP',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textMedium,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // Animated Progress bar
              AnimatedBuilder(
                animation: _progressAnimation,
                builder: (context, child) {
                  return LinearProgressIndicator(
                    value: _progressAnimation.value,
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                    minHeight: 6,
                  );
                },
              ),
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Card counter with smooth transition
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: Text(
                            'Card ${_currentCardIndex + 1} of ${widget.game.items.length}',
                            key: ValueKey(_currentCardIndex),
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: AppTheme.textMedium,
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                        // Card stack with swipe
                        Expanded(
                          child: SizedBox(
                            width: double.infinity,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                // Stack of next cards (background)
                                ...List.generate(
                                  _stackSize - 1,
                                  (index) {
                                    final cardIndex = _currentCardIndex + index + 1;
                                    if (cardIndex >= widget.game.items.length) {
                                      return const SizedBox.shrink();
                                    }
                                    final stackCard = widget.game.items[cardIndex];
                                    return Positioned(
                                      top: (index + 1) * 8.0,
                                      child: Transform.scale(
                                        scale: 1.0 - (index + 1) * 0.05,
                                        child: Opacity(
                                          opacity: 1.0 - (index + 1) * 0.3,
                                          child: _buildCardStackItem(stackCard, index + 1),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                // Current card (swipeable)
                                AnimatedBuilder(
                                  animation: _swipeController,
                                  builder: (context, child) {
                                    final dragOffset = _isDragging
                                        ? _dragOffset
                                        : Offset(_swipeAnimation.value.dx * MediaQuery.of(context).size.width, _swipeAnimation.value.dy);
                                    
                                    final rotation = _isDragging
                                        ? _dragPosition / 1000
                                        : _rotationAnimation.value;
                                    
                                    final scale = _isDragging
                                        ? 1.0 - (_dragPosition.abs() / 2000)
                                        : _scaleAnimation.value;
                                    
                                    final opacityValue = _isDragging
                                        ? (1.0 - (_dragPosition.abs() / 500))
                                        : (1.0 - (_swipeAnimation.value.dx.abs() / 2.0));
                                    final opacity = opacityValue.clamp(0.0, 1.0) as double;
                                    
                                    // Swipe direction indicators
                                    Color? swipeColor;
                                    IconData? swipeIcon;
                                    if (_isDragging) {
                                      if (_dragPosition > 50) {
                                        swipeColor = AppTheme.accentGreen;
                                        swipeIcon = Icons.check_circle;
                                      } else if (_dragPosition < -50) {
                                        swipeColor = Colors.red;
                                        swipeIcon = Icons.close;
                                      }
                                    }
                                    
                                    return Transform.translate(
                                      offset: dragOffset,
                                      child: Transform.rotate(
                                        angle: rotation,
                                        child: Transform.scale(
                                          scale: scale.clamp(0.8, 1.0) as double,
                                          child: Opacity(
                                            opacity: opacity,
                                            child: GestureDetector(
                                              onTap: _flipCard,
                                              onPanUpdate: _onPanUpdate,
                                              onPanEnd: _onPanEnd,
                                              child: AnimatedBuilder(
                                                animation: _flipAnimation,
                                                builder: (context, child) {
                                                  final angle = _flipAnimation.value * 3.14159;
                                                  final isFront = _flipAnimation.value < 0.5;
                                                  
                                                  return Stack(
                                                    children: [
                                                      Transform(
                                                        alignment: Alignment.center,
                                                        transform: Matrix4.identity()
                                                          ..setEntry(3, 2, 0.001)
                                                          ..rotateY(angle),
                                                        child: isFront
                                                            ? _buildCardFront(card)
                                                            : _buildCardBack(card),
                                                      ),
                                                      // Swipe indicator overlay
                                                      if (swipeColor != null && swipeIcon != null)
                                                        Positioned.fill(
                                                          child: Container(
                                                            decoration: BoxDecoration(
                                                              color: swipeColor!.withOpacity(0.2),
                                                              borderRadius: BorderRadius.circular(20),
                                                            ),
                                                            child: Center(
                                                              child: Icon(
                                                                swipeIcon,
                                                                size: 80,
                                                                color: swipeColor,
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                    ],
                                                  );
                                                },
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Action buttons and instructions
                        if (_isFlipped) ...[
                          Text(
                            'Swipe right if you know it, left if you don\'t',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: AppTheme.textMedium,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _handleSwipe(false),
                                  icon: const Icon(Icons.close, color: Colors.red),
                                  label: const Text('Don\'t Know'),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    side: const BorderSide(color: Colors.red),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () => _handleSwipe(true),
                                  icon: const Icon(Icons.check, color: Colors.white),
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
          // Confetti overlay
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirection: pi / 2, // Downward
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

  Widget _buildCardFront(GameItem card) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxHeight: 400),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primaryColor,
            AppTheme.primaryColor.withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Center(
        child: Text(
          card.term ?? '',
          style: GoogleFonts.poppins(
            fontSize: 28,
            fontWeight: FontWeight.w700,
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
      constraints: const BoxConstraints(maxHeight: 400),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Center(
        child: SingleChildScrollView(
          child: Text(
            card.definition ?? '',
            style: GoogleFonts.poppins(
              fontSize: 20,
              color: AppTheme.textDark,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
  
  Widget _buildCardStackItem(GameItem card, int index) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxHeight: 400),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey[300]!, width: 1),
      ),
      child: Center(
        child: Text(
          card.term ?? '',
          style: GoogleFonts.poppins(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: Colors.grey[600],
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
