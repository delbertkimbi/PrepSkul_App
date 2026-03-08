import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../widgets/game_roadmap_widget.dart';
import '../widgets/game_rules_overlay.dart';
import '../widgets/skulmate_game_app_bar.dart';
import '../services/daily_challenge_service.dart';
import 'game_results_screen.dart';

/// Quiz game screen with multiple choice questions
class QuizGameScreen extends StatefulWidget {
  final GameModel game;
  final bool isDailyChallenge;

  const QuizGameScreen({Key? key, required this.game, this.isDailyChallenge = false}) : super(key: key);

  @override
  State<QuizGameScreen> createState() => _QuizGameScreenState();
}

class _QuizGameScreenState extends State<QuizGameScreen> {
  static const int _minQuestionsPerRound = 5;
  static const int _maxQuestionsPerRound = 7;

  late final List<GameItem> _questions;
  int _currentQuestionIndex = 0;
  int? _selectedAnswerIndex;
  int _score = 0;
  int _xpEarned = 0;
  /// Shuffled display order for options: maps question index -> [originalIndex, ...]
  final Map<int, List<int>> _shuffledOptionIndices = {};
  DateTime? _startTime;
  final GameSoundService _soundService = GameSoundService();
  final TTSService _ttsService = TTSService();
  late ConfettiController _confettiController;
  dynamic _character;
  GameStats? _currentStats;
  bool _isTTSEnabled = true;
  int? _lastCorrectXp; // +10 or +15 for boss – show pop-up briefly
  final List<QuestionPerformance> _questionBreakdown = [];

  bool _hasShownRules = false;

  @override
  void initState() {
    super.initState();
    _questions = _buildQuestionSet(widget.game.items);
    _startTime = DateTime.now();
    _soundService.initialize();
    _ttsService.initialize();
    _confettiController = ConfettiController(duration: const Duration(milliseconds: 1200));
    _loadCharacter();
    _loadStats();
    // Show rules overlay if first time
    _showRulesIfNeeded();
  }

