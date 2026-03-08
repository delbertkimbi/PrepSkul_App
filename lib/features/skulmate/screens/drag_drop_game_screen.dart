import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import '../models/game_model.dart';
import '../widgets/game_rules_overlay.dart';
import '../widgets/skulmate_game_app_bar.dart';
import 'game_results_screen.dart';

/// Drag and drop game screen
class DragDropGameScreen extends StatefulWidget {
  final GameModel game;

  const DragDropGameScreen({Key? key, required this.game}) : super(key: key);

  @override
  State<DragDropGameScreen> createState() => _DragDropGameScreenState();
}

class _DragDropGameScreenState extends State<DragDropGameScreen> {
  int _score = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        GameRulesOverlay.showIfNeeded(
          context,
          GameType.dragDrop,
          () {},
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.softBackground,
      appBar: SkulMateGameAppBar(title: widget.game.title.isNotEmpty ? widget.game.title : 'Drag & Drop'),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.touch_app_outlined, size: 64, color: AppTheme.textMedium),
              const SizedBox(height: 24),
              Text(
                'Drag & Drop',
                style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.textDark),
              ),
              const SizedBox(height: 12),
              Text(
                'Implementation coming soon. Use Quiz or Flashcards for now.',
                style: GoogleFonts.poppins(fontSize: 14, color: AppTheme.textMedium),
                textAlign: TextAlign.center,
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
                child: const Text('Finish Game'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
