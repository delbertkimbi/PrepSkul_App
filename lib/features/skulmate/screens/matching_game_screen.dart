import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:confetti/confetti.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/core/utils/safe_set_state.dart';
import 'package:prepskul/core/services/log_service.dart';
import 'dart:async';
import 'dart:math';
import '../models/game_model.dart';
import '../models/skulmate_character_model.dart';
import '../models/game_stats_model.dart';
import '../services/skulmate_service.dart';
import '../services/game_sound_service.dart';
import '../services/tts_service.dart';
import '../services/game_stats_service.dart';
import '../services/game_rules_service.dart';
import '../services/character_selection_service.dart';
import '../widgets/game_settings_sheet.dart';
import '../widgets/skulmate_character_widget.dart';
import '../widgets/skulmate_game_app_bar.dart';
import '../widgets/skulmate_companion_banner.dart';
import '../widgets/game_standard_widgets.dart';
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
  dynamic _character;
  GameStats? _currentStats;
  bool _isProcessing = false;
  bool _isTTSEnabled = true;
  int _hintsRemaining = 3; // Peek at a pair (limited uses)
  Timer? _matchFlyerTimer;
  String? _matchFlyerText;
  String? _mascotReaction;
  CompanionTone _mascotReactionTone = CompanionTone.neutral;
  bool _mascotCelebrate = false;
  Timer? _mascotReactionTimer;
  static const int _maxPairsPerScreen = 5;
  final List<GameItem> _allPairs = [];
  List<GameItem> _currentRoundPairs = [];
  final Map<int, int> _roundAssignments = {};
  final Set<int> _roundCorrectPairIds = {};
  List<int> _rightColumnPairIds = [];
  int? _activeLeftPairId;
  int _currentRoundStart = 0;
  int _completedPairs = 0;
  bool _showRoundResult = false;
  static const int _roundCountdownSeconds = 50;
  int _roundRemainingSeconds = _roundCountdownSeconds;
  Timer? _roundTimer;

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
    _loadCharacter();
    _loadStats();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showHowToPlayIfFirstTime();
    });
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
    if (_isTTSEnabled && _currentRoundPairs.isNotEmpty) {
      unawaited(
        _ttsService.speak(
          'Section 1. Match each term on the left to the correct meaning on the right.',
        ),
      );
    }
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
    final end = min(_currentRoundStart + _maxPairsPerScreen, _allPairs.length);
    _currentRoundPairs = _allPairs.sublist(_currentRoundStart, end);
    _rightColumnPairIds = List<int>.generate(
      _currentRoundPairs.length,
      (i) => _currentRoundStart + i,
    )..shuffle(Random());
    _roundAssignments.clear();
    _roundCorrectPairIds.clear();
    _activeLeftPairId = null;
    _showRoundResult = false;
    _startRoundCountdown();
    unawaited(_soundService.ensureMusicForGame(GameType.mystery));
    if (_isTTSEnabled && _currentRoundPairs.isNotEmpty) {
      unawaited(_ttsService.stop());
      final section = _roundNumber();
      unawaited(
        _ttsService.speak(
          'Section $section. Tap a term on the left, then tap its correct match on the right.',
          ),
        );
      }
    }

  void _onSelectLeft(int pairId) {
    if (_showRoundResult) return;
    if (_isTTSEnabled) {
      unawaited(_ttsService.stop());
    }
    unawaited(_soundService.registerUserGesture());
    unawaited(_soundService.playMatchingTap());
    unawaited(_soundService.ensureMusicForGame(GameType.mystery));
    safeSetState(() {
      _activeLeftPairId = pairId;
    });
  }

  void _onSelectRight(int rightPairId) {
    if (_showRoundResult || _activeLeftPairId == null) return;
    if (_isTTSEnabled) {
      unawaited(_ttsService.stop());
    }
    unawaited(_soundService.registerUserGesture());
    unawaited(_soundService.playMatchingTap());
    unawaited(_soundService.ensureMusicForGame(GameType.mystery));
    safeSetState(() {
      final leftPairId = _activeLeftPairId!;
      final previousLeftForRight = _roundAssignments.entries
          .where((e) => e.value == rightPairId)
          .map((e) => e.key)
          .toList();
      for (final prevLeft in previousLeftForRight) {
        _roundAssignments.remove(prevLeft);
      }
      _roundAssignments[leftPairId] = rightPairId;
      _moves++;
      _activeLeftPairId = null;
    });
  }

  void _checkCurrentRound() {
    _roundTimer?.cancel();
    if (_isTTSEnabled) {
      unawaited(_ttsService.stop());
    }
    unawaited(_soundService.registerUserGesture());
    unawaited(_soundService.playClick());
    if (_roundAssignments.length < _currentRoundPairs.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Match all left items with right outcomes first.',
            style: GoogleFonts.poppins(fontSize: 13),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    _roundCorrectPairIds.clear();
    for (final pairId in _roundAssignments.keys) {
      if (_roundAssignments[pairId] == pairId) {
        _roundCorrectPairIds.add(pairId);
      }
    }
    final allCorrect = _roundCorrectPairIds.length == _currentRoundPairs.length;
    safeSetState(() {
      _showRoundResult = true;
    });
    final originalCorrectCount = _roundCorrectPairIds.length;
    _score += originalCorrectCount;
    _xpEarned += originalCorrectCount * 15;
    _completedPairs += _currentRoundPairs.length;

    if (!allCorrect) {
      // Show corrections inline on each matched card.
      for (final pairId in List<int>.from(_roundAssignments.keys)) {
        _roundAssignments[pairId] = pairId;
      }
    }

    if (allCorrect) {
      unawaited(_soundService.playMatchingSuccess());
      _showMascotReaction(
        'Perfect set. Move to the next section.',
        tone: CompanionTone.success,
        celebrate: true,
      );
      if (_isTTSEnabled) {
        unawaited(
          Future<void>.delayed(
            const Duration(milliseconds: 140),
            () => _ttsService.speak('Perfect set. Continue to the next section.'),
          ),
        );
      }
    } else {
      unawaited(_soundService.playMatchingWrong());
      _showMascotReaction(
        'Corrections are now shown inline on the cards.',
        tone: CompanionTone.warning,
      );
      if (_isTTSEnabled) {
        unawaited(
          Future<void>.delayed(const Duration(milliseconds: 140), () {
            return _ttsService.speak(
              'Not fully correct yet. I have shown the corrected matches on the cards.',
            );
          }),
        );
      }
    }
  }

  void _nextRoundOrFinish() {
    _roundTimer?.cancel();
    if (_completedPairs >= _allPairs.length) {
      _finishGame();
      return;
    }
    _currentRoundStart += _maxPairsPerScreen;
    if (_currentRoundStart >= _allPairs.length) {
      _finishGame();
      return;
    }
    safeSetState(_loadCurrentRound);
  }

  void _retryRound() {
    safeSetState(() {
      _showRoundResult = false;
      _activeLeftPairId = null;
    });
    _soundService.playClick();
  }

  void _startRoundCountdown() {
    _roundTimer?.cancel();
    _roundRemainingSeconds = _roundCountdownSeconds;
    _roundTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_showRoundResult) {
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
    if (_showRoundResult || _currentRoundPairs.isEmpty) return;
    final roundPairIds = List<int>.generate(
      _currentRoundPairs.length,
      (i) => _currentRoundStart + i,
    );
    safeSetState(() {
      for (final pairId in roundPairIds) {
        _roundAssignments[pairId] = pairId;
      }
      _roundCorrectPairIds.clear();
      _showRoundResult = true;
      _completedPairs += _currentRoundPairs.length;
    });
    unawaited(_soundService.playCountdownBuzzer());
    unawaited(
      Future<void>.delayed(const Duration(milliseconds: 90), _soundService.playMatchingWrong),
    );
    _showMascotReaction(
      'Time up for this section. Corrections are shown, continue to next.',
      tone: CompanionTone.warning,
    );
    if (_isTTSEnabled) {
      unawaited(_ttsService.speak('Time up. Corrections are shown. Continue to next section.'));
    }
  }

  Color _leftTileColor(int pairId) {
    if (!_showRoundResult) {
      return _activeLeftPairId == pairId
          ? const Color(0xFFDBEAFE)
          : const Color(0xFFEFF6FF);
    }
    return _roundCorrectPairIds.contains(pairId)
        ? AppTheme.accentGreen.withOpacity(0.10)
        : const Color(0xFFEFF6FF);
  }

  Color _leftTileBorder(int pairId) {
    if (!_showRoundResult) {
      return _activeLeftPairId == pairId
          ? const Color(0xFF2563EB)
          : const Color(0xFF60A5FA);
    }
    return _roundCorrectPairIds.contains(pairId)
        ? AppTheme.accentGreen.withOpacity(0.65)
        : const Color(0xFF60A5FA);
  }

  Color _rightTileColor(int pairId) {
    if (!_showRoundResult) {
      final selected = _roundAssignments.values.contains(pairId);
      return selected
          ? const Color(0xFFFEF3C7)
          : const Color(0xFFFFFBEB);
    }
    final isCorrectTarget = _roundCorrectPairIds.contains(pairId);
    return isCorrectTarget
        ? AppTheme.accentGreen.withOpacity(0.10)
        : const Color(0xFFFFFBEB);
  }

  Color _rightTileBorder(int pairId) {
    if (!_showRoundResult) {
      final selected = _roundAssignments.values.contains(pairId);
      return selected
          ? const Color(0xFFF59E0B)
          : const Color(0xFFFBBF24);
    }
    return _roundCorrectPairIds.contains(pairId)
        ? AppTheme.accentGreen.withOpacity(0.65)
        : const Color(0xFFFBBF24);
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

  bool _isRightChosenByAnotherLeft(int rightPairId, int leftPairId) {
    return _roundAssignments.entries.any(
      (e) => e.key != leftPairId && e.value == rightPairId,
    );
  }

  Widget _buildMatchingColumns() {
    final roundPairIds = List<int>.generate(
      _currentRoundPairs.length,
      (i) => _currentRoundStart + i,
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            children: roundPairIds.map((pairId) {
              final assignedRight = _roundAssignments[pairId];
              final wasCorrect = _roundCorrectPairIds.contains(pairId);
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => _onSelectLeft(pairId),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _leftTileColor(pairId),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _leftTileBorder(pairId),
                        width: _activeLeftPairId == pairId ? 1.8 : 1.2,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _leftLabelForPair(pairId),
                          style: GoogleFonts.poppins(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textDark,
                          ),
                        ),
                        if (assignedRight != null) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Text(
                                '-> ',
                                style: GoogleFonts.poppins(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  _rightLabelForPair(
                                    _showRoundResult ? pairId : assignedRight,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: AppTheme.primaryColor,
                                  ),
                                ),
                              ),
                              if (_showRoundResult)
                                Icon(
                                  wasCorrect
                                      ? Icons.check_circle_rounded
                                      : Icons.info_outline_rounded,
                                  size: 14,
                                  color: wasCorrect
                                      ? AppTheme.accentGreen
                                      : AppTheme.primaryColor,
                                ),
                            ],
                          ),
                          if (_showRoundResult && !wasCorrect)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                'corrected',
                                style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF1D4ED8),
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            children: _rightColumnPairIds.map((pairId) {
              final wasCorrect = _roundCorrectPairIds.contains(pairId);
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: _activeLeftPairId == null
                      ? null
                      : () {
                          if (_activeLeftPairId == null) return;
                          if (_isRightChosenByAnotherLeft(pairId, _activeLeftPairId!)) {
                            unawaited(_soundService.playMatchingWrong());
                          }
                          _onSelectRight(pairId);
                        },
                  child: Stack(
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _rightTileColor(pairId),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: _rightTileBorder(pairId),
                            width: 1.2,
                          ),
                        ),
                        child: Text(
                          _rightLabelForPair(pairId),
                          style: GoogleFonts.poppins(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.textDark,
                          ),
                        ),
                      ),
                      if (_showRoundResult)
                        Positioned(
                          right: 8,
                          top: 8,
                          child: Icon(
                            wasCorrect
                                ? Icons.check_circle_rounded
                                : Icons.cancel_rounded,
                            size: 16,
                            color: wasCorrect
                                ? AppTheme.accentGreen
                                : const Color(0xFFDC2626),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionActionArea() {
    final allAssigned = _roundAssignments.length == _currentRoundPairs.length;
    if (_showRoundResult) {
      return GameStandardsPrimaryButton(
        label: _completedPairs >= _allPairs.length ? 'Finish game' : 'Continue',
        onPressed: _nextRoundOrFinish,
      );
    }
    return GameStandardsPrimaryButton(
      label: allAssigned ? 'Check matches' : 'Select all matches',
      onPressed: _checkCurrentRound,
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _matchFlyerTimer?.cancel();
    _mascotReactionTimer?.cancel();
    _roundTimer?.cancel();
    unawaited(_ttsService.stop());
    unawaited(_soundService.stopMusic(force: true));
    for (final controller in _flipControllers.values) {
      controller.dispose();
    }
    _progressController.dispose();
    _confettiController.dispose();
    _ttsService.dispose();
    super.dispose();
  }

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

      _showMatchFlyer(_buildMatchSentence(card1, card2));
      _showMascotReaction(
        'Excellent match. Keep chaining them.',
        tone: CompanionTone.success,
        celebrate: true,
      );
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
      _showMascotReaction(
        'Not a pair yet. Remember positions and try again.',
        tone: CompanionTone.tip,
      );
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
        'This is a direct matching game. Choose a term on the left and map it to the correct outcome on the right. '
        'Complete each section before moving to the next one. '
        'Green means correct mapping, red means rematch needed.';
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
                  'Match each left concept to its correct right outcome in order.',
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
                  'Then tap the matching right item (definition/outcome).',
                ),
                _buildHowToBullet(
                  'Fill all mappings, then press Check matches.',
                ),
                _buildHowToBullet(
                  'Correct mappings turn green; incorrect mappings turn red.',
                ),
                _buildHowToBullet(
                  'You get up to 5 pairs per section, and 3 sections flow progressively.',
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
      await _ttsService.stop();
      await _soundService.stopMusic(force: true);
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
                  child: ClipOval(
                          child: SizedBox(
                            width: 28,
                            height: 28,
                            child: SkulMateCharacterWidget(
                        character: _character ?? SkulMateCharacters.middleMale,
                              size: 24,
                              animated: false,
                              showName: false,
                            ),
                          ),
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
                      value: _progressValue(),
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
                    child: LayoutBuilder(
                      builder: (context, constraints) => SingleChildScrollView(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(minHeight: constraints.maxHeight),
                          child: Column(
                            children: [
                        // Section 1: compact status strip (no large square cards)
                        FlatStageCard(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          borderColor: AppTheme.primaryColor.withOpacity(0.15),
                    child: Column(
                      children: [
                        Row(
                          children: [
                                  _buildCompactTopPill(
                                    icon: Icons.timer_outlined,
                                    label: 'Time',
                                    value: '${_roundRemainingSeconds}s',
                                    color: _roundRemainingSeconds <= 10
                                        ? AppTheme.primaryDark
                                        : AppTheme.primaryColor,
                                  ),
                                  const SizedBox(width: 8),
                                  _buildCompactTopPill(
                                    icon: Icons.check_circle,
                                    label: 'Matched',
                                    value: '$_completedPairs/$totalPairs',
                                    color: AppTheme.primaryColor,
                            ),
                            const SizedBox(width: 8),
                                  _buildCompactTopPill(
                                    icon: Icons.star_rounded,
                                    label: 'XP',
                                    value: '$_xpEarned',
                                    color: AppTheme.primaryLight,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Text(
                                    'Section ${_roundNumber()} of ${_totalSections()}',
                                    style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.textMedium,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    '${_currentRoundPairs.length} pairs on this screen',
                                    style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      color: AppTheme.textMedium,
                              ),
                            ),
                          ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Section 2: matching board
                        FlatStageCard(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          borderColor: AppTheme.primaryColor.withOpacity(0.14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Knowledge Match',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textMedium,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                        Expanded(
                                    child: Text(
                                      'Terms',
                                      style: GoogleFonts.poppins(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: AppTheme.primaryColor,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Definitions',
                                      textAlign: TextAlign.right,
                                      style: GoogleFonts.poppins(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: AppTheme.textMedium,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: List.generate(_totalSections().clamp(1, 5), (
                                index,
                                ) {
                                  final sectionCount = _totalSections().clamp(1, 5);
                                  final completedSteps = _showRoundResult
                                      ? _roundNumber().clamp(1, sectionCount)
                                      : (_roundNumber() - 1).clamp(
                                          0,
                                          sectionCount,
                                        );
                                  final filled = index < completedSteps;
                                  return Expanded(
                                    child: Container(
                                      margin: EdgeInsets.only(
                                        right: index == sectionCount - 1 ? 0 : 6,
                                      ),
                                      height: 6,
                                      decoration: BoxDecoration(
                                        color: filled
                                            ? AppTheme.skyBlue
                                            : AppTheme.neutral200,
                                        borderRadius: BorderRadius.circular(99),
                                      ),
                                    ),
                                  );
                                }),
                              ),
                              const SizedBox(height: 10),
                              _buildMatchingColumns(),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        if (_mascotReaction != null) ...[
                          SkulMateCompanionBanner(
                            tone: _mascotReactionTone,
                            message: _mascotReaction!,
                            celebrate: _mascotCelebrate,
                          ),
                          const SizedBox(height: 10),
                        ],
                        const SizedBox(height: 12),
                        // Section 3: action area
                        _buildSectionActionArea(),
                            ],
                          ),
                        ),
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
                  AppTheme.accentGreen,
                  AppTheme.primaryColor,
                  AppTheme.primaryDark,
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
                        colors: [AppTheme.primaryLight, AppTheme.primaryDark],
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
