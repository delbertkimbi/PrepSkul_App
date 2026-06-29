import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:confetti/confetti.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/core/utils/safe_set_state.dart';
import 'package:prepskul/core/services/log_service.dart';
import 'package:prepskul/core/localization/language_service.dart';
import 'dart:math';
import '../models/game_model.dart';
import '../models/game_stats_model.dart';
import '../models/revision_deck_model.dart';
import '../services/revision_deck_service.dart';
import '../services/scroll_play_mode_prefs.dart';
import '../services/skulmate_service.dart';
import '../services/game_sound_service.dart';
import '../services/game_audio_lifecycle.dart';
import '../services/tts_service.dart';
import '../services/game_stats_service.dart';
import '../services/game_progress_service.dart';
import '../widgets/skulmate_game_app_bar.dart';
import '../widgets/skulmate_profile_avatar.dart';
import '../widgets/flashcard_help_sheet.dart';
import '../widgets/adaptive_study_card_play.dart';
import '../widgets/deck_card_shared.dart';
import '../widgets/game_standard_widgets.dart';
import '../widgets/game_settings_sheet.dart';
import '../widgets/skulmate_surface_styles.dart';
import '../utils/skulmate_navigation.dart';
import 'game_results_screen.dart';

/// Flashcard game screen with flip animation
class FlashcardGameScreen extends StatefulWidget {
  final GameModel game;
  final GameProgress? resumeFrom;

  const FlashcardGameScreen({
    Key? key,
    required this.game,
    this.resumeFrom,
  }) : super(key: key);

  @override
  State<FlashcardGameScreen> createState() => _FlashcardGameScreenState();
}

