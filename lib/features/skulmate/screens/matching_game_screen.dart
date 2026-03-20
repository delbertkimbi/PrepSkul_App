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
import '../services/tts_service.dart';
import '../services/game_stats_service.dart';
import '../services/game_rules_service.dart';
import '../services/character_selection_service.dart';
import '../widgets/skulmate_character_widget.dart';
import '../widgets/skulmate_game_app_bar.dart';
import 'game_results_screen.dart';
import 'game_library_screen.dart';

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

  const MatchingGameScreen({Key? key, required this.game}) : super(key: key);

  @override
  State<MatchingGameScreen> createState() => _MatchingGameScreenState();
}

class _MatchingGameScreenState extends State<MatchingGameScreen>
    with TickerProviderStateMixin {
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
  dynamic _character;
  GameStats? _currentStats;
  bool _isProcessing = false;
  bool _isTTSEnabled = true;
  int _hintsRemaining = 3; // Peek at a pair (limited uses)
  Timer? _matchFlyerTimer;
  String? _matchFlyerText;

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();
    // Initialize sound and TTS early so they're ready on first flip
    _soundService.ensureInitialized();
    unawaited(_soundService.playMusicForGame(widget.game.gameType));
    _ttsService.ensureInitialized();
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
    _loadCharacter();
    _loadStats();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showHowToPlayIfFirstTime();
    });
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

  void _initializeItems() {
    // Create pairs from game items
    final pairs = <CardData>[];
    for (int i = 0; i < widget.game.items.length; i++) {
      final item = widget.game.items[i];
      if (item.leftItem != null && item.leftItem!.isNotEmpty) {
        pairs.add(
          CardData(id: i * 2, text: item.leftItem!, pairId: i, isLeft: true),
        );
      }
      if (item.rightItem != null && item.rightItem!.isNotEmpty) {
        pairs.add(
          CardData(
            id: i * 2 + 1,
            text: item.rightItem!,
            pairId: i,
            isLeft: false,
          ),
        );
      }
    }

    // Shuffle cards
    _cards = pairs..shuffle(Random());

    // Initialize flip animations for each card
    for (int i = 0; i < _cards.length; i++) {
      final controller = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 300),
      );
      _flipControllers[i] = controller;
      _flipAnimations[i] = Tween<double>(
        begin: 0,
        end: 1,
      ).animate(CurvedAnimation(parent: controller, curve: Curves.easeInOut));
    }
  }

  @override
  void dispose() {
    _matchFlyerTimer?.cancel();
    unawaited(_soundService.stopMusic());
    for (final controller in _flipControllers.values) {
      controller.dispose();
    }
    _progressController.dispose();
    _confettiController.dispose();
    _ttsService.dispose();
    super.dispose();
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
      _soundService.playFlip();
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
      _soundService.playFlip();
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

      _showMatchFlyer(_buildMatchSentence(card1, card2));
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
    _soundService.playFlip();
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

  void _showMatchFlyer(String text) {
    _matchFlyerTimer?.cancel();
    safeSetState(() {
      _matchFlyerText = text;
    });
    _matchFlyerTimer = Timer(const Duration(milliseconds: 1800), () {
      if (!mounted) return;
      safeSetState(() {
        _matchFlyerText = null;
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
        'This is a matching game. Each pair links two ideas from your notes. '
        'Tap one card, then tap another card to find its match. '
        'When cards match, they stay green and you earn XP. '
        'If cards do not match, they flip back, so try to remember where they were.';
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
                  'This is a matching game. Each pair links two ideas from your notes (left and right cards).',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: AppTheme.textMedium,
                  ),
                ),
                const SizedBox(height: 12),
                _buildHowToBullet(
                  'Tap any card to flip it and hear it read aloud.',
                ),
                _buildHowToBullet(
                  'Tap a second card to try to find its matching idea.',
                ),
                _buildHowToBullet(
                  'If they match, they stay green and you earn XP.',
                ),
                _buildHowToBullet(
                  'If they don’t match, they flip back—try to remember their positions.',
                ),
                _buildHowToBullet(
                  'Finish the game by matching all pairs with as few moves as possible.',
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
      _ttsService.speak(instructionText);
    }
    await sheetFuture;
    await _ttsService.stop();
  }

  void _openGameSettings() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, modalSetState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Game settings',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textDark,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('Game sounds', style: GoogleFonts.poppins()),
                      value: _soundService.soundsEnabled,
                      onChanged: (v) async {
                        await _soundService.toggleSounds(v);
                        modalSetState(() {});
                        if (mounted) safeSetState(() {});
                      },
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'SFX volume: ${(_soundService.soundsVolume * 100).round()}%',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textMedium,
                            ),
                          ),
                          Slider(
                            value: _soundService.soundsVolume,
                            min: 0,
                            max: 1,
                            divisions: 100,
                            onChanged: _soundService.soundsEnabled
                                ? (v) {
                                    unawaited(
                                      _soundService.setSoundsVolume(v),
                                    );
                                    modalSetState(() {});
                                    if (mounted) safeSetState(() {});
                                  }
                                : null,
                          ),
                        ],
                      ),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('Music', style: GoogleFonts.poppins()),
                      value: _soundService.musicEnabled,
                      onChanged: (v) async {
                        await _soundService.toggleMusic(v);
                        if (v) {
                          await _soundService.playMusicForGame(
                            widget.game.gameType,
                          );
                        }
                        modalSetState(() {});
                        if (mounted) safeSetState(() {});
                      },
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Music volume: ${(_soundService.musicVolume * 100).round()}%',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textMedium,
                            ),
                          ),
                          Slider(
                            value: _soundService.musicVolume,
                            min: 0,
                            max: 1,
                            divisions: 100,
                            onChanged: _soundService.musicEnabled
                                ? (v) {
                                    unawaited(
                                      _soundService.setMusicVolume(v),
                                    );
                                    modalSetState(() {});
                                    if (mounted) safeSetState(() {});
                                  }
                                : null,
                          ),
                        ],
                      ),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'Read aloud (TTS)',
                        style: GoogleFonts.poppins(),
                      ),
                      value: _isTTSEnabled,
                      onChanged: (v) {
                        _ttsService.setEnabled(v);
                        modalSetState(() => _isTTSEnabled = v);
                        if (mounted) safeSetState(() => _isTTSEnabled = v);
                      },
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Voice volume: ${(_ttsService.volume * 100).round()}%',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textMedium,
                            ),
                          ),
                          Slider(
                            value: _ttsService.volume,
                            min: 0,
                            max: 1,
                            divisions: 100,
                            onChanged: _isTTSEnabled
                                ? (v) {
                                    unawaited(
                                      _ttsService.setVolume(v),
                                    );
                                    modalSetState(() {});
                                    if (mounted) safeSetState(() {});
                                  }
                                : null,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
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
    final endTime = DateTime.now();
    final timeTaken = _startTime != null
        ? endTime.difference(_startTime!).inSeconds
        : null;

    final isPerfectScore = _score == widget.game.items.length;

    // Calculate bonus XP based on moves (fewer moves = more bonus)
    int bonusXP = 0;
    if (isPerfectScore) bonusXP += 50;
    if (timeTaken != null && timeTaken < 120) bonusXP += 25;
    final optimalMoves = widget.game.items.length * 2; // Minimum moves needed
    if (_moves <= optimalMoves * 1.5) bonusXP += 20; // Efficiency bonus
    final totalXP = _xpEarned + bonusXP;

    unawaited(
      GameStatsService.addGameResult(
        correctAnswers: _score,
        totalQuestions: widget.game.items.length,
        timeTakenSeconds: timeTaken ?? 0,
        isPerfectScore: isPerfectScore,
      ).catchError((e) {
        LogService.error('🎮 [Matching] Error updating game stats: $e');
      }),
    );

    unawaited(
      SkulMateService.saveGameSession(
        gameId: widget.game.id,
        score: _score,
        totalQuestions: widget.game.items.length,
        correctAnswers: _score,
        timeTakenSeconds: timeTaken,
        answers: {'moves': _moves, 'pairs': _matchedPairs.length},
      ).catchError((e) {
        LogService.error('🎮 [Matching] Error saving game session: $e');
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

  Future<void> _handleBack() async {
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
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => GameLibraryScreen(childId: widget.game.childId),
        ),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _handleBack();
      },
      child: Scaffold(
        backgroundColor: AppTheme.softBackground,
        appBar: SkulMateGameAppBar(
          title: widget.game.title,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: _handleBack,
          ),
          actions: [
            if (_hintsRemaining > 0)
              IconButton(
                tooltip: 'Peek at a pair ($_hintsRemaining left)',
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                padding: const EdgeInsets.all(6),
                icon: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Icon(Icons.lightbulb_outline, color: Colors.white),
                    Positioned(
                      right: -6,
                      top: -4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade400,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$_hintsRemaining',
                          style: GoogleFonts.poppins(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                onPressed: _useHint,
              ),
            IconButton(
              tooltip: 'How to play',
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
              padding: const EdgeInsets.all(6),
              icon: const Icon(Icons.help_outline, color: Colors.white),
              onPressed: _showHowToPlay,
            ),
            Padding(
              padding: const EdgeInsets.only(right: 2, left: 0),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: _openGameSettings,
                child: CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.white.withOpacity(0.22),
                  child: _character != null
                      ? ClipOval(
                          child: SizedBox(
                            width: 28,
                            height: 28,
                            child: SkulMateCharacterWidget(
                              character: _character,
                              size: 24,
                              animated: false,
                              showName: false,
                            ),
                          ),
                        )
                      : const Icon(
                          Icons.settings,
                          size: 16,
                          color: Colors.white,
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
                // Animated Progress bar
                AnimatedBuilder(
                  animation: _progressAnimation,
                  builder: (context, child) {
                    return LinearProgressIndicator(
                      value: _progressAnimation.value,
                      backgroundColor: AppTheme.neutral200,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        AppTheme.primaryColor,
                      ),
                      minHeight: 4,
                    );
                  },
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _buildStatCard(
                                'Moves',
                                '$_moves',
                                Icons.touch_app,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildStatCard(
                                'Matches',
                                '${_matchedPairs.length ~/ 2}/${widget.game.items.length}',
                                Icons.check_circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildStatCard(
                                'XP',
                                '$_xpEarned',
                                Icons.star,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Memory game grid
                        Expanded(
                          child: GridView.builder(
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: _cards.length <= 6
                                      ? 2
                                      : (_cards.length <= 12 ? 3 : 4),
                                  crossAxisSpacing: 6,
                                  mainAxisSpacing: 6,
                                  childAspectRatio: _cards.length <= 6
                                      ? 0.78
                                      : (_cards.length <= 12 ? 0.85 : 0.92),
                                ),
                            itemCount: _cards.length,
                            itemBuilder: (context, index) {
                              final card = _cards[index];
                              final isFlipped = _flippedCards.contains(index);
                              final isMatched = _matchedPairs.containsKey(
                                index,
                              );
                              final isSelected =
                                  _firstFlipped == index ||
                                  _secondFlipped == index;

                              return _buildMemoryCard(
                                card: card,
                                index: index,
                                isFlipped: isFlipped || isMatched,
                                isMatched: isMatched,
                                isSelected: isSelected,
                              );
                            },
                          ),
                        ),
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
                  AppTheme.accentGreen,
                  AppTheme.primaryColor,
                  Color(0xFF0A2D67),
                  AppTheme.softYellow,
                  AppTheme.accentPurple,
                  Colors.white,
                ],
              ),
            ),
            if (_matchFlyerText != null)
              Positioned(
                top: 10,
                left: 16,
                right: 16,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 220),
                  opacity: _matchFlyerText == null ? 0 : 1,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF13458F), Color(0xFF0A2E68)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppTheme.accentGreen.withOpacity(0.9),
                        width: 1.6,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryColor.withOpacity(0.2),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Text(
                      _matchFlyerText!,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon) {
    return Container(
      height: 82,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [const Color(0xFFEFF5FF), const Color(0xFFF8FBFF)],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.14)),
        boxShadow: [
          BoxShadow(
            color: Colors.white.withOpacity(0.9),
            blurRadius: 8,
            offset: const Offset(-2, -2),
          ),
          BoxShadow(
            color: AppTheme.primaryColor.withOpacity(0.10),
            blurRadius: 10,
            offset: const Offset(2, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: AppTheme.primaryColor, size: 20),
          const SizedBox(height: 3),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppTheme.textDark,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 10,
              color: AppTheme.textMedium,
            ),
          ),
        ],
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
        gradient: isMatched
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF2DBE62), Color(0xFF1E8E4D)],
              )
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF0C3574),
                  const Color(0xFF0A2D67),
                  if (isSelected) const Color(0xFF13458F),
                ],
              ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isMatched
              ? Colors.white
              : const Color(0xFF275AA2).withOpacity(0.95),
          width: isMatched ? 1.6 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF072552).withOpacity(isSelected ? 0.48 : 0.34),
            blurRadius: isSelected ? 15 : 12,
            offset: const Offset(4, 6),
          ),
        ],
      ),
      child: Center(
        child: isMatched
            ? const Icon(Icons.check_circle, color: Colors.white, size: 36)
            : Icon(
                isSelected ? Icons.radio_button_checked : Icons.help_outline,
                color: Colors.white.withOpacity(0.95),
                size: 34,
              ),
      ),
    );
  }

  Widget _buildCardFront(CardData card, bool isMatched, double rotationAngle) {
    // Front of the card should stay clean white whether the pair is correct
    // or not. We only vary the border subtlely for matched cards.
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFFFFFFF),
            const Color(0xFFF4F8FF),
            if (isMatched) const Color(0xFFE9F1FF),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isMatched
              ? const Color(0xFF0A2D67).withOpacity(0.9)
              : AppTheme.primaryColor.withOpacity(0.55),
          width: isMatched ? 1.7 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.white.withOpacity(0.55),
            blurRadius: 8,
            offset: const Offset(-3, -3),
          ),
          BoxShadow(
            color: const Color(0xFF9EB7DE).withOpacity(0.22),
            blurRadius: 11,
            offset: const Offset(4, 6),
          ),
        ],
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
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.textDark,
            ),
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}
