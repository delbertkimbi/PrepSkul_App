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

/// Puzzle Pieces game screen
class PuzzlePiecesGameScreen extends StatefulWidget {
  final GameModel game;

  const PuzzlePiecesGameScreen({Key? key, required this.game}) : super(key: key);

  @override
  State<PuzzlePiecesGameScreen> createState() => _PuzzlePiecesGameScreenState();
}

class PuzzlePiece {
  final String id;
  final String text;
  final Offset correctPosition;
  Offset? currentPosition;
  final double rotation;
  bool isPlaced;

  PuzzlePiece({
    required this.id,
    required this.text,
    required this.correctPosition,
    this.currentPosition,
    this.rotation = 0.0,
    this.isPlaced = false,
  });
}

class _PuzzlePiecesGameScreenState extends State<PuzzlePiecesGameScreen>
    with TickerProviderStateMixin {
  String? _imageUrl;
  List<PuzzlePiece> _pieces = [];
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
  String? _selectedPieceId;

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
    _initializePieces();
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

  void _initializePieces() {
    if (widget.game.items.isNotEmpty) {
      final item = widget.game.items[0];
      if (item.imageUrl != null) {
        _imageUrl = item.imageUrl;
      }
      if (item.puzzlePieces != null) {
        for (final pieceData in item.puzzlePieces!) {
          _pieces.add(PuzzlePiece(
            id: pieceData['id']?.toString() ?? Random().nextInt(1000).toString(),
            text: pieceData['text'] as String? ?? 'Piece',
            correctPosition: Offset(
              (pieceData['correctPosition']?['x'] as num?)?.toDouble() ?? 0.5,
              (pieceData['correctPosition']?['y'] as num?)?.toDouble() ?? 0.5,
            ),
            rotation: (pieceData['rotation'] as num?)?.toDouble() ?? 0.0,
            currentPosition: Offset(
              Random().nextDouble() * 200 + 50,
              Random().nextDouble() * 400 + 100,
            ),
          ));
        }
      }
    }
    
    if (_pieces.isEmpty) {
      // Create default pieces
      _pieces = [
        PuzzlePiece(
          id: '1',
          text: 'Piece 1',
          correctPosition: const Offset(100, 100),
          currentPosition: const Offset(50, 200),
        ),
        PuzzlePiece(
          id: '2',
          text: 'Piece 2',
          correctPosition: const Offset(200, 100),
          currentPosition: const Offset(150, 300),
        ),
      ];
    }
  }

  void _onPieceTap(String pieceId) {
    safeSetState(() {
      _selectedPieceId = _selectedPieceId == pieceId ? null : pieceId;
    });
  }

  void _onPieceDrag(String pieceId, Offset newPosition) {
    final piece = _pieces.firstWhere((p) => p.id == pieceId);
    final distance = (newPosition - piece.correctPosition).distance;
    final isCorrect = distance < 30; // 30 pixel tolerance
    
    safeSetState(() {
      piece.currentPosition = newPosition;
      if (isCorrect && !piece.isPlaced) {
        piece.currentPosition = piece.correctPosition;
        piece.isPlaced = true;
        _score += 10;
        _currentStreak++;
        _xpEarned += 5;
        _soundService.playPiecePlace();
        _confettiController.play();
        
        // Update progress
        final newProgress = _pieces.where((p) => p.isPlaced).length / _pieces.length;
        _progressAnimation = Tween<double>(
          begin: _progressAnimation.value,
          end: newProgress.clamp(0.0, 1.0),
        ).animate(CurvedAnimation(
          parent: _progressController,
          curve: Curves.easeOut,
        ));
        _progressController.forward(from: 0);
        
        // Check if game complete
        if (_pieces.every((p) => p.isPlaced)) {
          Future.delayed(const Duration(milliseconds: 500), () {
            _finishGame();
          });
        }
      }
    });
  }

  Future<void> _finishGame() async {
    final endTime = DateTime.now();
    final timeTaken = _startTime != null
        ? endTime.difference(_startTime!).inSeconds
        : null;

    final isPerfectScore = _pieces.every((p) => p.isPlaced);

    int bonusXP = 0;
    if (isPerfectScore) bonusXP += 50;
    if (timeTaken != null && timeTaken < 180) bonusXP += 25;
    final totalXP = _xpEarned + bonusXP;

    try {
      await GameStatsService.addGameResult(
        correctAnswers: _pieces.where((p) => p.isPlaced).length,
        totalQuestions: _pieces.length,
        timeTakenSeconds: timeTaken ?? 0,
        isPerfectScore: isPerfectScore,
      );
    } catch (e) {
      LogService.error('🎮 [PuzzlePieces] Error updating game stats: $e');
    }

    try {
      await SkulMateService.saveGameSession(
        gameId: widget.game.id,
        score: _score,
        totalQuestions: _pieces.length,
        correctAnswers: _pieces.where((p) => p.isPlaced).length,
        timeTakenSeconds: timeTaken,
        answers: {'pieces': _pieces.where((p) => p.isPlaced).length},
      );
    } catch (e) {
      LogService.error('🎮 [PuzzlePieces] Error saving game session: $e');
    }

    await _soundService.playComplete();
    
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => GameResultsScreen(
            game: widget.game,
            score: _score,
            totalQuestions: _pieces.length,
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
                  '${_pieces.where((p) => p.isPlaced).length}/${_pieces.length}',
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
      body: Column(
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
            child: Stack(
              children: [
                if (_imageUrl != null)
                  Positioned.fill(
                    child: CachedNetworkImage(
                      imageUrl: _imageUrl!,
                      fit: BoxFit.contain,
                      placeholder: (context, url) => const Center(
                        child: CircularProgressIndicator(),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: Colors.grey[200],
                        child: const Center(
                          child: Text('No puzzle image available'),
                        ),
                      ),
                    ),
                  ),
                // Puzzle pieces
                for (final piece in _pieces)
                  Positioned(
                    left: piece.currentPosition?.dx ?? 0,
                    top: piece.currentPosition?.dy ?? 0,
                    child: GestureDetector(
                      onTap: () => _onPieceTap(piece.id),
                      onPanUpdate: (details) {
                        _onPieceDrag(
                          piece.id,
                          Offset(
                            (piece.currentPosition?.dx ?? 0) + details.delta.dx,
                            (piece.currentPosition?.dy ?? 0) + details.delta.dy,
                          ),
                        );
                      },
                      child: Transform.rotate(
                        angle: piece.rotation,
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: piece.isPlaced
                                ? Colors.green.withOpacity(0.8)
                                : AppTheme.primaryColor.withOpacity(0.8),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _selectedPieceId == piece.id
                                  ? Colors.yellow
                                  : Colors.white,
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              piece.text,
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (_character != null)
            SkulMateCharacterWidget(
              character: _character,
              size: 80,
            ),
        ],
      ),
    );
  }
}

