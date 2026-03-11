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
import 'game_library_screen.dart';

/// Quiz game screen with multiple choice questions
class QuizGameScreen extends StatefulWidget {
  final GameModel game;
  final bool isDailyChallenge;
  /// When true, back/exit goes to game library (dashboard) instead of upload.
  final bool fromGenerationFlow;

  const QuizGameScreen({
    Key? key,
    required this.game,
    this.isDailyChallenge = false,
    this.fromGenerationFlow = false,
  }) : super(key: key);

  @override
  State<QuizGameScreen> createState() => _QuizGameScreenState();
}

class _QuizGameScreenState extends State<QuizGameScreen> with SingleTickerProviderStateMixin {
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
  bool _xpPopupVisible = false; // drives fade-out before advancing
  final List<QuestionPerformance> _questionBreakdown = [];

  bool _hasShownRules = false;
  /// When true, show correct answer + explanation and "Next" instead of auto-advancing.
  bool _showWrongAnswerFeedback = false;
  static const int _countdownSecondsPerQuestion = 15;
  int _countdownRemaining = _countdownSecondsPerQuestion;
  Timer? _countdownTimer;

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
          _startCountdown();
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted && _isTTSEnabled) {
              _speakCurrentQuestion();
            }
          });
        },
      );
    } else {
      _startCountdown();
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted && _isTTSEnabled) {
          _speakCurrentQuestion();
        }
      });
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _confettiController.dispose();
    _ttsService.dispose();
    super.dispose();
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownRemaining = _countdownSecondsPerQuestion;
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_countdownRemaining <= 0) {
        t.cancel();
        _onCountdownExpired();
        return;
      }
      safeSetState(() => _countdownRemaining--);
    });
  }

  /// When timer hits 0 without an answer: show correct answer + explanation and speak "No idea? No worries, let me explain..."
  void _onCountdownExpired() {
    if (_selectedAnswerIndex != null) return; // Already answered
    final question = _questions[_currentQuestionIndex];
    final correctAnswerIndex = question.correctAnswer is int
        ? question.correctAnswer as int
        : (question.correctAnswer is String
            ? int.tryParse(question.correctAnswer.toString()) ?? 0
            : 0);
    final rawQuestionText = (question.question ?? question.term ?? '').trim();
    if (rawQuestionText.isNotEmpty) {
      _questionBreakdown.add(QuestionPerformance(question: rawQuestionText, isCorrect: false));
    }
    safeSetState(() {
      _stopCountdown();
      _showWrongAnswerFeedback = true;
      // No answer selected; options stay unselected but we show correct + explanation
    });
    _soundService.playIncorrect();
    final correctText = question.options != null && correctAnswerIndex < question.options!.length
        ? question.options![correctAnswerIndex]
        : '';
    final explanation = (question.explanation ?? '').trim();
    final toSpeak = explanation.isEmpty
        ? 'No idea? No worries. The correct answer is $correctText.'
        : 'No idea? No worries, let me explain. The correct answer is $correctText. $explanation';
    if (_isTTSEnabled && toSpeak.isNotEmpty) {
      _ttsService.speakAndWait(toSpeak);
    }
  }

  void _stopCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
  }

  void _speakCurrentQuestion() {
    if (!_isTTSEnabled) return;
    if (_currentQuestionIndex >= _questions.length) return;
    final question = _questions[_currentQuestionIndex];
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
    _soundService.playClick();
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
      _stopCountdown();
      if (isCorrect) {
        _score++;
        final xpPerCorrect = question.isBoss ? 15 : 10;
        _xpEarned += xpPerCorrect;
        _lastCorrectXp = xpPerCorrect;
        _xpPopupVisible = true;
        _soundService.playCorrect();
        _confettiController.play();
        if (_isTTSEnabled) {
          _ttsService.speak('Correct!');
        }
        // Animate XP popup out, then advance
        Future.delayed(const Duration(milliseconds: 700), () {
          if (mounted) safeSetState(() => _xpPopupVisible = false);
        });
        Future.delayed(const Duration(milliseconds: 1200), () {
          if (mounted) {
            safeSetState(() => _lastCorrectXp = null);
            _nextQuestion();
          }
        });
      } else {
        _soundService.playIncorrect();
        _showWrongAnswerFeedback = true;
        final correctText = question.options != null && correctAnswerIndex < question.options!.length
            ? question.options![correctAnswerIndex]
            : '';
        final explanation = (question.explanation ?? '').trim();
        final toSpeak = explanation.isEmpty
            ? 'Incorrect. The correct answer is $correctText.'
            : 'Incorrect. The correct answer is $correctText. $explanation';
        if (_isTTSEnabled && toSpeak.isNotEmpty) {
          _ttsService.speakAndWait(toSpeak);
        }
      }
    });
  }

  void _nextQuestion() {
    safeSetState(() {
      _lastCorrectXp = null;
      _xpPopupVisible = false;
      _showWrongAnswerFeedback = false;
      _stopCountdown();
    });
    if (_currentQuestionIndex < _questions.length - 1) {
      safeSetState(() {
        _currentQuestionIndex++;
        _selectedAnswerIndex = null;
        _countdownRemaining = _countdownSecondsPerQuestion;
      });
      _startCountdown();
      Future.delayed(const Duration(milliseconds: 400), () {
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
            fromGenerationFlow: widget.fromGenerationFlow,
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
    final correctAnswerIdx = question.correctAnswer is int
        ? question.correctAnswer as int
        : (question.correctAnswer is String
            ? int.tryParse(question.correctAnswer.toString()) ?? 0
            : 0);
    final correctAnswerText = (question.options != null && correctAnswerIdx < question.options!.length)
        ? question.options![correctAnswerIdx]
        : '';

    return Stack(
      children: [
        Scaffold(
      appBar: SkulMateGameAppBar(
        title: widget.game.title,
        leading: widget.fromGenerationFlow
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const GameLibraryScreen(initialTab: 1),
                    ),
                    (route) => false,
                  );
                },
              )
            : null,
        actions: [
          if (_character != null)
            Padding(
              padding: const EdgeInsets.only(right: 2),
              child: Center(
                child: ClipOval(
                  child: Container(
                    width: 32,
                    height: 32,
                    color: Colors.white.withOpacity(0.2),
                    child: Center(
                      child: SkulMateCharacterWidget(
                        character: _character,
                        size: 28,
                        animated: false,
                        showName: false,
                      ),
                    ),
                  ),
                ),
              ),
            ),
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
          // Progress + countdown (nkwa-style: clear percentage and time)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
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
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 6,
                          backgroundColor: AppTheme.softBorder,
                          valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Circular countdown (Nkwa-style: dot-like ring that depletes to zero)
                    SizedBox(
                      width: 44,
                      height: 44,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 44,
                            height: 44,
                            child: CircularProgressIndicator(
                              value: _countdownRemaining / _countdownSecondsPerQuestion,
                              strokeWidth: 3,
                              backgroundColor: AppTheme.softBorder,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                _countdownRemaining <= 5 ? Colors.red : AppTheme.primaryColor,
                              ),
                            ),
                          ),
                          Text(
                            '${_countdownRemaining}s',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: _countdownRemaining <= 5 ? Colors.red : AppTheme.textDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              color: AppTheme.softBackground,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
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
                    // Question card (compact: no redundant label, smaller text)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.primaryColor.withOpacity(0.06),
                            AppTheme.accentPurple.withOpacity(0.04),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppTheme.softBorder),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        (question.question ?? '').trim().isEmpty
                            ? 'Question content is loading...'
                            : (question.question ?? ''),
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          height: 1.35,
                          color: AppTheme.textDark,
                        ),
                      ),
                    ),
                    if ((question.question ?? '').trim().isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'If this persists, the content may not support this game type. Go back and try a different format.',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: AppTheme.textMedium,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),
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
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: _showWrongAnswerFeedback ? null : () => _selectAnswer(displayIndex),
                              borderRadius: BorderRadius.circular(14),
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                                decoration: BoxDecoration(
                                  color: showResult
                                      ? (isCorrect
                                          ? AppTheme.accentGreen
                                          : (isSelected ? Colors.red.shade400 : Colors.grey.shade200))
                                      : (isSelected
                                          ? AppTheme.primaryColor
                                          : Colors.white),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: showResult
                                        ? (isCorrect ? AppTheme.accentGreen : (isSelected ? Colors.red : Colors.grey.shade300!))
                                        : (isSelected ? AppTheme.primaryColor : AppTheme.softBorder),
                                    width: 2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.06),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  option,
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: showResult && isCorrect
                                        ? Colors.white
                                        : (isSelected && !isCorrect ? Colors.white : AppTheme.textDark),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    if (_showWrongAnswerFeedback) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.accentLightGreen.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppTheme.accentGreen, width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.accentGreen.withOpacity(0.15),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.check_circle, color: AppTheme.accentGreen, size: 22),
                                const SizedBox(width: 8),
                                Text(
                                  'Correct answer',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.textDark,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              correctAnswerText,
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                            if ((question.explanation ?? '').trim().isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                question.explanation!.trim(),
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  height: 1.4,
                                  color: AppTheme.textDark,
                                ),
                              ),
                            ],
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  _ttsService.stop();
                                  _nextQuestion();
                                },
                                icon: const Icon(Icons.arrow_forward, size: 16),
                                label: const Text('Next question'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primaryColor,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 2,
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
          ),
          ),
        ],
      ),
    ),
        // XP pop-up on correct answer: animates in, then fades out before next question
        if (_lastCorrectXp != null)
          Positioned(
            top: MediaQuery.of(context).size.height * 0.32,
            left: 0,
            right: 0,
            child: Center(
              child: AnimatedOpacity(
                opacity: _xpPopupVisible ? 1 : 0,
                duration: const Duration(milliseconds: 300),
                child: AnimatedSlide(
                  offset: _xpPopupVisible ? Offset.zero : const Offset(0, -0.5),
                  duration: const Duration(milliseconds: 300),
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
