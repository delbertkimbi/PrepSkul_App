import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
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
import '../services/game_stats_service.dart';
import '../models/game_stats_model.dart';
import '../widgets/game_roadmap_widget.dart';
import '../widgets/game_rules_overlay.dart';
import '../widgets/skulmate_game_app_bar.dart';
import '../widgets/skulmate_profile_avatar.dart';
import '../widgets/drag_drop_question_widget.dart';
import '../widgets/game_standard_widgets.dart';
import '../widgets/game_settings_sheet.dart';
import '../widgets/skulmate_companion_banner.dart';
import '../services/daily_challenge_service.dart';
import '../services/game_progress_service.dart';
import '../utils/skulmate_navigation.dart';
import 'game_results_screen.dart';

/// Quiz game screen with multiple choice questions
class QuizGameScreen extends StatefulWidget {
  final GameModel game;
  final bool isDailyChallenge;

  /// When true, back/exit goes to game library (dashboard) instead of upload.
  final bool fromGenerationFlow;
  final GameProgress? resumeFrom;

  const QuizGameScreen({
    Key? key,
    required this.game,
    this.isDailyChallenge = false,
    this.fromGenerationFlow = false,
    this.resumeFrom,
  }) : super(key: key);

  @override
  State<QuizGameScreen> createState() => _QuizGameScreenState();
}

