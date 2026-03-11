import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import '../models/game_model.dart';
import '../widgets/skulmate_game_app_bar.dart';
import '../widgets/skulmate_character_widget.dart';
import '../services/character_selection_service.dart';
import 'game_results_screen.dart';

/// Bubble pop game screen
class BubblePopGameScreen extends StatefulWidget {
  final GameModel game;

  const BubblePopGameScreen({Key? key, required this.game}) : super(key: key);

  @override
  State<BubblePopGameScreen> createState() => _BubblePopGameScreenState();
}

class _BubblePopGameScreenState extends State<BubblePopGameScreen> {
  int _score = 0;
  dynamic _character;

  @override
  void initState() {
    super.initState();
    _loadCharacter();
  }

  Future<void> _loadCharacter() async {
    final character = await CharacterSelectionService.getSelectedCharacter();
    if (mounted) setState(() => _character = character);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.softBackground,
      appBar: SkulMateGameAppBar(
        title: widget.game.title.isNotEmpty ? widget.game.title : 'Bubble Pop',
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
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Bubble Pop Game',
              style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.textDark),
            ),
            const SizedBox(height: 16),
            Text(
              'Implementation coming soon',
              style: GoogleFonts.poppins(fontSize: 14, color: AppTheme.textMedium),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => GameResultsScreen(
                      game: widget.game,
                      score: _score,
                      totalQuestions: widget.game.items.length,
                    ),
                  ),
                );
              },
              child: Text('Finish Game'),
            ),
          ],
        ),
      ),
    );
  }
}
