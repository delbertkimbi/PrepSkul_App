import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../services/tts_service.dart';
import '../services/game_stats_service.dart';
import '../services/game_rules_service.dart';
import '../services/game_audio_lifecycle.dart';
import '../services/game_progress_service.dart';
import '../l10n/skulmate_copy.dart';
import '../widgets/game_settings_sheet.dart';
import '../widgets/skulmate_game_app_bar.dart';
import '../widgets/skulmate_profile_avatar.dart';
import '../widgets/skulmate_companion_banner.dart';
import '../widgets/game_standard_widgets.dart';
import '../widgets/matching_playfield.dart';
import '../widgets/skulmate_game_surface.dart';
import '../utils/skulmate_navigation.dart';
import 'game_results_screen.dart';

class CardData {
  final int id;
  final String text;
  final int pairId;
  final bool isLeft;

  CardData({
    required this.id,
    required this.text,
    required this.pairId,
    required this.isLeft,
  });
}

/// Matching pairs game screen
class MatchingGameScreen extends StatefulWidget {
  final GameModel game;
  final GameProgress? resumeFrom;

  const MatchingGameScreen({
    Key? key,
    required this.game,
    this.resumeFrom,
  }) : super(key: key);

  @override
  State<MatchingGameScreen> createState() => _MatchingGameScreenState();
}