class _QuizGameScreenState extends State<QuizGameScreen>
    with SingleTickerProviderStateMixin {
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
  GameStats? _currentStats;
  bool _isTTSEnabled = true;
  int? _lastCorrectXp; // +10 or +15 for boss – show pop-up briefly
  bool _xpPopupVisible = false; // drives fade-out before advancing
  final List<QuestionPerformance> _questionBreakdown = [];
  String? _mascotReaction;
  CompanionTone _mascotReactionTone = CompanionTone.neutral;
  bool _mascotCelebrate = false;
  Timer? _mascotReactionTimer;

  bool _hasShownRules = false;
  bool _gameCompleted = false;

  /// When true, show correct answer + explanation and "Next" instead of auto-advancing.
  bool _showWrongAnswerFeedback = false;
  bool _quizMusicStarted = false;
  static const int _countdownSecondsPerQuestion = 15;
  int _countdownRemaining = _countdownSecondsPerQuestion;
  Timer? _countdownTimer;
  final Map<String, int> _dragAssignments = {};
  final TextEditingController _fillBlankController = TextEditingController();
  String? _submittedFillBlankAnswer;

  bool _isDragDropQuestion(GameItem question) {
    return (question.dragItems ?? []).isNotEmpty &&
        (question.dropZones ?? []).isNotEmpty;
  }

  bool _isFillBlankQuestion(GameItem question) {
    return !_isDragDropQuestion(question) &&
        (question.blankText ?? '').trim().isNotEmpty &&
        (question.options ?? []).isEmpty;
  }

  @override
  void initState() {
    super.initState();
    _questions = _buildQuestionSet(widget.game.items);
    if (widget.resumeFrom != null) {
      _currentQuestionIndex = widget.resumeFrom!.currentIndex
          .clamp(0, _questions.length > 0 ? _questions.length - 1 : 0);
      _score = widget.resumeFrom!.score;
      _hasShownRules = true;
    }
    _startTime = DateTime.now();
    _soundService.initialize();
    _ttsService.initialize();
    _configureQuizTts();
    _confettiController = ConfettiController(
      duration: const Duration(milliseconds: 1200),
    );
    _loadStats();
    _startQuizMusicOnce();
    // Show rules overlay if first time
    _showRulesIfNeeded();
  }

  void _startQuizMusicOnce() {
    if (_quizMusicStarted) return;
    _quizMusicStarted = true;
    // Keep quiz on the mystery ambient track consistently.
    unawaited(_soundService.playMusicForGame(GameType.mystery));
  }

  Future<void> _configureQuizTts() async {
    await _ttsService.ensureInitialized();
    // Slightly slower than global to improve comprehension during timed quiz.
    await _ttsService.setSpeechRate(kIsWeb ? 0.72 : 0.5);
  }

  Future<void> _showRulesIfNeeded() async {
    if (!_hasShownRules) {
      await GameRulesOverlay.showIfNeeded(
        context,
        widget.game.gameType,
        (isFirstTime) async {
          _hasShownRules = true;
          if (!isFirstTime) {
            _startQuizMusicOnce();
          }
          _startCountdown();
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted && _isTTSEnabled) {
              _speakCurrentQuestion();
            }
          });
        },
        onAfterFirstTimeDialogClosed: _openFirstTimeSoundSettingsSheet,
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

  Future<void> _stopVoiceAndMusic() async {
    await _ttsService.stop();
    await _soundService.stopMusic(force: true);
  }

  Future<void> _persistProgress() async {
    if (_gameCompleted || _questions.isEmpty) return;
    await GameProgressService.saveProgress(
      GameProgress(
        gameId: widget.game.id,
        gameType: widget.game.gameType,
        currentIndex: _currentQuestionIndex,
        score: _score,
        savedAt: DateTime.now(),
      ),
    );
  }

  @override
  void dispose() {
    _mascotReactionTimer?.cancel();
    _countdownTimer?.cancel();
    _fillBlankController.dispose();
    unawaited(_persistProgress());
    unawaited(_stopVoiceAndMusic());
    _confettiController.dispose();
    _ttsService.resetSpeechRate();
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
      // Play urgent countdown tick in the last 5 seconds
      if (_countdownRemaining <= 5) {
        _soundService.playCountdownTick();
      }
      safeSetState(() => _countdownRemaining--);
    });
  }

  /// When timer hits 0 without an answer: show correct answer + explanation and speak "No idea? No worries, let me explain..."
  void _onCountdownExpired() {
    final question = _questions[_currentQuestionIndex];
    final isDrag = _isDragDropQuestion(question);
    final isFillBlank = _isFillBlankQuestion(question);
    if (isDrag && _showWrongAnswerFeedback) return;
    if (isFillBlank && _showWrongAnswerFeedback) return;
    if (!isDrag && _selectedAnswerIndex != null) return;

    final rawQuestionText = (question.question ?? question.term ?? '').trim();
    if (rawQuestionText.isNotEmpty) {
      _questionBreakdown.add(
        QuestionPerformance(question: rawQuestionText, isCorrect: false),
      );
    }

    int correctAnswerIndex = 0;
    if (isDrag) {
      safeSetState(() {
        _stopCountdown();
        _showWrongAnswerFeedback = true;
      });
    } else if (isFillBlank) {
      safeSetState(() {
        _stopCountdown();
        _showWrongAnswerFeedback = true;
      });
    } else {
      final shuffled = _getShuffledOptionIndices(question);
      correctAnswerIndex = question.correctAnswer is int
          ? question.correctAnswer as int
          : (question.correctAnswer is String
                ? int.tryParse(question.correctAnswer.toString()) ?? 0
                : 0);
      final correctDisplayIndex = shuffled.indexOf(correctAnswerIndex);
      safeSetState(() {
        _stopCountdown();
        _showWrongAnswerFeedback = true;
        // Auto-select the correct option so it renders green during explanation mode.
        _selectedAnswerIndex = correctDisplayIndex >= 0 ? correctDisplayIndex : null;
      });
    }

    // Stronger feedback when time runs out
    _soundService.playCountdownBuzzer();
    _showMascotReaction(
      'Time is up. No stress, review this one and keep going.',
      tone: CompanionTone.warning,
    );
    final explanation = (question.explanation ?? '').trim();
    String toSpeak;
    if (isDrag) {
      toSpeak = explanation.isEmpty
          ? 'Time is up. Let us review the correct drag and drop mapping.'
          : 'Time is up. Let us review the correct drag and drop mapping. $explanation';
    } else if (isFillBlank) {
      final correctText = _correctFillBlankText(question);
      toSpeak = explanation.isEmpty
          ? 'Time is up. The correct fill in answer is $correctText.'
          : 'Time is up. The correct fill in answer is $correctText. $explanation';
    } else {
      final correctText =
          question.options != null &&
              correctAnswerIndex < question.options!.length
          ? question.options![correctAnswerIndex]
          : '';
      toSpeak = explanation.isEmpty
          ? 'No idea? No worries. The correct answer is $correctText.'
          : 'No idea? No worries, let me explain. The correct answer is $correctText. $explanation';
    }

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
    // Keep playable quiz items: MCQ, drag-drop hybrid, or fill-blank hybrid.
    final filtered = allItems
        .where(
          (q) =>
              (q.options ?? []).isNotEmpty ||
              ((q.dragItems ?? []).isNotEmpty &&
                  (q.dropZones ?? []).isNotEmpty) ||
              ((q.blankText ?? '').trim().isNotEmpty),
        )
        .toList();
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
    final originalIndex = displayIndex < shuffled.length
        ? shuffled[displayIndex]
        : displayIndex;
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
        QuestionPerformance(question: rawQuestionText, isCorrect: isCorrect),
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
        _showMascotReaction(
          'Great answer! Keep this momentum.',
          tone: CompanionTone.success,
          celebrate: true,
        );
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
        unawaited(_soundService.registerUserGesture());
        unawaited(_soundService.playIncorrect());
        _showWrongAnswerFeedback = true;
        _showMascotReaction(
          'Close one. Read the explanation and bounce back.',
          tone: CompanionTone.tip,
        );
        final correctText =
            question.options != null &&
                correctAnswerIndex < question.options!.length
            ? question.options![correctAnswerIndex]
            : '';
        final explanation = (question.explanation ?? '').trim();
        final toSpeak = explanation.isEmpty
            ? 'Incorrect. The correct answer is $correctText.'
            : 'Incorrect. The correct answer is $correctText. $explanation';
        if (_isTTSEnabled && toSpeak.isNotEmpty) {
          unawaited(
            Future<void>.delayed(
              const Duration(milliseconds: 180),
              () => _ttsService.speakAndWait(toSpeak),
            ),
          );
        }
      }
    });
  }

  List<String> _acceptableFillBlankAnswers(GameItem question) {
    final Set<String> answers = {};
    final rawPrimary = question.correctAnswer;
    if (rawPrimary != null) {
      if (rawPrimary is String) {
        answers.add(rawPrimary.trim());
      } else {
        answers.add(rawPrimary.toString().trim());
      }
    }
    return answers.where((a) => a.isNotEmpty).toList();
  }

  bool _isFillBlankCorrect(GameItem question, String userAnswer) {
    final normalizedUser = userAnswer.trim().toLowerCase();
    if (normalizedUser.isEmpty) return false;
    for (final answer in _acceptableFillBlankAnswers(question)) {
      if (normalizedUser == answer.trim().toLowerCase()) return true;
    }
    return false;
  }

  void _submitFillBlankAnswer() {
    final question = _questions[_currentQuestionIndex];
    if (!_isFillBlankQuestion(question) || _showWrongAnswerFeedback) return;
    final answer = _fillBlankController.text.trim();
    if (answer.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Type your answer before submitting.',
            style: GoogleFonts.poppins(fontSize: 13),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final isCorrect = _isFillBlankCorrect(question, answer);
    final rawQuestionText = (question.question ?? question.term ?? '').trim();
    if (rawQuestionText.isNotEmpty) {
      _questionBreakdown.add(
        QuestionPerformance(question: rawQuestionText, isCorrect: isCorrect),
      );
    }

    safeSetState(() {
      _stopCountdown();
      _submittedFillBlankAnswer = answer;
      _showWrongAnswerFeedback = true;
      if (isCorrect) {
        _score++;
        _xpEarned += 12;
        _lastCorrectXp = 12;
        _xpPopupVisible = true;
      }
    });

    if (isCorrect) {
      _soundService.playCorrect();
      _confettiController.play();
      _showMascotReaction(
        'Perfect fill. You are locked in.',
        tone: CompanionTone.success,
        celebrate: true,
      );
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
      unawaited(_soundService.registerUserGesture());
      unawaited(_soundService.playIncorrect());
      _showMascotReaction(
        'Not quite. Let us use the hint and next one is yours.',
        tone: CompanionTone.tip,
      );
    }
  }

  String _correctFillBlankText(GameItem question) {
    final answers = _acceptableFillBlankAnswers(question);
    if (answers.isEmpty) return 'No answer provided';
    return answers.first;
  }

  void _submitDragDropAnswer() {
    final question = _questions[_currentQuestionIndex];
    if (!_isDragDropQuestion(question) || _showWrongAnswerFeedback) return;
    final dragItems = question.dragItems ?? [];
    final dropZones = question.dropZones ?? [];
    if (_dragAssignments.length < dropZones.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Place all items before submitting.',
            style: GoogleFonts.poppins(fontSize: 13),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final isCorrect = DragDropQuestionWidget.evaluateAssignments(
      dragItems: dragItems,
      dropZones: dropZones,
      assignments: _dragAssignments,
    );

    final rawQuestionText = (question.question ?? question.term ?? '').trim();
    if (rawQuestionText.isNotEmpty) {
      _questionBreakdown.add(
        QuestionPerformance(question: rawQuestionText, isCorrect: isCorrect),
      );
    }

    safeSetState(() {
      _stopCountdown();
      _showWrongAnswerFeedback = true;
      if (isCorrect) {
        _score++;
        _xpEarned += 12;
        _lastCorrectXp = 12;
        _xpPopupVisible = true;
      }
    });

    if (isCorrect) {
      _soundService.playCorrect();
      _confettiController.play();
      _showMascotReaction(
        'Nice match mapping. Excellent.',
        tone: CompanionTone.success,
        celebrate: true,
      );
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
      unawaited(_soundService.registerUserGesture());
      unawaited(_soundService.playIncorrect());
      _showMascotReaction(
        'Good attempt. Check the mapping and retry the next.',
        tone: CompanionTone.tip,
      );
    }
  }

  void _showMascotReaction(
    String message, {
    CompanionTone tone = CompanionTone.neutral,
    bool celebrate = false,
    Duration duration = const Duration(seconds: 2),
  }) {
    _mascotReactionTimer?.cancel();
    if (!mounted) return;
    safeSetState(() {
      _mascotReaction = message;
      _mascotReactionTone = tone;
      _mascotCelebrate = celebrate;
    });
    _mascotReactionTimer = Timer(duration, () {
      if (!mounted) return;
      safeSetState(() {
        _mascotReaction = null;
        _mascotCelebrate = false;
      });
    });
  }

  String _correctDragMappingText(GameItem question) {
    return DragDropQuestionWidget.buildMappingText(question.dragItems ?? []);
  }

  void _nextQuestion() {
    safeSetState(() {
      _lastCorrectXp = null;
      _xpPopupVisible = false;
      _showWrongAnswerFeedback = false;
      _stopCountdown();
      _dragAssignments.clear();
      _fillBlankController.clear();
      _submittedFillBlankAnswer = null;
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
    _gameCompleted = true;
    await GameProgressService.clearProgress(widget.game.id);
    final timeTaken = DateTime.now().difference(_startTime!).inSeconds;
    final totalQuestions = _questions.length;
    final isPerfectScore = _score == totalQuestions;

    _xpEarned += 50; // Completion bonus per PRD

    if (isPerfectScore) {
      _confettiController.play();
    }
    // Don't block navigation on audio playback.
    unawaited(_soundService.playComplete());
    unawaited(
      GameStatsService.addGameResult(
        correctAnswers: _score,
        totalQuestions: totalQuestions,
        timeTakenSeconds: timeTaken,
        isPerfectScore: isPerfectScore,
      ).catchError((_) {}),
    );

    if (widget.isDailyChallenge) {
      unawaited(
        DailyChallengeService.markCompleteForToday(
          childId: widget.game.childId,
        ),
      );
    }

    unawaited(
      SkulMateService.saveGameSession(
        gameId: widget.game.id,
        score: _score,
        totalQuestions: totalQuestions,
        correctAnswers: _score,
        timeTakenSeconds: timeTaken,
        answers: {
          'breakdown': _questionBreakdown
              .map((q) => {
                    'question': q.question,
                    'isCorrect': q.isCorrect,
                  })
              .toList(),
        },
      ).catchError((_) {}),
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
            questionBreakdown: _questionBreakdown,
            fromGenerationFlow: widget.fromGenerationFlow,
          ),
        ),
      );
    }
  }

  void _openLearnMoreSheet({
    required String term,
    required String definition,
  }) {
    _ttsService.stop();
    final explainFuture = SkulMateService.explainFlashcard(
      term: term,
      definition: definition,
      gameId: widget.game.id,
      weakTopicReroute: true,
    );

    bool didAutoSpeak = false;
    bool isSpeaking = false;
    String? explanationText;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, modalSetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: SafeArea(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.85,
                  ),
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(20),
                      ),
                    ),
                    child: FutureBuilder<ExplainResult>(
                      future: explainFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Padding(
                            padding: EdgeInsets.all(24),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }

                        if (snapshot.hasError || !snapshot.hasData) {
                          return const Padding(
                            padding: EdgeInsets.all(24),
                            child: Text(
                              'Could not load more details right now.',
                            ),
                          );
                        }

                        final result = snapshot.data!;
                        explanationText = result.explanation;

                        if (_isTTSEnabled && !didAutoSpeak) {
                          didAutoSpeak = true;
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (!context.mounted) return;
                            isSpeaking = true;
                            modalSetState(() {});
                            unawaited(_ttsService.speak(result.explanation));
                          });
                        }

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(16, 14, 12, 10),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Learn more',
                                      style: GoogleFonts.poppins(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: AppTheme.textDark,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () {
                                      if (explanationText == null ||
                                          explanationText!.trim().isEmpty) {
                                        return;
                                      }

                                      if (isSpeaking) {
                                        _ttsService.stop();
                                        isSpeaking = false;
                                        modalSetState(() {});
                                      } else if (_isTTSEnabled) {
                                        unawaited(_ttsService
                                            .speak(explanationText!));
                                        isSpeaking = true;
                                        modalSetState(() {});
                                      }
                                    },
                                    icon: Icon(
                                      isSpeaking
                                          ? Icons.volume_up_rounded
                                          : Icons.volume_off_rounded,
                                      color: AppTheme.primaryColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Expanded(
                              child: SingleChildScrollView(
                                padding: const EdgeInsets.all(16),
                                child: Text(
                                  result.explanation,
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    height: 1.6,
                                    color: AppTheme.textDark,
                                  ),
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                              child: SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: () {
                                    _ttsService.stop();
                                    Navigator.of(context).pop();
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.primaryColor,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: const Text('Done'),
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
            );
          },
        );
      },
    );
  }

  Future<void> _openFirstTimeSoundSettingsSheet() async {
    // Keep user preference intact; do not force-disable global music.
    await _soundService.toggleSounds(true);
    _ttsService.setEnabled(true);
    if (mounted) safeSetState(() => _isTTSEnabled = true);
    await _openGameSettingsSheet();
  }

  Future<void> _openGameSettingsSheet() async {
    await GameSettingsSheet.show(
      context: context,
      soundService: _soundService,
      gameType: widget.game.gameType,
      musicGameTypeOverride: GameType.mystery,
      ttsService: _ttsService,
      isTTSEnabled: _isTTSEnabled,
      onTTSToggled: (v) {
        safeSetState(() => _isTTSEnabled = v);
      },
    );
  }

  Widget _buildCountdownBadge() {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withOpacity(0.14),
            blurRadius: 10,
            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
      child: Stack(
        alignment: Alignment.center,
                        children: [
          SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(
              value: _countdownRemaining / _countdownSecondsPerQuestion,
              strokeWidth: 3.2,
              backgroundColor: AppTheme.softBorder,
              valueColor: AlwaysStoppedAnimation<Color>(
                _countdownRemaining <= 5
                    ? Colors.red
                    : AppTheme.primaryColor,
              ),
            ),
          ),
                          Text(
            '${_countdownRemaining}s',
                            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: _countdownRemaining <= 5 ? Colors.red : AppTheme.textDark,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_currentQuestionIndex >= _questions.length) {
      return Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final question = _questions[_currentQuestionIndex];
    final progress = (_currentQuestionIndex + 1) / _questions.length;
    final isBossQuestion = question.isBoss;
    final correctAnswerIdx = question.correctAnswer is int
        ? question.correctAnswer as int
        : (question.correctAnswer is String
              ? int.tryParse(question.correctAnswer.toString()) ?? 0
              : 0);
    final correctAnswerText =
        (question.options != null &&
            correctAnswerIdx < question.options!.length)
        ? question.options![correctAnswerIdx]
        : '';

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        if (didPop) return;
        await _stopVoiceAndMusic();
        if (!context.mounted) return;
        Navigator.of(context).pop(result);
      },
      child: Stack(
        children: [
          Scaffold(
            appBar: SkulMateGameAppBar(
              title: widget.game.title,
              leading: SkulMateNavigation.gameBackButton(
                context,
                onPressed: () async {
                  await _stopVoiceAndMusic();
                  await _persistProgress();
                  if (!context.mounted) return;
                  if (widget.fromGenerationFlow) {
                    SkulMateNavigation.exitToSkulMateHome(context);
                  } else {
                    SkulMateNavigation.popGame(context);
                  }
                },
              ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 4, left: 0),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => unawaited(_openGameSettingsSheet()),
                  child: CircleAvatar(
                    radius: 16,
                    backgroundColor: Colors.white.withOpacity(0.22),
                    child: const SkulMateProfileAvatar(
                    size: 28,
                    forGameAppBar: true,
                  ),
                  ),
                ),
              ),
            ],
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: GameStandardsHud(
                        progressText:
                          'Question ${_currentQuestionIndex + 1} of ${_questions.length}',
                        progressValue: progress,
                        xpEarned: _xpEarned,
                        gameType: widget.game.gameType,
                      ),
                    ),
                    const SizedBox(width: 10),
                    _buildCountdownBadge(),
                  ],
                ),
              ),
              if (_mascotReaction != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                  child: SkulMateCompanionBanner(
                    tone: _mascotReactionTone,
                    message: _mascotReaction!,
                    celebrate: _mascotCelebrate,
                ),
              ),
              Expanded(
                child: Container(
                  color: AppTheme.softBackground,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isBossQuestion)
                          Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade700.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.amber.shade700,
                                width: 2,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '⚔️',
                                  style: GoogleFonts.poppins(fontSize: 18),
                                ),
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
                        // One unified gameplay card: question + interaction area.
                        FlatStageCard(
                          backgroundColor: const Color(0xFFF8FAFF),
                          borderColor: AppTheme.primaryColor.withOpacity(0.25),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                            (question.question ?? '').trim().isEmpty
                                ? 'Question content is loading...'
                                : (question.question ?? ''),
                            style: GoogleFonts.poppins(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              height: 1.28,
                              color: AppTheme.textDark,
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
                        const SizedBox(height: 12),
                        if (!_isDragDropQuestion(question) &&
                            !_isFillBlankQuestion(question) &&
                            (question.options ?? []).isEmpty)
                          Container(
                            width: double.infinity,
                                  padding: const EdgeInsets.all(16),
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
                                      const SizedBox(height: 10),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: OutlinedButton(
                                              onPressed: _nextQuestion,
                                              style: OutlinedButton.styleFrom(
                                                foregroundColor: AppTheme.primaryColor,
                                                side: const BorderSide(
                                                  color: AppTheme.primaryColor,
                                                ),
                                              ),
                                              child: const Text('Skip question'),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: ElevatedButton(
                                              onPressed: () {
                                                SkulMateNavigation.exitToSkulMateHome(context);
                                              },
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: AppTheme.primaryColor,
                                                foregroundColor: Colors.white,
                                              ),
                                              child: const Text('Dashboard'),
                                            ),
                                          ),
                                        ],
                                ),
                              ],
                            ),
                          ),
                        if (_isDragDropQuestion(question)) ...[
                          DragDropQuestionWidget(
                            dragItems: question.dragItems ?? const [],
                            dropZones: question.dropZones ?? const [],
                            assignments: _dragAssignments,
                            showCorrection: _showWrongAnswerFeedback,
                            onAssignmentsChanged: (next) {
                              safeSetState(() {
                                _dragAssignments
                                  ..clear()
                                  ..addAll(next);
                              });
                            },
                          ),
                                if (!_showWrongAnswerFeedback) ...[
                                  const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _submitDragDropAnswer,
                                icon: const Icon(Icons.check, size: 16),
                                label: const Text('Submit answer'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primaryColor,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                                ],
                        ] else if (_isFillBlankQuestion(question)) ...[
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppTheme.softBorder),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  (question.blankText ?? '').trim().isEmpty
                                      ? 'Fill in the missing word or phrase'
                                      : question.blankText!,
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: AppTheme.textDark,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                TextField(
                                  controller: _fillBlankController,
                                  enabled: !_showWrongAnswerFeedback,
                                  decoration: InputDecoration(
                                    hintText: 'Type your answer',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                  ),
                                  style: GoogleFonts.poppins(fontSize: 14),
                                  onSubmitted: (_) {
                                    if (!_showWrongAnswerFeedback) {
                                      _submitFillBlankAnswer();
                                    }
                                  },
                                ),
                                const SizedBox(height: 10),
                                if (!_showWrongAnswerFeedback)
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      onPressed: _submitFillBlankAnswer,
                                      icon: const Icon(Icons.check, size: 16),
                                      label: const Text('Submit answer'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppTheme.primaryColor,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ] else if ((question.options ?? []).isNotEmpty)
                          ..._getShuffledOptionIndices(
                            question,
                          ).asMap().entries.map((entry) {
                            final displayIndex = entry.key;
                            final originalIndex = entry.value;
                                  final option = (question.options ?? [])[originalIndex];
                            final isSelected =
                                _selectedAnswerIndex == displayIndex;
                            final correctAnswerIndex =
                                question.correctAnswer is int
                                ? question.correctAnswer as int
                                : (question.correctAnswer is String
                                      ? int.tryParse(
                                              question.correctAnswer.toString(),
                                            ) ??
                                            0
                                      : 0);
                                  final isCorrect = originalIndex == correctAnswerIndex;
                            final showResult = _selectedAnswerIndex != null;

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                                    child: FlatChoiceTile(
                                      label: option,
                                      isSelected: isSelected,
                                      isCorrect: isCorrect,
                                      showResult: showResult,
                                  onTap: _showWrongAnswerFeedback
                                      ? null
                                      : () => _selectAnswer(displayIndex),
                                    ),
                                  );
                                }),
                            ],
                          ),
                        ),
                        if (_showWrongAnswerFeedback) ...[
                          const SizedBox(height: 12),
                          FlatStageCard(
                            backgroundColor: AppTheme.accentLightGreen.withOpacity(0.6),
                            borderColor: AppTheme.accentGreen,
                            radius: 14,
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Wrap(
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  spacing: 8,
                                  runSpacing: 4,
                                  children: [
                                    Icon(
                                      Icons.check_circle,
                                      color: AppTheme.accentGreen,
                                      size: 22,
                                    ),
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
                                if (_isDragDropQuestion(question))
                                  Text(
                                    _correctDragMappingText(question),
                                    style: GoogleFonts.poppins(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.primaryColor,
                                      height: 1.45,
                                    ),
                                  )
                                else if (_isFillBlankQuestion(question))
                                  Text(
                                    _correctFillBlankText(question),
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.primaryColor,
                                    ),
                                  )
                                else
                                  Text(
                                    correctAnswerText,
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.primaryColor,
                                    ),
                                  ),
                                if (_isFillBlankQuestion(question) &&
                                    (_submittedFillBlankAnswer ?? '').trim().isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    'Your answer: ${_submittedFillBlankAnswer!.trim()}',
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      color: AppTheme.textMedium,
                                    ),
                                  ),
                                ],
                                if ((question.explanation ?? '')
                                    .trim()
                                    .isNotEmpty) ...[
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
                                const SizedBox(height: 10),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: TextButton(
                                    onPressed: () {
                                      final term = correctAnswerText.trim();
                                      if (term.isEmpty) return;
                                      final definition = (question.explanation ??
                                              question.question ??
                                              '')
                                          .trim();

                                      _soundService.playClick();
                                      _openLearnMoreSheet(
                                        term: term,
                                        definition: definition,
                                      );
                                    },
                                    style: TextButton.styleFrom(
                                      padding: EdgeInsets.zero,
                                      minimumSize: Size.zero,
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    child: Text(
                                      'Learn more',
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: AppTheme.primaryColor,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: () {
                                      _ttsService.stop();
                                      _nextQuestion();
                                    },
                                    icon: const Icon(
                                      Icons.arrow_forward,
                                      size: 16,
                                    ),
                                    label: const Text('Next question'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.primaryColor,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
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
    ),
    );
  }
}
