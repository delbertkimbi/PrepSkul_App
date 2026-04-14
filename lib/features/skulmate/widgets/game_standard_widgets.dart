import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import '../models/game_model.dart';
import 'skulmate_mascot_media_widget.dart';

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
                  if (gameType != null) ...[
                    SizedBox(
                      width: 28,
                      height: 28,
                      child: SkulMateMascotMediaWidget(
                        state: SkulMateMascotState.neutral,
                        useLandscapeFrame: false,
                        borderRadius: 10,
                        preferStaticImage: true,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
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

/// Flat card style used by generation and quiz surfaces.
class FlatStageCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? borderColor;
  final Color? backgroundColor;
  final double radius;

  const FlatStageCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.borderColor,
    this.backgroundColor,
    this.radius = 14,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.white,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor ?? AppTheme.softBorder),
      ),
      child: child,
    );
  }
}

/// Flat selectable row used for quiz answer options.
class FlatChoiceTile extends StatelessWidget {
  final String label;
  final bool isSelected;
  final bool isCorrect;
  final bool showResult;
  final VoidCallback? onTap;

  const FlatChoiceTile({
    super.key,
    required this.label,
    required this.isSelected,
    required this.isCorrect,
    required this.showResult,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color fill = Colors.white;
    Color border = AppTheme.softBorder;
    Color textColor = AppTheme.textDark;
    IconData? leadingIcon;

    if (showResult) {
      if (isCorrect) {
        fill = AppTheme.accentGreen.withValues(alpha: 0.12);
        border = AppTheme.accentGreen;
        textColor = AppTheme.textDark;
        leadingIcon = Icons.check_circle;
      } else if (isSelected) {
        fill = const Color(0xFFFEF2F2);
        border = const Color(0xFFDC2626);
        textColor = AppTheme.textDark;
        leadingIcon = Icons.cancel;
      }
    } else if (isSelected) {
      fill = AppTheme.primaryColor.withValues(alpha: 0.09);
      border = AppTheme.primaryColor;
      textColor = AppTheme.primaryColor;
      leadingIcon = Icons.radio_button_checked;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: border, width: 1.5),
          ),
          child: Row(
            children: [
              if (leadingIcon != null) ...[
                Icon(leadingIcon, size: 18, color: border),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
