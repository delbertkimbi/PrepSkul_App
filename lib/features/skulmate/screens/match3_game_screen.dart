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

/// Match-3 style game screen
class Match3GameScreen extends StatefulWidget {
  final GameModel game;

  const Match3GameScreen({Key? key, required this.game}) : super(key: key);

  @override
  State<Match3GameScreen> createState() => _Match3GameScreenState();
}

class _Match3GameScreenState extends State<Match3GameScreen>
    with TickerProviderStateMixin {
  List<List<String>> _grid = [];
  int _score = 0;
  int _moves = 0;
  int _currentStreak = 0;
  int _xpEarned = 0;
  DateTime? _startTime;
  final GameSoundService _soundService = GameSoundService();
  late ConfettiController _confettiController;
  late AnimationController _progressController;
  late Animation<double> _progressAnimation;
  dynamic _character;
  GameStats? _currentStats;
  int? _selectedRow;
  int? _selectedCol;
  int _matchesFound = 0;
  int _totalMatches = 0;

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
    _initializeGrid();
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

  void _initializeGrid() {
    // Get grid data from first item or create default
    if (widget.game.items.isNotEmpty && widget.game.items[0].gridData != null) {
      _grid = List.from(widget.game.items[0].gridData!);
    } else {
      // Create a default 6x6 grid with items from game content
      _grid = List.generate(6, (row) {
        return List.generate(6, (col) {
          final items = widget.game.items;
          if (items.isNotEmpty) {
            final item = items[(row * 6 + col) % items.length];
            return item.term ?? item.question ?? 'Item ${row * 6 + col}';
          }
          return 'Item ${row * 6 + col}';
        });
      });
    }
    
    // Calculate total possible matches
    _totalMatches = _countPossibleMatches();
  }

  int _countPossibleMatches() {
    int count = 0;
    for (int row = 0; row < _grid.length; row++) {
      for (int col = 0; col < _grid[row].length; col++) {
        // Check horizontal matches
        if (col < _grid[row].length - 2) {
          if (_grid[row][col] == _grid[row][col + 1] &&
              _grid[row][col] == _grid[row][col + 2]) {
            count++;
          }
        }
        // Check vertical matches
        if (row < _grid.length - 2) {
          if (_grid[row][col] == _grid[row + 1][col] &&
              _grid[row][col] == _grid[row + 2][col]) {
            count++;
          }
        }
      }
    }
    return count;
  }

  void _onCellTap(int row, int col) {
    if (_selectedRow == null || _selectedCol == null) {
      // First selection
      safeSetState(() {
        _selectedRow = row;
        _selectedCol = col;
      });
      _soundService.playClick();
    } else {
      // Second selection - swap
      if ((_selectedRow == row && (_selectedCol! - col).abs() == 1) ||
          (_selectedCol == col && (_selectedRow! - row).abs() == 1)) {
        _swapCells(_selectedRow!, _selectedCol!, row, col);
      }
      safeSetState(() {
        _selectedRow = null;
        _selectedCol = null;
      });
    }
  }

  void _swapCells(int row1, int col1, int row2, int col2) {
    final temp = _grid[row1][col1];
    _grid[row1][col1] = _grid[row2][col2];
    _grid[row2][col2] = temp;
    _moves++;
    _checkMatches();
  }

  void _checkMatches() {
    final matches = <List<int>>[];
    
    // Check horizontal matches
    for (int row = 0; row < _grid.length; row++) {
      for (int col = 0; col < _grid[row].length - 2; col++) {
        if (_grid[row][col] == _grid[row][col + 1] &&
            _grid[row][col] == _grid[row][col + 2]) {
          matches.add([row, col]);
        }
      }
    }
    
    // Check vertical matches
    for (int row = 0; row < _grid.length - 2; row++) {
      for (int col = 0; col < _grid[row].length; col++) {
        if (_grid[row][col] == _grid[row + 1][col] &&
            _grid[row][col] == _grid[row + 2][col]) {
          matches.add([row, col]);
        }
      }
    }
    
    if (matches.isNotEmpty) {
      _matchesFound += matches.length;
      safeSetState(() {
        _score += matches.length * 10;
        _currentStreak++;
        _xpEarned += matches.length * 5;
      });
      
      _soundService.playMatch();
      _confettiController.play();
      
      // Update progress
      final newProgress = _matchesFound / _totalMatches;
      _progressAnimation = Tween<double>(
        begin: _progressAnimation.value,
        end: newProgress.clamp(0.0, 1.0),
      ).animate(CurvedAnimation(
        parent: _progressController,
        curve: Curves.easeOut,
      ));
      _progressController.forward(from: 0);
      
      // Check if game complete
      if (_matchesFound >= _totalMatches) {
        Future.delayed(const Duration(milliseconds: 500), () {
          _finishGame();
        });
      }
    } else {
      safeSetState(() {
        _currentStreak = 0;
      });
    }
  }

  Future<void> _finishGame() async {
    final endTime = DateTime.now();
    final timeTaken = _startTime != null
        ? endTime.difference(_startTime!).inSeconds
        : null;

    final isPerfectScore = _matchesFound >= _totalMatches;

    int bonusXP = 0;
    if (isPerfectScore) bonusXP += 50;
    if (timeTaken != null && timeTaken < 180) bonusXP += 25;
    final totalXP = _xpEarned + bonusXP;

    try {
      await GameStatsService.addGameResult(
        correctAnswers: _matchesFound,
        totalQuestions: _totalMatches,
        timeTakenSeconds: timeTaken ?? 0,
        isPerfectScore: isPerfectScore,
      );
    } catch (e) {
      LogService.error('🎮 [Match3] Error updating game stats: $e');
    }

    try {
      await SkulMateService.saveGameSession(
        gameId: widget.game.id,
        score: _score,
        totalQuestions: _totalMatches,
        correctAnswers: _matchesFound,
        timeTakenSeconds: timeTaken,
        answers: {'moves': _moves, 'matches': _matchesFound},
      );
    } catch (e) {
      LogService.error('🎮 [Match3] Error saving game session: $e');
    }

    await _soundService.playComplete();
    
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => GameResultsScreen(
            game: widget.game,
            score: _score,
            totalQuestions: _totalMatches,
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
          if (_currentStreak > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.orange, width: 1.5),
                ),
                child: Row(
                  children: [
                    const Text('🔥', style: TextStyle(fontSize: 16)),
                    const SizedBox(width: 4),
                    Text(
                      '$_currentStreak',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.orange[800],
                      ),
                    ),
                  ],
                ),
              ),
            ),
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
                  'Moves: $_moves',
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
      body: Stack(
        children: [
          Column(
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
                child: Center(
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
                        crossAxisCount: _grid.isNotEmpty ? _grid[0].length : 6,
                        crossAxisSpacing: 4,
                        mainAxisSpacing: 4,
                      ),
                      itemCount: _grid.length * (_grid.isNotEmpty ? _grid[0].length : 6),
                      itemBuilder: (context, index) {
                        final row = index ~/ (_grid.isNotEmpty ? _grid[0].length : 6);
                        final col = index % (_grid.isNotEmpty ? _grid[0].length : 6);
                        final isSelected = _selectedRow == row && _selectedCol == col;
                        
                        return GestureDetector(
                          onTap: () => _onCellTap(row, col),
                          child: Container(
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppTheme.primaryColor.withOpacity(0.3)
                                  : AppTheme.primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isSelected
                                    ? AppTheme.primaryColor
                                    : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                _grid[row][col],
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textDark,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
              if (_character != null)
                SkulMateCharacterWidget(
                  character: _character,
                  size: 80,
                ),
            ],
          ),
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirection: 3.14 / 2,
              maxBlastForce: 5,
              minBlastForce: 2,
              emissionFrequency: 0.05,
              numberOfParticles: 20,
              gravity: 0.1,
            ),
          ),
        ],
      ),
    );
  }
}

