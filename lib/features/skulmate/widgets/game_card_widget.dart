import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import '../models/game_model.dart';
import '../services/skulmate_service.dart';

/// Card widget for displaying a game in the library
class GameCard extends StatefulWidget {
  final GameModel game;
  final VoidCallback onTap;
  final VoidCallback? onDelete;
  final VoidCallback? onPreview;
  final VoidCallback? onShare;

  const GameCard({
    Key? key,
    required this.game,
    required this.onTap,
    this.onDelete,
    this.onPreview,
    this.onShare,
  }) : super(key: key);

  @override
  State<GameCard> createState() => _GameCardState();
}

class _GameCardState extends State<GameCard> {
  Map<String, dynamic>? _stats;
  bool _isFavorite = false;
  bool _isLoadingStats = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
    _loadFavorite();
  }

  Future<void> _loadStats() async {
    try {
      final stats = await SkulMateService.getGameStats(widget.game.id);
      if (mounted) {
        setState(() {
          _stats = stats;
          _isLoadingStats = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingStats = false;
        });
      }
    }
  }

  Future<void> _loadFavorite() async {
    final isFav = await SkulMateService.isFavorite(widget.game.id);
    if (mounted) {
      setState(() {
        _isFavorite = isFav;
      });
    }
  }

  Future<void> _toggleFavorite() async {
    final newFavorite = await SkulMateService.toggleFavorite(widget.game.id);
    if (mounted) {
      setState(() {
        _isFavorite = newFavorite;
      });
    }
  }

  IconData get _gameIcon {
    switch (widget.game.gameType) {
      case GameType.quiz:
        return Icons.quiz;
      case GameType.flashcards:
        return Icons.style;
      case GameType.matching:
        return Icons.compare_arrows;
      case GameType.fillBlank:
        return Icons.edit;
      case GameType.bubblePop:
        return Icons.bubble_chart;
      case GameType.dragDrop:
        return Icons.drag_indicator;
      case GameType.wordSearch:
        return Icons.search;
      case GameType.crossword:
        return Icons.grid_on;
      case GameType.match3:
        return Icons.apps;
      case GameType.diagramLabel:
        return Icons.label;
      case GameType.puzzlePieces:
        return Icons.extension;
      case GameType.simulation:
        return Icons.play_circle;
      case GameType.mystery:
        return Icons.help_outline;
      case GameType.escapeRoom:
        return Icons.lock;
    }
  }

  String get _gameTypeLabel {
    switch (widget.game.gameType) {
      case GameType.quiz:
        return 'Quiz';
      case GameType.flashcards:
        return 'Flashcards';
      case GameType.matching:
        return 'Matching';
      case GameType.fillBlank:
        return 'Fill in Blank';
      case GameType.bubblePop:
        return 'Bubble Pop';
      case GameType.dragDrop:
        return 'Drag & Drop';
      case GameType.wordSearch:
        return 'Word Search';
      case GameType.crossword:
        return 'Crossword';
      case GameType.match3:
        return 'Match-3';
      case GameType.diagramLabel:
        return 'Diagram Label';
      case GameType.puzzlePieces:
        return 'Puzzle';
      case GameType.simulation:
        return 'Simulation';
      case GameType.mystery:
        return 'Mystery';
      case GameType.escapeRoom:
        return 'Escape Room';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Game icon
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.primaryColor,
                      AppTheme.primaryColor.withOpacity(0.7),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _gameIcon,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              // Game info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            widget.game.title,
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textDark,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (_isFavorite)
                          Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: Icon(
                              Icons.favorite,
                              size: 18,
                              color: Colors.red[400],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _gameTypeLabel,
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${widget.game.items.length} items',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: AppTheme.textMedium,
                          ),
                        ),
                      ],
                    ),
                    if (_stats != null && _stats!['timesPlayed'] > 0) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.star,
                            size: 14,
                            color: Colors.amber[700],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Best: ${_stats!['bestScore']}/${widget.game.items.length}',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.amber[700],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Icon(
                            Icons.replay,
                            size: 14,
                            color: AppTheme.textMedium,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${_stats!['timesPlayed']}x',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: AppTheme.textMedium,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      _formatDate(widget.game.createdAt),
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: AppTheme.textMedium,
                      ),
                    ),
                  ],
                ),
              ),
              // Actions
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(
                      _isFavorite ? Icons.favorite : Icons.favorite_border,
                      color: _isFavorite ? Colors.red[400] : AppTheme.textMedium,
                    ),
                    onPressed: _toggleFavorite,
                    tooltip: _isFavorite ? 'Remove from favorites' : 'Add to favorites',
                  ),
                  if (widget.onShare != null)
                    IconButton(
                      icon: const Icon(Icons.share),
                      color: AppTheme.primaryColor,
                      onPressed: widget.onShare,
                      tooltip: 'Share game',
                    ),
                  if (widget.onPreview != null)
                    IconButton(
                      icon: const Icon(Icons.preview),
                      color: AppTheme.primaryColor,
                      onPressed: widget.onPreview,
                      tooltip: 'Preview game',
                    ),
                  if (widget.onDelete != null)
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      color: Colors.red,
                      onPressed: widget.onDelete,
                      tooltip: 'Delete game',
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}
