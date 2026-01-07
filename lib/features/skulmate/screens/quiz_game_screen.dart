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
import '../services/tts_service.dart';
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

class _QuizGameScreenState extends State<QuizGameScreen> {
  int _currentQuestionIndex = 0;
  int? _selectedAnswerIndex;
  int _score = 0;
  int _xpEarned = 0;
  DateTime? _startTime;
  final GameSoundService _soundService = GameSoundService();
  final TTSService _ttsService = TTSService();
  late ConfettiController _confettiController;
  dynamic _character;
  GameStats? _currentStats;
  bool _isTTSEnabled = true;

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();
    _soundService.initialize();
    _ttsService.initialize();
    _confettiController = ConfettiController(duration: const Duration(seconds: 2));
    _loadCharacter();
    _loadStats();
    // Speak first question
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted && _isTTSEnabled) {
        _speakCurrentQuestion();
      }
    });
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _ttsService.dispose();
    super.dispose();
  }

  void _speakCurrentQuestion() {
    if (!_isTTSEnabled) return;
    final question = widget.game.items[_currentQuestionIndex];
    final questionText = question.question ?? '';
    if (questionText.isNotEmpty) {
      _ttsService.speak(questionText);
    }
  }

  Future<void> _loadCharacter() async {
    final character = await CharacterSelectionService.getSelectedCharacter();
    safeSetState(() => _character = character);
  }

  Future<void> _loadStats() async {
    final stats = await GameStatsService.getStats();
    safeSetState(() => _currentStats = stats);
  }

  void _selectAnswer(int answerIndex) {
    if (_selectedAnswerIndex != null) return; // Already answered

    final question = widget.game.items[_currentQuestionIndex];
    final correctAnswerIndex = question.correctAnswer is int 
        ? question.correctAnswer as int 
        : (question.correctAnswer is String 
            ? int.tryParse(question.correctAnswer.toString()) ?? 0 
            : 0);
    final isCorrect = answerIndex == correctAnswerIndex;

    safeSetState(() {
      _selectedAnswerIndex = answerIndex;
      if (isCorrect) {
        _score++;
        _xpEarned += 10;
        _soundService.playCorrect();
        if (_isTTSEnabled) {
          _ttsService.speak('Correct!');
        }
      } else {
        _soundService.playIncorrect();
        if (_isTTSEnabled) {
          _ttsService.speak('Incorrect. The correct answer is ${question.options?[correctAnswerIndex] ?? ''}');
        }
      }
    });

    Future.delayed(Duration(seconds: 2), () {
      if (mounted) {
        _nextQuestion();
      }
    });
  }

  void _nextQuestion() {
    if (_currentQuestionIndex < widget.game.items.length - 1) {
      safeSetState(() {
        _currentQuestionIndex++;
        _selectedAnswerIndex = null;
      });
      // Speak next question
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted && _isTTSEnabled) {
          _speakCurrentQuestion();
        }
      });
    } else {
      _finishGame();
    }
  }

  Future<void> _finishGame() async {
    final timeTaken = DateTime.now().difference(_startTime!).inSeconds;
    final totalQuestions = widget.game.items.length;
    final isPerfectScore = _score == totalQuestions;

    if (isPerfectScore) {
      _confettiController.play();
      _soundService.playComplete();
    }

    final stats = await GameStatsService.addGameResult(
      correctAnswers: _score,
      totalQuestions: totalQuestions,
      timeTakenSeconds: timeTaken,
      isPerfectScore: isPerfectScore,
    );

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => GameResultsScreen(
            game: widget.game,
            score: _score,
            totalQuestions: totalQuestions,
            timeTakenSeconds: timeTaken,
            xpEarned: _xpEarned,
            isPerfectScore: isPerfectScore,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentQuestionIndex >= widget.game.items.length) {
      return Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final question = widget.game.items[_currentQuestionIndex];
    final progress = (_currentQuestionIndex + 1) / widget.game.items.length;

    return Scaffold(
      appBar: AppBar(
        title: Text('Quiz Game', style: GoogleFonts.poppins()),
        backgroundColor: AppTheme.primaryColor,
        actions: [
          IconButton(
            icon: Icon(
              _isTTSEnabled ? Icons.volume_up : Icons.volume_off,
              color: Colors.white,
            ),
            onPressed: () {
              safeSetState(() {
                _isTTSEnabled = !_isTTSEnabled;
                _ttsService.setEnabled(_isTTSEnabled);
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          LinearProgressIndicator(value: progress),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Question ${_currentQuestionIndex + 1} of ${widget.game.items.length}',
                    style: GoogleFonts.poppins(fontSize: 16, color: AppTheme.textMedium),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    question.question ?? '',
                    style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 24),
                  ...(question.options ?? []).asMap().entries.map((entry) {
                    final index = entry.key;
                    final option = entry.value;
                    final isSelected = _selectedAnswerIndex == index;
                    final correctAnswerIndex = question.correctAnswer is int 
                        ? question.correctAnswer as int 
                        : (question.correctAnswer is String 
                            ? int.tryParse(question.correctAnswer.toString()) ?? 0 
                            : 0);
                    final isCorrect = index == correctAnswerIndex;
                    final showResult = _selectedAnswerIndex != null;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: ElevatedButton(
                        onPressed: () => _selectAnswer(index),
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: showResult
                              ? (isCorrect
                                  ? AppTheme.accentGreen
                                  : (isSelected ? Colors.red : Colors.grey[300]))
                              : (isSelected ? AppTheme.primaryColor : Colors.white),
                        ),
                        child: Text(
                          option,
                          style: GoogleFonts.poppins(
                            color: showResult && isCorrect
                                ? Colors.white
                                : (isSelected && !isCorrect ? Colors.white : Colors.black),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
