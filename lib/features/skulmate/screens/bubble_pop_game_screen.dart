import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:confetti/confetti.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/core/utils/safe_set_state.dart';
import 'package:prepskul/core/services/log_service.dart';
import '../models/game_model.dart';
import '../services/skulmate_service.dart';
import '../services/game_sound_service.dart';
import '../services/character_selection_service.dart';
import '../services/game_stats_service.dart';
import '../models/game_stats_model.dart';
import '../widgets/skulmate_character_widget.dart';
import 'game_results_screen.dart';

/// Bubble Pop game screen
class BubblePopGameScreen extends StatefulWidget {
  final GameModel game;

  const BubblePopGameScreen({Key? key, required this.game}) : super(key: key);

  @override
  State<BubblePopGameScreen> createState() => _BubblePopGameScreenState();
}

class BubbleData {
  final int id;
  final String text;
  final bool isCorrect;
  final Offset position;
  final double velocity;

  BubbleData({
    required this.id,
    required this.text,
    required this.isCorrect,
    required this.position,
    this.velocity = 1.0,
  });
}

class _BubblePopGameScreenState extends State<BubblePopGameScreen>
    with TickerProviderStateMixin {
  final List<BubbleData> _bubbles = [];
  int _score = 0;
  int _correctPops = 0;
  int _currentStreak = 0;
  int _xpEarned = 0;
  DateTime? _startTime;
  final GameSoundService _soundService = GameSoundService();
  late ConfettiController _confettiController;
  late AnimationController _progressController;
  late Animation<double> _progressAnimation;
  late AnimationController _bubbleController;
  dynamic _character;
  GameStats? _currentStats;
  Timer? _bubbleTimer;
  int _totalBubbles = 0;

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();
    _soundService.initialize();
    _confettiController = ConfettiController(duration: const Duration(seconds: 2));
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _progressAnimation = Tween<double>(begin: 0, end: 0).animate(
      CurvedAnimation(parent: _progressController, curve: Curves.easeOut),
    );
    _bubbleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
    _initializeBubbles();
    _loadCharacter();
    _loadStats();
    _startBubbleGeneration();
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

  void _initializeBubbles() {
    // Get bubbles from game items
    if (widget.game.items.isNotEmpty && widget.game.items[0].bubbles != null) {
      final bubbles = widget.game.items[0].bubbles!;
      _totalBubbles = bubbles.length;
      for (int i = 0; i < bubbles.length; i++) {
        final bubble = bubbles[i];
        _bubbles.add(BubbleData(
          id: i,
          text: bubble['text'] as String? ?? 'Bubble $i',
          isCorrect: bubble['correctAnswer'] as bool? ?? false,
          position: Offset(
            Random().nextDouble() * 300 + 50,
            Random().nextDouble() * 400 + 100,
          ),
        ));
      }
    } else {
      // Create bubbles from game items
      _totalBubbles = widget.game.items.length;
      for (int i = 0; i < widget.game.items.length; i++) {
        final item = widget.game.items[i];
        _bubbles.add(BubbleData(
          id: i,
          text: item.term ?? item.question ?? 'Bubble $i',
          isCorrect: Random().nextBool(),
          position: Offset(
            Random().nextDouble() * 300 + 50,
            Random().nextDouble() * 400 + 100,
          ),
        ));
      }
    }
  }

  void _startBubbleGeneration() {
    _bubbleTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (_bubbles.length < _totalBubbles * 2) {
        safeSetState(() {
          _bubbles.add(BubbleData(
            id: _bubbles.length,
            text: 'New Bubble',
            isCorrect: Random().nextBool(),
            position: Offset(
              Random().nextDouble() * 300 + 50,
              -50,
            ),
          ));
        });
      }
    });
  }

  void _popBubble(int id) {
    final bubble = _bubbles.firstWhere((b) => b.id == id);
    safeSetState(() {
      _bubbles.removeWhere((b) => b.id == id);
      if (bubble.isCorrect) {
        _score += 10;
        _correctPops++;
        _currentStreak++;
        _xpEarned += 5;
        _soundService.playCorrect();
        _confettiController.play();
      } else {
        _currentStreak = 0;
        _soundService.playIncorrect();
      }
    });

    // Update progress
    final newProgress = _correctPops / _totalBubbles;
    _progressAnimation = Tween<double>(
      begin: _progressAnimation.value,
      end: newProgress.clamp(0.0, 1.0),
    ).animate(CurvedAnimation(
      parent: _progressController,
      curve: Curves.easeOut,
    ));
    _progressController.forward(from: 0);

    // Check if game complete
    if (_correctPops >= _totalBubbles) {
      Future.delayed(const Duration(milliseconds: 500), () {
        _finishGame();
      });
    }
  }

  Future<void> _finishGame() async {
    final endTime = DateTime.now();
    final timeTaken = _startTime != null
        ? endTime.difference(_startTime!).inSeconds
        : null;

    final isPerfectScore = _correctPops == _totalBubbles;

    int bonusXP = 0;
    if (isPerfectScore) bonusXP += 50;
    if (timeTaken != null && timeTaken < 120) bonusXP += 25;
    final totalXP = _xpEarned + bonusXP;

    try {
      await GameStatsService.addGameResult(
        correctAnswers: _correctPops,
        totalQuestions: _totalBubbles,
        timeTakenSeconds: timeTaken ?? 0,
        isPerfectScore: isPerfectScore,
      );
    } catch (e) {
      LogService.error('🎮 [BubblePop] Error updating game stats: $e');
    }

    try {
      await SkulMateService.saveGameSession(
        gameId: widget.game.id,
        score: _score,
        totalQuestions: _totalBubbles,
        correctAnswers: _correctPops,
        timeTakenSeconds: timeTaken,
        answers: {'pops': _correctPops},
      );
    } catch (e) {
      LogService.error('🎮 [BubblePop] Error saving game session: $e');
    }

    await _soundService.playComplete();
    
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => GameResultsScreen(
            game: widget.game,
            score: _score,
            totalQuestions: _totalBubbles,
            timeTakenSeconds: timeTaken,
            xpEarned: totalXP,
            isPerfectScore: isPerfectScore,
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _bubbleTimer?.cancel();
    _progressController.dispose();
    _bubbleController.dispose();
    _confettiController.dispose();
    super.dispose();
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
                  'Score: $_score',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryColor,
                  ),
                ),
                Text(
                  'Pops: $_correctPops/$_totalBubbles',
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
                child: Stack(
                  children: _bubbles.map((bubble) {
                    return Positioned(
                      left: bubble.position.dx,
                      top: bubble.position.dy,
                      child: GestureDetector(
                        onTap: () => _popBubble(bubble.id),
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: bubble.isCorrect
                                ? AppTheme.primaryColor.withOpacity(0.8)
                                : Colors.red.withOpacity(0.8),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              bubble.text,
                              style: GoogleFonts.poppins(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              if (_character != null)
                SkulMateCharacterWidget(
                  character: _character,
                  size: 80,
                ),
            ],
          ),
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirection: 3.14 / 2,
              maxBlastForce: 5,
              minBlastForce: 2,
              emissionFrequency: 0.05,
              numberOfParticles: 20,
              gravity: 0.1,
            ),
          ),
        ],
      ),
    );
  }
}

