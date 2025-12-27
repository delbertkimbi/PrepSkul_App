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

/// Word Search game screen
class WordSearchGameScreen extends StatefulWidget {
  final GameModel game;

  const WordSearchGameScreen({Key? key, required this.game}) : super(key: key);

  @override
  State<WordSearchGameScreen> createState() => _WordSearchGameScreenState();
}

class _WordSearchGameScreenState extends State<WordSearchGameScreen>
    with TickerProviderStateMixin {
  List<List<String>> _grid = [];
  List<String> _words = [];
  Set<String> _foundWords = {};
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
  Offset? _startSelection;
  Offset? _endSelection;
  Set<Offset> _selectedCells = {};

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
    if (widget.game.items.isNotEmpty) {
      final item = widget.game.items[0];
      if (item.gridData != null) {
        _grid = List.from(item.gridData!);
      }
      if (item.words != null) {
        _words = List.from(item.words!);
      }
    }
    
    if (_grid.isEmpty || _words.isEmpty) {
      // Create default grid and words
      _words = widget.game.items.take(8).map((item) {
        return item.term ?? item.question ?? 'WORD';
      }).toList();
      _grid = _generateWordSearchGrid(_words);
    }
  }

  List<List<String>> _generateWordSearchGrid(List<String> words) {
    final size = 12;
    final grid = List.generate(size, (_) => List.generate(size, (_) => ''));
    final random = Random();
    
    // Fill with random letters
    for (int i = 0; i < size; i++) {
      for (int j = 0; j < size; j++) {
        grid[i][j] = String.fromCharCode(65 + random.nextInt(26));
      }
    }
    
    // Place words
    for (final word in words) {
      final upperWord = word.toUpperCase().replaceAll(' ', '');
      if (upperWord.length <= size) {
        final row = random.nextInt(size);
        final col = random.nextInt(size - upperWord.length);
        for (int i = 0; i < upperWord.length; i++) {
          if (col + i < size) {
            grid[row][col + i] = upperWord[i];
          }
        }
      }
    }
    
    return grid;
  }

  void _onCellTap(int row, int col) {
    if (_startSelection == null) {
      safeSetState(() {
        _startSelection = Offset(row.toDouble(), col.toDouble());
        _selectedCells = {Offset(row.toDouble(), col.toDouble())};
      });
    } else {
      safeSetState(() {
        _endSelection = Offset(row.toDouble(), col.toDouble());
        _selectedCells = _getCellsBetween(_startSelection!, _endSelection!);
        _checkWord();
      });
    }
  }

  Set<Offset> _getCellsBetween(Offset start, Offset end) {
    final cells = <Offset>{};
    final dx = (end.dx - start.dx).sign;
    final dy = (end.dy - start.dy).sign;
    final distance = ((end.dx - start.dx).abs() + (end.dy - start.dy).abs()).toInt();
    
    for (int i = 0; i <= distance; i++) {
      cells.add(Offset(start.dx + dx * i, start.dy + dy * i));
    }
    
    return cells;
  }

  void _checkWord() {
    if (_startSelection == null || _endSelection == null) return;
    
    final word = _selectedCells.map((cell) {
      final row = cell.dx.toInt();
      final col = cell.dy.toInt();
      if (row >= 0 && row < _grid.length && col >= 0 && col < _grid[row].length) {
        return _grid[row][col];
      }
      return '';
    }).join('');
    
    final reversedWord = word.split('').reversed.join('');
    
    for (final targetWord in _words) {
      final upperTarget = targetWord.toUpperCase().replaceAll(' ', '');
      if ((word == upperTarget || reversedWord == upperTarget) &&
          !_foundWords.contains(targetWord)) {
        safeSetState(() {
          _foundWords.add(targetWord);
          _score += 10;
          _currentStreak++;
          _xpEarned += 5;
        });
        
        _soundService.playCorrect();
        _confettiController.play();
        
        // Update progress
        final newProgress = _foundWords.length / _words.length;
        _progressAnimation = Tween<double>(
          begin: _progressAnimation.value,
          end: newProgress.clamp(0.0, 1.0),
        ).animate(CurvedAnimation(
          parent: _progressController,
          curve: Curves.easeOut,
        ));
        _progressController.forward(from: 0);
        
        // Check if game complete
        if (_foundWords.length == _words.length) {
          Future.delayed(const Duration(milliseconds: 500), () {
            _finishGame();
          });
        }
        break;
      }
    }
    
    safeSetState(() {
      _startSelection = null;
      _endSelection = null;
      _selectedCells = {};
    });
  }

  Future<void> _finishGame() async {
    final endTime = DateTime.now();
    final timeTaken = _startTime != null
        ? endTime.difference(_startTime!).inSeconds
        : null;

    final isPerfectScore = _foundWords.length == _words.length;

    int bonusXP = 0;
    if (isPerfectScore) bonusXP += 50;
    if (timeTaken != null && timeTaken < 300) bonusXP += 25;
    final totalXP = _xpEarned + bonusXP;

    try {
      await GameStatsService.addGameResult(
        correctAnswers: _foundWords.length,
        totalQuestions: _words.length,
        timeTakenSeconds: timeTaken ?? 0,
        isPerfectScore: isPerfectScore,
      );
    } catch (e) {
      LogService.error('🎮 [WordSearch] Error updating game stats: $e');
    }

    try {
      await SkulMateService.saveGameSession(
        gameId: widget.game.id,
        score: _score,
        totalQuestions: _words.length,
        correctAnswers: _foundWords.length,
        timeTakenSeconds: timeTaken,
        answers: {'words': _foundWords.toList()},
      );
    } catch (e) {
      LogService.error('🎮 [WordSearch] Error saving game session: $e');
    }

    await _soundService.playComplete();
    
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => GameResultsScreen(
            game: widget.game,
            score: _score,
            totalQuestions: _words.length,
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
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Found: ${_foundWords.length}/${_words.length}',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryColor,
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
                        crossAxisCount: _grid.isNotEmpty ? _grid[0].length : 12,
                        crossAxisSpacing: 2,
                        mainAxisSpacing: 2,
                      ),
                      itemCount: _grid.length * (_grid.isNotEmpty ? _grid[0].length : 12),
                      itemBuilder: (context, index) {
                        final row = index ~/ (_grid.isNotEmpty ? _grid[0].length : 12);
                        final col = index % (_grid.isNotEmpty ? _grid[0].length : 12);
                        final cell = Offset(row.toDouble(), col.toDouble());
                        final isSelected = _selectedCells.contains(cell);
                        
                        return GestureDetector(
                          onTap: () => _onCellTap(row, col),
                          child: Container(
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppTheme.primaryColor.withOpacity(0.3)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: isSelected
                                    ? AppTheme.primaryColor
                                    : Colors.grey[300]!,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                _grid[row][col],
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textDark,
                                ),
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
                    'Words to Find:',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textDark,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _words.length,
                      itemBuilder: (context, index) {
                        final word = _words[index];
                        final isFound = _foundWords.contains(word);
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Icon(
                                isFound ? Icons.check_circle : Icons.circle_outlined,
                                color: isFound ? Colors.green : Colors.grey,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  word,
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: isFound ? FontWeight.w600 : FontWeight.normal,
                                    color: isFound ? Colors.green : AppTheme.textDark,
                                    decoration: isFound ? TextDecoration.lineThrough : null,
                                  ),
                                ),
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

