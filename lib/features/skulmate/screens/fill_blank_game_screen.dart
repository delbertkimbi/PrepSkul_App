import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:confetti/confetti.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/core/utils/safe_set_state.dart';
import 'package:prepskul/core/services/log_service.dart';
import 'dart:async';
import 'dart:math';
import '../models/game_model.dart';
import '../models/game_stats_model.dart';
import '../services/skulmate_service.dart';
import '../services/game_sound_service.dart';
import '../services/game_stats_service.dart';
import '../services/character_selection_service.dart';
import 'game_results_screen.dart';

/// Fill-in-the-blank game screen
class FillBlankGameScreen extends StatefulWidget {
  final GameModel game;

  const FillBlankGameScreen({Key? key, required this.game}) : super(key: key);

  @override
  State<FillBlankGameScreen> createState() => _FillBlankGameScreenState();
}

class _FillBlankGameScreenState extends State<FillBlankGameScreen>
    with TickerProviderStateMixin {
  int _currentQuestionIndex = 0;
  final Map<int, TextEditingController> _controllers = {};
  final Map<int, String> _userAnswers = {}; // questionIndex -> answer
  final Map<int, bool> _answeredQuestions = {}; // questionIndex -> isCorrect
  int _score = 0;
  int _currentStreak = 0;
  int _xpEarned = 0;
  DateTime? _startTime;
  final GameSoundService _soundService = GameSoundService();
  late ConfettiController _confettiController;
  late AnimationController _progressController;
  late Animation<double> _progressAnimation;
  late AnimationController _timerController;
  late Animation<double> _timerAnimation;
  late AnimationController _typingController;
  dynamic _character;
  GameStats? _currentStats;
  
  // Typing game mechanics
  int _timePerQuestion = 45; // seconds
  int _remainingTime = 45;
  Timer? _questionTimer;
  bool _isTimerRunning = false;
  List<String> _hints = []; // Auto-complete hints
  bool _hintShown = false;
  int _typingSpeed = 0; // Characters per second
  DateTime? _typingStartTime;
  int _charactersTyped = 0;

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
    _timerController = AnimationController(
      vsync: this,
      duration: Duration(seconds: _timePerQuestion),
    );
    _timerAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _timerController, curve: Curves.linear),
    );
    _typingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    // Initialize controllers
    for (int i = 0; i < widget.game.items.length; i++) {
      _controllers[i] = TextEditingController();
      _controllers[i]!.addListener(() => _onTextChanged(i));
    }
    _loadCharacter();
    _loadStats();
    _startQuestionTimer();
  }
  
  void _onTextChanged(int index) {
    if (index != _currentQuestionIndex) return;
    
    if (_typingStartTime == null) {
      _typingStartTime = DateTime.now();
    }
    
    final text = _controllers[index]?.text ?? '';
    _charactersTyped = text.length;
    
    // Generate hints based on partial input
    _generateHints(text);
  }
  
  void _generateHints(String partial) {
    if (partial.isEmpty || partial.length < 2) {
      safeSetState(() {
        _hints = [];
        _hintShown = false;
      });
      return;
    }
    
    final question = widget.game.items[_currentQuestionIndex];
    final correctAnswer = (question.correctAnswer ?? '').toString().toLowerCase();
    final partialLower = partial.toLowerCase();
    
    // Simple hint generation - show if partial matches start of answer
    if (correctAnswer.startsWith(partialLower)) {
      final remaining = correctAnswer.substring(partialLower.length);
      if (remaining.isNotEmpty) {
        safeSetState(() {
          _hints = [remaining.substring(0, remaining.length > 10 ? 10 : remaining.length)];
          _hintShown = true;
        });
      }
    } else {
      safeSetState(() {
        _hints = [];
        _hintShown = false;
      });
    }
  }
  
  void _startQuestionTimer() {
    _questionTimer?.cancel();
    _remainingTime = _timePerQuestion;
    _isTimerRunning = true;
    _hintShown = false;
    _typingStartTime = null;
    _charactersTyped = 0;
    
    _timerController.reset();
    _timerController.forward();
    
    _questionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || !_isTimerRunning) {
        timer.cancel();
        return;
      }
      
      safeSetState(() {
        _remainingTime--;
      });
      
      if (_remainingTime <= 0) {
        timer.cancel();
        _isTimerRunning = false;
        _onTimerExpired();
      }
    });
  }
  
  void _onTimerExpired() {
    if (_answeredQuestions.containsKey(_currentQuestionIndex)) return;
    
    final answer = _controllers[_currentQuestionIndex]?.text.trim() ?? '';
    if (answer.isNotEmpty) {
      _submitAnswer();
    } else {
      // Time's up - mark as incorrect
      safeSetState(() {
        _answeredQuestions[_currentQuestionIndex] = false;
        _currentStreak = 0;
      });
      _soundService.playIncorrect();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '⏰ Time\'s up!',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          ),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 1),
        ),
      );
      
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) _nextQuestion();
      });
    }
  }

  @override
  void dispose() {
    _questionTimer?.cancel();
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    _progressController.dispose();
    _timerController.dispose();
    _typingController.dispose();
    _confettiController.dispose();
    super.dispose();
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

  void _submitAnswer() {
    _questionTimer?.cancel();
    _isTimerRunning = false;
    
    final answer = _controllers[_currentQuestionIndex]?.text.trim() ?? '';
    if (answer.isEmpty) return;

    final question = widget.game.items[_currentQuestionIndex];
    final correctAnswer = (question.correctAnswer ?? '').toString().toLowerCase().trim();
    final userAnswer = answer.toLowerCase().trim();
    final isCorrect = userAnswer == correctAnswer;
    
    // Calculate typing speed bonus
    int speedBonus = 0;
    if (_typingStartTime != null && _charactersTyped > 0) {
      final timeTaken = DateTime.now().difference(_typingStartTime!).inSeconds;
      if (timeTaken > 0) {
        _typingSpeed = (_charactersTyped / timeTaken).round();
        if (_typingSpeed > 3 && isCorrect) speedBonus = 5; // Fast typing bonus
      }
    }
    
    // Calculate XP with streak multiplier
    int baseXP = 10;
    int streakMultiplier = _currentStreak > 0 ? (1 + (_currentStreak ~/ 3)) : 1;
    int timeBonus = _remainingTime > 30 ? 5 : 0; // Quick answer bonus
    int xpForThisAnswer = (baseXP * streakMultiplier) + speedBonus + timeBonus;

    safeSetState(() {
      _userAnswers[_currentQuestionIndex] = answer;
      _answeredQuestions[_currentQuestionIndex] = isCorrect;
      if (isCorrect) {
        _score++;
        _currentStreak++;
        _xpEarned += xpForThisAnswer;
        _soundService.playCorrect();
        // Trigger confetti
        _confettiController.play();
      } else {
        _currentStreak = 0; // Reset streak on wrong answer
        _soundService.playIncorrect();
      }
      _hints = [];
      _hintShown = false;
    });

    // Update progress bar animation
    final newProgress = (_currentQuestionIndex + 1) / widget.game.items.length;
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
            Expanded(
              child: Text(
                isCorrect ? 'Correct! 🎉' : 'Incorrect. The answer is: ${question.correctAnswer}',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
            ),
            if (isCorrect) ...[
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
        backgroundColor: isCorrect ? AppTheme.accentGreen : Colors.red,
        duration: const Duration(seconds: 2),
      ),
    );

    // Move to next question after delay
    Future.delayed(const Duration(milliseconds: 2000), () {
      if (mounted) {
        _nextQuestion();
      }
    });
  }

  void _nextQuestion() {
    _soundService.playClick();
    _questionTimer?.cancel();
    _isTimerRunning = false;
    
    if (_currentQuestionIndex < widget.game.items.length - 1) {
      safeSetState(() {
        _currentQuestionIndex++;
        _hints = [];
        _hintShown = false;
        _typingStartTime = null;
        _charactersTyped = 0;
      });
      // Animate progress bar
      final newProgress = (_currentQuestionIndex + 1) / widget.game.items.length;
      _progressAnimation = Tween<double>(
        begin: _progressAnimation.value,
        end: newProgress,
      ).animate(CurvedAnimation(
        parent: _progressController,
        curve: Curves.easeOut,
      ));
      _progressController.forward(from: 0);
      _startQuestionTimer(); // Start timer for next question
    } else {
      _finishGame();
    }
  }

  void _previousQuestion() {
    _soundService.playClick();
    if (_currentQuestionIndex > 0) {
      safeSetState(() {
        _currentQuestionIndex--;
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
      LogService.error('🎮 [FillBlank] Error updating game stats: $e');
    }

    // Save session
    try {
      await SkulMateService.saveGameSession(
        gameId: widget.game.id,
        score: _score,
        totalQuestions: widget.game.items.length,
        correctAnswers: _score,
        timeTakenSeconds: timeTaken,
        answers: _userAnswers.map((key, value) => MapEntry(key.toString(), value)),
      );
    } catch (e) {
      LogService.error('🎮 [FillBlank] Error saving game session: $e');
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
    final question = widget.game.items[_currentQuestionIndex];
    final isAnswered = _answeredQuestions.containsKey(_currentQuestionIndex);
    final isCorrect = _answeredQuestions[_currentQuestionIndex] ?? false;

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
                  'Score: $_score/${widget.game.items.length}',
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
              // Timer bar
              AnimatedBuilder(
                animation: _timerAnimation,
                builder: (context, child) {
                  final isLowTime = _remainingTime <= 10;
                  return Container(
                    height: 4,
                    child: LinearProgressIndicator(
                      value: _timerAnimation.value,
                      backgroundColor: Colors.grey[100],
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isLowTime ? Colors.red : AppTheme.accentGreen,
                      ),
                    ),
                  );
                },
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Timer and typing stats
                      Row(
                        children: [
                          // Timer
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: _remainingTime <= 10 ? Colors.red.withOpacity(0.1) : Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _remainingTime <= 10 ? Colors.red : AppTheme.accentGreen,
                                  width: 2,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.timer,
                                    color: _remainingTime <= 10 ? Colors.red : AppTheme.accentGreen,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '$_remainingTime',
                                    style: GoogleFonts.poppins(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      color: _remainingTime <= 10 ? Colors.red : AppTheme.accentGreen,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (_typingSpeed > 0 && !isAnswered) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.blue, width: 1),
                              ),
                              child: Text(
                                '⚡ $_typingSpeed c/s',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.blue,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Question with blank
                      Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          question.blankText ?? '',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            color: AppTheme.textDark,
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Answer input with auto-complete
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextField(
                              controller: _controllers[_currentQuestionIndex],
                              enabled: !isAnswered,
                              autofocus: !isAnswered,
                              decoration: InputDecoration(
                                hintText: 'Type your answer...',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                filled: true,
                                fillColor: isAnswered
                                    ? (isCorrect
                                        ? AppTheme.accentGreen.withOpacity(0.1)
                                        : Colors.red.withOpacity(0.1))
                                    : Colors.grey[50],
                                suffixIcon: isAnswered
                                    ? Icon(
                                        isCorrect ? Icons.check_circle : Icons.cancel,
                                        color: isCorrect ? AppTheme.accentGreen : Colors.red,
                                      )
                                    : _hintShown && _hints.isNotEmpty
                                        ? IconButton(
                                            icon: const Icon(Icons.lightbulb_outline, color: Colors.amber),
                                            onPressed: () {
                                              _soundService.playClick();
                                              final currentText = _controllers[_currentQuestionIndex]?.text ?? '';
                                              _controllers[_currentQuestionIndex]?.text = currentText + _hints[0];
                                              _generateHints(_controllers[_currentQuestionIndex]!.text);
                                            },
                                            tooltip: 'Use hint',
                                          )
                                        : null,
                              ),
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                                color: AppTheme.textDark,
                              ),
                              onSubmitted: (_) {
                                if (!isAnswered) {
                                  _submitAnswer();
                                }
                              },
                            ),
                            // Auto-complete hint
                            if (_hintShown && _hints.isNotEmpty && !isAnswered)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.amber, width: 1),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.lightbulb, color: Colors.amber, size: 20),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Hint: Continue with "${_hints[0]}"',
                                          style: GoogleFonts.poppins(
                                            fontSize: 13,
                                            color: Colors.amber[900],
                                            fontStyle: FontStyle.italic,
                                          ),
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          _soundService.playClick();
                                          final currentText = _controllers[_currentQuestionIndex]?.text ?? '';
                                          _controllers[_currentQuestionIndex]?.text = currentText + _hints[0];
                                          _generateHints(_controllers[_currentQuestionIndex]!.text);
                                        },
                                        child: Text(
                                          'Use',
                                          style: GoogleFonts.poppins(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.amber[900],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                        if (isAnswered && !isCorrect) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.info_outline, color: Colors.blue, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Correct answer: ${question.correctAnswer}',
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      color: Colors.blue[900],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                      ),
                      const SizedBox(height: 24),
                      // Submit button
                      if (!isAnswered)
                        ElevatedButton(
                      onPressed: () {
                        final answer = _controllers[_currentQuestionIndex]?.text.trim() ?? '';
                        if (answer.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please enter an answer'),
                              backgroundColor: Colors.orange,
                            ),
                          );
                          return;
                        }
                        _submitAnswer();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        _currentQuestionIndex == widget.game.items.length - 1
                            ? 'Finish Quiz'
                            : 'Submit Answer',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      ),
                      // Navigation buttons
                      if (isAnswered) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            if (_currentQuestionIndex > 0)
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: _previousQuestion,
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: Text(
                                    'Previous',
                                    style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            if (_currentQuestionIndex > 0) const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _nextQuestion,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primaryColor,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: Text(
                                  _currentQuestionIndex == widget.game.items.length - 1
                                      ? 'View Results'
                                      : 'Next',
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
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
}
