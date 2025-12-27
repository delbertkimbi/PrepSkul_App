import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:confetti/confetti.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/core/utils/safe_set_state.dart';
import 'package:prepskul/core/services/log_service.dart';
import '../models/game_model.dart';
import '../services/skulmate_service.dart';
import '../services/game_sound_service.dart';
import '../services/character_selection_service.dart';
import '../services/game_stats_service.dart';
import '../models/game_stats_model.dart';
import '../widgets/skulmate_character_widget.dart';
import 'game_results_screen.dart';

/// Crossword game screen
class CrosswordGameScreen extends StatefulWidget {
  final GameModel game;

  const CrosswordGameScreen({Key? key, required this.game}) : super(key: key);

  @override
  State<CrosswordGameScreen> createState() => _CrosswordGameScreenState();
}

class _CrosswordGameScreenState extends State<CrosswordGameScreen>
    with TickerProviderStateMixin {
  List<List<String>> _grid = [];
  List<Map<String, dynamic>> _clues = [];
  Map<String, String> _userAnswers = {};
  Map<String, bool> _answeredClues = {};
  int _score = 0;
  int _currentStreak = 0;
  int _xpEarned = 0;
  DateTime? _startTime;
  final GameSoundService _soundService = GameSoundService();
  late ConfettiController _confettiController;
  late AnimationController _progressController;
  late Animation<double> _progressAnimation;
  dynamic _character;
  GameStats? _currentStats;
  String? _selectedClue;
  final Map<String, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();
    _soundService.initialize();
    _confettiController = ConfettiController(duration: const Duration(seconds: 2));
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _progressAnimation = Tween<double>(begin: 0, end: 0).animate(
      CurvedAnimation(parent: _progressController, curve: Curves.easeOut),
    );
    _initializeCrossword();
    _loadCharacter();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final stats = await GameStatsService.getStats();
    safeSetState(() {
      _currentStats = stats;
      _currentStreak = stats.currentStreak;
    });
  }

  Future<void> _loadCharacter() async {
    final character = await CharacterSelectionService.getSelectedCharacter();
    safeSetState(() {
      _character = character;
    });
  }

  void _initializeCrossword() {
    if (widget.game.items.isNotEmpty) {
      final item = widget.game.items[0];
      if (item.gridData != null) {
        _grid = List.from(item.gridData!);
      }
      if (item.clues != null) {
        _clues = List.from(item.clues!);
        for (final clue in _clues) {
          final id = clue['number'].toString();
          _controllers[id] = TextEditingController();
          _answeredClues[id] = false;
        }
      }
    }
    
    if (_grid.isEmpty || _clues.isEmpty) {
      // Create default crossword
      _grid = List.generate(10, (_) => List.generate(10, (_) => '.'));
      _clues = [
        {'number': 1, 'clue': 'First clue', 'answer': 'WORD', 'direction': 'across', 'row': 0, 'col': 0},
        {'number': 2, 'clue': 'Second clue', 'answer': 'TEST', 'direction': 'down', 'row': 0, 'col': 0},
      ];
      for (final clue in _clues) {
        final id = clue['number'].toString();
        _controllers[id] = TextEditingController();
        _answeredClues[id] = false;
      }
    }
  }

  void _checkAnswer(String clueId, String answer) {
    final clue = _clues.firstWhere((c) => c['number'].toString() == clueId);
    final correctAnswer = (clue['answer'] as String).toUpperCase();
    final userAnswer = answer.toUpperCase().trim();
    
    if (userAnswer == correctAnswer && !_answeredClues[clueId]!) {
      safeSetState(() {
        _answeredClues[clueId] = true;
        _userAnswers[clueId] = userAnswer;
        _score += 10;
        _currentStreak++;
        _xpEarned += 5;
      });
      
      _soundService.playCorrect();
      _confettiController.play();
      
      // Fill in the grid
      _fillGrid(clue, userAnswer);
      
      // Update progress
      final newProgress = _answeredClues.values.where((v) => v).length / _clues.length;
      _progressAnimation = Tween<double>(
        begin: _progressAnimation.value,
        end: newProgress.clamp(0.0, 1.0),
      ).animate(CurvedAnimation(
        parent: _progressController,
        curve: Curves.easeOut,
      ));
      _progressController.forward(from: 0);
      
      // Check if game complete
      if (_answeredClues.values.every((v) => v)) {
        Future.delayed(const Duration(milliseconds: 500), () {
          _finishGame();
        });
      }
    } else if (userAnswer.isNotEmpty && userAnswer != correctAnswer) {
      safeSetState(() {
        _currentStreak = 0;
      });
      _soundService.playIncorrect();
    }
  }

  void _fillGrid(Map<String, dynamic> clue, String answer) {
    final row = clue['row'] as int;
    final col = clue['col'] as int;
    final direction = clue['direction'] as String;
    
    for (int i = 0; i < answer.length; i++) {
      if (direction == 'across' && col + i < _grid[row].length) {
        _grid[row][col + i] = answer[i];
      } else if (direction == 'down' && row + i < _grid.length) {
        _grid[row + i][col] = answer[i];
      }
    }
  }

  Future<void> _finishGame() async {
    final endTime = DateTime.now();
    final timeTaken = _startTime != null
        ? endTime.difference(_startTime!).inSeconds
        : null;

    final isPerfectScore = _answeredClues.values.every((v) => v);

    int bonusXP = 0;
    if (isPerfectScore) bonusXP += 50;
    if (timeTaken != null && timeTaken < 600) bonusXP += 25;
    final totalXP = _xpEarned + bonusXP;

    try {
      await GameStatsService.addGameResult(
        correctAnswers: _answeredClues.values.where((v) => v).length,
        totalQuestions: _clues.length,
        timeTakenSeconds: timeTaken ?? 0,
        isPerfectScore: isPerfectScore,
      );
    } catch (e) {
      LogService.error('🎮 [Crossword] Error updating game stats: $e');
    }

    try {
      await SkulMateService.saveGameSession(
        gameId: widget.game.id,
        score: _score,
        totalQuestions: _clues.length,
        correctAnswers: _answeredClues.values.where((v) => v).length,
        timeTakenSeconds: timeTaken,
        answers: _userAnswers,
      );
    } catch (e) {
      LogService.error('🎮 [Crossword] Error saving game session: $e');
    }

    await _soundService.playComplete();
    
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => GameResultsScreen(
            game: widget.game,
            score: _score,
            totalQuestions: _clues.length,
            timeTakenSeconds: timeTaken,
            xpEarned: totalXP,
            isPerfectScore: isPerfectScore,
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    _progressController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.softBackground,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          widget.game.title,
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppTheme.textDark,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Score: $_score',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryColor,
                  ),
                ),
                Text(
                  '${_answeredClues.values.where((v) => v).length}/${_clues.length}',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textMedium,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Row(
        children: [
          Expanded(
            flex: 2,
            child: Column(
              children: [
                AnimatedBuilder(
                  animation: _progressAnimation,
                  builder: (context, child) {
                    return LinearProgressIndicator(
                      value: _progressAnimation.value,
                      backgroundColor: Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                      minHeight: 6,
                    );
                  },
                ),
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: _grid.isNotEmpty ? _grid[0].length : 10,
                        crossAxisSpacing: 2,
                        mainAxisSpacing: 2,
                      ),
                      itemCount: _grid.length * (_grid.isNotEmpty ? _grid[0].length : 10),
                      itemBuilder: (context, index) {
                        final row = index ~/ (_grid.isNotEmpty ? _grid[0].length : 10);
                        final col = index % (_grid.isNotEmpty ? _grid[0].length : 10);
                        final cell = _grid[row][col];
                        
                        return Container(
                          decoration: BoxDecoration(
                            color: cell == '.' ? Colors.grey[300] : Colors.white,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: cell == '.' ? Colors.grey[400]! : AppTheme.primaryColor,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              cell == '.' ? '' : cell,
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textDark,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 1,
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Clues:',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textDark,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _clues.length,
                      itemBuilder: (context, index) {
                        final clue = _clues[index];
                        final clueId = clue['number'].toString();
                        final isAnswered = _answeredClues[clueId] ?? false;
                        
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      color: isAnswered
                                          ? Colors.green
                                          : AppTheme.primaryColor,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Center(
                                      child: Text(
                                        clue['number'].toString(),
                                        style: GoogleFonts.poppins(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '${clue['direction'] as String? ?? 'across'}: ${clue['clue'] as String? ?? ''}',
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: AppTheme.textDark,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              TextField(
                                controller: _controllers[clueId],
                                enabled: !isAnswered,
                                decoration: InputDecoration(
                                  hintText: 'Enter answer',
                                  filled: isAnswered,
                                  fillColor: Colors.green.withOpacity(0.1),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                onChanged: (value) {
                                  if (value.length == (clue['answer'] as String).length) {
                                    _checkAnswer(clueId, value);
                                  }
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

