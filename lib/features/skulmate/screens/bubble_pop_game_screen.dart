import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/core/utils/safe_set_state.dart';
import '../models/game_model.dart';
import '../models/skulmate_character_model.dart';
import '../widgets/skulmate_game_app_bar.dart';
import '../widgets/skulmate_character_widget.dart';
import '../services/character_selection_service.dart';
import '../services/game_sound_service.dart';
import '../services/game_stats_service.dart';
import '../widgets/game_standard_widgets.dart';
import 'game_results_screen.dart';

/// Bubble pop game screen
class BubblePopGameScreen extends StatefulWidget {
  final GameModel game;

  const BubblePopGameScreen({Key? key, required this.game}) : super(key: key);

  @override
  State<BubblePopGameScreen> createState() => _BubblePopGameScreenState();
}

class _BubblePopGameScreenState extends State<BubblePopGameScreen> {
  final GameSoundService _soundService = GameSoundService();
  final List<_BubbleItem> _bubbles = [];
  DateTime _startTime = DateTime.now();
  int _targetTotal = 0;
  int _score = 0;
  int _xpEarned = 0;
  dynamic _character;

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();
    _soundService.initialize();
    unawaited(_soundService.playMusicForGame(widget.game.gameType));
    _buildBubbles();
    _loadCharacter();
  }

  void _buildBubbles() {
    final first = widget.game.items.isNotEmpty ? widget.game.items.first : null;
    final raw = first?.bubbles ?? <Map<String, dynamic>>[];
    if (raw.isNotEmpty) {
      for (final bubble in raw) {
        final text = (bubble['text'] ?? bubble['label'] ?? '').toString().trim();
        if (text.isEmpty) continue;
        _bubbles.add(
          _BubbleItem(
            text: text,
            isTarget: bubble['isTarget'] == true || bubble['is_target'] == true,
          ),
        );
      }
    }

    if (_bubbles.isEmpty) {
      final words = (first?.words ?? <String>[]).where((w) => w.trim().isNotEmpty);
      for (final word in words) {
        _bubbles.add(_BubbleItem(text: word.trim(), isTarget: true));
      }
    }
    if (_bubbles.isEmpty) {
      _bubbles.addAll([
        _BubbleItem(text: 'Key term', isTarget: true),
        _BubbleItem(text: 'Concept', isTarget: true),
        _BubbleItem(text: 'Distractor', isTarget: false),
        _BubbleItem(text: 'Wrong one', isTarget: false),
      ]);
    }
    if (_bubbles.where((b) => b.isTarget).isEmpty) {
      for (var i = 0; i < _bubbles.length; i++) {
        _bubbles[i] = _BubbleItem(text: _bubbles[i].text, isTarget: i.isEven);
      }
    }
    _targetTotal = _bubbles.where((b) => b.isTarget).length;
    _bubbles.shuffle(Random());
  }

  Future<void> _loadCharacter() async {
    final character = await CharacterSelectionService.getSelectedCharacter();
    if (mounted) safeSetState(() => _character = character);
  }

  @override
  void dispose() {
    unawaited(_soundService.stopMusic(force: true));
    super.dispose();
  }

  void _onPop(int index) {
    final bubble = _bubbles[index];
    if (bubble.popped) return;
    safeSetState(() => _bubbles[index] = bubble.copyWith(popped: true));
    if (bubble.isTarget) {
      _score++;
      _xpEarned += 10;
      _soundService.playPop();
    } else {
      _xpEarned = (_xpEarned - 2).clamp(0, 99999);
      _soundService.playIncorrect();
    }
    final foundTargets = _bubbles.where((b) => b.isTarget && b.popped).length;
    if (foundTargets >= _targetTotal) {
      _finishGame();
    }
  }

  Future<void> _finishGame() async {
    final seconds = DateTime.now().difference(_startTime).inSeconds;
    final isPerfect = _score >= _targetTotal;
    _xpEarned += 30;
    unawaited(_soundService.playComplete());
    unawaited(() async {
      try {
        await GameStatsService.addGameResult(
          correctAnswers: _score,
          totalQuestions: _targetTotal,
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
          totalQuestions: _targetTotal,
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
        title: widget.game.title.isNotEmpty ? widget.game.title : 'Bubble Pop',
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Center(
              child: const SkulMateCharacterWidget(
                character: SkulMateCharacters.middleMale,
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
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            child: GameStandardsHud(
              progressText: 'Targets: $_score / $_targetTotal',
              progressValue: _targetTotal == 0 ? 0 : _score / _targetTotal,
              xpEarned: _xpEarned,
              gameType: widget.game.gameType,
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: GameStandardsTipCard(
              text: 'Pop the correct bubbles. Wrong bubbles reduce XP.',
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _bubbles.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1,
              ),
              itemBuilder: (context, index) {
                final bubble = _bubbles[index];
                final color = bubble.popped
                    ? Colors.grey.shade300
                    : (bubble.isTarget ? AppTheme.primaryColor : Colors.orange.shade400);
                return InkWell(
                  onTap: bubble.popped ? null : () => _onPop(index),
                  borderRadius: BorderRadius.circular(999),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color,
                      boxShadow: [
                        BoxShadow(
                          color: color.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text(
                          bubble.popped ? '✓' : bubble.text,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
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

class _BubbleItem {
  final String text;
  final bool isTarget;
  final bool popped;

  const _BubbleItem({
    required this.text,
    required this.isTarget,
    this.popped = false,
  });

  _BubbleItem copyWith({String? text, bool? isTarget, bool? popped}) {
    return _BubbleItem(
      text: text ?? this.text,
      isTarget: isTarget ?? this.isTarget,
      popped: popped ?? this.popped,
    );
  }
}
