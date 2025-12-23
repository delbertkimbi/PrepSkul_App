import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import '../models/skulmate_character_model.dart';
import 'dart:math';

/// Widget for displaying skulMate character with animations
class SkulMateCharacterWidget extends StatefulWidget {
  final SkulMateCharacter character;
  final double size;
  final bool showName;
  final bool animated;
  final VoidCallback? onTap;

  const SkulMateCharacterWidget({
    Key? key,
    required this.character,
    this.size = 120,
    this.showName = false,
    this.animated = true,
    this.onTap,
  }) : super(key: key);

  @override
  State<SkulMateCharacterWidget> createState() => _SkulMateCharacterWidgetState();
}

class _SkulMateCharacterWidgetState extends State<SkulMateCharacterWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _bounceAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    if (widget.animated) {
      _controller = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1500),
      );

      _bounceAnimation = Tween<double>(begin: 0, end: 10).animate(
        CurvedAnimation(
          parent: _controller,
          curve: Curves.easeInOut,
        ),
      );

      _scaleAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
        CurvedAnimation(
          parent: _controller,
          curve: Curves.easeInOut,
        ),
      );

      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    if (widget.animated) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget characterImage = Image.asset(
      widget.character.assetPath,
      width: widget.size,
      height: widget.size,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        // Fallback to icon if image not found
        return Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppTheme.accentBlue.withOpacity(0.1),
          ),
          child: Icon(
            Icons.school,
            size: widget.size * 0.5,
            color: AppTheme.accentBlue,
          ),
        );
      },
    );

    if (widget.animated) {
      characterImage = AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, -_bounceAnimation.value),
            child: Transform.scale(
              scale: _scaleAnimation.value,
              child: child!,
            ),
          );
        },
        child: characterImage,
      );
    }

    Widget content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: widget.onTap,
          child: characterImage,
        ),
        if (widget.showName) ...[
          const SizedBox(height: 8),
          Text(
            widget.character.name,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.textDark,
            ),
          ),
        ],
      ],
    );

    return content;
  }
}

/// Compact character display for game screens
class CompactCharacterWidget extends StatelessWidget {
  final SkulMateCharacter character;
  final String? message; // Optional message bubble

  const CompactCharacterWidget({
    Key? key,
    required this.character,
    this.message,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (message != null) ...[
          // Message bubble
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              message!,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppTheme.textDark,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
        // Character
        SkulMateCharacterWidget(
          character: character,
          size: 60,
          animated: true,
        ),
      ],
    );
  }
}