  Future<void> _showRulesIfNeeded() async {
    if (!_hasShownRules) {
      await GameRulesOverlay.showIfNeeded(
        context,
        widget.game.gameType,
        () {
          _hasShownRules = true;
          // Speak first question after rules
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted && _isTTSEnabled) {
              _speakCurrentQuestion();
            }
          });
        },
      );
    } else {
      // Speak first question
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted && _isTTSEnabled) {
          _speakCurrentQuestion();
        }
      });
    }
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

  /// Get or create shuffled option indices for a question (so correct answer isn't always B)
  List<int> _getShuffledOptionIndices(GameItem question) {
    return _shuffledOptionIndices.putIfAbsent(_currentQuestionIndex, () {
      final opts = question.options ?? [];
      final indices = List.generate(opts.length, (i) => i);
      indices.shuffle(Random());
      return indices;
    });
  }

  /// Build a short round of questions (5–7 where possible) for a tighter game loop
  List<GameItem> _buildQuestionSet(List<GameItem> allItems) {
    // Prefer only items that actually have options
    final filtered = allItems.where((q) => (q.options ?? []).isNotEmpty).toList();
    if (filtered.isEmpty) return allItems;

    filtered.shuffle(Random());
    final available = filtered.length;
    if (available <= _minQuestionsPerRound) {
      return filtered;
    }
    final target = min(_maxQuestionsPerRound, available);
    return filtered.take(target).toList();
  }

  void _selectAnswer(int displayIndex) {
    if (_selectedAnswerIndex != null) return; // Already answered
    final question = _questions[_currentQuestionIndex];
    final shuffled = _getShuffledOptionIndices(question);
    final originalIndex = displayIndex < shuffled.length ? shuffled[displayIndex] : displayIndex;
    final correctAnswerIndex = question.correctAnswer is int 
        ? question.correctAnswer as int 
        : (question.correctAnswer is String 
            ? int.tryParse(question.correctAnswer.toString()) ?? 0 
            : 0);
    final isCorrect = originalIndex == correctAnswerIndex;

    // Track per-question performance for end-of-game summary
    final rawQuestionText = (question.question ?? question.term ?? '').trim();
    if (rawQuestionText.isNotEmpty) {
      _questionBreakdown.add(
        QuestionPerformance(
          question: rawQuestionText,
          isCorrect: isCorrect,
        ),
      );
    }

    safeSetState(() {
      _selectedAnswerIndex = displayIndex;
      if (isCorrect) {
        _score++;
        final xpPerCorrect = question.isBoss ? 15 : 10;
        _xpEarned += xpPerCorrect;
        _lastCorrectXp = xpPerCorrect;
        _soundService.playCorrect();
        _confettiController.play();
        if (_isTTSEnabled) {
          _ttsService.speak('Correct!');
        }
        // Clear XP pop-up after 1.2s
        Future.delayed(const Duration(milliseconds: 1200), () {
          if (mounted) safeSetState(() => _lastCorrectXp = null);
        });
      } else {
        _soundService.playIncorrect();
        if (_isTTSEnabled) {
          final correctText = question.options != null && correctAnswerIndex < question.options!.length
              ? question.options![correctAnswerIndex]
              : '';
          _ttsService.speak('Incorrect. The correct answer is $correctText');
        }
      }
    });

    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) {
        _nextQuestion();
      }
    });
  }

  void _nextQuestion() {
    if (_currentQuestionIndex < _questions.length - 1) {
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
    final totalQuestions = _questions.length;
    final isPerfectScore = _score == totalQuestions;

    _xpEarned += 50; // Completion bonus per PRD

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

    if (widget.isDailyChallenge) {
      await DailyChallengeService.markCompleteForToday(childId: widget.game.childId);
    }

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
            questionBreakdown: _questionBreakdown,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentQuestionIndex >= _questions.length) {
      return Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final question = _questions[_currentQuestionIndex];
    final progress = (_currentQuestionIndex + 1) / _questions.length;
    final isBossQuestion = question.isBoss;

    return Stack(
      children: [
        Scaffold(
      appBar: SkulMateGameAppBar(
        title: widget.game.title,
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
          // Enhanced progress indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.white,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Question ${_currentQuestionIndex + 1} of ${_questions.length}',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textDark,
                      ),
                    ),
                    Row(
                      children: [
                        Icon(Icons.star, color: Colors.amber, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          '$_xpEarned XP',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.amber.shade700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: AppTheme.softBorder,
                    valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              color: AppTheme.softBackground,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (isBossQuestion)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade700.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.amber.shade700, width: 2),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('⚔️', style: GoogleFonts.poppins(fontSize: 18)),
                          const SizedBox(width: 8),
                          Text(
                            'Boss Question',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.amber.shade900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  Text(
                    'Question ${_currentQuestionIndex + 1} of ${_questions.length}',
                    style: GoogleFonts.poppins(fontSize: 16, color: AppTheme.textMedium),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    (question.question ?? '').trim().isEmpty
                        ? 'Question content is loading...'
                        : (question.question ?? ''),
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textDark,
                    ),
                  ),
                  if ((question.question ?? '').trim().isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        'If this persists, the content may not support this game type. Go back and try a different format.',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: AppTheme.textMedium,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  const SizedBox(height: 24),
                  if ((question.options ?? []).isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      margin: const EdgeInsets.only(top: 8),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.amber.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'No answer options available',
                            style: GoogleFonts.poppins(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textDark,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'This content may not be in quiz format. Try Flashcards or Matching instead.',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: AppTheme.textMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if ((question.options ?? []).isNotEmpty)
                    ..._getShuffledOptionIndices(question).asMap().entries.map((entry) {
                    final displayIndex = entry.key;
                    final originalIndex = entry.value;
                    final option = (question.options ?? [])[originalIndex];
                    final isSelected = _selectedAnswerIndex == displayIndex;
                    final correctAnswerIndex = question.correctAnswer is int 
                        ? question.correctAnswer as int 
                        : (question.correctAnswer is String 
                            ? int.tryParse(question.correctAnswer.toString()) ?? 0 
                            : 0);
                    final isCorrect = originalIndex == correctAnswerIndex;
                    final showResult = _selectedAnswerIndex != null;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: ElevatedButton(
                        onPressed: () => _selectAnswer(displayIndex),
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
          ),
        ],
      ),
    ),
        // XP pop-up on correct answer
        if (_lastCorrectXp != null)
          Positioned(
            top: MediaQuery.of(context).size.height * 0.35,
            left: 0,
            right: 0,
            child: Center(
              child: AnimatedOpacity(
                opacity: 1,
                duration: const Duration(milliseconds: 200),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.accentGreen,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.accentGreen.withOpacity(0.5),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Text(
                    '+$_lastCorrectXp XP',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
        Align(
          alignment: Alignment.topCenter,
          child: ConfettiWidget(
            confettiController: _confettiController,
            blastDirection: pi / 2,
            maxBlastForce: 5,
            minBlastForce: 2,
            emissionFrequency: 0.05,
            numberOfParticles: 30,
            gravity: 0.1,
          ),
        ),
      ],
    );
  }
}
