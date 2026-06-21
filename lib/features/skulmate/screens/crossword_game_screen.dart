import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/core/utils/safe_set_state.dart';
import '../models/game_model.dart';
import '../widgets/skulmate_game_app_bar.dart';
import '../widgets/skulmate_profile_avatar.dart';
import '../services/game_sound_service.dart';
import '../services/game_stats_service.dart';
import '../widgets/game_standard_widgets.dart';
import '../widgets/skulmate_mascot_media_widget.dart';
import '../widgets/skulmate_companion_banner.dart';
import 'game_results_screen.dart';

/// Crossword game screen
class CrosswordGameScreen extends StatefulWidget {
  final GameModel game;

  const CrosswordGameScreen({Key? key, required this.game}) : super(key: key);

  @override
  State<CrosswordGameScreen> createState() => _CrosswordGameScreenState();
}

class _CrosswordGameScreenState extends State<CrosswordGameScreen> {
  final GameSoundService _soundService = GameSoundService();
  final Set<int> _solved = {};
  final List<_CrosswordClue> _clues = [];
  final Map<int, TextEditingController> _controllers = {};
  DateTime _startTime = DateTime.now();
  int _score = 0;
  int _xpEarned = 0;

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();
    _soundService.initialize();
    unawaited(_soundService.playMusicForGame(widget.game.gameType));
    _buildClues();
  }

  void _buildClues() {
    final item = widget.game.items.isNotEmpty ? widget.game.items.first : null;
    final raw = item?.clues ?? <Map<String, dynamic>>[];
    if (raw.isNotEmpty) {
      for (final c in raw) {
        final clue = (c['clue'] ?? c['question'] ?? '').toString().trim();
        final answer = (c['answer'] ?? c['solution'] ?? '').toString().trim();
        if (clue.isEmpty || answer.isEmpty) continue;
        _clues.add(_CrosswordClue(clue: clue, answer: answer.toUpperCase()));
      }
    }
    if (_clues.isEmpty) {
      for (final i in widget.game.items) {
        final clue = (i.question ?? '').trim();
        final answer = (i.correctAnswer ?? '').toString().trim();
        if (clue.isEmpty || answer.isEmpty) continue;
        _clues.add(_CrosswordClue(clue: clue, answer: answer.toUpperCase()));
      }
    }
    if (_clues.isEmpty) {
      _clues.addAll(const [
        _CrosswordClue(clue: 'Learning platform name', answer: 'SKULMATE'),
        _CrosswordClue(clue: 'What we gain from studying', answer: 'KNOWLEDGE'),
      ]);
    }
    for (var i = 0; i < _clues.length; i++) {
      _controllers[i] = TextEditingController();
    }
  }

  @override
  void dispose() {
    unawaited(_soundService.stopMusic(force: true));
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _checkAnswer(int index) {
    if (_solved.contains(index)) return;
    final typed = _controllers[index]?.text.trim().toUpperCase() ?? '';
    final correct = _clues[index].answer.toUpperCase();
    if (typed.isEmpty) return;
    if (typed == correct) {
      safeSetState(() {
        _solved.add(index);
        _score = _solved.length;
        _xpEarned += 12;
      });
      _soundService.playCorrect();
      if (_solved.length >= _clues.length) {
        _finishGame();
      }
    } else {
      _soundService.playIncorrect();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Not quite, try again.',
            style: GoogleFonts.poppins(fontSize: 13),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _finishGame() async {
    final seconds = DateTime.now().difference(_startTime).inSeconds;
    final isPerfect = _score >= _clues.length;
    _xpEarned += 30;
    unawaited(_soundService.playComplete());
    unawaited(() async {
      try {
        await GameStatsService.addGameResult(
          correctAnswers: _score,
          totalQuestions: _clues.length,
          timeTakenSeconds: seconds,
          isPerfectScore: isPerfect,
        );
      } catch (_) {}
    }());
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => GameResultsScreen(
          game: widget.game,
          score: _score,
          totalQuestions: _clues.length,
          timeTakenSeconds: seconds,
          xpEarned: _xpEarned,
          isPerfectScore: isPerfect,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.softBackground,
      appBar: SkulMateGameAppBar(
        title: widget.game.title.isNotEmpty ? widget.game.title : 'Crossword',
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Center(
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
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            child: GameStandardsHud(
              progressText: 'Solved: $_score / ${_clues.length}',
              progressValue: _clues.isEmpty ? 0 : _score / _clues.length,
              xpEarned: _xpEarned,
              gameType: widget.game.gameType,
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: SkulMateCompanionBanner(
              message: 'Use hint-style thinking: solve clue by clue and verify each word.',
              tone: CompanionTone.tip,
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _clues.length,
              itemBuilder: (context, index) {
                final solved = _solved.contains(index);
                final controller = _controllers[index]!;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: FlatStageCard(
                    backgroundColor: Colors.white,
                    borderColor: solved ? AppTheme.accentGreen : AppTheme.softBorder,
                    radius: 14,
                    padding: const EdgeInsets.all(12),
                    child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${index + 1}. ${_clues[index].clue}',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textDark,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: controller,
                              enabled: !solved,
                              decoration: InputDecoration(
                                hintText: 'Answer',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 10,
                                ),
                              ),
                              onSubmitted: (_) => _checkAnswer(index),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: solved ? null : () => _checkAnswer(index),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryColor,
                              foregroundColor: Colors.white,
                            ),
                            child: Text(solved ? 'Done' : 'Check'),
                          ),
                        ],
                      ),
                    ],
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: SizedBox(
              width: double.infinity,
              child: GameStandardsPrimaryButton(
                label: 'Finish Game',
                onPressed: _finishGame,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CrosswordClue {
  final String clue;
  final String answer;
  const _CrosswordClue({required this.clue, required this.answer});
}
