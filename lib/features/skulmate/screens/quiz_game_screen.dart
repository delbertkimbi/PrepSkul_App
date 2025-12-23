import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/core/utils/safe_set_state.dart';
import '../models/game_model.dart';
import '../services/skulmate_service.dart';
import '../services/game_sound_service.dart';
import '../services/character_selection_service.dart';
import '../widgets/skulmate_character_widget.dart';
import 'game_results_screen.dart';

/// Quiz game screen with multiple choice questions
class QuizGameScreen extends StatefulWidget {
  final GameModel game;

  const QuizGameScreen({Key? key, required this.game}) : super(key: key);

  @override
  State<QuizGameScreen> createState() => _QuizGameScreenState();
}

class _QuizGameScreenState extends State<QuizGameScreen> {
  int _currentQuestionIndex = 0;
  int? _selectedAnswer;
  int _score = 0;
  final Map<int, int> _userAnswers = {}; // questionIndex -> selectedOptionIndex
  final Map<int, bool> _answeredQuestions = {}; // questionIndex -> isCorrect
  DateTime? _startTime;
  final GameSoundService _soundService = GameSoundService();
  dynamic _character; // Will be SkulMateCharacter

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();
    _soundService.initialize();
    _loadCharacter();
  }

  Future<void> _loadCharacter() async {
    final character = await CharacterSelectionService.getSelectedCharacter();
    safeSetState(() {
      _character = character;
    });
  }

  void _selectAnswer(int optionIndex) {
    safeSetState(() {
      _selectedAnswer = optionIndex;
    });
  }

  void _submitAnswer() {
    if (_selectedAnswer == null) return;

    final question = widget.game.items[_currentQuestionIndex];
    final correctAnswer = question.correctAnswer as int? ?? 0;
    final isCorrect = _selectedAnswer == correctAnswer;

    safeSetState(() {
      _userAnswers[_currentQuestionIndex] = _selectedAnswer!;
      _answeredQuestions[_currentQuestionIndex] = isCorrect;
      if (isCorrect) {
        _score++;
        _soundService.playCorrect();
      } else {
        _soundService.playIncorrect();
      }
    });

    // Show feedback
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isCorrect ? 'Correct! 🎉' : 'Incorrect. Try again!',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        backgroundColor: isCorrect ? AppTheme.accentGreen : Colors.red,
        duration: const Duration(seconds: 1),
      ),
    );

    // Move to next question after delay
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        _nextQuestion();
      }
    });
  }

  void _nextQuestion() {
    if (_currentQuestionIndex < widget.game.items.length - 1) {
      safeSetState(() {
        _currentQuestionIndex++;
        _selectedAnswer = _userAnswers[_currentQuestionIndex];
      });
    } else {
      _finishGame();
    }
  }

  void _previousQuestion() {
    if (_currentQuestionIndex > 0) {
      safeSetState(() {
        _currentQuestionIndex--;
        _selectedAnswer = _userAnswers[_currentQuestionIndex];
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
        answers: _userAnswers.map((key, value) => MapEntry(key.toString(), value)),
      );
    } catch (e) {
      // Log but don't block navigation
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
    final question = widget.game.items[_currentQuestionIndex];
    final progress = (_currentQuestionIndex + 1) / widget.game.items.length;

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
              'Score: $_score/${widget.game.items.length}',
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
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Question number
                  Text(
                    'Question ${_currentQuestionIndex + 1} of ${widget.game.items.length}',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: AppTheme.textMedium,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Question
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
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textDark,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Options
                  ...(question.options ?? []).asMap().entries.map((entry) {
                    final index = entry.key;
                    final option = entry.value;
                    final isSelected = _selectedAnswer == index;
                    final isAnswered = _answeredQuestions[_currentQuestionIndex] != null;
                    final isCorrect = question.correctAnswer == index;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: InkWell(
                        onTap: isAnswered ? null : () => _selectAnswer(index),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? (isAnswered && isCorrect
                                    ? AppTheme.accentGreen.withOpacity(0.1)
                                    : AppTheme.primaryColor.withOpacity(0.1))
                                : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? (isAnswered && isCorrect
                                      ? AppTheme.accentGreen
                                      : AppTheme.primaryColor)
                                  : Colors.grey.withOpacity(0.3),
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isSelected
                                      ? (isAnswered && isCorrect
                                          ? AppTheme.accentGreen
                                          : AppTheme.primaryColor)
                                      : Colors.grey.withOpacity(0.2),
                                ),
                                child: Center(
                                  child: Text(
                                    String.fromCharCode(65 + index), // A, B, C, D
                                    style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: isSelected ? Colors.white : AppTheme.textDark,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Text(
                                  option,
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    color: AppTheme.textDark,
                                  ),
                                ),
                              ),
                              if (isAnswered && isCorrect && isSelected)
                                const Icon(
                                  Icons.check_circle,
                                  color: AppTheme.accentGreen,
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 24),
                  // Submit button
                  if (!_answeredQuestions.containsKey(_currentQuestionIndex))
                    ElevatedButton(
                      onPressed: _selectedAnswer == null ? null : _submitAnswer,
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
                  if (_answeredQuestions.containsKey(_currentQuestionIndex)) ...[
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
    );
  }
}

