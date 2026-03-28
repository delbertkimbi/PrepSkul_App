import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/core/utils/safe_set_state.dart';
import '../models/game_model.dart';
import '../widgets/skulmate_game_app_bar.dart';
import '../widgets/skulmate_character_widget.dart';
import '../services/character_selection_service.dart';
import '../services/game_sound_service.dart';
import '../services/game_stats_service.dart';
import '../widgets/game_standard_widgets.dart';
import 'game_results_screen.dart';

/// Word search game screen
class WordSearchGameScreen extends StatefulWidget {
  final GameModel game;

  const WordSearchGameScreen({Key? key, required this.game}) : super(key: key);

  @override
  State<WordSearchGameScreen> createState() => _WordSearchGameScreenState();
}

class _WordSearchGameScreenState extends State<WordSearchGameScreen> {
  final GameSoundService _soundService = GameSoundService();
  final Set<String> _found = {};
  final List<String> _words = [];
  final List<List<String>> _grid = [];
  DateTime _startTime = DateTime.now();
  int _score = 0;
  int _xpEarned = 0;
  dynamic _character;

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();
    _soundService.initialize();
    unawaited(_soundService.playMusicForGame(widget.game.gameType));
    _buildData();
    _loadCharacter();
  }

  void _buildData() {
    final item = widget.game.items.isNotEmpty ? widget.game.items.first : null;
    final words = (item?.words ?? <String>[])
        .map((w) => w.trim().toUpperCase())
        .where((w) => w.isNotEmpty)
        .toList();
    _words.addAll(words.isNotEmpty ? words : <String>['LEARN', 'SMART', 'SKULMATE']);

    if ((item?.gridData ?? []).isNotEmpty) {
      _grid.addAll(
        item!.gridData!
            .map((row) => row.map((c) => c.toUpperCase()).toList())
            .toList(),
      );
      return;
    }

    final size = 8;
    final rand = Random();
    const letters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    for (var r = 0; r < size; r++) {
      final row = <String>[];
      for (var c = 0; c < size; c++) {
        row.add(letters[rand.nextInt(letters.length)]);
      }
      _grid.add(row);
    }
    // Put words horizontally where they fit.
    for (var i = 0; i < _words.length; i++) {
      final w = _words[i];
      if (w.length > size) continue;
      final row = i % size;
      final start = (i * 2) % (size - w.length + 1);
      for (var j = 0; j < w.length; j++) {
        _grid[row][start + j] = w[j];
      }
    }
  }

  Future<void> _loadCharacter() async {
    final character = await CharacterSelectionService.getSelectedCharacter();
    if (mounted) safeSetState(() => _character = character);
  }

  @override
  void dispose() {
    unawaited(_soundService.stopMusic());
    super.dispose();
  }

  void _toggleFound(String word) {
    if (_found.contains(word)) return;
    safeSetState(() {
      _found.add(word);
      _score = _found.length;
      _xpEarned += 10;
    });
    _soundService.playWordFound();
    if (_found.length >= _words.length) {
      _finishGame();
    }
  }

  Future<void> _finishGame() async {
    final seconds = DateTime.now().difference(_startTime).inSeconds;
    final isPerfect = _score >= _words.length;
    _xpEarned += 25;
    unawaited(_soundService.playComplete());
    unawaited(() async {
      try {
        await GameStatsService.addGameResult(
          correctAnswers: _score,
          totalQuestions: _words.length,
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
          totalQuestions: _words.length,
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
        title: widget.game.title.isNotEmpty ? widget.game.title : 'Word Search',
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
      body: Column(
        children: [
          GameStandardsHud(
            progressText: 'Found: $_score / ${_words.length}',
            progressValue: _words.isEmpty ? 0 : _score / _words.length,
            xpEarned: _xpEarned,
            gameType: widget.game.gameType,
          ),
          const SizedBox(height: 10),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.softBorder),
                    ),
                    child: Column(
                      children: _grid
                          .map(
                            (row) => Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: row
                                  .map(
                                    (c) => Container(
                                      width: 26,
                                      height: 26,
                                      margin: const EdgeInsets.all(2),
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: AppTheme.primaryColor.withOpacity(0.08),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        c,
                                        style: GoogleFonts.poppins(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: GameStandardsTipCard(
                      text: 'Tap a word when you find it:',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _words.map((word) {
                      final found = _found.contains(word);
                      return FilterChip(
                        selected: found,
                        label: Text(word, style: GoogleFonts.poppins(fontSize: 12)),
                        onSelected: (_) => _toggleFound(word),
                        selectedColor: AppTheme.primaryColor.withOpacity(0.18),
                        checkmarkColor: AppTheme.primaryColor,
                      );
                    }).toList(),
                  ),
                ],
              ),
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
