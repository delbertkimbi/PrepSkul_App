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

/// Quiz game screen with multiple choice questions
class QuizGameScreen extends StatefulWidget {
  final GameModel game;

  const QuizGameScreen({Key? key, required this.game}) : super(key: key);

  @override
  State<QuizGameScreen> createState() => _QuizGameScreenState();
}

class _QuizGameScreenState extends State<QuizGameScreen>
    with TickerProviderStateMixin {
  int _currentQuestionIndex = 0;
  final Map<int, String?> _selectedAnswers = {};
  final Map<int, bool> _answeredQuestions = {};
  int _score = 0;
  int _currentStreak = 0;
  int _xpEarned = 0;
  DateTime? _startTime;
  final GameSoundService _soundService = GameSoundService();
  late ConfettiController _confettiController;
  late AnimationController _progressController;
  late Animation<double> _progressAnimation;
  dynamic _character;
  GameStats? _currentStats;

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
    _loadCharacter();
    _loadStats();
  }

  @override
  void dispose() {
    _progressController.dispose();
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

  void _selectAnswer(String answer) {
    if (_answeredQuestions.containsKey(_currentQuestionIndex)) return;

    final question = widget.game.items[_currentQuestionIndex];
    final correctAnswer = (question.correctAnswer ?? '').toString();
    final isCorrect = answer == correctAnswer;

    int baseXP = 10;
    int streakMultiplier = _currentStreak > 0 ? (1 + (_currentStreak ~/ 3)) : 1;
    int xpForThisAnswer = baseXP * streakMultiplier;

    safeSetState(() {
      _selectedAnswers[_currentQuestionIndex] = answer;
      _answeredQuestions[_currentQuestionIndex] = isCorrect;
      if (isCorrect) {
        _score++;
        _currentStreak++;
        _xpEarned += xpForThisAnswer;
        _soundService.playCorrect();
        _confettiController.play();
      } else {
        _currentStreak = 0;
        _soundService.playIncorrect();
      }
    });

    final newProgress = (_currentQuestionIndex + 1) / widget.game.items.length;
    _progressAnimation = Tween<double>(
      begin: _progressAnimation.value,
      end: newProgress,
    ).animate(CurvedAnimation(
      parent: _progressController,
      curve: Curves.easeOut,
    ));
    _progressController.forward(from: 0);

    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        if (_currentQuestionIndex < widget.game.items.length - 1) {
          safeSetState(() {
            _currentQuestionIndex++;
          });
        } else {
          _finishGame();
        }
      }
    });
  }

  Future<void> _finishGame() async {
    final endTime = DateTime.now();
    final timeTaken = _startTime != null
        ? endTime.difference(_startTime!).inSeconds
        : null;

    final isPerfectScore = _score == widget.game.items.length;

    int bonusXP = 0;
    if (isPerfectScore) bonusXP += 50;
    if (timeTaken != null && timeTaken < 120) bonusXP += 25;
    final totalXP = _xpEarned + bonusXP;

    try {
      await GameStatsService.addGameResult(
        correctAnswers: _score,
        totalQuestions: widget.game.items.length,
        timeTakenSeconds: timeTaken ?? 0,
        isPerfectScore: isPerfectScore,
      );
    } catch (e) {
      LogService.error('🎮 [Quiz] Error updating game stats: $e');
    }

    try {
      await SkulMateService.saveGameSession(
        gameId: widget.game.id,
        score: _score,
        totalQuestions: widget.game.items.length,
        correctAnswers: _score,
        timeTakenSeconds: timeTaken,
        answers: _selectedAnswers.map((key, value) => MapEntry(key.toString(), value ?? '')),
      );
    } catch (e) {
      LogService.error('🎮 [Quiz] Error saving game session: $e');
    }

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
    final selectedAnswer = _selectedAnswers[_currentQuestionIndex];

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
      body: Column(
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
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Question ${_currentQuestionIndex + 1} of ${widget.game.items.length}',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: AppTheme.textMedium,
                    ),
                  ),
                  const SizedBox(height: 20),
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
                    child: Text(
                      question.question ?? '',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textDark,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ...(question.options ?? []).map((option) {
                    final isSelected = selectedAnswer == option;
                    final isCorrectOption = option == (question.correctAnswer ?? '').toString();
                    Color? backgroundColor;
                    Color? borderColor;
                    Color? textColor = AppTheme.textDark;

                    if (isAnswered) {
                      if (isSelected && isCorrect) {
                        backgroundColor = AppTheme.accentGreen.withOpacity(0.1);
                        borderColor = AppTheme.accentGreen;
                        textColor = AppTheme.accentGreen;
                      } else if (isSelected && !isCorrect) {
                        backgroundColor = Colors.red.withOpacity(0.1);
                        borderColor = Colors.red;
                        textColor = Colors.red;
                      } else if (isCorrectOption) {
                        backgroundColor = AppTheme.accentGreen.withOpacity(0.1);
                        borderColor = AppTheme.accentGreen;
                        textColor = AppTheme.accentGreen;
                      }
                    } else if (isSelected) {
                      backgroundColor = AppTheme.primaryColor.withOpacity(0.1);
                      borderColor = AppTheme.primaryColor;
                    }

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: InkWell(
                        onTap: isAnswered ? null : () => _selectAnswer(option),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: backgroundColor ?? Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: borderColor ?? Colors.grey[300]!,
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  option,
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                    color: textColor,
                                  ),
                                ),
                              ),
                              if (isAnswered && isSelected)
                                Icon(
                                  isCorrect ? Icons.check_circle : Icons.cancel,
                                  color: isCorrect ? AppTheme.accentGreen : Colors.red,
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
          ),
          if (_character != null)
            SkulMateCharacterWidget(
              character: _character,
              size: 80,
            ),
        ],
      ),
    );
  }
}
