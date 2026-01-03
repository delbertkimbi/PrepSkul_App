import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import '../models/game_model.dart';
import 'game_results_screen.dart';

/// Crossword game screen
class CrosswordGameScreen extends StatefulWidget {
  final GameModel game;

  const CrosswordGameScreen({Key? key, required this.game}) : super(key: key);

  @override
  State<CrosswordGameScreen> createState() => _CrosswordGameScreenState();
}

class _CrosswordGameScreenState extends State<CrosswordGameScreen> {
  int _score = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Crossword', style: GoogleFonts.poppins()),
        backgroundColor: AppTheme.primaryColor,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Crossword Game',
              style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Text(
              'Implementation coming soon',
              style: GoogleFonts.poppins(),
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
