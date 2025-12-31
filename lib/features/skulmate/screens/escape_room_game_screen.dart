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

/// Escape Room game screen - Concept-based puzzle games
/// Examples: "Escape the Lab", "Break the Code", "Unlock the Story"
/// Keys = applying knowledge correctly
class EscapeRoomGameScreen extends StatefulWidget {
  final GameModel game;

  const EscapeRoomGameScreen({Key? key, required this.game}) : super(key: key);

  @override
  State<EscapeRoomGameScreen> createState() => _EscapeRoomGameScreenState();
}

class _EscapeRoomGameScreenState extends State<EscapeRoomGameScreen>
    with TickerProviderStateMixin {
  int _currentRoomIndex = 0;
  final Map<int, String?> _puzzleAnswers = {};
  final Map<int, bool> _roomsUnlocked = {};
  List<Map<String, dynamic>>? _rooms;
  int _score = 0;
  int _xpEarned = 0;
  DateTime? _startTime;
  final GameSoundService _soundService = GameSoundService();
  late ConfettiController _confettiController;
  late AnimationController _progressController;
  late Animation<double> _progressAnimation;
  dynamic _character;
  GameStats? _currentStats;
  final Map<int, TextEditingController> _answerControllers = {};

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
    _loadCharacter();
    _loadStats();
    _parseGameData();
  }

  void _parseGameData() {
    if (widget.game.items.isEmpty) return;
    
    final firstItem = widget.game.items[0];
    _rooms = firstItem.rooms ?? [];
    
    // If rooms not in first item, try to extract from gameData
    if (_rooms == null || _rooms!.isEmpty) {
      final gameData = firstItem.gameData;
      if (gameData != null && gameData['rooms'] != null) {
        _rooms = List<Map<String, dynamic>>.from(gameData['rooms'] as List);
      }
    }
    
    // Initialize answer controllers for each room
    if (_rooms != null) {
      for (int i = 0; i < _rooms!.length; i++) {
        _answerControllers[i] = TextEditingController();
      }
    }
    
    LogService.debug('Escape room game: Rooms=${_rooms?.length ?? 0}');
  }

  @override
  void dispose() {
    _progressController.dispose();
    _confettiController.dispose();
    for (var controller in _answerControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadStats() async {
    final stats = await GameStatsService.getStats();
    safeSetState(() {
      _currentStats = stats;
    });
  }

  Future<void> _loadCharacter() async {
    final character = await CharacterSelectionService.getSelectedCharacter();
    safeSetState(() {
      _character = character;
    });
  }

  void _submitPuzzleAnswer(String answer) {
    if (_puzzleAnswers.containsKey(_currentRoomIndex)) return;
    if (_rooms == null || _currentRoomIndex >= _rooms!.length) return;

    final room = _rooms![_currentRoomIndex];
    final puzzle = room['puzzle'] as Map<String, dynamic>? ?? {};
    final solution = puzzle['solution'] as String? ?? '';
    
    final isCorrect = answer.toLowerCase().trim() == solution.toLowerCase().trim() ||
                     answer.toLowerCase().contains(solution.toLowerCase().substring(0, min(5, solution.length)));

    int baseXP = 20;
    int xpForThisRoom = baseXP;

    safeSetState(() {
      _puzzleAnswers[_currentRoomIndex] = answer;
      _roomsUnlocked[_currentRoomIndex] = isCorrect;
      if (isCorrect) {
        _score++;
        _xpEarned += xpForThisRoom;
        _soundService.playCorrect();
      } else {
        _soundService.playIncorrect();
      }
    });

    _showPuzzleFeedback(isCorrect, solution);
  }

  void _showPuzzleFeedback(bool isCorrect, String solution) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          isCorrect ? '🔓 Room Unlocked!' : '🔒 Incorrect',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: isCorrect ? AppTheme.accentGreen : AppTheme.primaryColor,
          ),
        ),
        content: Text(
          isCorrect
              ? 'You solved the puzzle! The door unlocks and you can proceed to the next room.'
              : 'That\'s not quite right. The correct answer is: $solution. Try again!',
          style: GoogleFonts.poppins(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              if (isCorrect) {
                _nextRoom();
              } else {
                // Clear answer for retry
                safeSetState(() {
                  _puzzleAnswers.remove(_currentRoomIndex);
                  _roomsUnlocked.remove(_currentRoomIndex);
                });
                _answerControllers[_currentRoomIndex]?.clear();
              }
            },
            child: Text(
              isCorrect ? 'Continue' : 'Try Again',
              style: GoogleFonts.poppins(
                color: AppTheme.primaryColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _nextRoom() {
    if (_rooms == null) return;
    
    if (_currentRoomIndex < _rooms!.length - 1) {
      safeSetState(() {
        _currentRoomIndex++;
      });
      _progressController.forward(from: 0);
      _progressAnimation = Tween<double>(
        begin: 0,
        end: (_currentRoomIndex + 1) / _rooms!.length,
      ).animate(CurvedAnimation(
        parent: _progressController,
        curve: Curves.easeOut,
      ));
      _progressController.forward();
    } else {
      _completeGame();
    }
  }

  Future<void> _completeGame() async {
    final endTime = DateTime.now();
    final duration = _startTime != null
        ? endTime.difference(_startTime!).inSeconds
        : 0;

    final totalRooms = _rooms?.length ?? 1;
    final percentage = (_score / totalRooms * 100).round();
    
    // Save game stats
    if (widget.game.userId.isNotEmpty) {
      try {
        await GameStatsService.recordGameCompletion(
          gameId: widget.game.id,
          score: _score,
          totalItems: totalRooms,
          xpEarned: _xpEarned,
          duration: Duration(seconds: duration),
          streak: 0,
        );
      } catch (e) {
        LogService.error('Failed to save game stats: $e');
      }
    }

    // Navigate to results screen
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => GameResultsScreen(
            game: widget.game,
            score: _score,
            totalQuestions: totalRooms,
            xpEarned: _xpEarned,
            timeTakenSeconds: duration,
            isPerfectScore: percentage == 100,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_rooms == null || _rooms!.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          title: Text(
            widget.game.title,
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: AppTheme.textDark,
            ),
          ),
        ),
        body: Center(
          child: Text(
            'No rooms available',
            style: GoogleFonts.poppins(),
          ),
        ),
      );
    }

    final room = _rooms![_currentRoomIndex];
    final lockedBy = room['lockedBy'] as String? ?? 'A concept';
    final puzzle = room['puzzle'] as Map<String, dynamic>? ?? {};
    final puzzleType = puzzle['type'] as String? ?? 'logic';
    final puzzlePrompt = puzzle['prompt'] as String? ?? 'Solve this puzzle.';
    final solution = puzzle['solution'] as String? ?? '';
    final hasAnswered = _puzzleAnswers.containsKey(_currentRoomIndex);
    final isUnlocked = _roomsUnlocked[_currentRoomIndex] == true;

    return Scaffold(
      backgroundColor: AppTheme.softBackground,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          widget.game.title,
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: AppTheme.textDark,
          ),
        ),
        actions: [
          if (_character != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: SkulMateCharacterWidget(character: _character),
            ),
        ],
      ),
      body: Column(
        children: [
          // Progress bar
          AnimatedBuilder(
            animation: _progressAnimation,
            builder: (context, child) {
              return LinearProgressIndicator(
                value: _progressAnimation.value,
                backgroundColor: AppTheme.textLight.withOpacity(0.2),
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                minHeight: 4,
              );
            },
          ),
          
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Room number
                  Text(
                    'Room ${_currentRoomIndex + 1} of ${_rooms!.length}',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: AppTheme.textMedium,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Locked by
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.lock, color: Colors.red),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Locked by: $lockedBy',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.red,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Puzzle card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _getPuzzleIcon(puzzleType),
                              color: AppTheme.primaryColor,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Puzzle',
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textDark,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          puzzlePrompt,
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            color: AppTheme.textDark,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  if (!hasAnswered) ...[
                    const SizedBox(height: 24),
                    Text(
                      'Enter your answer:',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textDark,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _answerControllers[_currentRoomIndex],
                      decoration: InputDecoration(
                        hintText: 'Type your answer...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      style: GoogleFonts.poppins(fontSize: 16),
                      onSubmitted: (value) {
                        if (value.trim().isNotEmpty) {
                          _submitPuzzleAnswer(value.trim());
                        }
                      },
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          final answer = _answerControllers[_currentRoomIndex]?.text.trim() ?? '';
                          if (answer.isNotEmpty) {
                            _submitPuzzleAnswer(answer);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Submit Answer',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                  
                  // Show answer feedback
                  if (hasAnswered) ...[
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: (isUnlocked
                            ? AppTheme.accentGreen
                            : Colors.red).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isUnlocked
                              ? AppTheme.accentGreen
                              : Colors.red,
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                isUnlocked ? Icons.check_circle : Icons.cancel,
                                color: isUnlocked
                                    ? AppTheme.accentGreen
                                    : Colors.red,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                isUnlocked ? 'Correct!' : 'Incorrect',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: isUnlocked
                                      ? AppTheme.accentGreen
                                      : Colors.red,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Your answer: ${_puzzleAnswers[_currentRoomIndex]}',
                            style: GoogleFonts.poppins(
                              fontSize: 15,
                              color: AppTheme.textDark,
                            ),
                          ),
                          if (!isUnlocked) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Correct answer: $solution',
                              style: GoogleFonts.poppins(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textDark,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: isUnlocked
                            ? _nextRoom
                            : () {
                                safeSetState(() {
                                  _puzzleAnswers.remove(_currentRoomIndex);
                                  _roomsUnlocked.remove(_currentRoomIndex);
                                });
                                _answerControllers[_currentRoomIndex]?.clear();
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          isUnlocked
                              ? (_currentRoomIndex < _rooms!.length - 1
                                  ? 'Next Room'
                                  : 'Complete Escape')
                              : 'Try Again',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getPuzzleIcon(String puzzleType) {
    switch (puzzleType.toLowerCase()) {
      case 'logic':
        return Icons.psychology;
      case 'calculation':
        return Icons.calculate;
      case 'matching':
        return Icons.compare_arrows;
      case 'sequence':
        return Icons.timeline;
      default:
        return Icons.help_outline;
    }
  }
}
