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
  final VoidCallback? onShare;

  const GameCard({
    Key? key,
    required this.game,
    required this.onTap,
    this.onDelete,
    this.onShare,
  }) : super(key: key);

  @override
  State<GameCard> createState() => _GameCardState();
}

class _GameCardState extends State<GameCard> with AutomaticKeepAliveClientMixin {
  Map<String, dynamic>? _stats;
  bool _isFavorite = false;
  
  @override
  bool get wantKeepAlive => true; // Keep widget alive when scrolled off-screen
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
      case GameType.match3:
        return Icons.grid_view;
      case GameType.bubblePop:
        return Icons.bubble_chart;
      case GameType.wordSearch:
        return Icons.search;
      case GameType.crossword:
        return Icons.grid_4x4;
      case GameType.diagramLabel:
        return Icons.label;
      case GameType.dragDrop:
        return Icons.drag_handle;
      case GameType.puzzlePieces:
        return Icons.extension;
      case GameType.simulation:
        return Icons.sim_card;
      case GameType.mystery:
        return Icons.search;
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
      case GameType.match3:
        return 'Match-3';
      case GameType.bubblePop:
        return 'Bubble Pop';
      case GameType.wordSearch:
        return 'Word Search';
      case GameType.crossword:
        return 'Crossword';
      case GameType.diagramLabel:
        return 'Diagram Label';
      case GameType.dragDrop:
        return 'Drag & Drop';
      case GameType.puzzlePieces:
        return 'Puzzle Pieces';
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
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    final accentColor = _accentColorForGameType(widget.game.gameType);
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: AppTheme.softCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.softBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left content: icon + game info (extra left/top for nicer fill)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 6, top: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Game icon
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: accentColor.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          _gameIcon,
                          color: accentColor,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Game info
                      Expanded(
                        child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.game.title,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textDark,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: accentColor.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _gameTypeLabel,
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: accentColor,
                            ),
                          ),
                        ),
                        // Difficulty indicator
                        if (widget.game.metadata.difficulty != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: _getDifficultyColor(widget.game.metadata.difficulty!).withOpacity(0.08),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              widget.game.metadata.difficulty!.toUpperCase(),
                              style: GoogleFonts.poppins(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                color: _getDifficultyColor(widget.game.metadata.difficulty!),
                              ),
                            ),
                          ),
                        Text(
                          '${widget.game.items.length} items',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: AppTheme.textMedium,
                          ),
                        ),
                      ],
                    ),
                    if (_stats != null && _stats!['timesPlayed'] > 0) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 12,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.star,
                                size: 14,
                                color: Colors.amber[700],
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  'Best: ${_stats!['bestScore']}/${widget.game.items.length}',
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.amber[700],
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
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
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      _formatDate(widget.game.createdAt),
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: AppTheme.textMedium,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ],
                ),
                      ),
                    ],
                  ),
                ),
              ),
              // Actions — favourite and share in a row (delete via swipe)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  InkWell(
                    onTap: _toggleFavorite,
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Icon(
                        _isFavorite ? Icons.favorite : Icons.favorite_border,
                        size: 22,
                      color: _isFavorite ? accentColor : AppTheme.textMedium,
                      ),
                    ),
                  ),
                  if (widget.onShare != null) ...[
                    const SizedBox(width: 4),
                    InkWell(
                      onTap: widget.onShare,
                      borderRadius: BorderRadius.circular(20),
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: Icon(Icons.share_outlined, size: 20, color: AppTheme.textMedium),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        ),
      ),
    );
  }

  Color _getDifficultyColor(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'easy':
        return Colors.green;
      case 'medium':
        return Colors.orange;
      case 'hard':
        return Colors.red;
      default:
        return AppTheme.textMedium;
    }
  }

  Color _accentColorForGameType(GameType type) {
    switch (type) {
      case GameType.quiz:
        return AppTheme.accentPurple;
      case GameType.flashcards:
        return AppTheme.accentOrange;
      case GameType.matching:
        return AppTheme.skyBlue;
      case GameType.fillBlank:
        return AppTheme.accentGreen;
      case GameType.match3:
        return AppTheme.accentPurple;
      case GameType.bubblePop:
        return AppTheme.accentPink;
      case GameType.wordSearch:
        return AppTheme.accentBlue;
      case GameType.crossword:
        return AppTheme.accentOrange;
      case GameType.diagramLabel:
        return AppTheme.accentPink;
      case GameType.dragDrop:
        return AppTheme.accentGreen;
      case GameType.puzzlePieces:
        return AppTheme.accentOrange;
      case GameType.simulation:
        return AppTheme.accentPurple;
      case GameType.mystery:
        return AppTheme.accentPink;
      case GameType.escapeRoom:
        return AppTheme.skyBlue;
    }
  }

  IconData _getDifficultyIcon(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'easy':
        return Icons.trending_down;
      case 'medium':
        return Icons.trending_flat;
      case 'hard':
        return Icons.trending_up;
      default:
        return Icons.help_outline;
    }
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