import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/core/utils/safe_set_state.dart';
import 'dart:math';
import '../models/game_model.dart';
import '../services/skulmate_service.dart';
import '../services/game_sound_service.dart';
import 'game_results_screen.dart';

/// Matching pairs game screen
class MatchingGameScreen extends StatefulWidget {
  final GameModel game;

  const MatchingGameScreen({Key? key, required this.game}) : super(key: key);

  @override
  State<MatchingGameScreen> createState() => _MatchingGameScreenState();
}

class _MatchingGameScreenState extends State<MatchingGameScreen> {
  late List<String> _leftItems;
  late List<String> _rightItems;
  final Map<int, int?> _matches = {}; // leftIndex -> rightIndex
  int? _selectedLeft;
  int? _selectedRight;
  int _score = 0;
  DateTime? _startTime;
  final GameSoundService _soundService = GameSoundService();

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();
    _soundService.initialize();
    _initializeItems();
  }

  void _initializeItems() {
    _leftItems = widget.game.items
        .map((item) => item.leftItem ?? '')
        .where((item) => item.isNotEmpty)
        .toList();
    _rightItems = widget.game.items
        .map((item) => item.rightItem ?? '')
        .where((item) => item.isNotEmpty)
        .toList();

    // Shuffle right items
    _rightItems.shuffle(Random());
  }

  void _selectLeft(int index) {
    safeSetState(() {
      if (_matches.containsKey(index)) {
        // Already matched, deselect
        _selectedLeft = null;
      } else {
        _selectedLeft = index;
        if (_selectedRight != null) {
          _tryMatch(_selectedLeft!, _selectedRight!);
        }
      }
    });
  }

  void _selectRight(int index) {
    safeSetState(() {
      // Check if already matched
      final isMatched = _matches.values.contains(index);
      if (isMatched) {
        _selectedRight = null;
        return;
      }

      _selectedRight = index;
      if (_selectedLeft != null) {
        _tryMatch(_selectedLeft!, _selectedRight!);
      }
    });
  }

  void _tryMatch(int leftIndex, int rightIndex) {
    // Find original right index for this left item
    final originalRightIndex = widget.game.items.indexWhere(
      (item) => item.leftItem == _leftItems[leftIndex],
    );

    if (originalRightIndex != -1) {
      final originalRightItem = widget.game.items[originalRightIndex].rightItem;
      final selectedRightItem = _rightItems[rightIndex];

      if (originalRightItem == selectedRightItem) {
        // Correct match!
        safeSetState(() {
          _matches[leftIndex] = rightIndex;
          _score++;
        });
        _soundService.playMatch();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Correct match! 🎉'),
            backgroundColor: AppTheme.accentGreen,
            duration: Duration(seconds: 1),
          ),
        );

        // Check if game is complete
        if (_matches.length == _leftItems.length) {
          Future.delayed(const Duration(milliseconds: 1000), () {
            _finishGame();
          });
        }
      } else {
        // Wrong match
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Wrong match. Try again!'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 1),
          ),
        );
      }
    }

    safeSetState(() {
      _selectedLeft = null;
      _selectedRight = null;
    });
  }

  Future<void> _finishGame() async {
    final endTime = DateTime.now();
    final timeTaken = _startTime != null
        ? endTime.difference(_startTime!).inSeconds
        : null;

    // Save session
    try {
      await SkulMateService.saveGameSession(
        gameId: widget.game.id,
        score: _score,
        totalQuestions: _leftItems.length,
        correctAnswers: _score,
        timeTakenSeconds: timeTaken,
        answers: _matches.map((key, value) => MapEntry(key.toString(), value.toString())),
      );
    } catch (e) {
      print('Error saving game session: $e');
    }

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => GameResultsScreen(
            game: widget.game,
            score: _score,
            totalQuestions: _leftItems.length,
            timeTakenSeconds: timeTaken,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = _matches.length / _leftItems.length;

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
            child: Text(
              'Matches: ${_matches.length}/$_leftItems.length',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.primaryColor,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Progress bar
          LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
            minHeight: 4,
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  // Left column
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Match the items:',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textDark,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Expanded(
                          child: ListView.builder(
                            itemCount: _leftItems.length,
                            itemBuilder: (context, index) {
                              final isSelected = _selectedLeft == index;
                              final isMatched = _matches.containsKey(index);

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: InkWell(
                                  onTap: isMatched ? null : () => _selectLeft(index),
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: isMatched
                                          ? AppTheme.accentGreen.withOpacity(0.1)
                                          : isSelected
                                              ? AppTheme.primaryColor.withOpacity(0.1)
                                              : Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: isMatched
                                            ? AppTheme.accentGreen
                                            : isSelected
                                                ? AppTheme.primaryColor
                                                : Colors.grey.withOpacity(0.3),
                                        width: isMatched || isSelected ? 2 : 1,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            _leftItems[index],
                                            style: GoogleFonts.poppins(
                                              fontSize: 16,
                                              color: AppTheme.textDark,
                                            ),
                                          ),
                                        ),
                                        if (isMatched)
                                          const Icon(
                                            Icons.check_circle,
                                            color: AppTheme.accentGreen,
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Right column
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'To:',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textDark,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Expanded(
                          child: ListView.builder(
                            itemCount: _rightItems.length,
                            itemBuilder: (context, index) {
                              final isSelected = _selectedRight == index;
                              final isMatched = _matches.values.contains(index);

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: InkWell(
                                  onTap: isMatched ? null : () => _selectRight(index),
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: isMatched
                                          ? AppTheme.accentGreen.withOpacity(0.1)
                                          : isSelected
                                              ? AppTheme.primaryColor.withOpacity(0.1)
                                              : Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: isMatched
                                            ? AppTheme.accentGreen
                                            : isSelected
                                                ? AppTheme.primaryColor
                                                : Colors.grey.withOpacity(0.3),
                                        width: isMatched || isSelected ? 2 : 1,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            _rightItems[index],
                                            style: GoogleFonts.poppins(
                                              fontSize: 16,
                                              color: AppTheme.textDark,
                                            ),
                                          ),
                                        ),
                                        if (isMatched)
                                          const Icon(
                                            Icons.check_circle,
                                            color: AppTheme.accentGreen,
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
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