class _MatchingGameScreenState extends State<MatchingGameScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  // Memory game: All cards face down, flip to find pairs
  late List<CardData> _cards;
  final Set<int> _flippedCards = {}; // Currently flipped card indices
  final Map<int, int> _matchedPairs = {}; // cardIndex -> pairIndex
  int? _firstFlipped;
  int? _secondFlipped;
  int _moves = 0;
  int _score = 0;
  int _currentStreak = 0;
  int _xpEarned = 0;
  DateTime? _startTime;
  final GameSoundService _soundService = GameSoundService();
  final TTSService _ttsService = TTSService();
  late ConfettiController _confettiController;
  late AnimationController _progressController;
  late Animation<double> _progressAnimation;
  final Map<int, AnimationController> _flipControllers = {};
  final Map<int, Animation<double>> _flipAnimations = {};
  GameStats? _currentStats;
  bool _isProcessing = false;
  bool _isTTSEnabled = true;
  int _hintsRemaining = 3; // Peek at a pair (limited uses)
  String? _mascotReaction;
  CompanionTone _mascotReactionTone = CompanionTone.neutral;
  bool _mascotCelebrate = false;
  Timer? _mascotReactionTimer;
  static const int _maxPairsPerScreen = 5;
  final List<GameItem> _allPairs = [];
  List<GameItem> _currentRoundPairs = [];
  final Set<int> _matchedInRound = {};
  bool _roundCompleting = false;
  String _feedbackMessage = '';
  GameFeedbackTone _feedbackTone = GameFeedbackTone.neutral;
  int? _flashWrongRightId;
  int? _celebratePairId;
  int _lastXpBurst = 0;
  int _edgeFlashTrigger = 0;
  bool _edgeFlashSuccess = true;
  int _matchPulseTrigger = 0;
  Timer? _feedbackTimer;
  List<int> _rightColumnPairIds = [];
  int? _activeLeftPairId;
  int _currentRoundStart = 0;
  int _completedPairs = 0;
  static const int _roundCountdownSeconds = 50;
  int _roundRemainingSeconds = _roundCountdownSeconds;
  Timer? _roundTimer;
  Timer? _leftTermSpeakTimer;
  int? _pendingLeftSpeakPairId;
  bool _gameCompleted = false;
  bool _awaitingSectionContinue = false;
  String _sectionContinueMessage = '';
  bool _xpPopupVisible = false;
  bool _isLeaving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startTime = DateTime.now();
    unawaited(_initializeAudio());
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
    _initializeItems();
    if (widget.resumeFrom != null) {
      _completedPairs = widget.resumeFrom!.currentIndex
          .clamp(0, _allPairs.length);
      _score = widget.resumeFrom!.score;
      _currentRoundStart =
          (_completedPairs ~/ _maxPairsPerScreen) * _maxPairsPerScreen;
      if (_currentRoundStart < _allPairs.length) {
        _loadCurrentRound();
      }
    }
    _loadStats();
  }

  Future<void> _initializeAudio() async {
    // Ensure engines are actually ready before first tap/check sounds.
    await _soundService.ensureInitialized();
    await _ttsService.ensureInitialized();
    _isTTSEnabled = _ttsService.isEnabled;
    // Recover from sessions where SFX was left disabled, while music is on.
    if (!_soundService.soundsEnabled) {
      await _soundService.toggleSounds(true);
    }
    // Use the Mystery ambient track for a stronger premium vibe.
    await _soundService.playMusicForGame(GameType.mystery);
  }

  Future<void> _loadStats() async {
    final stats = await GameStatsService.getStats();
    safeSetState(() {
      _currentStats = stats;
      _currentStreak = stats.currentStreak;
    });
  }

  void _initializeItems() {
    _allPairs
      ..clear()
      ..addAll(
        widget.game.items.where(
          (item) =>
              (item.leftItem ?? '').trim().isNotEmpty &&
              (item.rightItem ?? '').trim().isNotEmpty,
        ),
      );
    _cards = const <CardData>[];
    if (_allPairs.isEmpty) {
      _currentRoundPairs = const [];
      return;
    }
    _currentRoundStart = 0;
    _loadCurrentRound();
  }

  void _loadCurrentRound() {
    if (_isLeaving || !mounted) return;
    final end = min(_currentRoundStart + _maxPairsPerScreen, _allPairs.length);
    _currentRoundPairs = _allPairs.sublist(_currentRoundStart, end);
    _rightColumnPairIds = List<int>.generate(
      _currentRoundPairs.length,
      (i) => _currentRoundStart + i,
    )..shuffle(Random());
    _matchedInRound.clear();
    _activeLeftPairId = null;
    _cancelPendingLeftTermSpeak();
    _roundCompleting = false;
    _feedbackMessage = '';
    _flashWrongRightId = null;
    _startRoundCountdown();
    unawaited(_soundService.ensureMusicForGame(GameType.mystery));
      unawaited(_ttsService.stop());
    }

  void _onSelectLeft(int pairId) {
    if (_roundCompleting || _awaitingSectionContinue || _matchedInRound.contains(pairId)) {
      return;
    }
    unawaited(_soundService.registerUserGesture());

    if (_activeLeftPairId == pairId) {
      _cancelPendingLeftTermSpeak();
      unawaited(_soundService.playMatchingTap(quiet: _isTTSEnabled));
      if (_isTTSEnabled) unawaited(_ttsService.stop());
      safeSetState(() => _activeLeftPairId = null);
      return;
    }

    unawaited(_soundService.playMatchingTap(quiet: _isTTSEnabled));
    safeSetState(() => _activeLeftPairId = pairId);
    _scheduleLeftTermSpeak(pairId);
  }

  void _cancelPendingLeftTermSpeak() {
    _leftTermSpeakTimer?.cancel();
    _leftTermSpeakTimer = null;
    _pendingLeftSpeakPairId = null;
    _ttsService.cancelDebouncedSpeak();
  }

  void _scheduleLeftTermSpeak(int pairId) {
    if (!_isTTSEnabled) return;
    _pendingLeftSpeakPairId = pairId;
    _leftTermSpeakTimer?.cancel();
    _leftTermSpeakTimer = Timer(const Duration(milliseconds: 550), () {
      final pendingId = _pendingLeftSpeakPairId;
      if (!mounted || pendingId == null || _activeLeftPairId != pendingId) {
        return;
      }
      unawaited(_speakLeftTerm(pendingId));
    });
  }

  Future<void> _speakLeftTerm(int pairId) async {
    if (!_isTTSEnabled || _activeLeftPairId != pairId) return;
    final text = _leftLabelForPair(pairId);
    if (text.isEmpty) return;
    await _soundService.duckBgmForSpeech();
    await _ttsService.speak(text, interrupt: false);
  }

  void _showFeedback(String message, GameFeedbackTone tone) {
    _feedbackTimer?.cancel();
    safeSetState(() {
      _feedbackMessage = message;
      _feedbackTone = tone;
    });
    _feedbackTimer = Timer(const Duration(milliseconds: 2200), () {
      if (mounted) safeSetState(() => _feedbackMessage = '');
    });
  }

  void _onSelectRight(int rightPairId) {
    if (_roundCompleting || _awaitingSectionContinue || _activeLeftPairId == null) return;
    if (_matchedInRound.contains(rightPairId)) return;
    final leftPairId = _activeLeftPairId!;
    if (_matchedInRound.contains(leftPairId)) return;

    _cancelPendingLeftTermSpeak();
    unawaited(_soundService.registerUserGesture());
    unawaited(_soundService.playMatchingTap(quiet: _isTTSEnabled));
      _moves++;

    if (leftPairId == rightPairId) {
      if (_isTTSEnabled) {
        unawaited(_ttsService.stop());
      }
      _handleCorrectMatch(leftPairId);
    } else {
      _currentStreak = 0;
      HapticFeedback.mediumImpact();
    if (_isTTSEnabled) {
      unawaited(_ttsService.stop());
    }
      unawaited(_soundService.playIncorrect());
      final copy = SkulMateCopy.read(context);
      safeSetState(() {
        _flashWrongRightId = rightPairId;
        _activeLeftPairId = null;
        _edgeFlashSuccess = false;
        _edgeFlashTrigger++;
      });
      _showFeedback(copy.matchingTryAgain, GameFeedbackTone.error);
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) safeSetState(() => _flashWrongRightId = null);
      });
    }
  }

  void _handleCorrectMatch(int pairId) {
    _matchedInRound.add(pairId);
    _completedPairs++;
    _score++;
    _currentStreak++;
    _xpEarned += _currentStreak >= 3 ? 20 : 15;
    _lastXpBurst = _currentStreak >= 3 ? 20 : 15;
    _edgeFlashSuccess = true;
    _edgeFlashTrigger++;
    _matchPulseTrigger++;
    HapticFeedback.mediumImpact();
    unawaited(_soundService.playMatch());
    unawaited(_soundService.playCorrect());

    safeSetState(() {
      _activeLeftPairId = null;
      _celebratePairId = pairId;
      _feedbackMessage = '';
      _xpPopupVisible = true;
    });

    Future.delayed(const Duration(milliseconds: 720), () {
      if (mounted) {
        safeSetState(() {
          _celebratePairId = null;
          _xpPopupVisible = false;
        });
      }
    });

    final newProgress = _completedPairs / _allPairs.length.clamp(1, 9999);
    _progressAnimation = Tween<double>(
      begin: _progressAnimation.value,
      end: newProgress,
    ).animate(
      CurvedAnimation(parent: _progressController, curve: Curves.easeOut),
    );
    _progressController.forward(from: 0);

    if (_matchedInRound.length == _currentRoundPairs.length) {
      _handleRoundComplete();
    }
  }

  void _handleRoundComplete() {
    if (_roundCompleting) return;
    _roundCompleting = true;
    _roundTimer?.cancel();
    unawaited(_soundService.playMatchingSuccess());
    _confettiController.play();
    final copy = SkulMateCopy.read(context);
    final message = copy.matchingSectionComplete;
    safeSetState(() {
      _awaitingSectionContinue = true;
      _sectionContinueMessage = message;
      _feedbackMessage = message;
      _feedbackTone = GameFeedbackTone.success;
      _xpPopupVisible = false;
      _mascotReaction = null;
      _mascotCelebrate = false;
    });
  }

  void _onSectionContinue() {
    if (!_awaitingSectionContinue) return;
    unawaited(_ttsService.stop());
    safeSetState(() {
      _awaitingSectionContinue = false;
      _sectionContinueMessage = '';
      _feedbackMessage = '';
      _mascotReaction = null;
      _mascotCelebrate = false;
    });
    _nextRoundOrFinish();
  }

  void _nextRoundOrFinish() {
    _roundTimer?.cancel();
    _awaitingSectionContinue = false;
    _sectionContinueMessage = '';
    if (_completedPairs >= _allPairs.length) {
      unawaited(_finishGame());
      return;
    }
    _currentRoundStart += _maxPairsPerScreen;
    if (_currentRoundStart >= _allPairs.length) {
      unawaited(_finishGame());
      return;
    }
    safeSetState(_loadCurrentRound);
  }

  void _startRoundCountdown() {
    _roundTimer?.cancel();
    _roundRemainingSeconds = _roundCountdownSeconds;
    _roundTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _isLeaving) {
        timer.cancel();
        return;
      }
      if (_roundCompleting) {
        timer.cancel();
        return;
      }
      final nextRemaining = (_roundRemainingSeconds - 1).clamp(0, 9999);
      safeSetState(() {
        _roundRemainingSeconds = nextRemaining;
      });
      // Trigger tick based on the visible countdown value in red range.
      if (nextRemaining <= 10 && nextRemaining > 0) {
        unawaited(_soundService.playCountdownTick());
      }
      if (_roundRemainingSeconds <= 0) {
        timer.cancel();
        _onRoundTimeout();
      }
    });
  }

  void _onRoundTimeout() {
    if (_roundCompleting || _currentRoundPairs.isEmpty) return;
    _roundCompleting = true;
    _roundTimer?.cancel();
    for (var i = 0; i < _currentRoundPairs.length; i++) {
      final pairId = _currentRoundStart + i;
      if (!_matchedInRound.contains(pairId)) {
        _matchedInRound.add(pairId);
        _completedPairs++;
      }
    }
    unawaited(_soundService.playCountdownBuzzer());
    final copy = SkulMateCopy.read(context);
    final message = copy.matchingTimeUpContinue;
    safeSetState(() {
      _awaitingSectionContinue = true;
      _sectionContinueMessage = message;
      _feedbackMessage = message;
      _feedbackTone = GameFeedbackTone.error;
    });
    _showFeedback(message, GameFeedbackTone.error);
  }

  List<int> _roundLeftPairIds() => List<int>.generate(
        _currentRoundPairs.length,
        (i) => _currentRoundStart + i,
      );

  Widget _buildMatchingBoard() {
    return MatchingPlayfield(
      leftPairIds: _roundLeftPairIds(),
      rightPairIds: _rightColumnPairIds,
      leftLabel: _leftLabelForPair,
      rightLabel: _rightLabelForPair,
      matchedPairIds: _matchedInRound,
      activeLeftPairId: _activeLeftPairId,
      flashWrongRightId: _flashWrongRightId,
      celebratePairId: _celebratePairId,
      connectedLabel: _celebratePairId != null
          ? SkulMateCopy.of(context).matchingConnected
          : null,
      onLeftTap: _onSelectLeft,
      onRightTap: _onSelectRight,
    );
  }

  Widget _buildSectionActionArea() {
    if (_awaitingSectionContinue) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _onSectionContinue,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: Text(
            SkulMateCopy.of(context).matchingContinueButton,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
    }
    if (_roundCompleting) {
      return const SizedBox.shrink();
    }
    return Text(
      SkulMateCopy.of(context).matchingTapHint,
      textAlign: TextAlign.center,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 12.5,
        color: AppTheme.textMedium,
        fontStyle: FontStyle.italic,
      ),
    );
  }

  String _rightLabelForPair(int pairId) {
    if (pairId < 0 || pairId >= _allPairs.length) return '';
    return _allPairs[pairId].rightItem!.trim();
  }

  String _leftLabelForPair(int pairId) {
    if (pairId < 0 || pairId >= _allPairs.length) return '';
    return _allPairs[pairId].leftItem!.trim();
  }

  int _roundNumber() {
    return (_currentRoundStart ~/ _maxPairsPerScreen) + 1;
  }

  int _totalSections() {
    return (_allPairs.length / _maxPairsPerScreen).ceil();
  }

  double _progressValue() {
    if (_allPairs.isEmpty) return 0;
    return (_completedPairs / _allPairs.length).clamp(0.0, 1.0);
  }

  Future<void> _persistProgress() async {
    if (_gameCompleted) return;
    await GameProgressService.saveProgress(
      GameProgress(
        gameId: widget.game.id,
        gameType: widget.game.gameType,
        currentIndex: _completedPairs,
        score: _score,
        savedAt: DateTime.now(),
      ),
    );
  }

  @override
  void dispose() {
    _isLeaving = true;
    WidgetsBinding.instance.removeObserver(this);
    _mascotReactionTimer?.cancel();
    _feedbackTimer?.cancel();
    _roundTimer?.cancel();
    _cancelPendingLeftTermSpeak();
    unawaited(_persistProgress());
    unawaited(GameAudioLifecycle.stopAll(
      tts: _ttsService,
      sound: _soundService,
    ));
    for (final controller in _flipControllers.values) {
      controller.dispose();
    }
    _progressController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  Future<void> _stopVoiceAndMusic() => GameAudioLifecycle.stopAll(
        tts: _ttsService,
        sound: _soundService,
      );

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_soundService.resumeBgmIfNeeded());
    }
  }

  void _flipCard(int index) {
    if (_isProcessing ||
        _flippedCards.contains(index) ||
        _matchedPairs.containsKey(index))
      return;

    if (_firstFlipped == null) {
      // First card flipped
      safeSetState(() {
        _firstFlipped = index;
        _flippedCards.add(index);
        _moves++;
      });
      _flipControllers[index]?.forward();
      _soundService.playCardFlip();
      // Speak card text
      if (_isTTSEnabled) {
        _ttsService.speak(_cards[index].text);
      }
    } else if (_secondFlipped == null && _firstFlipped != index) {
      // Second card flipped
      safeSetState(() {
        _secondFlipped = index;
        _flippedCards.add(index);
        _isProcessing = true;
      });
      _flipControllers[index]?.forward();
      _soundService.playCardFlip();
      // Speak card text
      if (_isTTSEnabled) {
        _ttsService.speak(_cards[index].text);
      }

      // Check for match
      Future.delayed(const Duration(milliseconds: 500), () {
        _checkMatch();
      });
    }
  }

  void _checkMatch() {
    // Capture indices locally to avoid null issues inside delayed callbacks
    final firstIndex = _firstFlipped;
    final secondIndex = _secondFlipped;
    if (firstIndex == null || secondIndex == null) {
      safeSetState(() {
        _isProcessing = false;
      });
      return;
    }

    final card1 = _cards[firstIndex];
    final card2 = _cards[secondIndex];

    final isMatch =
        card1.pairId == card2.pairId && card1.isLeft != card2.isLeft;

    if (isMatch) {
      // Correct match!
      _soundService.playCorrect();
      _soundService.playMatch();
      if (_isTTSEnabled) {
        _ttsService.speak(_buildMatchSentence(card1, card2));
      }
      safeSetState(() {
        _matchedPairs[firstIndex] = card1.pairId;
        _matchedPairs[secondIndex] = card2.pairId;
        _score++;
        _currentStreak++;
        _xpEarned += 15; // 15 XP per match
        _flippedCards.remove(firstIndex);
        _flippedCards.remove(secondIndex);
      });

      _confettiController.play();

      // Update progress
      final newProgress = _matchedPairs.length / 2 / widget.game.items.length;
      _progressAnimation =
          Tween<double>(
            begin: _progressAnimation.value,
            end: newProgress,
          ).animate(
            CurvedAnimation(parent: _progressController, curve: Curves.easeOut),
          );
      _progressController.forward(from: 0);

      // Check if game complete
      if (_matchedPairs.length == _cards.length) {
        Future.delayed(const Duration(milliseconds: 500), () {
          _finishGame();
        });
      }
    } else {
      // Wrong match - flip back
      Future.delayed(const Duration(milliseconds: 1000), () {
        if (!mounted) return;
        _flipControllers[firstIndex]?.reverse();
        _flipControllers[secondIndex]?.reverse();
        safeSetState(() {
          _flippedCards.remove(firstIndex);
          _flippedCards.remove(secondIndex);
          _currentStreak = 0;
        });
      });
      _soundService.playIncorrect();
    }

    safeSetState(() {
      _firstFlipped = null;
      _secondFlipped = null;
      _isProcessing = false;
    });
  }

  void _useHint() {
    if (_hintsRemaining <= 0 || _isProcessing) return;
    _soundService.playClick();
    _showMascotReaction(
      'Hint used. Focus on this pair.',
      tone: CompanionTone.tip,
      duration: const Duration(seconds: 3),
    );
    // Find a random unmatched pair
    final unmatched = <int>[];
    for (int i = 0; i < _cards.length; i++) {
      if (!_matchedPairs.containsKey(i)) unmatched.add(i);
    }
    if (unmatched.length < 2) return;
    // Group by pairId to find two cards of same pair
    final byPair = <int, List<int>>{};
    for (final i in unmatched) {
      byPair.putIfAbsent(_cards[i].pairId, () => []).add(i);
    }
    final pairIndices = byPair.values.where((l) => l.length >= 2).toList();
    if (pairIndices.isEmpty) return;
    final pair = pairIndices[Random().nextInt(pairIndices.length)];
    final idx1 = pair[0], idx2 = pair[1];
    safeSetState(() {
      _hintsRemaining--;
      _flippedCards.add(idx1);
      _flippedCards.add(idx2);
    });
    _flipControllers[idx1]?.forward();
    _flipControllers[idx2]?.forward();
    _soundService.playCardFlip();
    if (_isTTSEnabled) {
      _ttsService.speak('Hint used. Try matching these two cards.');
    }
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (!mounted) return;
      _flipControllers[idx1]?.reverse();
      _flipControllers[idx2]?.reverse();
      safeSetState(() {
        _flippedCards.remove(idx1);
        _flippedCards.remove(idx2);
      });
    });
  }

  String _buildMatchSentence(CardData firstCard, CardData secondCard) {
    final leftCard = firstCard.isLeft ? firstCard : secondCard;
    final rightCard = firstCard.isLeft ? secondCard : firstCard;
    return 'Great match! "${leftCard.text}" goes with "${rightCard.text}".';
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

  Future<void> _showHowToPlayIfFirstTime() async {
    final hasSeen = await GameRulesService.hasSeenRules(GameType.matching);
    if (!mounted || hasSeen) return;
    await _showHowToPlay(autoRead: true);
    await GameRulesService.markRulesSeen(GameType.matching);
  }

  Future<void> _showHowToPlay({bool autoRead = false}) async {
    if (!mounted) return;
    final instructionText =
        'Match one pair at a time. Tap a term on the left, then tap its definition on the right. '
        'You get instant feedback on every try. Clear each section to move on.';
    var muted = !_isTTSEnabled;
    final sheetFuture = showModalBottomSheet(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                StatefulBuilder(
                  builder: (context, setSheetState) => Row(
                    children: [
                      Expanded(
                        child: Text(
                          'How to play',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textDark,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: muted
                            ? 'Unmute explanation'
                            : 'Mute explanation',
                        onPressed: () {
                          setSheetState(() => muted = !muted);
                          if (muted) {
                            _ttsService.stop();
                          } else if (_isTTSEnabled) {
                            _ttsService.speak(instructionText);
                          }
                        },
                        icon: Icon(
                          muted
                              ? Icons.volume_off_rounded
                              : Icons.volume_up_rounded,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Match each left term to its right definition, one pair at a time.',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: AppTheme.textMedium,
                  ),
                ),
                const SizedBox(height: 12),
                _buildHowToBullet(
                  'Tap a left item (term) first.',
                ),
                _buildHowToBullet(
                  'Then tap the matching right item. You hear right or wrong instantly.',
                ),
                _buildHowToBullet(
                  'Correct pairs lock green and you earn XP.',
                ),
                _buildHowToBullet(
                  'Wrong picks bounce back. Try again until the section is clear.',
                ),
                _buildHowToBullet(
                  'Up to 5 pairs per section. Sections unlock as you go.',
                ),
                const SizedBox(height: 16),
                Text(
                  'Tip: Matching helps your brain connect concepts so you remember them longer.',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                    color: AppTheme.textMedium,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (autoRead && _isTTSEnabled && !muted) {
      await _soundService.duckBgmForSpeech();
      await _ttsService.speakAndWait(instructionText);
    }
    await sheetFuture;
    await _ttsService.stop();
  }

  void _openGameSettings() {
    GameSettingsSheet.show(
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

  Widget _buildHowToBullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(fontSize: 14)),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: AppTheme.textMedium,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _finishGame() async {
    _gameCompleted = true;
    await GameProgressService.clearProgress(widget.game.id);
    final endTime = DateTime.now();
    final timeTaken = _startTime != null
        ? endTime.difference(_startTime!).inSeconds
        : null;

    final isPerfectScore = _score == _allPairs.length;

    // Calculate bonus XP based on moves (fewer moves = more bonus)
    int bonusXP = 0;
    if (isPerfectScore) bonusXP += 50;
    if (timeTaken != null && timeTaken < 120) bonusXP += 25;
    final optimalMoves = _allPairs.length * 2; // Minimum moves needed
    if (_moves <= optimalMoves * 1.5) bonusXP += 20; // Efficiency bonus
    final totalXP = _xpEarned + bonusXP;

    unawaited(() async {
      try {
        await GameStatsService.addGameResult(
          correctAnswers: _score,
          totalQuestions: _allPairs.length,
          timeTakenSeconds: timeTaken ?? 0,
          isPerfectScore: isPerfectScore,
        );
      } catch (e) {
        LogService.error('🎮 [Matching] Error updating game stats: $e');
      }
    }());

    unawaited(() async {
      try {
        await SkulMateService.saveGameSession(
          gameId: widget.game.id,
          score: _score,
          totalQuestions: _allPairs.length,
          correctAnswers: _score,
          timeTakenSeconds: timeTaken,
          answers: {'moves': _moves, 'pairs': _score},
        );
      } catch (e) {
        LogService.error('🎮 [Matching] Error saving game session: $e');
      }
    }());

    // Play completion sound without blocking navigation.
    unawaited(_soundService.playComplete());

    await _stopVoiceAndMusic();

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => GameResultsScreen(
            game: widget.game,
            score: _score,
            totalQuestions: _allPairs.length,
            timeTakenSeconds: timeTaken,
            xpEarned: totalXP,
            isPerfectScore: isPerfectScore,
          ),
        ),
      );
    }
  }

  Future<void> _handleBack() async {
    if (_isLeaving) return;

    final quit = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Quit game?',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Your progress is saved. You can continue this game later from the Game Dashboard.',
          style: GoogleFonts.poppins(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Keep playing',
              style: GoogleFonts.poppins(color: AppTheme.primaryColor),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Quit to Dashboard',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
    if (quit == true && mounted) {
      _isLeaving = true;
      _roundTimer?.cancel();
      _cancelPendingLeftTermSpeak();
      await _stopVoiceAndMusic();
      await _persistProgress();
      if (!mounted) return;
      await SkulMateNavigation.popGame(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_allPairs.isEmpty) {
      return Scaffold(
        backgroundColor: AppTheme.softBackground,
        appBar: SkulMateGameAppBar(
          title: widget.game.title,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: _handleBack,
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
                  children: [
                const Icon(
                  Icons.info_outline_rounded,
                  size: 40,
                  color: AppTheme.primaryColor,
                ),
                const SizedBox(height: 10),
                Text(
                  'No matching pairs available for this game yet.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textDark,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Try regenerating with another game type.',
                  textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: AppTheme.textMedium,
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: _handleBack,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primaryColor,
                    side: const BorderSide(color: AppTheme.primaryColor),
                  ),
                  child: const Text('Back to dashboard'),
                    ),
                  ],
                ),
          ),
        ),
      );
    }

    final totalPairs = _allPairs.length.clamp(1, 9999);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) unawaited(_handleBack());
      },
      child: Scaffold(
        backgroundColor: AppTheme.softBackground,
        appBar: SkulMateGameAppBar(
          light: true,
          title: widget.game.title,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: _handleBack,
          ),
          actions: [
            IconButton(
              tooltip: 'How to play',
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
              padding: const EdgeInsets.all(6),
              icon: const Icon(Icons.help_outline_rounded),
              onPressed: _showHowToPlay,
            ),
            Padding(
              padding: const EdgeInsets.only(right: 2, left: 0),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: _openGameSettings,
                child: CircleAvatar(
                  radius: 16,
                  backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.08),
                  child: const SkulMateProfileAvatar(
                    size: 28,
                    forGameAppBar: true,
                  ),
                ),
              ),
            ),
          ],
        ),
        body: Stack(
          children: [
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: GameStandardsHud(
                    progressText:
                        'Section ${_roundNumber()} · $_completedPairs/$totalPairs matched',
                    progressValue: _progressValue(),
                    xpEarned: _xpEarned,
                    gameType: GameType.matching,
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                          child: Column(
                            children: [
                        if (_feedbackMessage.isNotEmpty) ...[
                          GameFeedbackBanner(
                            tone: _feedbackTone,
                            message: _feedbackMessage,
                          ),
                          const SizedBox(height: 10),
                        ],
                        GameFlatPanel(
                    child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                              Row(
                                children: [
                                  Text(
                                    'Match It',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: AppTheme.textDark,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    '${_matchedInRound.length}/${_currentRoundPairs.length}',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.textMedium,
                              ),
                            ),
                                  const SizedBox(width: 8),
                                  Container(
                          padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _roundRemainingSeconds <= 10
                                          ? AppTheme.gameNudgeBg
                                          : AppTheme.neutral100,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '${_roundRemainingSeconds}s',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: AppTheme.textDark,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              _buildMatchingBoard(),
                            ],
                          ),
                        ),
                        if (_mascotReaction != null) ...[
                          const SizedBox(height: 10),
                          SkulMateCompanionBanner(
                            tone: _mascotReactionTone,
                            message: _mascotReaction!,
                            celebrate: _mascotCelebrate,
                          ),
                        ],
                        const SizedBox(height: 10),
                        _buildSectionActionArea(),
                            ],
                    ),
                  ),
                ),
              ],
            ),
            GameEdgeFlash(
              trigger: _edgeFlashTrigger,
              success: _edgeFlashSuccess,
            ),
            GameMatchPulse(trigger: _matchPulseTrigger),
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
                  AppTheme.accentGreen,
                  AppTheme.primaryColor,
                  AppTheme.primaryDark,
                  AppTheme.softYellow,
                  AppTheme.accentPurple,
                  Colors.white,
                ],
              ),
            ),
            GameXpPopup(amount: _lastXpBurst, visible: _xpPopupVisible),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon) {
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.14)),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppTheme.primaryColor, size: 18),
          const SizedBox(height: 3),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: AppTheme.textDark,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 9.5,
              color: AppTheme.textMedium,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactTopPill({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        decoration: BoxDecoration(
          color: AppTheme.neutral100,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppTheme.primaryColor.withOpacity(0.22)),
          boxShadow: [
            BoxShadow(
              color: Colors.white.withOpacity(0.9),
              blurRadius: 1,
              offset: const Offset(-1, -1),
            ),
            BoxShadow(
              color: AppTheme.primaryColor.withOpacity(0.08),
              blurRadius: 7,
              offset: const Offset(1, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                '$value $label',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textDark,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMemoryCard({
    required CardData card,
    required int index,
    required bool isFlipped,
    required bool isMatched,
    required bool isSelected,
  }) {
    final flipAnimation =
        _flipAnimations[index] ??
        _flipControllers[index]!.drive(
          Tween<double>(
            begin: 0,
            end: 1,
          ).chain(CurveTween(curve: Curves.easeInOut)),
        );

    return GestureDetector(
      onTap: () => _flipCard(index),
      child: AnimatedBuilder(
        animation: flipAnimation,
        builder: (context, child) {
          final angle = flipAnimation.value * 3.14159;
          final isFront = flipAnimation.value < 0.5;

          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateY(angle),
            child: isFront || (!isFlipped && !isMatched)
                ? _buildCardBack(isMatched, isSelected)
                : _buildCardFront(card, isMatched, angle),
          );
        },
      ),
    );
  }

  Widget _buildCardBack(bool isMatched, bool isSelected) {
    return Container(
      decoration: BoxDecoration(
        color: isMatched
            ? AppTheme.primaryColor.withOpacity(0.14)
            : const Color(0xFFEFF2F7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isMatched
              ? AppTheme.primaryColor
              : (isSelected
                    ? AppTheme.primaryColor.withOpacity(0.8)
                    : AppTheme.softBorder),
          width: isMatched ? 1.6 : 1.0,
        ),
      ),
      child: Center(
        child: isMatched
            ? const Icon(Icons.check_circle, color: AppTheme.primaryColor, size: 22)
            : Icon(
                isSelected ? Icons.radio_button_checked : Icons.help_outline,
                color: isSelected ? AppTheme.primaryColor : AppTheme.textMedium,
                size: 18,
              ),
      ),
    );
  }

  Widget _buildCardFront(CardData card, bool isMatched, double rotationAngle) {
    // Front of the card should stay clean white whether the pair is correct
    // or not. We only vary the border subtlely for matched cards.
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isMatched ? AppTheme.primaryColor.withOpacity(0.10) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isMatched ? AppTheme.primaryColor : AppTheme.softBorder,
          width: isMatched ? 1.7 : 1.0,
        ),
      ),
      child: Center(
        child: Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001)
            ..rotateY(-rotationAngle), // Counter-rotate text to keep it upright
          child: Text(
            card.text,
            style: GoogleFonts.poppins(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: AppTheme.textDark,
            ),
            textAlign: card.isLeft ? TextAlign.left : TextAlign.right,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}
