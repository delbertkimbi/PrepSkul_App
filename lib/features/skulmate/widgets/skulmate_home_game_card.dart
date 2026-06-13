import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';

import '../models/game_model.dart';
import '../services/skulmate_service.dart';
import 'skulmate_surface_styles.dart';

/// Compact neumorphic deck card for the SkulMate home carousel.
class SkulMateHomeGameCard extends StatefulWidget {
  final GameModel game;
  final VoidCallback onTap;
  final double? width;

  const SkulMateHomeGameCard({
    super.key,
    required this.game,
    required this.onTap,
    this.width = 168,
  });

  static const double cardHeight = 76;

  @override
  State<SkulMateHomeGameCard> createState() => _SkulMateHomeGameCardState();
}

class _SkulMateHomeGameCardState extends State<SkulMateHomeGameCard> {
  double _progress = 0;

  @override
  void initState() {
    super.initState();
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    try {
      final stats = await SkulMateService.getGameStats(widget.game.id);
      if (mounted) {
        setState(() {
          _progress =
              (stats['bestScorePercentage'] as num?)?.toDouble() ?? 0;
        });
      }
    } catch (_) {}
  }

  Color get _accent {
    switch (widget.game.gameType) {
      case GameType.flashcards:
        return const Color(0xFF14B8A6);
      case GameType.matching:
        return const Color(0xFF8B5CF6);
      case GameType.fillBlank:
        return const Color(0xFFF59E0B);
      default:
        return AppTheme.primaryColor;
    }
  }

  String get _typeLabel {
    switch (widget.game.gameType) {
      case GameType.flashcards:
        return 'Drill';
      case GameType.matching:
        return 'Matching';
      case GameType.fillBlank:
        return 'Fill blank';
      default:
        return 'Quiz';
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = _progress.clamp(0, 100);
    final barHeight =
        progress > 0 ? (progress / 100) * (SkulMateHomeGameCard.cardHeight - 8) : 6.0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: widget.width,
          height: SkulMateHomeGameCard.cardHeight,
          decoration: SkulMateSurfaceStyles.homeCard(radius: 16, compact: true),
          child: Row(
            children: [
              SizedBox(
                width: 4,
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    width: 4,
                    height: barHeight,
                    decoration: BoxDecoration(
                      color: _accent,
                      borderRadius: const BorderRadius.horizontal(
                        left: Radius.circular(16),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: _accent.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.sports_esports_outlined,
                  size: 17,
                  color: _accent,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      widget.game.title,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textDark,
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _typeLabel,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: AppTheme.textMedium,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }
}
