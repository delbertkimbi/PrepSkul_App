import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import '../models/game_model.dart';

/// Shared Duolingo-style HUD and controls for consistent game UX.
class GameStandardsHud extends StatelessWidget {
  final String progressText;
  final double progressValue;
  final int xpEarned;
  final GameType? gameType;

  const GameStandardsHud({
    super.key,
    required this.progressText,
    required this.progressValue,
    required this.xpEarned,
    this.gameType,
  });

  @override
  Widget build(BuildContext context) {
    final safeProgress = progressValue.clamp(0.0, 1.0);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.neutral100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  if (gameType != null)
                    _GameTypeFeatureIcon(
                      gameType: gameType!,
                    ),
                  if (gameType != null) const SizedBox(width: 8),
                  Text(
                    progressText,
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: AppTheme.textDark,
                    ),
                  ),
                ],
              ),
              Text(
                '$xpEarned XP',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: AppTheme.primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _TactileProgressBar(
            value: safeProgress,
            height: 7,
            fillGradient: _gradientForGameType(gameType),
          ),
        ],
      ),
    );
  }

  LinearGradient _gradientForGameType(GameType? type) {
    if (type == null) return AppTheme.primaryGradient;
    switch (type) {
      case GameType.dragDrop:
      case GameType.fillBlank:
        return AppTheme.stitchYellowGradient;
      case GameType.wordSearch:
      case GameType.match3:
      case GameType.matching:
      case GameType.flashcards:
      case GameType.quiz:
        return AppTheme.stitchSkyBlueGradient;
      case GameType.bubblePop:
        return LinearGradient(
          colors: [AppTheme.accentOrange, AppTheme.accentPink],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case GameType.crossword:
        return LinearGradient(
          colors: [AppTheme.accentPurple, AppTheme.skyBlue],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case GameType.diagramLabel:
        return AppTheme.primaryGradient;
      case GameType.puzzlePieces:
        return AppTheme.primaryGradient;
      case GameType.simulation:
      case GameType.mystery:
      case GameType.escapeRoom:
        return AppTheme.primaryGradient;
    }
  }
}

class _TactileProgressBar extends StatelessWidget {
  final double value;
  final double height;
  final LinearGradient fillGradient;

  const _TactileProgressBar({
    required this.value,
    required this.height,
    required this.fillGradient,
  });

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(8);
    return ClipRRect(
      borderRadius: borderRadius,
      child: Stack(
        children: [
          // Track surface.
          Container(
            height: height,
            width: double.infinity,
            color: AppTheme.neutral100,
          ),
          // Gradient fill.
          FractionallySizedBox(
            widthFactor: value,
            child: Container(
              height: height,
              decoration: BoxDecoration(
                gradient: fillGradient,
              ),
              child: Stack(
                children: [
                  // Top-half shine overlay.
                  FractionallySizedBox(
                    heightFactor: 0.5,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withOpacity(0.12),
                            Colors.white.withOpacity(0.0),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
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

class _GameTypeFeatureIcon extends StatelessWidget {
  final GameType gameType;

  const _GameTypeFeatureIcon({
    required this.gameType,
  });

  @override
  Widget build(BuildContext context) {
    final gradient = _gradientForGameType(gameType);

    final icon = switch (gameType) {
      GameType.dragDrop => Icons.drag_handle,
      GameType.fillBlank => Icons.edit,
      GameType.wordSearch => Icons.search,
      GameType.crossword => Icons.grid_on,
      GameType.bubblePop => Icons.circle,
      GameType.match3 => Icons.auto_awesome,
      GameType.matching => Icons.extension,
      GameType.flashcards => Icons.layers,
      GameType.quiz => Icons.school,
      GameType.simulation => Icons.memory,
      GameType.mystery => Icons.help_outline,
      GameType.escapeRoom => Icons.lock_outline,
      GameType.diagramLabel => Icons.label,
      _ => Icons.help_outline,
    };

    return Container(
      width: 26,
      height: 18,
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Center(
        child: Icon(
          icon,
          size: 13,
          color: Colors.white,
        ),
      ),
    );
  }

  LinearGradient _gradientForGameType(GameType type) {
    switch (type) {
      case GameType.dragDrop:
      case GameType.fillBlank:
        return AppTheme.stitchYellowGradient;
      case GameType.wordSearch:
      case GameType.match3:
      case GameType.matching:
      case GameType.flashcards:
      case GameType.quiz:
        return AppTheme.stitchSkyBlueGradient;
      case GameType.bubblePop:
        return LinearGradient(
          colors: [AppTheme.accentOrange, AppTheme.accentPink],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case GameType.crossword:
        return LinearGradient(
          colors: [AppTheme.accentPurple, AppTheme.skyBlue],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case GameType.diagramLabel:
        return AppTheme.primaryGradient;
      case GameType.puzzlePieces:
        return AppTheme.primaryGradient;
      case GameType.simulation:
      case GameType.mystery:
      case GameType.escapeRoom:
        return AppTheme.primaryGradient;
    }
  }
}

class GameStandardsTipCard extends StatelessWidget {
  final String text;
  const GameStandardsTipCard({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: GoogleFonts.beVietnamPro(
          fontSize: 13,
          color: AppTheme.textMedium,
        ),
      ),
    );
  }
}

class GameStandardsPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  const GameStandardsPrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return _GameStandardsSquishyPrimaryButton(
      label: label,
      onPressed: onPressed,
    );
  }
}

class _GameStandardsSquishyPrimaryButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;

  const _GameStandardsSquishyPrimaryButton({
    required this.label,
    required this.onPressed,
  });

  @override
  State<_GameStandardsSquishyPrimaryButton> createState() =>
      _GameStandardsSquishyPrimaryButtonState();
}

class _GameStandardsSquishyPrimaryButtonState
    extends State<_GameStandardsSquishyPrimaryButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final borderRadius = BorderRadius.circular(12);

    final double translateY = _isPressed ? 2 : 0;
    final double shadowOffsetY = _isPressed ? 2 : 4;
    final double shadowBlur = _isPressed ? 8 : 14;
    final double shadowOpacity = enabled ? 0.35 : 0.18;

    return SizedBox(
      width: double.infinity,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 90),
        transform: Matrix4.translationValues(0, translateY, 0),
        decoration: BoxDecoration(
          gradient: AppTheme.primaryGradient,
          borderRadius: borderRadius,
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryColor.withOpacity(shadowOpacity),
              blurRadius: shadowBlur,
              offset: Offset(0, shadowOffsetY),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: borderRadius,
          child: InkWell(
            borderRadius: borderRadius,
            onTap: enabled ? widget.onPressed : null,
            onTapDown: enabled
                ? (_) {
                    setState(() => _isPressed = true);
                  }
                : null,
            onTapCancel: enabled
                ? () {
                    setState(() => _isPressed = false);
                  }
                : null,
            onTapUp: enabled
                ? (_) {
                    setState(() => _isPressed = false);
                  }
                : null,
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(vertical: 13),
              child: Text(
                widget.label,
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
