import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/features/skulmate/models/tutor_session_models.dart';

/// In-thread tutor board. Steps, not a finished solution dump.
class SkulMateTutorBoard extends StatelessWidget {
  final TutorBoard board;

  const SkulMateTutorBoard({super.key, required this.board});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F1E3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE4D7C0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            board.title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppTheme.accentPurple,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 10),
          for (final step in board.steps) ...[
            _StepLine(step: step),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _StepLine extends StatelessWidget {
  final TutorBoardStep step;

  const _StepLine({required this.step});

  @override
  Widget build(BuildContext context) {
    if (step.kind == 'equation') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 88,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFE0F2FE),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.primaryColor, width: 2),
            ),
            child: Text(
              step.text,
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppTheme.primaryColor,
              ),
            ),
          ),
        ],
      );
    }
    if (step.kind == 'diagram') {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.architecture_rounded, size: 18, color: AppTheme.primaryColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              step.text,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                height: 1.4,
                color: AppTheme.textDark,
              ),
            ),
          ),
        ],
      );
    }
    if (step.kind == 'prompt') {
      return Text(
        step.text,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          height: 1.4,
          color: AppTheme.primaryColor,
        ),
      );
    }
    return Text(
      step.text,
      style: GoogleFonts.plusJakartaSans(
        fontSize: step.kind == 'heading' ? 15 : 14,
        fontWeight: step.kind == 'heading' ? FontWeight.w700 : FontWeight.w500,
        height: 1.4,
        color: AppTheme.textDark,
      ),
    );
  }
}
