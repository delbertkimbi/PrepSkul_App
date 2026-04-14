import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:confetti/confetti.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/core/utils/safe_set_state.dart';
import 'package:prepskul/core/services/log_service.dart';
import '../models/game_model.dart';
import '../models/skulmate_character_model.dart';
import '../services/skulmate_service.dart';
import '../services/game_sound_service.dart';
import '../services/character_selection_service.dart';
import '../services/game_stats_service.dart';
import '../models/game_stats_model.dart';
import '../widgets/skulmate_character_widget.dart';
import '../widgets/skulmate_game_app_bar.dart';
import '../widgets/game_standard_widgets.dart';
import 'game_results_screen.dart';

/// Simulation game screen - Decision-based life games
/// Examples: "Diagnose the Patient", "Run a Small Business", "Lead a Nation Through Crisis"
/// Wrong understanding → consequences, not red Xs
class SimulationGameScreen extends StatefulWidget {
  final GameModel game;

  const SimulationGameScreen({Key? key, required this.game}) : super(key: key);

  @override
  State<SimulationGameScreen> createState() => _SimulationGameScreenState();
}

class _SimulationGameScreenState extends State<SimulationGameScreen>
    with TickerProviderStateMixin {
  int _currentScenarioIndex = 0;
  final Map<int, String?> _selectedActions = {};
  final Map<int, Map<String, dynamic>> _consequences = {};
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
  String? _role;
  List<Map<String, dynamic>>? _scenarios;

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();
    _soundService.initialize();
    unawaited(_soundService.playMusicForGame(widget.game.gameType));
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 2),
    );
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
    _role = firstItem.role ?? 'Decision Maker';
    _scenarios = firstItem.scenarios ?? [];

    // If scenarios not in first item, try to extract from gameData
    if (_scenarios == null || _scenarios!.isEmpty) {
      final gameData = firstItem.gameData;
      if (gameData != null) {
        _role = gameData['role'] as String? ?? _role;
        if (gameData['scenarios'] != null) {
          _scenarios = List<Map<String, dynamic>>.from(
            gameData['scenarios'] as List,
          );
        }
      }
    }

    LogService.debug(
      'Simulation game: Role=$_role, Scenarios=${_scenarios?.length ?? 0}',
    );
  }

  @override
  void dispose() {
    unawaited(_soundService.stopMusic(force: true));
    _progressController.dispose();
    _confettiController.dispose();
    super.dispose();
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

  void _selectAction(String action) {
    if (_selectedActions.containsKey(_currentScenarioIndex)) return;
    if (_scenarios == null || _currentScenarioIndex >= _scenarios!.length)
      return;

    final scenario = _scenarios![_currentScenarioIndex];
    final consequences =
        scenario['consequences'] as Map<String, dynamic>? ?? {};
    final consequence = consequences[action] as String? ?? 'Action taken.';

    // Determine if this is a "good" decision based on consequence
    // Positive consequences indicate good understanding
    final isGoodDecision =
        !consequence.toLowerCase().contains('fail') &&
        !consequence.toLowerCase().contains('wrong') &&
        !consequence.toLowerCase().contains('error');

    int baseXP = 15;
    int streakMultiplier = _currentStreak > 0 ? (1 + (_currentStreak ~/ 3)) : 1;
    int xpForThisAction = baseXP * streakMultiplier;

    safeSetState(() {
      _selectedActions[_currentScenarioIndex] = action;
      _consequences[_currentScenarioIndex] = {
        'action': action,
        'consequence': consequence,
        'isGood': isGoodDecision,
      };
      if (isGoodDecision) {
        _score++;
        _currentStreak++;
        _xpEarned += xpForThisAction;
        _soundService.playCorrect();
      } else {
        _currentStreak = 0;
        _soundService.playIncorrect();
      }
    });

    // Show consequence feedback
    _showConsequenceDialog(consequence, isGoodDecision);
  }

  void _showConsequenceDialog(String consequence, bool isGood) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          isGood ? '✓ Decision Made' : 'Decision Impact',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: isGood ? AppTheme.accentGreen : AppTheme.primaryColor,
          ),
        ),
        content: Text(consequence, style: GoogleFonts.poppins(fontSize: 16)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _nextScenario();
            },
            child: Text(
              'Continue',
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

  void _nextScenario() {
    if (_scenarios == null) return;

    if (_currentScenarioIndex < _scenarios!.length - 1) {
      safeSetState(() {
        _currentScenarioIndex++;
      });
      _progressController.forward(from: 0);
      _progressAnimation =
          Tween<double>(
            begin: 0,
            end: (_currentScenarioIndex + 1) / _scenarios!.length,
          ).animate(
            CurvedAnimation(parent: _progressController, curve: Curves.easeOut),
          );
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

    // Calculate final score and XP
    final totalScenarios = _scenarios?.length ?? 1;
    final percentage = (_score / totalScenarios * 100).round();

    if (widget.game.userId.isNotEmpty) {
      unawaited(
        GameStatsService.recordGameCompletion(
          gameId: widget.game.id,
          score: _score,
          totalItems: totalScenarios,
          xpEarned: _xpEarned,
          duration: Duration(seconds: duration),
          streak: _currentStreak,
        ).catchError((e) {
          LogService.error('Failed to save game stats: $e');
        }),
      );
    }

    // Don't block navigation on audio playback.
    unawaited(_soundService.playComplete());

    // Navigate to results screen
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => GameResultsScreen(
            game: widget.game,
            score: _score,
            totalQuestions: totalScenarios,
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
    if (_scenarios == null || _scenarios!.isEmpty) {
      return Scaffold(
        appBar: SkulMateGameAppBar(title: widget.game.title),
        body: Center(
          child: Text('No scenarios available', style: GoogleFonts.poppins()),
        ),
      );
    }

    final scenario = _scenarios![_currentScenarioIndex];
    final situation =
        scenario['situation'] as String? ??
        'A situation requires your decision.';
    final actions =
        (scenario['actions'] as List<dynamic>?)
            ?.map((a) => a.toString())
            .toList() ??
        [];
    final hasSelected = _selectedActions.containsKey(_currentScenarioIndex);

    return Scaffold(
      backgroundColor: AppTheme.softBackground,
      appBar: SkulMateGameAppBar(
        title: widget.game.title,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 4, left: 0),
            child: CircleAvatar(
              radius: 16,
              backgroundColor: Colors.white.withOpacity(0.22),
              child: ClipOval(
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: const SkulMateCharacterWidget(
                    character: SkulMateCharacters.middleMale,
                    size: 24,
                    animated: false,
                    showName: false,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            child: GameStandardsHud(
              progressText:
                  'Scenario ${_currentScenarioIndex + 1} of ${_scenarios!.length}',
              progressValue:
                  ((_currentScenarioIndex + 1) / _scenarios!.length).clamp(
                    0.0,
                    1.0,
                  ),
              xpEarned: _xpEarned,
              gameType: widget.game.gameType,
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Role display
                  if (_role != null)
                    FlatStageCard(
                      padding: const EdgeInsets.all(16),
                      backgroundColor: AppTheme.primaryColor.withOpacity(0.08),
                      borderColor: AppTheme.primaryColor.withOpacity(0.2),
                      child: Row(
                        children: [
                          Icon(Icons.person, color: AppTheme.primaryColor),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Role: $_role',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 24),

                  // Scenario number
                  Text(
                    'Scenario ${_currentScenarioIndex + 1} of ${_scenarios!.length}',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: AppTheme.textMedium,
                      fontWeight: FontWeight.w500,
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Situation
                  FlatStageCard(
                    padding: const EdgeInsets.all(20),
                    radius: 16,
                    backgroundColor: Colors.white,
                    borderColor: AppTheme.primaryColor.withOpacity(0.14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Situation',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textDark,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          situation,
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

                  // Actions
                  Text(
                    'What would you do?',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textDark,
                    ),
                  ),

                  const SizedBox(height: 16),

                  ...actions.asMap().entries.map((entry) {
                    final index = entry.key;
                    final action = entry.value;
                    final isSelected =
                        _selectedActions[_currentScenarioIndex] == action;
                    final consequence = _consequences[_currentScenarioIndex];
                    final isGood = consequence?['isGood'] == true;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: GestureDetector(
                        onTap: hasSelected ? null : () => _selectAction(action),
                        child: FlatStageCard(
                          padding: const EdgeInsets.all(16),
                          borderColor: isSelected
                              ? (isGood
                                    ? AppTheme.accentGreen
                                    : AppTheme.primaryColor)
                              : AppTheme.textLight.withOpacity(0.3),
                          backgroundColor: isSelected
                              ? (isGood
                                    ? AppTheme.accentGreen.withOpacity(0.1)
                                    : AppTheme.primaryColor.withOpacity(0.1))
                              : Colors.white,
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  action,
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    color: AppTheme.textDark,
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                  ),
                                ),
                              ),
                              if (isSelected)
                                Icon(
                                  isGood ? Icons.check_circle : Icons.info,
                                  color: isGood
                                      ? AppTheme.accentGreen
                                      : AppTheme.primaryColor,
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),

                  // Show consequence if selected
                  if (hasSelected) ...[
                    const SizedBox(height: 24),
                    Builder(
                      builder: (context) {
                        final consequence =
                            _consequences[_currentScenarioIndex];
                        if (consequence == null) return const SizedBox.shrink();
                        final isGood = consequence['isGood'] == true;
                        return FlatStageCard(
                          padding: const EdgeInsets.all(16),
                          backgroundColor:
                              (isGood
                                      ? AppTheme.accentGreen
                                      : AppTheme.primaryColor)
                                  .withOpacity(0.1),
                          borderColor: isGood
                              ? AppTheme.accentGreen
                              : AppTheme.primaryColor,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    isGood ? Icons.check_circle : Icons.info,
                                    color: isGood
                                        ? AppTheme.accentGreen
                                        : AppTheme.primaryColor,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Consequence',
                                    style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: isGood
                                          ? AppTheme.accentGreen
                                          : AppTheme.primaryColor,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                consequence['consequence'] as String,
                                style: GoogleFonts.poppins(
                                  fontSize: 15,
                                  color: AppTheme.textDark,
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Next button
                  if (hasSelected)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _nextScenario,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          _currentScenarioIndex < _scenarios!.length - 1
                              ? 'Next Scenario'
                              : 'Complete Game',
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
          ),
        ],
      ),
    );
  }
}
