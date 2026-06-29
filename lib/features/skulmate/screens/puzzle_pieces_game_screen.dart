import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/services/log_service.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/core/utils/safe_set_state.dart';

import '../l10n/skulmate_copy.dart';
import '../models/game_model.dart';
import '../models/game_stats_model.dart';
import '../models/puzzle_step_model.dart';
import '../services/game_audio_lifecycle.dart';
import '../services/game_progress_service.dart';
import '../services/game_sound_service.dart';
import '../services/game_stats_service.dart';
import '../services/skulmate_service.dart';
import '../services/tts_service.dart';
import '../utils/skulmate_navigation.dart';
import '../widgets/game_settings_sheet.dart';
import '../widgets/game_standard_widgets.dart';
import '../widgets/puzzle_learn_more_sheet.dart';
import '../widgets/puzzle_sequence_widgets.dart';
import '../widgets/skulmate_game_app_bar.dart';
import '../widgets/skulmate_game_surface.dart';
import '../widgets/skulmate_profile_avatar.dart';
import 'game_results_screen.dart';

/// Multi-mode puzzle journey (pick, hotspot, order).
class PuzzlePiecesGameScreen extends StatefulWidget {
  final GameModel game;
  final GameProgress? resumeFrom;

  const PuzzlePiecesGameScreen({
    super.key,
    required this.game,
    this.resumeFrom,
  });

  @override
  State<PuzzlePiecesGameScreen> createState() => _PuzzlePiecesGameScreenState();
}

class _PuzzlePiecesGameScreenState extends State<PuzzlePiecesGameScreen> {
  List<PuzzleStepDefinition> _steps = [];
  int _currentStepIndex = 0;
  int _score = 0;
  int _xpEarned = 0;
  int _wrongAttempts = 0;
  DateTime? _startTime;
  final GameSoundService _soundService = GameSoundService();
  final TTSService _ttsService = TTSService();
  String? _flashWrongId;
  String _feedbackMessage = '';
  GameFeedbackTone _feedbackTone = GameFeedbackTone.neutral;
  bool _isAdvancing = false;
  bool _showCompletionAnimation = false;
  bool _xpPopupVisible = false;
  int _lastXpBurst = 0;
  int _edgeFlashTrigger = 0;
  bool _edgeFlashSuccess = true;
  bool _gameCompleted = false;
  bool _isTTSEnabled = true;
  bool _isLeaving = false;

