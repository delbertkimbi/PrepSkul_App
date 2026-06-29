import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';

/// Highlights [highlight] inside [text] with a soft green chip (Gizmo-style).
class DeckTermHighlightText extends StatelessWidget {
  final String text;
  final String highlight;
  final TextStyle? baseStyle;
  final double fontSize;
  final FontWeight fontWeight;

  const DeckTermHighlightText({
    super.key,
    required this.text,
    required this.highlight,
    this.baseStyle,
    this.fontSize = 15,
    this.fontWeight = FontWeight.w600,
  });

  @override
  Widget build(BuildContext context) {
    final lowerText = text.toLowerCase();
    final lowerHighlight = highlight.trim().toLowerCase();
    final style = baseStyle ??
        GoogleFonts.plusJakartaSans(
          fontSize: fontSize,
          fontWeight: fontWeight,
          height: 1.35,
          color: AppTheme.textDark,
        );

    if (lowerHighlight.isEmpty || !lowerText.contains(lowerHighlight)) {
      return Text(text, style: style);
    }

    final index = lowerText.indexOf(lowerHighlight);
    return RichText(
      text: TextSpan(
        style: style,
        children: [
          TextSpan(text: text.substring(0, index)),
          TextSpan(
            text: text.substring(index, index + highlight.trim().length),
            style: style.copyWith(
              fontWeight: FontWeight.w800,
              backgroundColor: AppTheme.accentGreen.withValues(alpha: 0.25),
            ),
          ),
          TextSpan(text: text.substring(index + highlight.trim().length)),
        ],
      ),
    );
  }
}
