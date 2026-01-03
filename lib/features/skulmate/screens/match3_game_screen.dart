import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import '../models/game_model.dart';
import 'game_results_screen.dart';

/// Match-3 game screen (like Candy Crush)
class Match3GameScreen extends StatefulWidget {
  final GameModel game;

  const Match3GameScreen({Key? key, required this.game}) : super(key: key);

  @override
  State<Match3GameScreen> createState() => _Match3GameScreenState();
}

class _Match3GameScreenState extends State<Match3GameScreen> {
  int _score = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Match-3 Game', style: GoogleFonts.poppins()),
        backgroundColor: AppTheme.primaryColor,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Match-3 Game',
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