class _FlashcardGameScreenState extends State<FlashcardGameScreen>
    with TickerProviderStateMixin {
  int _currentCardIndex = 0;
  bool _isFlipped = false;
  final Map<int, bool> _knownCards = {}; // cardIndex -> isKnown
  int _score = 0;
  int _currentStreak = 0;
  int _xpEarned = 0;
  DateTime? _startTime;
  late AnimationController _flipController;
  late Animation<double> _flipAnimation;
  late AnimationController _progressController;
  late Animation<double> _progressAnimation;
  late AnimationController _swipeController;
  late Animation<Offset> _swipeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;
  final GameSoundService _soundService = GameSoundService();
  final TTSService _ttsService = TTSService();
  late ConfettiController _confettiController;
  GameStats? _currentStats;
  bool _isTTSEnabled = true;
  bool _gameCompleted = false;
  List<RevisionDeckCard> _deckCards = const [];
  bool _cardRevealed = false;
  String? _mcqSelection;
  bool _mcqShowResult = false;
  bool _isLeaving = false;

  // Swipe mechanics
  double _dragPosition = 0;
  bool _isDragging = false;
  Offset _dragOffset = Offset.zero;

  // Card stack - show next 2 cards
  static const int _stackSize = 3;
  bool get _isFrench => LanguageService.languageCode == 'fr';

  @override
  void initState() {
    super.initState();
    if (widget.resumeFrom != null) {
      final max = widget.game.items.length > 0 ? widget.game.items.length - 1 : 0;
      _currentCardIndex =
          widget.resumeFrom!.currentIndex.clamp(0, max);
      _score = widget.resumeFrom!.score;
    }
    _startTime = DateTime.now();
    _soundService.initialize();
    unawaited(_soundService.playMusicForGame(widget.game.gameType));
    _ttsService.initialize();
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 2),
    );
    // Speak first card term
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted && !_isLeaving && _isTTSEnabled) {
        _speakCurrentCard();
      }
    });
    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _flipAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOut),
    );
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _progressAnimation = Tween<double>(begin: 0, end: 0).animate(
      CurvedAnimation(parent: _progressController, curve: Curves.easeOut),
    );
    _swipeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _swipeAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(2, 0), // Default right swipe
    ).animate(CurvedAnimation(parent: _swipeController, curve: Curves.easeOut));
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.8,
    ).animate(CurvedAnimation(parent: _swipeController, curve: Curves.easeOut));
    _rotationAnimation = Tween<double>(
      begin: 0,
      end: 0.2,
    ).animate(CurvedAnimation(parent: _swipeController, curve: Curves.easeOut));
    _loadStats();
    unawaited(_loadDeck());
    unawaited(ScrollPlayModePrefs.markFlashcards(widget.game.id));
  }

  Future<void> _loadDeck() async {
    try {
      final deck = await RevisionDeckService.resolveForGame(widget.game);
      if (!mounted) return;
      safeSetState(() => _deckCards = deck.cards);
    } catch (_) {}
  }

  RevisionDeckCard? _deckCardForIndex(int index) {
    if (_deckCards.isEmpty) return null;
    for (final card in _deckCards) {
      if (card.gameItemIndex == index) return card;
    }
    if (index < _deckCards.length) return _deckCards[index];
    return null;
  }

  MemoriseInteraction get _currentInteraction =>
      interactionFor(_deckCardForIndex(_currentCardIndex));

  bool get _canSwipeNow {
    switch (_currentInteraction) {
      case MemoriseInteraction.trueFalseSwipe:
        return true;
      case MemoriseInteraction.revealSwipe:
        return _cardRevealed;
      case MemoriseInteraction.mcq:
        return _mcqShowResult;
      case MemoriseInteraction.legacyFlip:
        return _isFlipped;
    }
  }

  Future<void> _persistProgress() async {
    if (_gameCompleted) return;
    await GameProgressService.saveProgress(
      GameProgress(
        gameId: widget.game.id,
        gameType: widget.game.gameType,
        currentIndex: _currentCardIndex,
        score: _score,
        savedAt: DateTime.now(),
      ),
    );
  }

  Future<void> _stopVoiceAndMusic() => GameAudioLifecycle.stopAll(
        tts: _ttsService,
        sound: _soundService,
      );

  Future<void> _handleBack() async {
    if (_isLeaving) return;
    if (_gameCompleted) {
      await SkulMateNavigation.popGame(context);
      return;
    }

    final quit = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          _isFrench ? 'Quitter le jeu ?' : 'Quit game?',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: Text(
          _isFrench
              ? 'Votre progression est enregistrée. Vous pourrez reprendre plus tard.'
              : 'Your progress is saved. You can continue this game later from the Game Dashboard.',
          style: GoogleFonts.poppins(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              _isFrench ? 'Continuer' : 'Keep playing',
              style: GoogleFonts.poppins(color: AppTheme.primaryColor),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              _isFrench ? 'Quitter' : 'Quit to Dashboard',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    if (quit == true && mounted) {
      _isLeaving = true;
      await _stopVoiceAndMusic();
      await _persistProgress();
      if (!mounted) return;
      await SkulMateNavigation.popGame(context);
    }
  }

  @override
  void dispose() {
    _isLeaving = true;
    _flipController.dispose();
    unawaited(_persistProgress());
    unawaited(_soundService.stopMusic(force: true));
    unawaited(_ttsService.stop());
    _progressController.dispose();
    _swipeController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  void _handleSwipe(bool isKnown) {
    if (_isLeaving || _swipeController.isAnimating) return;

    // Set swipe direction
    _swipeAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: Offset(isKnown ? 2 : -2, 0), // Right for known, left for unknown
    ).animate(CurvedAnimation(parent: _swipeController, curve: Curves.easeOut));

    _soundService.playFlip();
    _swipeController.forward().then((_) {
      if (!mounted || _isLeaving) return;
      _markAsKnown(isKnown);
      if (!_isLeaving) _swipeController.reset();
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_isLeaving || !_canSwipeNow) return;

    safeSetState(() {
      _isDragging = true;
      _dragOffset += details.delta;
      _dragPosition = _dragOffset.dx;
    });
  }

  void _onPanEnd(DragEndDetails details) {
    if (_isLeaving || !_isDragging) return;

    final swipeThreshold = 100.0;
    final velocity = details.velocity.pixelsPerSecond.dx;

    if (_dragPosition.abs() > swipeThreshold || velocity.abs() > 500) {
      final swipedRight = _dragPosition > 0 || velocity > 500;
      if (_currentInteraction == MemoriseInteraction.trueFalseSwipe) {
        _handleTrueFalseSwipe(swipedRight);
      } else {
        _handleSwipe(swipedRight);
      }
    } else {
      // Snap back
      safeSetState(() {
        _dragPosition = 0;
        _dragOffset = Offset.zero;
        _isDragging = false;
      });
    }
  }

  Future<void> _loadStats() async {
    final stats = await GameStatsService.getStats();
    safeSetState(() {
      _currentStats = stats;
      _currentStreak = stats.currentStreak;
    });
  }

  void _handleTrueFalseSwipe(bool swipedRight) {
    final deckCard = _deckCardForIndex(_currentCardIndex);
    if (deckCard == null) return;
    final answerTrue = deckCard.answer.toLowerCase() == 'true';
    _handleSwipe(swipedRight == answerTrue);
  }

  void _onCardTap() {
    switch (_currentInteraction) {
      case MemoriseInteraction.legacyFlip:
        _flipCard();
      case MemoriseInteraction.revealSwipe:
        if (_flipController.isAnimating) return;
        _soundService.playCardFlip();
        safeSetState(() => _cardRevealed = !_cardRevealed);
        if (_isTTSEnabled) {
          final deckCard = _deckCardForIndex(_currentCardIndex);
          if (deckCard != null) {
            final text = _cardRevealed ? deckCard.answer : deckCard.prompt;
            if (text.isNotEmpty) _ttsService.speak(text);
          }
        }
      case MemoriseInteraction.mcq:
      case MemoriseInteraction.trueFalseSwipe:
        break;
    }
  }

  void _onMcqOptionSelected(String option) {
    final deckCard = _deckCardForIndex(_currentCardIndex);
    if (deckCard == null || _mcqShowResult) return;
    final isCorrect =
        option.toLowerCase() == deckCard.answer.toLowerCase();
    safeSetState(() {
      _mcqSelection = option;
      _mcqShowResult = true;
    });
    Future.delayed(const Duration(milliseconds: 700), () {
      if (mounted && !_isLeaving) _handleSwipe(isCorrect);
    });
  }

  void _flipCard() {
    if (_flipController.isAnimating) return;

    if (_isFlipped) {
      _flipController.reverse();
      _soundService.playCardFlip();
      // Speak term when flipping back
      if (_isTTSEnabled) {
        _speakCurrentCard();
      }
    } else {
      _flipController.forward();
      _soundService.playCardFlip();
      // Speak definition when flipped
      if (_isTTSEnabled) {
        final card = widget.game.items[_currentCardIndex];
        final resolved = _resolveTermDefinition(card);
        if (resolved.definition.isNotEmpty) {
          _ttsService.speak(resolved.definition);
        }
      }
    }
    safeSetState(() {
      _isFlipped = !_isFlipped;
    });
  }

  void _speakCurrentCard() {
    if (!_isTTSEnabled) return;
    final deckCard = _deckCardForIndex(_currentCardIndex);
    if (deckCard != null) {
      if (deckCard.prompt.isNotEmpty) {
        _ttsService.speak(deckCard.prompt);
      }
      return;
    }
    final card = widget.game.items[_currentCardIndex];
    final resolved = _resolveTermDefinition(card);
    if (resolved.term.isNotEmpty) {
      _ttsService.speak(resolved.term);
    }
  }

  void _openLearnMoreSheet() {
    _soundService.playClick();
    final deckCard = _deckCardForIndex(_currentCardIndex);
    final card = widget.game.items[_currentCardIndex];
    final resolved = _resolveTermDefinition(card);
    FlashcardHelpSheet.show(
      context,
      term: deckCard?.prompt ?? resolved.term,
      definition: deckCard?.answer ?? resolved.definition,
      gameId: widget.game.id,
    );
  }

  void _openGameSettings() {
    GameSettingsSheet.show(
      context: context,
      title: _isFrench ? 'Parametres du jeu' : 'Game settings',
      soundService: _soundService,
      gameType: widget.game.gameType,
      ttsService: _ttsService,
      isTTSEnabled: _isTTSEnabled,
      onTTSToggled: (v) {
        safeSetState(() => _isTTSEnabled = v);
      },
    );
  }

  void _markAsKnown(bool isKnown) {
    // Calculate XP with streak multiplier
    int baseXP = 10;
    int streakMultiplier = _currentStreak > 0 ? (1 + (_currentStreak ~/ 3)) : 1;
    int xpForThisCard = baseXP * streakMultiplier;

    safeSetState(() {
      _knownCards[_currentCardIndex] = isKnown;
      if (isKnown) {
        _score++;
        _currentStreak++;
        _xpEarned += xpForThisCard;
        _soundService.playCorrect();
        // Trigger confetti
        _confettiController.play();
      } else {
        _currentStreak = 0; // Reset streak on wrong answer
        _soundService.playIncorrect();
      }
      _dragPosition = 0;
      _dragOffset = Offset.zero;
      _isDragging = false;
    });

    // If learner doesn't know this card, immediately open explanation sheet.
    if (!isKnown) {
      Future.delayed(const Duration(milliseconds: 120), () {
        if (mounted) _openLearnMoreSheet();
      });
    }

    // Update progress bar animation
    final newProgress = (_currentCardIndex + 1) / widget.game.items.length;
    _progressAnimation =
        Tween<double>(
          begin: _progressAnimation.value,
          end: newProgress,
        ).animate(
          CurvedAnimation(parent: _progressController, curve: Curves.easeOut),
        );
    _progressController.forward(from: 0);

    // Show feedback with XP
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Text(
              isKnown
                  ? (_isFrench ? 'Super! 🎉' : 'Great! 🎉')
                  : (_isFrench ? 'Continue à pratiquer !' : 'Keep practicing!'),
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
            if (isKnown) ...[
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
        backgroundColor: isKnown ? AppTheme.accentGreen : Colors.orange,
        duration: const Duration(seconds: 2),
      ),
    );

    // Move to next card
    Future.delayed(const Duration(milliseconds: 2000), () {
      if (mounted && !_isLeaving) {
        _nextCard();
      }
    });
  }

  void _nextCard() {
    if (_currentCardIndex < widget.game.items.length - 1) {
      safeSetState(() {
        _currentCardIndex++;
        _isFlipped = false;
        _cardRevealed = false;
        _mcqSelection = null;
        _mcqShowResult = false;
        _flipController.reset();
        _dragPosition = 0;
        _dragOffset = Offset.zero;
        _isDragging = false;
      });
      // Speak next card
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted && _isTTSEnabled) {
          _speakCurrentCard();
        }
      });
      // Animate progress bar
      final newProgress = (_currentCardIndex + 1) / widget.game.items.length;
      _progressAnimation =
          Tween<double>(
            begin: _progressAnimation.value,
            end: newProgress,
          ).animate(
            CurvedAnimation(parent: _progressController, curve: Curves.easeOut),
          );
      _progressController.forward(from: 0);
    } else {
      _finishGame();
    }
  }

  void _previousCard() {
    if (_currentCardIndex > 0) {
      safeSetState(() {
        _currentCardIndex--;
        _isFlipped = false;
        _cardRevealed = false;
        _mcqSelection = null;
        _mcqShowResult = false;
        _flipController.reset();
      });
    }
  }

  Future<void> _finishGame() async {
    _gameCompleted = true;
    await GameProgressService.clearProgress(widget.game.id);
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

    unawaited(
      GameStatsService.addGameResult(
        correctAnswers: _score,
        totalQuestions: widget.game.items.length,
        timeTakenSeconds: timeTaken ?? 0,
        isPerfectScore: isPerfectScore,
      ).catchError((e) {
        LogService.error('🎮 [Flashcard] Error updating game stats: $e');
      }),
    );

    unawaited(
      SkulMateService.saveGameSession(
        gameId: widget.game.id,
        score: _score,
        totalQuestions: widget.game.items.length,
        correctAnswers: _score,
        timeTakenSeconds: timeTaken,
        answers: _knownCards.map(
          (key, value) => MapEntry(key.toString(), value),
        ),
      ).catchError((e) {
        LogService.error('🎮 [Flashcard] Error saving game session: $e');
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

  @override
  Widget build(BuildContext context) {
    final card = widget.game.items[_currentCardIndex];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) unawaited(_handleBack());
      },
      child: Scaffold(
      backgroundColor: AppTheme.softBackground,
      appBar: SkulMateGameAppBar(
        title: widget.game.title,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => unawaited(_handleBack()),
        ),
        actions: [
          IconButton(
            tooltip: _isFrench ? 'Suggestion' : 'Suggestion',
            icon: const Icon(Icons.lightbulb_outline, color: Colors.white),
            onPressed: _openLearnMoreSheet,
          ),
          Padding(
            padding: const EdgeInsets.only(right: 4, left: 0),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: _openGameSettings,
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
      body: Stack(
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
                          'Card ${_currentCardIndex + 1} of ${widget.game.items.length}',
                      progressValue: _progressAnimation.value,
                      xpEarned: _xpEarned,
                      gameType: widget.game.gameType,
                    ),
                  );
                },
              ),
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 12),
                        // Card stack with swipe (flat refined surface)
                        Expanded(
                          child: FlatStageCard(
                            padding: const EdgeInsets.all(10),
                            radius: 18,
                            backgroundColor: Colors.white,
                            borderColor: AppTheme.primaryColor.withOpacity(0.18),
                            child: SizedBox(
                              width: double.infinity,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                // Stack of next cards (background)
                                ...List.generate(_stackSize - 1, (index) {
                                  final cardIndex =
                                      _currentCardIndex + index + 1;
                                  if (cardIndex >= widget.game.items.length) {
                                    return const SizedBox.shrink();
                                  }
                                  final stackCard =
                                      widget.game.items[cardIndex];
                                  return Positioned(
                                    left: 0,
                                    right: 0,
                                    top: (index + 1) * 8.0,
                                    child: Transform.scale(
                                      scale: 1.0 - (index + 1) * 0.05,
                                      child: Opacity(
                                        opacity: 1.0 - (index + 1) * 0.3,
                                        child: _buildCardStackItem(
                                          stackCard,
                                          index + 1,
                                        ),
                                      ),
                                    ),
                                  );
                                }),
                                // Current card (swipeable)
                                AnimatedBuilder(
                                  animation: _swipeController,
                                  builder: (context, child) {
                                    final dragOffset = _isDragging
                                        ? _dragOffset
                                        : Offset(
                                            _swipeAnimation.value.dx *
                                                MediaQuery.of(
                                                  context,
                                                ).size.width,
                                            _swipeAnimation.value.dy,
                                          );

                                    final rotation = _isDragging
                                        ? _dragPosition / 1000
                                        : _rotationAnimation.value;

                                    final scale = _isDragging
                                        ? 1.0 - (_dragPosition.abs() / 2000)
                                        : _scaleAnimation.value;

                                    final opacityValue = _isDragging
                                        ? (1.0 - (_dragPosition.abs() / 500))
                                        : (1.0 -
                                              (_swipeAnimation.value.dx.abs() /
                                                  2.0));
                                    final opacity =
                                        opacityValue.clamp(0.0, 1.0) as double;

                                    // Swipe direction indicators
                                    Color? swipeColor;
                                    IconData? swipeIcon;
                                    if (_isDragging) {
                                      if (_dragPosition > 50) {
                                        swipeColor = AppTheme.accentGreen;
                                        swipeIcon = Icons.check_circle;
                                      } else if (_dragPosition < -50) {
                                        swipeColor = Colors.red;
                                        swipeIcon = Icons.close;
                                      }
                                    }

                                    return Transform.translate(
                                      offset: dragOffset,
                                      child: Transform.rotate(
                                        angle: rotation,
                                        child: Transform.scale(
                                          scale:
                                              scale.clamp(0.8, 1.0) as double,
                                          child: Opacity(
                                            opacity: opacity,
                                            child: GestureDetector(
                                              onTap: _onCardTap,
                                              onPanUpdate: _onPanUpdate,
                                              onPanEnd: _onPanEnd,
                                              child: _buildCurrentCardWidget(
                                                                  card,
                                                swipeColor: swipeColor,
                                                swipeIcon: swipeIcon,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                        const SizedBox(height: 24),
                        // Action buttons and instructions
                        if (_currentInteraction == MemoriseInteraction.mcq) ...[
                          Text(
                            _isFrench
                                ? 'Choisis la bonne réponse'
                                : 'Tap the correct answer',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              color: AppTheme.textMedium,
                            ),
                          ),
                        ] else if (_canSwipeNow) ...[
                          Text(
                            _currentInteraction ==
                                    MemoriseInteraction.trueFalseSwipe
                                ? (_isFrench
                                    ? 'Glisse à droite = Vrai, à gauche = Faux'
                                    : 'Swipe right = True, left = False')
                                : (_isFrench
                                    ? 'Glisse à droite si tu sais, à gauche sinon'
                                    : 'Swipe right if you know it, left if not'),
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              color: AppTheme.textMedium,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () {
                                    if (_currentInteraction ==
                                        MemoriseInteraction.trueFalseSwipe) {
                                      _handleTrueFalseSwipe(false);
                                    } else {
                                      _handleSwipe(false);
                                    }
                                  },
                                  icon: Icon(
                                    _currentInteraction ==
                                            MemoriseInteraction.trueFalseSwipe
                                        ? Icons.close_rounded
                                        : Icons.close,
                                    color: Colors.red,
                                  ),
                                  label: Text(
                                    _currentInteraction ==
                                            MemoriseInteraction.trueFalseSwipe
                                        ? (_isFrench ? 'Faux' : 'False')
                                        : (_isFrench
                                        ? 'Je ne sais pas'
                                            : 'I Don\'t Know'),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.red,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 15,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    side: const BorderSide(color: Colors.red),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed: () {
                                    if (_currentInteraction ==
                                        MemoriseInteraction.trueFalseSwipe) {
                                      _handleTrueFalseSwipe(true);
                                    } else {
                                      _handleSwipe(true);
                                    }
                                  },
                                  icon: const Icon(
                                    Icons.check,
                                    color: Colors.white,
                                  ),
                                  label: Text(
                                    _currentInteraction ==
                                            MemoriseInteraction.trueFalseSwipe
                                        ? (_isFrench ? 'Vrai' : 'True')
                                        : (_isFrench ? 'Je connais' : 'I Know'),
                                  ),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: AppTheme.primaryDark,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 15,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ] else ...[
                          Text(
                            _currentInteraction ==
                                    MemoriseInteraction.revealSwipe
                                ? (_isFrench
                                    ? 'Touchez la carte pour révéler'
                                    : 'Tap card to reveal')
                                : (_isFrench
                                ? 'Touchez la carte pour la retourner'
                                    : 'Tap card to flip'),
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              color: AppTheme.textMedium,
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                        // Navigation
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (_currentCardIndex > 0)
                              IconButton(
                                onPressed: _previousCard,
                                icon: const Icon(Icons.arrow_back),
                                tooltip: _isFrench ? 'Précédent' : 'Previous',
                              ),
                            const SizedBox(width: 16),
                            if (_currentCardIndex <
                                widget.game.items.length - 1)
                              IconButton(
                                onPressed: _nextCard,
                                icon: const Icon(Icons.arrow_forward),
                                tooltip: _isFrench ? 'Suivant' : 'Next',
                              ),
                          ],
                        ),
                      ],
                    ),
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
                AppTheme.primaryColor,
                AppTheme.skyBlue,
                AppTheme.softYellow,
                AppTheme.accentGreen,
                AppTheme.accentOrange,
                AppTheme.primaryLight,
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildCurrentCardWidget(
    GameItem item, {
    Color? swipeColor,
    IconData? swipeIcon,
  }) {
    final deckCard = _deckCardForIndex(_currentCardIndex);

    Widget core;
    if (deckCard != null &&
        _currentInteraction != MemoriseInteraction.legacyFlip) {
      core = AdaptiveStudyCardPlay(
        card: deckCard,
        revealed: _cardRevealed,
        selectedOption: _mcqSelection,
        showMcqResult: _mcqShowResult,
        onOptionSelected: _onMcqOptionSelected,
      );
    } else {
      core = AnimatedBuilder(
        animation: _flipAnimation,
        builder: (context, child) {
          final angle = _flipAnimation.value * pi;
          final isFront = _flipAnimation.value < 0.5;
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateY(angle),
            child: isFront
                ? _buildCardFront(item)
                : Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()..scale(-1.0, 1.0, 1.0),
                    child: _buildCardBack(item),
                  ),
          );
        },
      );
    }

    return Stack(
      children: [
        Positioned.fill(child: core),
        if (swipeColor != null && swipeIcon != null)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: swipeColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Center(
                child: Icon(swipeIcon, size: 80, color: swipeColor),
              ),
            ),
          ),
      ],
    );
  }

  /// Resolves term/definition - some APIs return them swapped (definition in term, term in definition).
  /// Heuristic: if "term" is longer than "definition", they're likely swapped (terms are usually shorter).
  ({String term, String definition}) _resolveTermDefinition(GameItem card) {
    final t = card.term ?? '';
    final d = card.definition ?? '';
    if (t.isEmpty && d.isEmpty) return (term: '', definition: '');
    if (t.isEmpty) return (term: d, definition: ''); // Only definition present
    if (d.isEmpty) return (term: t, definition: ''); // Only term present
    if (d.length < t.length) return (term: d, definition: t); // Likely swapped
    return (term: t, definition: d);
  }

  Widget _buildCardFront(GameItem card) {
    final resolved = _resolveTermDefinition(card);
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxHeight: 400),
      padding: const EdgeInsets.all(24),
      decoration: SkulMateSurfaceStyles.homeCard(radius: 18),
      child: Center(
        child: Text(
          resolved.term,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: AppTheme.textDark,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildCardBack(GameItem card) {
    final resolved = _resolveTermDefinition(card);
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxHeight: 400),
      padding: const EdgeInsets.all(24),
      decoration: SkulMateSurfaceStyles.homeCard(radius: 18),
      child: Stack(
        children: [
          Center(
            child: SingleChildScrollView(
                child: Text(
                  resolved.definition,
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 17,
                    color: AppTheme.textDark,
                    height: 1.5,
                  fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
              ),
            ),
          ),
          Positioned(
            top: 2,
            right: 2,
            child: IconButton(
              tooltip: _isFrench ? 'En savoir plus' : 'Read more',
              onPressed: _openLearnMoreSheet,
              icon: const Icon(
                Icons.menu_book_rounded,
                size: 22,
                color: AppTheme.primaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardStackItem(GameItem card, int index) {
    final deckCard = _deckCardForIndex(_currentCardIndex + index);
    if (deckCard != null) {
      return AdaptiveStudyCardPlay(
        card: deckCard,
        compact: true,
      );
    }
    final resolved = _resolveTermDefinition(card);
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxHeight: 400),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primaryColor.withOpacity(0.10),
            AppTheme.primaryLight.withOpacity(0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.2), width: 1),
      ),
      child: Center(
        child: Text(
          resolved.term,
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: AppTheme.primaryDark,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
