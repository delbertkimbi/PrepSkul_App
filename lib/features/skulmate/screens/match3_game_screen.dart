import 'dart:async';
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

/// Match-3 game screen (like Candy Crush)
class Match3GameScreen extends StatefulWidget {
  final GameModel game;

  const Match3GameScreen({Key? key, required this.game}) : super(key: key);

  @override
  State<Match3GameScreen> createState() => _Match3GameScreenState();
}

class _Match3GameScreenState extends State<Match3GameScreen> {
  final GameSoundService _soundService = GameSoundService();
  final Set<int> _removed = {};
  final List<int> _selected = [];
  final List<String> _tiles = [];
  DateTime _startTime = DateTime.now();
  int _score = 0; // successful matches
  int _xpEarned = 0;
  int _targetMatches = 1;
  dynamic _character;

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();
    _soundService.initialize();
    unawaited(_soundService.playMusicForGame(widget.game.gameType));
    _buildTiles();
    _loadCharacter();
  }

  void _buildTiles() {
    final item = widget.game.items.isNotEmpty ? widget.game.items.first : null;
    final flatFromGrid = <String>[];
    if (item?.gridData != null) {
      for (final row in item!.gridData!) {
        for (final cell in row) {
          final v = cell.trim();
          if (v.isNotEmpty) flatFromGrid.add(v);
        }
      }
    }
    final source = flatFromGrid.isNotEmpty
        ? flatFromGrid
        : ((item?.words ?? <String>[]).where((w) => w.trim().isNotEmpty).toList());
    final normalized = source.isNotEmpty ? source : <String>['A', 'A', 'A', 'B', 'B', 'B', 'C', 'C', 'C'];
    while (normalized.length < 9) {
      normalized.add(normalized[normalized.length % 3]);
    }
    normalized.shuffle();
    _tiles
      ..clear()
      ..addAll(normalized);
    _targetMatches = (_tiles.length / 3).floor().clamp(1, 1000);
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

  void _onTapTile(int index) {
    if (_removed.contains(index) || _selected.contains(index)) return;
    _soundService.playClick();
    safeSetState(() => _selected.add(index));
    if (_selected.length < 3) return;

    final a = _tiles[_selected[0]].toLowerCase();
    final b = _tiles[_selected[1]].toLowerCase();
    final c = _tiles[_selected[2]].toLowerCase();
    final matched = a == b && b == c;
    if (matched) {
      safeSetState(() {
        _removed.addAll(_selected);
        _selected.clear();
        _score++;
        _xpEarned += 12;
      });
      _soundService.playMatch();
      if (_removed.length >= _tiles.length) {
        _finishGame();
      }
      return;
    }

    _soundService.playIncorrect();
    Future.delayed(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      safeSetState(() => _selected.clear());
    });
  }

  Future<void> _finishGame() async {
    final seconds = DateTime.now().difference(_startTime).inSeconds;
    final isPerfect = _removed.length >= _tiles.length;
    _xpEarned += 35;
    unawaited(_soundService.playComplete());
    unawaited(() async {
      try {
        await GameStatsService.addGameResult(
          correctAnswers: _score,
          totalQuestions: _targetMatches,
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
          totalQuestions: _targetMatches,
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
      appBar: SkulMateGameAppBar(
        title: widget.game.title.isNotEmpty ? widget.game.title : 'Match-3',
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
      body: Center(
        child: Column(
          children: [
            GameStandardsHud(
              progressText: 'Matches: $_score / $_targetMatches',
              progressValue: _targetMatches == 0 ? 0 : _score / _targetMatches,
              xpEarned: _xpEarned,
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GameStandardsTipCard(
                text: 'Tap three identical tiles to clear a match.',
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: GridView.builder(
                  itemCount: _tiles.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemBuilder: (context, index) {
                    final removed = _removed.contains(index);
                    final selected = _selected.contains(index);
                    return InkWell(
                      onTap: removed ? null : () => _onTapTile(index),
                      borderRadius: BorderRadius.circular(12),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        decoration: BoxDecoration(
                          color: removed
                              ? Colors.grey.shade200
                              : (selected ? AppTheme.primaryColor : Colors.white),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: selected ? AppTheme.primaryColor : AppTheme.softBorder,
                            width: 2,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            removed ? '✓' : _tiles[index],
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: selected ? Colors.white : AppTheme.textDark,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: GameStandardsPrimaryButton(
                label: 'Finish Game',
                onPressed: _finishGame,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
