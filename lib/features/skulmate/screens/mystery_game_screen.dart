import 'dart:async';
import 'dart:math' as math;
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

/// Mystery game screen - Detective-style games
/// Examples: "Who is the unreliable narrator?", "What caused the mutation?"
/// Wrong interpretation = false lead (not instant failure)
class MysteryGameScreen extends StatefulWidget {
  final GameModel game;

  const MysteryGameScreen({Key? key, required this.game}) : super(key: key);

  @override
  State<MysteryGameScreen> createState() => _MysteryGameScreenState();
}

class _MysteryGameScreenState extends State<MysteryGameScreen>
    with TickerProviderStateMixin {
  int _currentClueIndex = 0;
  final Set<int> _revealedClues = {};
  final Map<int, String?> _interpretations = {};
  final Map<int, bool> _isFalseLead = {};
  String? _finalSolution;
  String? _caseName;
  List<Map<String, dynamic>>? _clues;
  int _score = 0;
  int _xpEarned = 0;
  DateTime? _startTime;
  final GameSoundService _soundService = GameSoundService();
  late ConfettiController _confettiController;
  late AnimationController _progressController;
  late Animation<double> _progressAnimation;
  dynamic _character;
  GameStats? _currentStats;
  bool _showSolutionInput = false;
  final TextEditingController _solutionController = TextEditingController();

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
    _caseName = firstItem.caseName ?? 'The Mystery';
    _clues = firstItem.mysteryClues ?? [];
    _finalSolution = firstItem.solution;
    
    // If clues not in first item, try to extract from gameData
    if (_clues == null || _clues!.isEmpty) {
      final gameData = firstItem.gameData;
      if (gameData != null) {
        _caseName = gameData['case'] as String? ?? gameData['caseName'] as String? ?? _caseName;
        if (gameData['clues'] != null) {
          _clues = List<Map<String, dynamic>>.from(gameData['clues'] as List);
        }
        _finalSolution = gameData['solution'] as String? ?? _finalSolution;
      }
    }
    
    LogService.debug('Mystery game: Case=$_caseName, Clues=${_clues?.length ?? 0}');
  }

  @override
  void dispose() {
    _progressController.dispose();
    _confettiController.dispose();
    _solutionController.dispose();
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

  void _revealClue(int index) {
    if (_revealedClues.contains(index)) return;
    
    safeSetState(() {
      _revealedClues.add(index);
    });
    _soundService.playCorrect();
  }

  void _submitInterpretation(String interpretation) {
    if (_interpretations.containsKey(_currentClueIndex)) return;
    if (_clues == null || _currentClueIndex >= _clues!.length) return;

    final clue = _clues![_currentClueIndex];
    final reveals = clue['reveals'] as String? ?? '';
    
    // Simple check: if interpretation is too generic or doesn't match reveals, it's a false lead
    final isFalseLead = interpretation.toLowerCase().trim().length < 10 ||
                        !interpretation.toLowerCase().contains(reveals.toLowerCase().substring(0, math.min(5, reveals.length)));

    safeSetState(() {
      _interpretations[_currentClueIndex] = interpretation;
      _isFalseLead[_currentClueIndex] = isFalseLead;
      if (!isFalseLead) {
        _score++;
        _xpEarned += 20;
      }
    });

    _showInterpretationFeedback(interpretation, isFalseLead, reveals);
  }

  void _showInterpretationFeedback(String interpretation, bool isFalseLead, String reveals) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          isFalseLead ? '⚠️ False Lead' : '✓ Clue Understood',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: isFalseLead ? Colors.orange : AppTheme.accentGreen,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isFalseLead
                  ? 'This interpretation doesn\'t match the clue. Try again with a different perspective.'
                  : 'Good interpretation! This clue reveals:',
              style: GoogleFonts.poppins(fontSize: 16),
            ),
            if (!isFalseLead) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.accentGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  reveals,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.accentGreen,
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              if (!isFalseLead) {
                _nextClue();
              }
            },
            child: Text(
              isFalseLead ? 'Try Again' : 'Continue',
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

  void _nextClue() {
    if (_clues == null) return;
    
    if (_currentClueIndex < _clues!.length - 1) {
      safeSetState(() {
        _currentClueIndex++;
      });
      _progressController.forward(from: 0);
      _progressAnimation = Tween<double>(
        begin: 0,
        end: (_currentClueIndex + 1) / _clues!.length,
      ).animate(CurvedAnimation(
        parent: _progressController,
        curve: Curves.easeOut,
      ));
      _progressController.forward();
    } else {
      // All clues revealed, show solution input
      safeSetState(() {
        _showSolutionInput = true;
      });
    }
  }

  void _submitSolution() {
    final userSolution = _solutionController.text.trim();
    if (userSolution.isEmpty) return;
    
    final isCorrect = _finalSolution != null &&
        userSolution.toLowerCase().contains(_finalSolution!.toLowerCase().substring(0, math.min(10, _finalSolution!.length)));
    
    if (isCorrect) {
      _score++;
      _xpEarned += 50;
      _soundService.playCorrect();
      _confettiController.play();
    } else {
      _soundService.playIncorrect();
    }
    
    _completeGame(isCorrect);
  }

  Future<void> _completeGame(bool solved) async {
    final endTime = DateTime.now();
    final duration = _startTime != null
        ? endTime.difference(_startTime!).inSeconds
        : 0;

    final totalClues = _clues?.length ?? 1;
    final percentage = (_score / (totalClues + 1) * 100).round(); // +1 for final solution
    
    // Save game stats
    if (widget.game.userId.isNotEmpty) {
      try {
        await GameStatsService.recordGameCompletion(
          gameId: widget.game.id,
          score: _score,
          totalItems: totalClues + 1,
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
            totalQuestions: totalClues + 1,
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
    if (_clues == null || _clues!.isEmpty) {
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
            'No clues available',
            style: GoogleFonts.poppins(),
          ),
        ),
      );
    }

    if (_showSolutionInput) {
      return _buildSolutionInput();
    }

    final clue = _clues![_currentClueIndex];
    final noteReference = clue['noteReference'] as String? ?? 'From the notes';
    final reveals = clue['reveals'] as String? ?? '';
    final isRevealed = _revealedClues.contains(_currentClueIndex);
    final hasInterpretation = _interpretations.containsKey(_currentClueIndex);

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
                  // Case name
                  if (_caseName != null)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.purple.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.search, color: Colors.purple),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Case: $_caseName',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.purple,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  
                  const SizedBox(height: 24),
                  
                  // Clue number
                  Text(
                    'Clue ${_currentClueIndex + 1} of ${_clues!.length}',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: AppTheme.textMedium,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Clue card
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
                            Icon(Icons.lightbulb_outline, color: Colors.amber),
                            const SizedBox(width: 8),
                            Text(
                              'Clue',
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textDark,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (!isRevealed)
                          GestureDetector(
                            onTap: () => _revealClue(_currentClueIndex),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: AppTheme.primaryColor,
                                  width: 2,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.visibility_off, color: AppTheme.primaryColor),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Tap to reveal clue',
                                    style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.primaryColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else ...[
                          Text(
                            noteReference,
                            style: GoogleFonts.poppins(
                              fontSize: 15,
                              color: AppTheme.textMedium,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.amber.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              reveals,
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                color: AppTheme.textDark,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  
                  if (isRevealed && !hasInterpretation) ...[
                    const SizedBox(height: 24),
                    Text(
                      'What does this clue reveal?',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textDark,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _solutionController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'Enter your interpretation...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      style: GoogleFonts.poppins(fontSize: 16),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          _submitInterpretation(_solutionController.text);
                          _solutionController.clear();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Submit Interpretation',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                  
                  // Show interpretation feedback
                  if (hasInterpretation) ...[
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: (_isFalseLead[_currentClueIndex] == true
                            ? Colors.orange
                            : AppTheme.accentGreen).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _isFalseLead[_currentClueIndex] == true
                              ? Colors.orange
                              : AppTheme.accentGreen,
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                _isFalseLead[_currentClueIndex] == true
                                    ? Icons.warning
                                    : Icons.check_circle,
                                color: _isFalseLead[_currentClueIndex] == true
                                    ? Colors.orange
                                    : AppTheme.accentGreen,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _isFalseLead[_currentClueIndex] == true
                                    ? 'False Lead'
                                    : 'Correct Interpretation',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: _isFalseLead[_currentClueIndex] == true
                                      ? Colors.orange
                                      : AppTheme.accentGreen,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _interpretations[_currentClueIndex] ?? '',
                            style: GoogleFonts.poppins(
                              fontSize: 15,
                              color: AppTheme.textDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isFalseLead[_currentClueIndex] == true
                            ? () {
                                safeSetState(() {
                                  _interpretations.remove(_currentClueIndex);
                                  _isFalseLead.remove(_currentClueIndex);
                                });
                                _solutionController.clear();
                              }
                            : _nextClue,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          _isFalseLead[_currentClueIndex] == true
                              ? 'Try Again'
                              : _currentClueIndex < _clues!.length - 1
                                  ? 'Next Clue'
                                  : 'Solve Mystery',
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

  Widget _buildSolutionInput() {
    return Scaffold(
      backgroundColor: AppTheme.softBackground,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Solve the Mystery',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: AppTheme.textDark,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
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
                  Text(
                    'All clues revealed!',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textDark,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Based on all the clues you\'ve collected, what is the solution to this mystery?',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      color: AppTheme.textDark,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _solutionController,
              maxLines: 5,
              decoration: InputDecoration(
                hintText: 'Enter your solution...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
              style: GoogleFonts.poppins(fontSize: 16),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submitSolution,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Submit Solution',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
