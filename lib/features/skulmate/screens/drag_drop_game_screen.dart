import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/core/utils/safe_set_state.dart';
import '../models/game_model.dart';
import '../widgets/game_rules_overlay.dart';
import '../widgets/skulmate_game_app_bar.dart';
import '../widgets/skulmate_character_widget.dart';
import '../widgets/drag_drop_question_widget.dart';
import '../widgets/game_standard_widgets.dart';
import '../services/character_selection_service.dart';
import '../services/game_sound_service.dart';
import 'game_results_screen.dart';

/// Drag and drop game screen
class DragDropGameScreen extends StatefulWidget {
  final GameModel game;

  const DragDropGameScreen({Key? key, required this.game}) : super(key: key);

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
  dynamic _character;

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
    _startTime = DateTime.now();
    _soundService.initialize();
    unawaited(_soundService.playMusicForGame(widget.game.gameType));
    _loadCharacter();
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

  Future<void> _loadCharacter() async {
    final character = await CharacterSelectionService.getSelectedCharacter();
    if (mounted) setState(() => _character = character);
  }

  @override
  void dispose() {
    unawaited(_soundService.stopMusic());
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
          if (_character != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Center(
                child: SkulMateCharacterWidget(
                  character: _character,
                  size: 40,
                  animated: false,
                  showName: false,
                ),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GameStandardsHud(
              progressText:
                  'Question ${_currentQuestionIndex + 1} of ${_questions.length}',
              progressValue:
                  (_currentQuestionIndex + 1) / (_questions.isEmpty ? 1 : _questions.length),
              xpEarned: _xpEarned,
              gameType: widget.game.gameType,
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: GameStandardsTipCard(
                text: 'Drag each item into the right zone, then submit.',
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.softBorder),
              ),
              child: Text(
                (question.question ?? '').trim().isEmpty
                    ? 'Match each item to its correct zone.'
                    : (question.question ?? ''),
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textDark,
                ),
              ),
            ),
            const SizedBox(height: 12),
            DragDropQuestionWidget(
              dragItems: dragItems,
              dropZones: dropZones,
              assignments: _assignments,
              showCorrection: _showFeedback,
              onAssignmentsChanged: (next) {
                safeSetState(() {
                  _assignments
                    ..clear()
                    ..addAll(next);
                });
              },
            ),
            if (_showFeedback) ...[
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.accentLightGreen.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.accentGreen),
                ),
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
              label: _showFeedback ? 'Next' : 'Submit answer',
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
