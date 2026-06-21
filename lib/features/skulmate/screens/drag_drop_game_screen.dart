import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/core/utils/safe_set_state.dart';
import '../models/game_model.dart';
import '../widgets/game_rules_overlay.dart';
import '../widgets/skulmate_game_app_bar.dart';
import '../widgets/skulmate_profile_avatar.dart';
import '../widgets/drag_drop_question_widget.dart';
import '../widgets/game_standard_widgets.dart';
import '../widgets/skulmate_mascot_media_widget.dart';
import '../widgets/skulmate_companion_banner.dart';
import '../services/game_progress_service.dart';
import '../widgets/game_settings_sheet.dart';
import '../services/game_sound_service.dart';
import 'game_results_screen.dart';

/// Drag and drop game screen
class DragDropGameScreen extends StatefulWidget {
  final GameModel game;
  final GameProgress? resumeFrom;

  const DragDropGameScreen({
    Key? key,
    required this.game,
    this.resumeFrom,
  }) : super(key: key);

  @override
  State<DragDropGameScreen> createState() => _DragDropGameScreenState();
}

class _DragDropGameScreenState extends State<DragDropGameScreen> {
  late final List<GameItem> _questions;
  int _currentQuestionIndex = 0;
  int _score = 0;
  int _xpEarned = 0;
  DateTime? _startTime;
  final GameSoundService _soundService = GameSoundService();
  final Map<String, int> _assignments = {};
  bool _showFeedback = false;
  bool _gameCompleted = false;

  @override
  void initState() {
    super.initState();
    _questions = widget.game.items
        .where(
          (item) =>
              (item.dragItems ?? []).isNotEmpty &&
              (item.dropZones ?? []).isNotEmpty,
        )
        .toList();
    if (widget.resumeFrom != null && _questions.isNotEmpty) {
      _currentQuestionIndex = widget.resumeFrom!.currentIndex
          .clamp(0, _questions.length - 1);
      _score = widget.resumeFrom!.score;
    }
    _startTime = DateTime.now();
    _soundService.initialize();
    unawaited(_soundService.playMusicForGame(widget.game.gameType));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        GameRulesOverlay.showIfNeeded(
          context,
          GameType.dragDrop,
          (_) async {},
        );
      }
    });
  }

  void _openGameSettingsSheet() {
    GameSettingsSheet.show(
      context: context,
      soundService: _soundService,
      gameType: widget.game.gameType,
      musicGameTypeOverride: widget.game.gameType,
    );
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
    unawaited(_persistProgress());
    unawaited(_soundService.stopMusic(force: true));
    super.dispose();
  }

  void _submitCurrent() {
    if (_showFeedback || _questions.isEmpty) return;
    final question = _questions[_currentQuestionIndex];
    final items = question.dragItems ?? [];
    final zones = question.dropZones ?? [];
    if (_assignments.length < zones.length) {
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
      dragItems: items,
      dropZones: zones,
      assignments: _assignments,
    );

    safeSetState(() {
      _showFeedback = true;
      if (isCorrect) {
        _score++;
        _xpEarned += 12;
      }
    });

    if (isCorrect) {
      _soundService.playCorrect();
    } else {
      _soundService.playIncorrect();
    }
  }

  String _mappingText(GameItem question) {
    return DragDropQuestionWidget.buildMappingText(question.dragItems ?? const []);
  }

  int _remainingWords(List<Map<String, dynamic>> dragItems) {
    return (dragItems.length - _assignments.length).clamp(0, 999);
  }

  void _nextOrFinish() {
    _soundService.playClick();
    if (_currentQuestionIndex < _questions.length - 1) {
      safeSetState(() {
        _currentQuestionIndex++;
        _assignments.clear();
        _showFeedback = false;
      });
      return;
    }
    _gameCompleted = true;
    unawaited(GameProgressService.clearProgress(widget.game.id));
    final duration = DateTime.now().difference(_startTime!).inSeconds;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => GameResultsScreen(
          game: widget.game,
          score: _score,
          totalQuestions: _questions.length,
          timeTakenSeconds: duration,
          xpEarned: _xpEarned,
          isPerfectScore: _score == _questions.length,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_questions.isEmpty) {
      return Scaffold(
        backgroundColor: AppTheme.softBackground,
        appBar: SkulMateGameAppBar(
          title: widget.game.title.isNotEmpty ? widget.game.title : 'Drag & Drop',
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'No drag and drop content found in this game.',
              style: GoogleFonts.poppins(fontSize: 14, color: AppTheme.textMedium),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final question = _questions[_currentQuestionIndex];
    final dragItems = question.dragItems ?? [];
    final dropZones = question.dropZones ?? [];

    return Scaffold(
      backgroundColor: AppTheme.softBackground,
      appBar: SkulMateGameAppBar(
        title: widget.game.title.isNotEmpty ? widget.game.title : 'Drag & Drop',
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
          )
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
              child: GameStandardsHud(
                progressText:
                    'Question ${_currentQuestionIndex + 1} of ${_questions.length}',
                progressValue:
                    (_currentQuestionIndex + 1) / (_questions.isEmpty ? 1 : _questions.length),
                xpEarned: _xpEarned,
                gameType: widget.game.gameType,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 4),
                  FlatStageCard(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    radius: 16,
                    backgroundColor: Colors.white,
                    borderColor: AppTheme.softBorder,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 44,
                          height: 44,
                          child: const SkulMateMascotMediaWidget(
                            state: SkulMateMascotState.encouraging,
                            useLandscapeFrame: false,
                            borderRadius: 999,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Drag the missing pieces of the definition into the correct spots. You\'ve got this, Scholar.',
                            style: GoogleFonts.poppins(
                              fontSize: 13.5,
                              height: 1.4,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.textDark,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  FlatStageCard(
                    padding: const EdgeInsets.all(16),
                    radius: 20,
                    backgroundColor: const Color(0xFFF3F6FC),
                    borderColor: const Color(0xFFE4EAF5),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ((question.question ?? '').trim().isEmpty
                                  ? 'Concept Builder'
                                  : (question.question ?? ''))
                              .trim(),
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF223A64),
                          ),
                        ),
                        const SizedBox(height: 10),
                        DragDropQuestionWidget(
                          dragItems: dragItems,
                          dropZones: dropZones,
                          assignments: _assignments,
                          showCorrection: _showFeedback,
                          instructionText: '',
                          onAssignmentsChanged: (next) {
                            safeSetState(() {
                              _assignments
                                ..clear()
                                ..addAll(next);
                            });
                          },
                          onDragStart: () => unawaited(_soundService.playClick()),
                          onDrop: () => unawaited(_soundService.playClick()),
                          onClearZone: () => unawaited(_soundService.playClick()),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'VOCABULARY POOL',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          letterSpacing: 1.1,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textMedium,
                        ),
                      ),
                      Text(
                        '${_remainingWords(dragItems)} WORDS LEFT',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          letterSpacing: 1.0,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0EA5E9),
                        ),
                      ),
                    ],
                  ),
                  if (_showFeedback) ...[
                    const SizedBox(height: 6),
                    FlatStageCard(
                      padding: const EdgeInsets.all(14),
                      backgroundColor: AppTheme.accentLightGreen.withOpacity(0.5),
                      borderColor: AppTheme.accentGreen,
                      child: Text(
                        _mappingText(question),
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primaryColor,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  GameStandardsPrimaryButton(
                    label: _showFeedback ? 'Next' : 'Check Answer',
                    onPressed: _showFeedback ? _nextOrFinish : _submitCurrent,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
