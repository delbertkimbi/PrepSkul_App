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
import '../services/tts_service.dart';
import '../services/game_progress_service.dart';
import '../widgets/skulmate_game_app_bar.dart';
import '../widgets/skulmate_profile_avatar.dart';
import '../widgets/game_standard_widgets.dart';
import '../widgets/game_settings_sheet.dart';
import '../widgets/skulmate_companion_banner.dart';
import '../utils/skulmate_navigation.dart';
import 'game_results_screen.dart';

/// Fill-in-the-blank game screen
class FillBlankGameScreen extends StatefulWidget {
  final GameModel game;
  final GameProgress? resumeFrom;

  const FillBlankGameScreen({
    Key? key,
    required this.game,
    this.resumeFrom,
  }) : super(key: key);

  @override
  State<FillBlankGameScreen> createState() => _FillBlankGameScreenState();
}

class _FillBlankGameScreenState extends State<FillBlankGameScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  int _currentQuestionIndex = 0;
  final Map<int, TextEditingController> _controllers = {};
  final Map<int, String> _userAnswers = {}; // questionIndex -> answer
  final Map<int, bool> _answeredQuestions = {}; // questionIndex -> isCorrect
  int _score = 0;
  int _currentStreak = 0;
  int _xpEarned = 0;
  DateTime? _startTime;
  final GameSoundService _soundService = GameSoundService();
  final TTSService _ttsService = TTSService();
  late ConfettiController _confettiController;
  late AnimationController _progressController;
  late Animation<double> _progressAnimation;
  late AnimationController _timerController;
  late Animation<double> _timerAnimation;
  late AnimationController _typingController;
  GameStats? _currentStats;
  bool _ttsEnabled = true;

  // Typing game mechanics
  int _timePerQuestion = 45; // seconds
  int _remainingTime = 45;
  Timer? _questionTimer;
  Timer? _autoAdvanceTimer;
  Timer? _bgmKeepAliveTimer;
  bool _isTimerRunning = false;
  bool _isFinishingGame = false;
  bool _gameCompleted = false;
  List<String> _hints = []; // Auto-complete hints
  bool _hintShown = false;
  int _typingSpeed = 0; // Characters per second
  DateTime? _typingStartTime;
  int _charactersTyped = 0;
  String? _mascotReaction;
  CompanionTone _mascotReactionTone = CompanionTone.neutral;
  bool _mascotCelebrate = false;
  Timer? _mascotReactionTimer;
  final Map<int, List<String>> _displayOptionsCache = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.resumeFrom != null) {
      final max = widget.game.items.isEmpty ? 0 : widget.game.items.length - 1;
      _currentQuestionIndex =
          widget.resumeFrom!.currentIndex.clamp(0, max);
      _score = widget.resumeFrom!.score;
    }
    _startTime = DateTime.now();
    unawaited(_initAudio());
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 2),
    );
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
    _timerAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _timerController, curve: Curves.linear));
    _typingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    // Initialize controllers
    for (int i = 0; i < widget.game.items.length; i++) {
      _controllers[i] = TextEditingController();
      _controllers[i]!.addListener(() => _onTextChanged(i));
    }
    _loadStats();
    _startQuestionTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_speakCurrentPrompt());
    });
  }

  Future<void> _initAudio() async {
    await _soundService.ensureInitialized();
    await _soundService.playMusicForGame(widget.game.gameType);
    // Retry once shortly after mount for devices where first start is delayed.
    unawaited(
      Future<void>.delayed(
        const Duration(milliseconds: 250),
        () => _soundService.playMusicForGame(widget.game.gameType),
      ),
    );
    await _ttsService.ensureInitialized();
    _ttsEnabled = _ttsService.isEnabled;
    _bgmKeepAliveTimer?.cancel();
    _bgmKeepAliveTimer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (!mounted) return;
      unawaited(_soundService.ensureMusicForGame(widget.game.gameType));
    });
    safeSetState(() {});
  }

  Future<void> _speakCurrentPrompt() async {
    if (!_ttsEnabled || !mounted) return;
    await _ttsService.stop();
    final current = widget.game.items[_currentQuestionIndex];
    final prompt = (current.blankText ?? '').trim();
    if (prompt.isEmpty) return;
    final spokenPrompt = prompt
        .replaceAll(RegExp(r'(_{2,}|-{2,}|\.{3,})'), ' dash ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    await _ttsService.speak('Fill in the blank. $spokenPrompt');
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
    final correctAnswer = (question.correctAnswer ?? '')
        .toString()
        .toLowerCase();
    final partialLower = partial.toLowerCase();

    // Simple hint generation - show if partial matches start of answer
    if (correctAnswer.startsWith(partialLower)) {
      final remaining = correctAnswer.substring(partialLower.length);
      if (remaining.isNotEmpty) {
        safeSetState(() {
          _hints = [
            remaining.substring(
              0,
              remaining.length > 10 ? 10 : remaining.length,
            ),
          ];
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

      if (_remainingTime <= 10 && _remainingTime > 0) {
        unawaited(_soundService.playCountdownTick());
      }

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
      final question = widget.game.items[_currentQuestionIndex];
      final correctAnswer = _formatRangeAnswer(
        (question.correctAnswer ?? '').toString(),
      );
      final explanation = (question.explanation ?? '').trim();
      // Time's up - mark as incorrect
      safeSetState(() {
        _userAnswers[_currentQuestionIndex] = '';
        _answeredQuestions[_currentQuestionIndex] = false;
        _currentStreak = 0;
      });
      _soundService.playIncorrect();
      _showMascotReaction(
        'Time up. Correct answer shown. Read the explanation and continue.',
        tone: CompanionTone.warning,
      );
      if (_ttsEnabled) {
        unawaited(_ttsService.stop());
        final explanationSpeech = explanation.isEmpty ? '' : ' Explanation: $explanation';
        _autoAdvanceTimer?.cancel();
        unawaited(() async {
          await _ttsService.speakAndWait(
            'Time is up. The correct answer is $correctAnswer.$explanationSpeech',
            timeout: const Duration(milliseconds: 3800),
          );
          await _soundService.resumeBgmIfNeeded();
          if (mounted) _nextQuestion();
        }());
      } else {
        _autoAdvanceTimer?.cancel();
        _autoAdvanceTimer = Timer(const Duration(milliseconds: 2600), () {
          if (mounted) _nextQuestion();
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            explanation.isEmpty
                ? '⏰ Time\'s up! Correct answer: $correctAnswer'
                : '⏰ Time\'s up! Correct: $correctAnswer • ${explanation.length > 90 ? '${explanation.substring(0, 90)}...' : explanation}',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          ),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 3),
        ),
      );

    }
  }

  Future<void> _persistProgress() async {
    if (_gameCompleted || _isFinishingGame) return;
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
    WidgetsBinding.instance.removeObserver(this);
    _mascotReactionTimer?.cancel();
    _questionTimer?.cancel();
    _autoAdvanceTimer?.cancel();
    _bgmKeepAliveTimer?.cancel();
    unawaited(_persistProgress());
    unawaited(_ttsService.stop());
    unawaited(_soundService.stopMusic(force: true));
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    _progressController.dispose();
    _timerController.dispose();
    _typingController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_soundService.resumeBgmIfNeeded());
    }
  }

  Future<void> _loadStats() async {
    final stats = await GameStatsService.getStats();
    safeSetState(() {
      _currentStats = stats;
      _currentStreak = stats.currentStreak;
    });
  }

  void _openGameSettingsSheet() {
    GameSettingsSheet.show(
      context: context,
      soundService: _soundService,
      gameType: widget.game.gameType,
      musicGameTypeOverride: widget.game.gameType,
      ttsService: _ttsService,
      isTTSEnabled: _ttsEnabled,
      onTTSToggled: (enabled) {
        _ttsEnabled = enabled;
        safeSetState(() {});
      },
    );
  }

  List<String> _currentOptions(GameItem question) {
    final raw = question.options ?? const <String>[];
    return raw
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
  }

  List<String> _displayOptionsForQuestion(GameItem question) {
    final cacheKey = _currentQuestionIndex;
    final cached = _displayOptionsCache[cacheKey];
    if (cached != null && cached.isNotEmpty) return cached;

    final direct = _currentOptions(question);
    if (direct.isNotEmpty) {
      _displayOptionsCache[cacheKey] = direct;
      return direct;
    }

    final correct = (question.correctAnswer ?? '').toString().trim();
    final pool = <String>{};
    if (correct.isNotEmpty) pool.add(correct);

    for (final item in widget.game.items) {
      final candidate = (item.correctAnswer ?? '').toString().trim();
      if (candidate.isNotEmpty && candidate.toLowerCase() != correct.toLowerCase()) {
        pool.add(candidate);
      }
      if (pool.length >= 6) break;
    }

    final options = pool.toList()..shuffle();
    if (correct.isNotEmpty && !options.any((e) => e.toLowerCase() == correct.toLowerCase())) {
      options.insert(0, correct);
    }
    final bounded = options.take(6).toList(growable: false);
    _displayOptionsCache[cacheKey] = bounded;
    return bounded;
  }

  String _formatRangeAnswer(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return value;
    final match = RegExp(
      r'^\s*([^-\u2013\u2014]+)\s*[-\u2013\u2014]\s*([^-\u2013\u2014]+)\s*$',
    ).firstMatch(value);
    if (match == null) return value;
    final left = (match.group(1) ?? '').trim();
    final right = (match.group(2) ?? '').trim();
    if (left.isEmpty || right.isEmpty) return value;
    return '$left to $right';
  }

  Widget _buildQuestionPrompt(GameItem question, bool isAnswered, bool isCorrect) {
    final text = question.blankText ?? '';
    final blankMatches = RegExp(r'(_{2,}|-{2,}|\.{3,})').allMatches(text).toList();
    if (blankMatches.isEmpty || !isAnswered) {
      return Text(
        text,
        style: GoogleFonts.poppins(fontSize: 18, color: AppTheme.textDark),
      );
    }
    final userAnswer = (_userAnswers[_currentQuestionIndex] ?? '').trim();
    final correctAnswer = (question.correctAnswer ?? '').toString().trim();
    final answerToShow = _formatRangeAnswer(
      isCorrect ? userAnswer : correctAnswer,
    );
    final isRangeAnswer = answerToShow.toLowerCase().contains(' to ');
    final first = blankMatches.first;
    final second = blankMatches.length > 1 ? blankMatches[1] : null;
    final useCombinedRangeSlot = isRangeAnswer && second != null;
    final replaceStart = first.start;
    final replaceEnd = useCombinedRangeSlot ? second!.end : first.end;
    final before = text.substring(0, replaceStart);
    final after = text.substring(replaceEnd);
    final answerColor = isCorrect ? AppTheme.accentGreen : const Color(0xFF1D4ED8);
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: before),
          TextSpan(
            text: answerToShow,
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: answerColor,
            ),
          ),
          TextSpan(text: after),
        ],
      ),
      style: GoogleFonts.poppins(fontSize: 18, color: AppTheme.textDark),
    );
  }

  void _submitAnswer() {
    _autoAdvanceTimer?.cancel();
    _questionTimer?.cancel();
    _isTimerRunning = false;

    final answer = _controllers[_currentQuestionIndex]?.text.trim() ?? '';
    if (answer.isEmpty) return;

    final question = widget.game.items[_currentQuestionIndex];
    final correctAnswer = (question.correctAnswer ?? '')
        .toString()
        .toLowerCase()
        .trim();
    final userAnswer = answer.toLowerCase().trim();
    final isCorrect = userAnswer == correctAnswer;
    if (_ttsEnabled) {
      unawaited(_ttsService.stop());
    }

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

    // Play success/fail audio outside setState so it starts immediately.
    if (isCorrect) {
      unawaited(_soundService.registerUserGesture());
      unawaited(_soundService.playCorrect());
      // Layer a soft match ping for clearer "correct" feedback on device speakers.
      unawaited(
        Future<void>.delayed(
          const Duration(milliseconds: 110),
          _soundService.playMatch,
        ),
      );
    } else {
      unawaited(_soundService.registerUserGesture());
      unawaited(_soundService.playIncorrect());
    }

    safeSetState(() {
      _userAnswers[_currentQuestionIndex] = answer;
      _answeredQuestions[_currentQuestionIndex] = isCorrect;
      if (isCorrect) {
        _score++;
        _currentStreak++;
        _xpEarned += xpForThisAnswer;
        _showMascotReaction(
          'Great typing! Strong accuracy.',
          tone: CompanionTone.success,
          celebrate: true,
        );
        if (_ttsEnabled) {
          unawaited(
            Future<void>.delayed(
              const Duration(milliseconds: 320),
              () => _ttsService.speak('Correct. Nice work.'),
            ),
          );
        }
        // Trigger confetti
        _confettiController.play();
      } else {
        _currentStreak = 0; // Reset streak on wrong answer
        _showMascotReaction(
          'Almost there. Check spelling and try next.',
          tone: CompanionTone.tip,
        );
        if (_ttsEnabled) {
          unawaited(
            Future<void>.delayed(
              const Duration(milliseconds: 200),
              () => _ttsService.speak(
                'Not quite. The correct answer is ${_formatRangeAnswer((question.correctAnswer ?? '').toString())}.',
              ),
            ),
          );
        }
      }
      _hints = [];
      _hintShown = false;
    });

    // Update progress bar animation
    final newProgress = (_currentQuestionIndex + 1) / widget.game.items.length;
    _progressAnimation =
        Tween<double>(
          begin: _progressAnimation.value,
          end: newProgress,
        ).animate(
          CurvedAnimation(parent: _progressController, curve: Curves.easeOut),
        );
    _progressController.forward(from: 0);

    // Keep successful path clean; only show snackbar on incorrect answers.
    if (!isCorrect) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Incorrect. The answer is: ${_formatRangeAnswer((question.correctAnswer ?? '').toString())}',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
    }

    // Keep flow deterministic: user explicitly moves with Next button.
  }

  void _nextQuestion() {
    _autoAdvanceTimer?.cancel();
    unawaited(_ttsService.stop());
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
      final newProgress =
          (_currentQuestionIndex + 1) / widget.game.items.length;
      _progressAnimation =
          Tween<double>(
            begin: _progressAnimation.value,
            end: newProgress,
          ).animate(
            CurvedAnimation(parent: _progressController, curve: Curves.easeOut),
          );
      _progressController.forward(from: 0);
      _startQuestionTimer(); // Start timer for next question
      unawaited(_speakCurrentPrompt());
    } else {
      _finishGame();
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

  void _previousQuestion() {
    _autoAdvanceTimer?.cancel();
    unawaited(_ttsService.stop());
    _soundService.playClick();
    if (_currentQuestionIndex > 0) {
      safeSetState(() {
        _currentQuestionIndex--;
      });
    }
  }

  Future<void> _finishGame() async {
    if (_isFinishingGame) return;
    _isFinishingGame = true;
    _gameCompleted = true;
    await GameProgressService.clearProgress(widget.game.id);
    _autoAdvanceTimer?.cancel();
    _questionTimer?.cancel();
    await _ttsService.stop();
    await _soundService.stopMusic(force: true);

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

    unawaited(() async {
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
    }());

    unawaited(
      SkulMateService.saveGameSession(
        gameId: widget.game.id,
        score: _score,
        totalQuestions: widget.game.items.length,
        correctAnswers: _score,
        timeTakenSeconds: timeTaken,
        answers: _userAnswers.map(
          (key, value) => MapEntry(key.toString(), value),
        ),
      ).catchError((e) {
        LogService.error('🎮 [FillBlank] Error saving game session: $e');
      }),
    );

    // Play completion sound
    // Don't block navigation on audio playback.
    unawaited(_soundService.playComplete());

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

  Future<void> _exitGame() async {
    _autoAdvanceTimer?.cancel();
    _questionTimer?.cancel();
    await _persistProgress();
    await _ttsService.stop();
    await _soundService.stopMusic(force: true);
    if (mounted) {
      SkulMateNavigation.exitToSkulMateHome(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final question = widget.game.items[_currentQuestionIndex];
    final isAnswered = _answeredQuestions.containsKey(_currentQuestionIndex);
    final isCorrect = _answeredQuestions[_currentQuestionIndex] ?? false;
    final options = _displayOptionsForQuestion(question);
    final hasSuggestedAnswers = options.isNotEmpty;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          unawaited(_exitGame());
        }
      },
      child: Scaffold(
        backgroundColor: AppTheme.softBackground,
        appBar: SkulMateGameAppBar(
          title: widget.game.title,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => unawaited(_exitGame()),
          ),
          actions: [
          Padding(
            padding: const EdgeInsets.only(right: 4, left: 0),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: _openGameSettingsSheet,
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
        body: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => unawaited(_soundService.registerUserGesture()),
          child: Stack(
        children: [
          Column(
            children: [
              AnimatedBuilder(
                animation: _progressAnimation,
                builder: (context, child) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                    child: GameStandardsHud(
                      progressText:
                          'Question ${_currentQuestionIndex + 1} of ${widget.game.items.length}',
                      progressValue:
                          ((_currentQuestionIndex + 1) / widget.game.items.length)
                              .clamp(0.0, 1.0),
                      xpEarned: _xpEarned,
                      gameType: widget.game.gameType,
                    ),
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
                            child: FlatStageCard(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              backgroundColor: _remainingTime <= 10
                                  ? Colors.red.withOpacity(0.08)
                                  : Colors.white,
                              borderColor: _remainingTime <= 10
                                  ? Colors.red
                                  : AppTheme.accentGreen,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.timer,
                                    color: _remainingTime <= 10
                                        ? Colors.red
                                        : AppTheme.accentGreen,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '$_remainingTime',
                                    style: GoogleFonts.poppins(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      color: _remainingTime <= 10
                                          ? Colors.red
                                          : AppTheme.accentGreen,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (_typingSpeed > 0 && !isAnswered) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.blue,
                                  width: 1,
                                ),
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
                      const SizedBox(height: 4),
                      // Question with blank
                      FlatStageCard(
                        padding: const EdgeInsets.all(20),
                        radius: 16,
                        backgroundColor: Colors.white,
                        borderColor: AppTheme.primaryColor.withOpacity(0.16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildQuestionPrompt(question, isAnswered, isCorrect),
                            if (!isAnswered && hasSuggestedAnswers) ...[
                              const SizedBox(height: 12),
                              Text(
                                'Suggested answers',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textMedium,
                                ),
                              ),
                              const SizedBox(height: 8),
                              GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: options.length,
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 2,
                                      mainAxisSpacing: 8,
                                      crossAxisSpacing: 8,
                                      childAspectRatio: 2.4,
                                    ),
                                itemBuilder: (context, index) {
                                  final option = options[index];
                                  final selected =
                                      (_controllers[_currentQuestionIndex]?.text.trim() ?? '') ==
                                      option;
                                  return FlatChoiceTile(
                                    label: option,
                                    isSelected: selected,
                                    isCorrect: false,
                                    showResult: false,
                                    onTap: () {
                                      _controllers[_currentQuestionIndex]?.text = option;
                                      unawaited(_soundService.registerUserGesture());
                                      unawaited(_soundService.playClick());
                                      safeSetState(() {});
                                    },
                                  );
                                },
                              ),
                            ],
                            if (!isAnswered && hasSuggestedAnswers) ...[
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Text(
                                    'Tap one answer then submit.',
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: AppTheme.textMedium,
                                    ),
                                  ),
                                ],
                              ),
                            ],
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
                                    const Icon(
                                      Icons.info_outline,
                                      color: Colors.blue,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Correct answer: ${_formatRangeAnswer((question.correctAnswer ?? '').toString())}',
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
                            final answer =
                                _controllers[_currentQuestionIndex]?.text
                                    .trim() ??
                                '';
                            if (answer.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Please select an answer'),
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
                            _currentQuestionIndex ==
                                    widget.game.items.length - 1
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
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
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
                            if (_currentQuestionIndex > 0)
                              const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _nextQuestion,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primaryColor,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: Text(
                                  _currentQuestionIndex ==
                                          widget.game.items.length - 1
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
        ),
      ),
    );
  }
}
