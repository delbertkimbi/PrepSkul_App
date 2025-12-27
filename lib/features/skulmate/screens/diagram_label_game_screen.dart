import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:confetti/confetti.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/core/utils/safe_set_state.dart';
import 'package:prepskul/core/services/log_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/game_model.dart';
import '../services/skulmate_service.dart';
import '../services/game_sound_service.dart';
import '../services/character_selection_service.dart';
import '../services/game_stats_service.dart';
import '../models/game_stats_model.dart';
import '../widgets/skulmate_character_widget.dart';
import 'game_results_screen.dart';

/// Diagram Label game screen
class DiagramLabelGameScreen extends StatefulWidget {
  final GameModel game;

  const DiagramLabelGameScreen({Key? key, required this.game}) : super(key: key);

  @override
  State<DiagramLabelGameScreen> createState() => _DiagramLabelGameScreenState();
}

class LabelData {
  final String id;
  final String label;
  final Offset correctPosition;
  Offset? currentPosition;
  final bool isPlaced;

  LabelData({
    required this.id,
    required this.label,
    required this.correctPosition,
    this.currentPosition,
    this.isPlaced = false,
  });
}

class _DiagramLabelGameScreenState extends State<DiagramLabelGameScreen>
    with TickerProviderStateMixin {
  String? _imageUrl;
  List<LabelData> _labels = [];
  List<LabelData> _availableLabels = [];
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
  String? _selectedLabelId;
  Offset? _imageSize;

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
    _initializeLabels();
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

  void _initializeLabels() {
    if (widget.game.items.isNotEmpty) {
      final item = widget.game.items[0];
      if (item.imageUrl != null) {
        _imageUrl = item.imageUrl;
      }
      if (item.diagramLabels != null) {
        for (final labelData in item.diagramLabels!) {
          _labels.add(LabelData(
            id: labelData['id']?.toString() ?? Random().nextInt(1000).toString(),
            label: labelData['label'] as String? ?? 'Label',
            correctPosition: Offset(
              (labelData['x'] as num?)?.toDouble() ?? 0.5,
              (labelData['y'] as num?)?.toDouble() ?? 0.5,
            ),
          ));
        }
      }
    }
    
    if (_labels.isEmpty) {
      // Create default labels
      _labels = [
        LabelData(id: '1', label: 'Label 1', correctPosition: const Offset(0.3, 0.3)),
        LabelData(id: '2', label: 'Label 2', correctPosition: const Offset(0.7, 0.5)),
      ];
    }
    
    _availableLabels = List.from(_labels);
  }

  void _onLabelTap(String labelId) {
    safeSetState(() {
      _selectedLabelId = _selectedLabelId == labelId ? null : labelId;
    });
  }

  void _onImageTap(Offset localPosition, Size imageSize) {
    if (_selectedLabelId == null) return;
    
    final label = _availableLabels.firstWhere((l) => l.id == _selectedLabelId);
    final normalizedPosition = Offset(
      localPosition.dx / imageSize.width,
      localPosition.dy / imageSize.height,
    );
    
    // Check if position is close to correct position (within 10% tolerance)
    final distance = (normalizedPosition - label.correctPosition).distance;
    final isCorrect = distance < 0.1;
    
    safeSetState(() {
      label.currentPosition = normalizedPosition;
      if (isCorrect) {
        _labels.removeWhere((l) => l.id == label.id);
        _availableLabels.removeWhere((l) => l.id == label.id);
        _score += 10;
        _currentStreak++;
        _xpEarned += 5;
        _soundService.playCorrect();
        _confettiController.play();
        
        // Update progress
        final newProgress = (_labels.length - _availableLabels.length) / _labels.length;
        _progressAnimation = Tween<double>(
          begin: _progressAnimation.value,
          end: newProgress.clamp(0.0, 1.0),
        ).animate(CurvedAnimation(
          parent: _progressController,
          curve: Curves.easeOut,
        ));
        _progressController.forward(from: 0);
        
        // Check if game complete
        if (_availableLabels.isEmpty) {
          Future.delayed(const Duration(milliseconds: 500), () {
            _finishGame();
          });
        }
      } else {
        _currentStreak = 0;
        _soundService.playIncorrect();
      }
      _selectedLabelId = null;
    });
  }

  Future<void> _finishGame() async {
    final endTime = DateTime.now();
    final timeTaken = _startTime != null
        ? endTime.difference(_startTime!).inSeconds
        : null;

    final isPerfectScore = _availableLabels.isEmpty;

    int bonusXP = 0;
    if (isPerfectScore) bonusXP += 50;
    if (timeTaken != null && timeTaken < 180) bonusXP += 25;
    final totalXP = _xpEarned + bonusXP;

    try {
      await GameStatsService.addGameResult(
        correctAnswers: _labels.length - _availableLabels.length,
        totalQuestions: _labels.length,
        timeTakenSeconds: timeTaken ?? 0,
        isPerfectScore: isPerfectScore,
      );
    } catch (e) {
      LogService.error('🎮 [DiagramLabel] Error updating game stats: $e');
    }

    try {
      await SkulMateService.saveGameSession(
        gameId: widget.game.id,
        score: _score,
        totalQuestions: _labels.length,
        correctAnswers: _labels.length - _availableLabels.length,
        timeTakenSeconds: timeTaken,
        answers: {'labels': _labels.length - _availableLabels.length},
      );
    } catch (e) {
      LogService.error('🎮 [DiagramLabel] Error saving game session: $e');
    }

    await _soundService.playComplete();
    
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => GameResultsScreen(
            game: widget.game,
            score: _score,
            totalQuestions: _labels.length,
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
                  'Score: $_score',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryColor,
                  ),
                ),
                Text(
                  '${_labels.length - _availableLabels.length}/${_labels.length}',
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
                    child: GestureDetector(
                      onTapDown: (details) {
                        final RenderBox box = context.findRenderObject() as RenderBox;
                        final localPosition = box.globalToLocal(details.globalPosition);
                        final imageSize = box.size;
                        _onImageTap(localPosition, imageSize);
                      },
                      child: Stack(
                        children: [
                          if (_imageUrl != null)
                            CachedNetworkImage(
                              imageUrl: _imageUrl!,
                              fit: BoxFit.contain,
                              placeholder: (context, url) => const Center(
                                child: CircularProgressIndicator(),
                              ),
                              errorWidget: (context, url, error) => const Center(
                                child: Icon(Icons.error),
                              ),
                            )
                          else
                            Container(
                              color: Colors.grey[200],
                              child: const Center(
                                child: Text('No diagram image available'),
                              ),
                            ),
                          // Show placed labels
                          for (final label in _labels)
                            if (label.currentPosition != null)
                              Positioned(
                                left: label.currentPosition!.dx * 300,
                                top: label.currentPosition!.dy * 300,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryColor,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    label.label,
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
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
                    'Labels to Place:',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textDark,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _availableLabels.length,
                      itemBuilder: (context, index) {
                        final label = _availableLabels[index];
                        final isSelected = _selectedLabelId == label.id;
                        
                        return GestureDetector(
                          onTap: () => _onLabelTap(label.id),
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppTheme.primaryColor.withOpacity(0.2)
                                  : Colors.grey[100],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isSelected
                                    ? AppTheme.primaryColor
                                    : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: Text(
                              label.label,
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: AppTheme.textDark,
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
          ),
        ],
      ),
    );
  }
}

