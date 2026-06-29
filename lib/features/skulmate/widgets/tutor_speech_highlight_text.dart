import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';

/// Read-along highlight — active word gets a soft yellow chip.
class TutorSpeechHighlightText extends StatelessWidget {
  final String text;
  final int highlightStart;
  final int highlightEnd;

  const TutorSpeechHighlightText({
    super.key,
    required this.text,
    this.highlightStart = -1,
    this.highlightEnd = -1,
  });

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) return const SizedBox.shrink();

    final baseStyle = GoogleFonts.plusJakartaSans(
      fontSize: 14,
      height: 1.45,
      color: AppTheme.textDark,
    );

    final hasHighlight =
        highlightStart >= 0 && highlightEnd > highlightStart && highlightEnd <= text.length;

    if (!hasHighlight) {
      return Text(text, style: baseStyle);
    }

    final before = text.substring(0, highlightStart.clamp(0, text.length));
    final active = text.substring(
      highlightStart.clamp(0, text.length),
      highlightEnd.clamp(0, text.length),
    );
    final after = text.substring(highlightEnd.clamp(0, text.length));

    return Text.rich(
      TextSpan(
        style: baseStyle,
        children: [
          if (before.isNotEmpty) TextSpan(text: before),
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
              decoration: BoxDecoration(
                color: AppTheme.softYellowLight.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(active, style: baseStyle),
            ),
          ),
          if (after.isNotEmpty) TextSpan(text: after),
        ],
      ),
    );
  }
}
