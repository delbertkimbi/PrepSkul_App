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
import 'game_results_screen.dart';

class CardData {
  final int id;
  final String text;
  final int pairId;
  final bool isLeft;
  
  CardData({
    required this.id,
    required this.text,
    required this.pairId,
    required this.isLeft,
  });
}

/// Matching pairs game screen
class MatchingGameScreen extends StatefulWidget {
  final GameModel game;

  const MatchingGameScreen({Key? key, required this.game}) : super(key: key);

  @override
  State<MatchingGameScreen> createState() => _MatchingGameScreenState();
}

class _MatchingGameScreenState extends State<MatchingGameScreen>
    with TickerProviderStateMixin {
  // Memory game: All cards face down, flip to find pairs
  late List<CardData> _cards;
  final Set<int> _flippedCards = {}; // Currently flipped card indices
  final Map<int, int> _matchedPairs = {}; // cardIndex -> pairIndex
  int? _firstFlipped;
  int? _secondFlipped;
  int _moves = 0;
  int _score = 0;
  int _currentStreak = 0;
  int _xpEarned = 0;
  DateTime? _startTime;
  final GameSoundService _soundService = GameSoundService();
  final TTSService _ttsService = TTSService();
  late ConfettiController _confettiController;
  late AnimationController _progressController;
  late Animation<double> _progressAnimation;
  final Map<int, AnimationController> _flipControllers = {};
  final Map<int, Animation<double>> _flipAnimations = {};
  dynamic _character;
  GameStats? _currentStats;
  bool _isProcessing = false;
  bool _isTTSEnabled = true;

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();
    _soundService.initialize();
    _ttsService.initialize();
    _confettiController = ConfettiController(duration: const Duration(seconds: 2));
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _progressAnimation = Tween<double>(begin: 0, end: 0).animate(
      CurvedAnimation(parent: _progressController, curve: Curves.easeOut),
    );
    _initializeItems();
    _loadCharacter();
    _loadStats();
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

  void _initializeItems() {
    // Create pairs from game items
    final pairs = <CardData>[];
    for (int i = 0; i < widget.game.items.length; i++) {
      final item = widget.game.items[i];
      if (item.leftItem != null && item.leftItem!.isNotEmpty) {
        pairs.add(CardData(
          id: i * 2,
          text: item.leftItem!,
          pairId: i,
          isLeft: true,
        ));
      }
      if (item.rightItem != null && item.rightItem!.isNotEmpty) {
        pairs.add(CardData(
          id: i * 2 + 1,
          text: item.rightItem!,
          pairId: i,
          isLeft: false,
        ));
      }
    }
    
    // Shuffle cards
    _cards = pairs..shuffle(Random());
    
    // Initialize flip animations for each card
    for (int i = 0; i < _cards.length; i++) {
      final controller = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 300),
      );
      _flipControllers[i] = controller;
      _flipAnimations[i] = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: controller, curve: Curves.easeInOut),
      );
    }
  }
  
  @override
  void dispose() {
    for (final controller in _flipControllers.values) {
      controller.dispose();
    }
    _progressController.dispose();
    _confettiController.dispose();
    _ttsService.dispose();
    super.dispose();
  }

  void _flipCard(int index) {
    if (_isProcessing || 
        _flippedCards.contains(index) || 
        _matchedPairs.containsKey(index)) return;
    
    if (_firstFlipped == null) {
      // First card flipped
      safeSetState(() {
        _firstFlipped = index;
        _flippedCards.add(index);
        _moves++;
      });
      _flipControllers[index]?.forward();
      _soundService.playFlip();
      // Speak card text
      if (_isTTSEnabled) {
        _ttsService.speak(_cards[index].text);
      }
    } else if (_secondFlipped == null && _firstFlipped != index) {
      // Second card flipped
      safeSetState(() {
        _secondFlipped = index;
        _flippedCards.add(index);
        _isProcessing = true;
      });
      _flipControllers[index]?.forward();
      _soundService.playFlip();
      // Speak card text
      if (_isTTSEnabled) {
        _ttsService.speak(_cards[index].text);
      }
      
      // Check for match
      Future.delayed(const Duration(milliseconds: 500), () {
        _checkMatch();
      });
    }
  }
  
  void _checkMatch() {
    if (_firstFlipped == null || _secondFlipped == null) return;
    
    final card1 = _cards[_firstFlipped!];
    final card2 = _cards[_secondFlipped!];
    
    final isMatch = card1.pairId == card2.pairId && card1.isLeft != card2.isLeft;
    
    if (isMatch) {
      // Correct match!
      _soundService.playCorrect();
      if (_isTTSEnabled) {
        _ttsService.speak('Match! ${card1.text} and ${card2.text}');
      }
      safeSetState(() {
        _matchedPairs[_firstFlipped!] = card1.pairId;
        _matchedPairs[_secondFlipped!] = card2.pairId;
        _score++;
        _currentStreak++;
        _xpEarned += 15; // 15 XP per match
        _flippedCards.remove(_firstFlipped);
        _flippedCards.remove(_secondFlipped);
      });
      
      _soundService.playMatch();
      _confettiController.play();
      
      // Update progress
      final newProgress = _matchedPairs.length / 2 / widget.game.items.length;
      _progressAnimation = Tween<double>(
        begin: _progressAnimation.value,
        end: newProgress,
      ).animate(CurvedAnimation(
        parent: _progressController,
        curve: Curves.easeOut,
      ));
      _progressController.forward(from: 0);
      
      // Check if game complete
      if (_matchedPairs.length == _cards.length) {
        Future.delayed(const Duration(milliseconds: 500), () {
          _finishGame();
        });
      }
    } else {
      // Wrong match - flip back
      Future.delayed(const Duration(milliseconds: 1000), () {
        _flipControllers[_firstFlipped!]?.reverse();
        _flipControllers[_secondFlipped!]?.reverse();
        safeSetState(() {
          _flippedCards.remove(_firstFlipped);
          _flippedCards.remove(_secondFlipped);
          _currentStreak = 0;
        });
      });
      _soundService.playIncorrect();
    }
    
    safeSetState(() {
      _firstFlipped = null;
      _secondFlipped = null;
      _isProcessing = false;
    });
  }

  Future<void> _finishGame() async {
    final endTime = DateTime.now();
    final timeTaken = _startTime != null
        ? endTime.difference(_startTime!).inSeconds
        : null;

    final isPerfectScore = _score == widget.game.items.length;

    // Calculate bonus XP based on moves (fewer moves = more bonus)
    int bonusXP = 0;
    if (isPerfectScore) bonusXP += 50;
    if (timeTaken != null && timeTaken < 120) bonusXP += 25;
    final optimalMoves = widget.game.items.length * 2; // Minimum moves needed
    if (_moves <= optimalMoves * 1.5) bonusXP += 20; // Efficiency bonus
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
      LogService.error('🎮 [Matching] Error updating game stats: $e');
    }

    // Save session
    try {
      await SkulMateService.saveGameSession(
        gameId: widget.game.id,
        score: _score,
        totalQuestions: widget.game.items.length,
        correctAnswers: _score,
        timeTakenSeconds: timeTaken,
        answers: {'moves': _moves, 'pairs': _matchedPairs.length},
      );
    } catch (e) {
      LogService.error('🎮 [Matching] Error saving game session: $e');
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
                  'Matches: ${_matchedPairs.length ~/ 2}/${widget.game.items.length}',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryColor,
                  ),
                ),
                Text(
                  'Moves: $_moves',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textMedium,
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
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Game stats
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildStatCard('Moves', '$_moves', Icons.touch_app),
                          _buildStatCard('Matches', '${_matchedPairs.length ~/ 2}/${widget.game.items.length}', Icons.check_circle),
                          _buildStatCard('XP', '$_xpEarned', Icons.star),
                        ],
                      ),
                      const SizedBox(height: 20),
                      // Memory game grid
                      Expanded(
                        child: GridView.builder(
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: _cards.length <= 8 ? 2 : 3,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 0.75,
                          ),
                          itemCount: _cards.length,
                          itemBuilder: (context, index) {
                            final card = _cards[index];
                            final isFlipped = _flippedCards.contains(index);
                            final isMatched = _matchedPairs.containsKey(index);
                            final isSelected = _firstFlipped == index || _secondFlipped == index;
                            
                            return _buildMemoryCard(
                              card: card,
                              index: index,
                              isFlipped: isFlipped || isMatched,
                              isMatched: isMatched,
                              isSelected: isSelected,
                            );
                          },
                        ),
                      ),
                    ],
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
  
  Widget _buildStatCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: AppTheme.primaryColor, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppTheme.textDark,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: AppTheme.textMedium,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildMemoryCard({
    required CardData card,
    required int index,
    required bool isFlipped,
    required bool isMatched,
    required bool isSelected,
  }) {
    final flipAnimation = _flipAnimations[index] ?? _flipControllers[index]!.drive(
      Tween<double>(begin: 0, end: 1).chain(
        CurveTween(curve: Curves.easeInOut),
      ),
    );
    
    return GestureDetector(
      onTap: () => _flipCard(index),
      child: AnimatedBuilder(
        animation: flipAnimation,
        builder: (context, child) {
          final angle = flipAnimation.value * 3.14159;
          final isFront = flipAnimation.value < 0.5;
          
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateY(angle),
            child: isFront || (!isFlipped && !isMatched)
                ? _buildCardBack(isMatched, isSelected)
                : _buildCardFront(card, isMatched),
          );
        },
      ),
    );
  }
  
  Widget _buildCardBack(bool isMatched, bool isSelected) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isMatched
              ? [AppTheme.accentGreen, AppTheme.accentGreen.withOpacity(0.8)]
              : isSelected
                  ? [AppTheme.primaryColor, AppTheme.primaryColor.withOpacity(0.8)]
                  : [AppTheme.primaryColor, AppTheme.primaryColor.withOpacity(0.9)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Center(
        child: isMatched
            ? const Icon(Icons.check_circle, color: Colors.white, size: 40)
            : Icon(
                Icons.help_outline,
                color: Colors.white.withOpacity(0.9),
                size: 40,
              ),
      ),
    );
  }
  
  Widget _buildCardFront(CardData card, bool isMatched) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isMatched ? AppTheme.accentGreen.withOpacity(0.1) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isMatched ? AppTheme.accentGreen : Colors.grey[300]!,
          width: isMatched ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Center(
        child: Text(
          card.text,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppTheme.textDark,
          ),
          textAlign: TextAlign.center,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
