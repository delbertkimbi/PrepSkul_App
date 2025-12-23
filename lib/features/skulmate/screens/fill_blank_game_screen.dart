import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/core/utils/safe_set_state.dart';
import '../models/game_model.dart';
import '../services/skulmate_service.dart';
import 'game_results_screen.dart';

/// Fill-in-the-blank game screen
class FillBlankGameScreen extends StatefulWidget {
  final GameModel game;

  const FillBlankGameScreen({Key? key, required this.game}) : super(key: key);

  @override
  State<FillBlankGameScreen> createState() => _FillBlankGameScreenState();
}

class _FillBlankGameScreenState extends State<FillBlankGameScreen> {
  int _currentQuestionIndex = 0;
  final Map<int, TextEditingController> _controllers = {};
  final Map<int, String> _userAnswers = {}; // questionIndex -> answer
  final Map<int, bool> _answeredQuestions = {}; // questionIndex -> isCorrect
  int _score = 0;
  DateTime? _startTime;
  final GameSoundService _soundService = GameSoundService();

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();
    _soundService.initialize();
    // Initialize controllers
    for (int i = 0; i < widget.game.items.length; i++) {
      _controllers[i] = TextEditingController();
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _submitAnswer() {
    final answer = _controllers[_currentQuestionIndex]?.text.trim() ?? '';
    if (answer.isEmpty) return;

    final question = widget.game.items[_currentQuestionIndex];
    final correctAnswer = (question.correctAnswer ?? '').toString().toLowerCase().trim();
    final userAnswer = answer.toLowerCase().trim();
    final isCorrect = userAnswer == correctAnswer;

    safeSetState(() {
      _userAnswers[_currentQuestionIndex] = answer;
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
          isCorrect ? 'Correct! 🎉' : 'Incorrect. The answer is: ${question.correctAnswer}',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
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
    if (_currentQuestionIndex < widget.game.items.length - 1) {
      safeSetState(() {
        _currentQuestionIndex++;
      });
    } else {
      _finishGame();
    }
  }

  void _previousQuestion() {
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
                  const SizedBox(height: 24),
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
                        // Answer input
                        TextField(
                          controller: _controllers[_currentQuestionIndex],
                          enabled: !isAnswered,
                          decoration: InputDecoration(
                            hintText: 'Enter your answer',
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
                                : null,
                          ),
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            color: AppTheme.textDark,
                          ),
                          onSubmitted: (_) {
                            if (!isAnswered) {
                              _submitAnswer();
                            }
                          },
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
    );
  }
}

