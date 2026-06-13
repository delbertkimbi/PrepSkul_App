import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import '../models/game_model.dart';
import '../services/skulmate_service.dart';
import '../utils/game_type_visuals.dart';
import 'skulmate_surface_styles.dart';

/// Card widget for displaying a game in the library
class GameCard extends StatefulWidget {
  final GameModel game;
  final VoidCallback onTap;
  final VoidCallback? onDelete;
  final VoidCallback? onShare;
  final bool compact;
  /// Tighter layout for horizontal carousels on the home screen.
  final bool horizontal;
  /// Optional subtitle override (e.g. progress hint).
  final String? subtitleOverride;

  const GameCard({
    Key? key,
    required this.game,
    required this.onTap,
    this.onDelete,
    this.onShare,
    this.compact = false,
    this.horizontal = false,
    this.subtitleOverride,
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
    if (!widget.compact) {
      _loadStats();
      _loadFavorite();
    }
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

  IconData get _gameIcon => GameTypeVisuals.iconFor(widget.game.gameType);

  String get _gameTypeLabel => GameTypeVisuals.labelFor(widget.game.gameType);

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    final accentColor = GameTypeVisuals.accentColorFor(widget.game.gameType);
    final c = widget.compact;
    final h = widget.horizontal && c;
    final cardRadius = h ? 12.0 : (c ? 13.0 : 14.0);
    final hPad = h ? 10.0 : (c ? 11.0 : 14.0);
    final vPad = h ? 8.0 : (c ? 9.0 : 12.0);
    final iconSize = h ? 34.0 : (c ? 36.0 : 42.0);
    final iconInner = h ? 17.0 : (c ? 18.0 : 20.0);
    final iconRadius = h ? 9.0 : (c ? 10.0 : 12.0);
    final titleSize = h ? 13.0 : (c ? 13.0 : 14.0);
    final metaSize = h ? 10.0 : (c ? 10.0 : 11.0);
    final favSize = c ? 20.0 : 22.0;
    final metaLine = widget.subtitleOverride ??
        '$_gameTypeLabel · ${widget.game.items.length} items';

    if (c) {
      return Container(
        margin: const EdgeInsets.only(bottom: 2),
        decoration: SkulMateSurfaceStyles.homeCard(
          radius: cardRadius,
          compact: true,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(cardRadius),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
              child: Row(
                children: [
                  if (h)
                    Container(
                      width: 3,
                      height: iconSize + 4,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: accentColor,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  Container(
                    width: iconSize,
                    height: iconSize,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          accentColor.withValues(alpha: 0.18),
                          accentColor.withValues(alpha: 0.08),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(iconRadius),
                    ),
                    child: Icon(
                      _gameIcon,
                      color: accentColor,
                      size: iconInner,
                    ),
                  ),
                  SizedBox(width: h ? 8 : 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          widget.game.title,
                          style: GoogleFonts.poppins(
                            fontSize: titleSize,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textDark,
                            height: 1.15,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: h ? 2 : 3),
                        Text(
                          metaLine,
                          style: GoogleFonts.poppins(
                            fontSize: metaSize,
                            color: AppTheme.textMedium,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (!h)
                    Icon(
                      Icons.chevron_right_rounded,
                      color: AppTheme.textMedium.withValues(alpha: 0.7),
                      size: 22,
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      margin: EdgeInsets.only(bottom: c ? 2 : 4),
      decoration: SkulMateSurfaceStyles.homeCard(
        radius: cardRadius,
        compact: c,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(cardRadius),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(left: c ? 4 : 6, top: c ? 2 : 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: iconSize,
                        height: iconSize,
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.12),
                          border: Border.all(
                            color: accentColor.withValues(alpha: 0.30),
                            width: 1,
                          ),
                          borderRadius: BorderRadius.circular(iconRadius),
                        ),
                        child: Icon(
                          _gameIcon,
                          color: accentColor,
                          size: iconInner,
                        ),
                      ),
                      SizedBox(width: c ? 8 : 10),
                      Expanded(
                        child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.game.title,
                      style: GoogleFonts.poppins(
                        fontSize: titleSize,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textDark,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: c ? 4 : 6),
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
                            color: accentColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _gameTypeLabel,
                            style: GoogleFonts.poppins(
                              fontSize: metaSize,
                              fontWeight: FontWeight.w500,
                              color: accentColor,
                            ),
                          ),
                        ),
                        if (widget.game.metadata.difficulty != null)
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: c ? 6 : 8,
                              vertical: c ? 2 : 3,
                            ),
                            decoration: BoxDecoration(
                              color: _getDifficultyColor(widget.game.metadata.difficulty!).withOpacity(0.08),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              widget.game.metadata.difficulty!.toUpperCase(),
                              style: GoogleFonts.poppins(
                                fontSize: c ? 9.5 : 10.5,
                                fontWeight: FontWeight.w600,
                                color: _getDifficultyColor(widget.game.metadata.difficulty!),
                              ),
                            ),
                          ),
                        Text(
                          '${widget.game.items.length} items',
                          style: GoogleFonts.poppins(
                            fontSize: metaSize,
                            color: AppTheme.textMedium,
                          ),
                        ),
                      ],
                    ),
                    if (!c && _stats != null && _stats!['timesPlayed'] > 0) ...[
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
                    if (!c) ...[
                      const SizedBox(height: 4),
                      Text(
                        _formatDate(widget.game.createdAt),
                        style: GoogleFonts.poppins(
                          fontSize: metaSize,
                          color: AppTheme.textMedium,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ],
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
                        size: favSize,
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