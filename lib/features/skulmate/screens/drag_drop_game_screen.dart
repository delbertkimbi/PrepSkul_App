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

/// Drag-Drop game screen
class DragDropGameScreen extends StatefulWidget {
  final GameModel game;

  const DragDropGameScreen({Key? key, required this.game}) : super(key: key);

  @override
  State<DragDropGameScreen> createState() => _DragDropGameScreenState();
}

class DragItem {
  final String id;
  final String text;
  final String correctDropZoneId;
  String? currentDropZoneId;

  DragItem({
    required this.id,
    required this.text,
    required this.correctDropZoneId,
    this.currentDropZoneId,
  });
}

class DropZone {
  final String id;
  final String label;
  final Offset position;

  DropZone({
    required this.id,
    required this.label,
    required this.position,
  });
}

class _DragDropGameScreenState extends State<DragDropGameScreen>
    with TickerProviderStateMixin {
  List<DragItem> _dragItems = [];
  List<DropZone> _dropZones = [];
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
  String? _draggedItemId;

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
    _initializeItems();
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

  void _initializeItems() {
    if (widget.game.items.isNotEmpty) {
      final item = widget.game.items[0];
      if (item.dragItems != null) {
        for (final dragData in item.dragItems!) {
          _dragItems.add(DragItem(
            id: dragData['id']?.toString() ?? Random().nextInt(1000).toString(),
            text: dragData['text'] as String? ?? 'Item',
            correctDropZoneId: dragData['correctDropZoneId']?.toString() ?? '',
          ));
        }
      }
      if (item.dropZones != null) {
        for (int i = 0; i < item.dropZones!.length; i++) {
          final zoneData = item.dropZones![i];
          _dropZones.add(DropZone(
            id: zoneData['id']?.toString() ?? i.toString(),
            label: zoneData['label'] as String? ?? 'Zone $i',
            position: Offset(
              (zoneData['position']?['x'] as num?)?.toDouble() ?? 0.5,
              (zoneData['position']?['y'] as num?)?.toDouble() ?? 0.5,
            ),
          ));
        }
      }
    }
    
    if (_dragItems.isEmpty || _dropZones.isEmpty) {
      // Create default items
      _dragItems = [
        DragItem(id: '1', text: 'Item 1', correctDropZoneId: 'zone1'),
        DragItem(id: '2', text: 'Item 2', correctDropZoneId: 'zone2'),
      ];
      _dropZones = [
        DropZone(id: 'zone1', label: 'Zone 1', position: const Offset(0.3, 0.5)),
        DropZone(id: 'zone2', label: 'Zone 2', position: const Offset(0.7, 0.5)),
      ];
    }
  }

  void _onDragStart(String itemId) {
    safeSetState(() {
      _draggedItemId = itemId;
    });
  }

  void _onDragEnd(String itemId, String? dropZoneId) {
    final item = _dragItems.firstWhere((i) => i.id == itemId);
    
    if (dropZoneId != null) {
      final isCorrect = dropZoneId == item.correctDropZoneId;
      
      safeSetState(() {
        item.currentDropZoneId = dropZoneId;
        if (isCorrect) {
          _score += 10;
          _currentStreak++;
          _xpEarned += 5;
          _soundService.playCorrect();
          _confettiController.play();
          
          // Update progress
          final newProgress = _dragItems.where((i) => i.currentDropZoneId == i.correctDropZoneId).length / _dragItems.length;
          _progressAnimation = Tween<double>(
            begin: _progressAnimation.value,
            end: newProgress.clamp(0.0, 1.0),
          ).animate(CurvedAnimation(
            parent: _progressController,
            curve: Curves.easeOut,
          ));
          _progressController.forward(from: 0);
          
          // Check if game complete
          if (_dragItems.every((i) => i.currentDropZoneId == i.correctDropZoneId)) {
            Future.delayed(const Duration(milliseconds: 500), () {
              _finishGame();
            });
          }
        } else {
          _currentStreak = 0;
          _soundService.playIncorrect();
        }
      });
    }
    
    safeSetState(() {
      _draggedItemId = null;
    });
  }

  Future<void> _finishGame() async {
    final endTime = DateTime.now();
    final timeTaken = _startTime != null
        ? endTime.difference(_startTime!).inSeconds
        : null;

    final isPerfectScore = _dragItems.every((i) => i.currentDropZoneId == i.correctDropZoneId);

    int bonusXP = 0;
    if (isPerfectScore) bonusXP += 50;
    if (timeTaken != null && timeTaken < 120) bonusXP += 25;
    final totalXP = _xpEarned + bonusXP;

    try {
      await GameStatsService.addGameResult(
        correctAnswers: _dragItems.where((i) => i.currentDropZoneId == i.correctDropZoneId).length,
        totalQuestions: _dragItems.length,
        timeTakenSeconds: timeTaken ?? 0,
        isPerfectScore: isPerfectScore,
      );
    } catch (e) {
      LogService.error('🎮 [DragDrop] Error updating game stats: $e');
    }

    try {
      await SkulMateService.saveGameSession(
        gameId: widget.game.id,
        score: _score,
        totalQuestions: _dragItems.length,
        correctAnswers: _dragItems.where((i) => i.currentDropZoneId == i.correctDropZoneId).length,
        timeTakenSeconds: timeTaken,
        answers: {'matches': _dragItems.where((i) => i.currentDropZoneId == i.correctDropZoneId).length},
      );
    } catch (e) {
      LogService.error('🎮 [DragDrop] Error saving game session: $e');
    }

    await _soundService.playComplete();
    
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => GameResultsScreen(
            game: widget.game,
            score: _score,
            totalQuestions: _dragItems.length,
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
                  '${_dragItems.where((i) => i.currentDropZoneId == i.correctDropZoneId).length}/${_dragItems.length}',
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
                    'Drag Items:',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textDark,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _dragItems.length,
                      itemBuilder: (context, index) {
                        final item = _dragItems[index];
                        final isPlaced = item.currentDropZoneId != null;
                        
                        return Draggable<String>(
                          data: item.id,
                          onDragStarted: () => _onDragStart(item.id),
                          onDragEnd: (details) => _onDragEnd(item.id, null),
                          feedback: Material(
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                item.text,
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isPlaced
                                  ? Colors.green.withOpacity(0.2)
                                  : AppTheme.primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isPlaced
                                    ? Colors.green
                                    : AppTheme.primaryColor,
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    item.text,
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: AppTheme.textDark,
                                    ),
                                  ),
                                ),
                                if (isPlaced)
                                  const Icon(Icons.check_circle, color: Colors.green),
                              ],
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
                    child: Stack(
                      children: _dropZones.map((zone) {
                        final itemInZone = _dragItems.firstWhere(
                          (item) => item.currentDropZoneId == zone.id,
                          orElse: () => DragItem(id: '', text: '', correctDropZoneId: ''),
                        );
                        final hasItem = itemInZone.id.isNotEmpty;
                        
                        return Positioned(
                          left: zone.position.dx * 300,
                          top: zone.position.dy * 300,
                          child: DragTarget<String>(
                            onAccept: (itemId) => _onDragEnd(itemId, zone.id),
                            builder: (context, candidateData, rejectedData) {
                              return Container(
                                width: 120,
                                height: 120,
                                decoration: BoxDecoration(
                                  color: hasItem
                                      ? Colors.green.withOpacity(0.2)
                                      : Colors.grey[200],
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: candidateData.isNotEmpty
                                        ? AppTheme.primaryColor
                                        : hasItem
                                            ? Colors.green
                                            : Colors.grey[400]!,
                                    width: 2,
                                  ),
                                ),
                                child: Center(
                                  child: hasItem
                                      ? Text(
                                          itemInZone.text,
                                          style: GoogleFonts.poppins(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.green[800],
                                          ),
                                          textAlign: TextAlign.center,
                                        )
                                      : Text(
                                          zone.label,
                                          style: GoogleFonts.poppins(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                            color: AppTheme.textMedium,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                ),
                              );
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