  // hotspot_drop state for current step
  final Map<String, String> _filledHotspots = {};
  String? _selectedLabelId;
  // order_check state for current step
  final List<String> _orderTapped = [];

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();
    unawaited(_initializeAudio());
    _loadSteps();
    _restoreFromProgress();
  }

  Future<void> _initializeAudio() async {
    await _soundService.ensureInitialized();
    await _ttsService.ensureInitialized();
    _isTTSEnabled = _ttsService.isEnabled;
    if (!_soundService.soundsEnabled) {
      await _soundService.toggleSounds(true);
    }
    await _soundService.playMusicForGame(GameType.puzzlePieces);
  }

  void _loadSteps() {
    if (widget.game.items.isEmpty) {
      _steps = PuzzleStepDefinition.fromLegacyPieces([
        {'id': '1', 'text': 'Learn the concept', 'order': 0},
        {'id': '2', 'text': 'Practice', 'order': 1},
        {'id': '3', 'text': 'Apply', 'order': 2},
      ]);
      return;
    }
    final item = widget.game.items.first;
    _steps = PuzzleStepDefinition.parseFromGameItem(
      puzzleSteps: item.puzzleSteps,
      puzzlePieces: item.puzzlePieces,
      gameData: item.gameData,
    );
    if (_steps.isEmpty) {
      _steps = PuzzleStepDefinition.fromLegacyPieces([
        {'id': '1', 'text': 'Learn the concept', 'order': 0},
        {'id': '2', 'text': 'Practice', 'order': 1},
      ]);
    }
  }

  void _restoreFromProgress() {
    final resume = widget.resumeFrom;
    if (resume == null) return;
    _score = resume.score;
    _currentStepIndex = resume.currentIndex.clamp(0, _steps.length);
    _xpEarned = _currentStepIndex * 5;
  }

  PuzzleStepDefinition? get _currentStep =>
      _currentStepIndex < _steps.length ? _steps[_currentStepIndex] : null;

  String _stepKindLabel(SkulMateCopy copy, PuzzleStepDefinition step) {
    switch (step.type) {
      case PuzzleStepType.pickOne:
        return copy.puzzleStepTypePick;
      case PuzzleStepType.hotspotDrop:
        return copy.puzzleStepTypeHotspot;
      case PuzzleStepType.orderCheck:
        return copy.puzzleStepTypeOrder;
    }
  }

  String get _questionPrompt {
    final step = _currentStep;
    if (step == null) return '';
    if (step.prompt.isNotEmpty) return step.prompt;
    return SkulMateCopy.of(context).puzzleNextPrompt(
      placedCount: _currentStepIndex,
      total: _steps.length,
    );
  }

  bool get _isComplete => _currentStepIndex >= _steps.length;

  double get _progressValue {
    if (_steps.isEmpty) return 0;
    return (_currentStepIndex / _steps.length).clamp(0.0, 1.0);
  }

  void _resetStepState() {
    _filledHotspots.clear();
    _orderTapped.clear();
    _selectedLabelId = null;
    _flashWrongId = null;
  }

  Future<void> _persistProgress() async {
    if (_gameCompleted) return;
    await GameProgressService.saveProgress(
      GameProgress(
        gameId: widget.game.id,
        gameType: widget.game.gameType,
        currentIndex: _currentStepIndex,
        score: _score,
        stateData: const {},
        savedAt: DateTime.now(),
      ),
    );
  }

  Future<void> _onStepSuccess() async {
    if (_isAdvancing || _isComplete) return;
    _isAdvancing = true;
    HapticFeedback.mediumImpact();
    unawaited(_soundService.playCorrect());
    unawaited(_soundService.playPiecePlace());

    safeSetState(() {
      _score += 10;
      _xpEarned += 5;
      _lastXpBurst = 5;
      _xpPopupVisible = true;
      _edgeFlashSuccess = true;
      _edgeFlashTrigger++;
      _feedbackMessage = '';
    });

    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    safeSetState(() => _xpPopupVisible = false);

    if (_currentStepIndex + 1 >= _steps.length) {
      safeSetState(() {
        _showCompletionAnimation = true;
        _feedbackMessage = SkulMateCopy.read(context).puzzleSequenceComplete;
        _feedbackTone = GameFeedbackTone.success;
      });
      await Future.delayed(const Duration(milliseconds: 900));
      if (mounted) await _finishGame();
      return;
    }

    safeSetState(() {
      _currentStepIndex++;
      _resetStepState();
      _isAdvancing = false;
    });
    unawaited(_persistProgress());
  }

  void _onWrong({String? message}) {
    _wrongAttempts++;
    HapticFeedback.lightImpact();
    unawaited(_soundService.playIncorrect());
    final copy = SkulMateCopy.read(context);
    safeSetState(() {
      _feedbackMessage = message ?? copy.puzzleWrongStep;
      _feedbackTone = GameFeedbackTone.error;
      _edgeFlashSuccess = false;
      _edgeFlashTrigger++;
    });
  }

  Future<void> _onPickOne(String choiceId) async {
    if (_isAdvancing) return;
    final step = _currentStep;
    if (step == null) return;

    unawaited(_soundService.playClick());
    final choice = step.choices.cast<PuzzleStepChoice?>().firstWhere(
          (c) => c?.id == choiceId,
          orElse: () => null,
        );
    if (choice == null) return;

    if (!choice.correct) {
      safeSetState(() => _flashWrongId = choiceId);
      _onWrong();
      await Future.delayed(const Duration(milliseconds: 420));
      if (mounted) safeSetState(() => _flashWrongId = null);
      return;
    }
    await _onStepSuccess();
  }

  Future<void> _onHotspotDrop(String labelId, String hotspotId) async {
    if (_isAdvancing) return;
    final step = _currentStep;
    if (step == null) return;

    unawaited(_soundService.playClick());
    final hotspot = step.hotspots.cast<PuzzleHotspot?>().firstWhere(
          (h) => h?.id == hotspotId,
          orElse: () => null,
        );
    if (hotspot == null || hotspot.accepts != labelId) {
      safeSetState(() => _flashWrongId = labelId);
      _onWrong();
      await Future.delayed(const Duration(milliseconds: 420));
      if (mounted) safeSetState(() => _flashWrongId = null);
      return;
    }

    safeSetState(() => _filledHotspots[hotspotId] = labelId);
    final allFilled = step.hotspots.every((h) => _filledHotspots.containsKey(h.id));
    if (allFilled) await _onStepSuccess();
  }

  void _onLabelSelect(String labelId) {
    if (_isAdvancing) return;
    unawaited(_soundService.playClick());
    safeSetState(() {
      _selectedLabelId = _selectedLabelId == labelId ? null : labelId;
    });
  }

  Future<void> _onSlotTap(String hotspotId) async {
    final labelId = _selectedLabelId;
    if (labelId == null || _isAdvancing) return;
    await _onHotspotDrop(labelId, hotspotId);
    if (mounted) safeSetState(() => _selectedLabelId = null);
  }

  Future<void> _onOrderTap(String choiceId) async {
    if (_isAdvancing) return;
    final step = _currentStep;
    if (step == null) return;

    unawaited(_soundService.playClick());
    final expected = step.orderSequence;
    final nextIndex = _orderTapped.length;
    if (nextIndex >= expected.length || expected[nextIndex] != choiceId) {
    safeSetState(() {
        _flashWrongId = choiceId;
        _orderTapped.clear();
      });
      _onWrong();
      await Future.delayed(const Duration(milliseconds: 420));
      if (mounted) safeSetState(() => _flashWrongId = null);
      return;
    }

    safeSetState(() => _orderTapped.add(choiceId));
    if (_orderTapped.length == expected.length) {
      await _onStepSuccess();
    }
  }

  Future<void> _finishGame() async {
    _gameCompleted = true;
    await GameProgressService.clearProgress(widget.game.id);
    final timeTaken = _startTime != null
        ? DateTime.now().difference(_startTime!).inSeconds
        : null;
    final isPerfectScore = _wrongAttempts == 0;
    var bonusXP = 50;
    if (timeTaken != null && timeTaken < 120) bonusXP += 25;
    final totalXP = _xpEarned + bonusXP;
    final totalSteps = _steps.length;

    unawaited(
      GameStatsService.addGameResult(
        correctAnswers: totalSteps,
        totalQuestions: totalSteps,
        timeTakenSeconds: timeTaken ?? 0,
        isPerfectScore: isPerfectScore,
      ).catchError((e) {
        LogService.error('🎮 [PuzzlePieces] stats error: $e');
        return GameStats.empty();
      }),
    );

    unawaited(
      SkulMateService.saveGameSession(
        gameId: widget.game.id,
        score: _score,
        totalQuestions: totalSteps,
        correctAnswers: totalSteps,
        timeTakenSeconds: timeTaken,
        answers: {'steps': totalSteps, 'wrongAttempts': _wrongAttempts},
      ).catchError((e) {
        LogService.error('🎮 [PuzzlePieces] session error: $e');
      }),
    );

    unawaited(_soundService.playComplete());
    await GameAudioLifecycle.stopAll(tts: _ttsService, sound: _soundService);

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => GameResultsScreen(
            game: widget.game,
            score: _score,
            totalQuestions: totalSteps,
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
    if (_gameCompleted) {
      await SkulMateNavigation.popGame(context);
      return;
    }

    final quit = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Quit game?',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Your progress is saved. You can continue later from the game library.',
          style: GoogleFonts.plusJakartaSans(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep playing'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Quit'),
          ),
        ],
      ),
    );
    if (quit == true && mounted) {
      _isLeaving = true;
      await GameAudioLifecycle.stopAll(tts: _ttsService, sound: _soundService);
      await _persistProgress();
      if (!mounted) return;
      await SkulMateNavigation.popGame(context);
    }
  }

  void _openLearnMore() {
    final step = _currentStep;
    if (step == null) return;
    final explanation = step.explanation?.trim() ?? '';
    if (explanation.isEmpty && step.prompt.isEmpty) return;
    unawaited(_soundService.playClick());
    unawaited(
      showPuzzleLearnMoreSheet(
        context: context,
        term: widget.game.title,
        definition: explanation.isNotEmpty ? explanation : step.prompt,
        gameId: widget.game.id,
        ttsService: _ttsService,
        ttsEnabled: _isTTSEnabled,
      ),
    );
  }

  Future<void> _openGameSettings() async {
    await GameSettingsSheet.show(
      context: context,
      soundService: _soundService,
      gameType: widget.game.gameType,
      ttsService: _ttsService,
      isTTSEnabled: _isTTSEnabled,
      onTTSToggled: (v) => safeSetState(() => _isTTSEnabled = v),
    );
  }

  Widget _buildInteractionArea(SkulMateCopy copy) {
    final step = _currentStep;
    if (step == null || _showCompletionAnimation) {
      return PuzzleCompletionPathAnimation(nodeCount: _steps.length);
    }

    switch (step.type) {
      case PuzzleStepType.hotspotDrop:
        if (step.hotspots.isEmpty) {
          return _buildChoiceList(
            step.choices.map((c) => (id: c.id, text: c.text)).toList(),
          );
        }
        return PuzzleSlotMatchBoard(
          slots: step.hotspots
              .map((h) => (id: h.id, hint: h.label))
              .toList(),
          labels: step.dragLabels
              .map((l) => (id: l.id, text: l.text))
              .toList(),
          filledSlots: Map.from(_filledHotspots),
          selectedLabelId: _selectedLabelId,
          flashWrongId: _flashWrongId,
          disabled: _isAdvancing,
          onLabelTap: _onLabelSelect,
          onSlotTap: (slotId) => unawaited(_onSlotTap(slotId)),
        );
      case PuzzleStepType.orderCheck:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_orderTapped.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  copy.puzzleOrderProgress(_orderTapped.length, step.orderSequence.length),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textMedium,
                  ),
                ),
              ),
            PuzzleOrderTapBoard(
              choices: step.choices.map((c) => (id: c.id, text: c.text)).toList(),
              orderSequence: step.orderSequence,
              tappedOrder: _orderTapped,
              flashWrongId: _flashWrongId,
              disabled: _isAdvancing,
              onTap: (id) => unawaited(_onOrderTap(id)),
            ),
          ],
        );
      case PuzzleStepType.pickOne:
        return _buildChoiceList(
          step.choices.map((c) => (id: c.id, text: c.text)).toList(),
        );
    }
  }

  Widget _buildChoiceList(List<({String id, String text})> choices) {
    if (choices.length <= 3) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: choices
            .map(
              (c) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: PuzzleConceptTile(
                  text: c.text,
                  fullWidth: true,
                  isWrongFlash: _flashWrongId == c.id,
                  disabled: _isAdvancing,
                  onTap: () => unawaited(_onPickOne(c.id)),
                ),
              ),
            )
            .toList(),
      );
    }
    return PuzzleChoiceGrid(
      choices: choices,
      flashWrongId: _flashWrongId,
      disabled: _isAdvancing,
      onTap: (id) => unawaited(_onPickOne(id)),
    );
  }

  @override
  void dispose() {
    _isLeaving = true;
    unawaited(_persistProgress());
    unawaited(GameAudioLifecycle.stopAll(tts: _ttsService, sound: _soundService));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final copy = SkulMateCopy.of(context);
    final total = _steps.length;
    final step = _currentStep;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_handleBack());
      },
      child: Scaffold(
      backgroundColor: AppTheme.softBackground,
      appBar: SkulMateGameAppBar(
          light: true,
        title: widget.game.title,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => unawaited(_handleBack()),
          ),
        actions: [
          Padding(
              padding: const EdgeInsets.only(right: 4),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => unawaited(_openGameSettings()),
            child: CircleAvatar(
              radius: 16,
                  backgroundColor:
                      AppTheme.primaryColor.withValues(alpha: 0.08),
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
                    progressText: copy.puzzleProgressText(
                      _currentStepIndex,
                      total,
                    ),
                    progressValue: _progressValue,
              xpEarned: _xpEarned,
                    gameType: GameType.puzzlePieces,
            ),
          ),
          Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                        PuzzleQuestTrail(
                          total: total,
                          currentIndex: _currentStepIndex,
                          completedCount: _currentStepIndex,
                        ),
                        const SizedBox(height: 16),
                        if (step != null)
                          PuzzleStepFocusCard(
                            stepNumber: _currentStepIndex + 1,
                            total: total,
                            prompt: _questionPrompt,
                            stepKindLabel: _stepKindLabel(copy, step),
                          ),
                        if (step?.explanation?.isNotEmpty == true ||
                            step?.prompt.isNotEmpty == true)
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              onPressed: _openLearnMore,
                              icon: const Icon(Icons.lightbulb_outline_rounded, size: 18),
                              label: Text(copy.puzzleWhyLabel),
                              style: TextButton.styleFrom(
                                foregroundColor: AppTheme.primaryColor,
                              ),
                            ),
                          ),
                        if (_feedbackMessage.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          GameFeedbackBanner(
                            tone: _feedbackTone,
                            message: _feedbackMessage,
                          ),
                        ],
                        const SizedBox(height: 16),
                        if (step != null &&
                            step.type != PuzzleStepType.hotspotDrop)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Text(
                              copy.puzzlePickFromBelow,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textMedium,
                              ),
                            ),
                          ),
                        _buildInteractionArea(copy),
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
            GameXpPopup(amount: _lastXpBurst, visible: _xpPopupVisible),
          ],
        ),
      ),
    );
  }
}
