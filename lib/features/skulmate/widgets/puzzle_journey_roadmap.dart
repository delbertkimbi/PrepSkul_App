import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';

import '../l10n/skulmate_copy.dart';
import '../models/puzzle_step_model.dart';

/// Vertical journey preview for puzzle briefing (replaces how-to-play list).
class PuzzleJourneyRoadmap extends StatelessWidget {
  final List<PuzzleStepDefinition> steps;

  const PuzzleJourneyRoadmap({super.key, required this.steps});

  IconData _iconFor(PuzzleStepType type) {
    switch (type) {
      case PuzzleStepType.pickOne:
        return Icons.touch_app_rounded;
      case PuzzleStepType.hotspotDrop:
        return Icons.pin_drop_outlined;
      case PuzzleStepType.orderCheck:
        return Icons.format_list_numbered_rounded;
    }
  }

  String _labelFor(PuzzleStepType type, SkulMateCopy copy) {
    switch (type) {
      case PuzzleStepType.pickOne:
        return copy.puzzleStepTypePick;
      case PuzzleStepType.hotspotDrop:
        return copy.puzzleStepTypeHotspot;
      case PuzzleStepType.orderCheck:
        return copy.puzzleStepTypeOrder;
    }
  }

  @override
  Widget build(BuildContext context) {
    final copy = SkulMateCopy.of(context);
    if (steps.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.neutral100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.softBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            copy.briefingJourneySection.toUpperCase(),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
              color: AppTheme.textDark,
            ),
          ),
          const SizedBox(height: 10),
          ...List.generate(steps.length, (i) {
            final step = steps[i];
            final isLast = i == steps.length - 1;
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0A2A66),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppTheme.primaryColor.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Icon(
                        _iconFor(step.type),
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                    if (!isLast)
                      Container(
                        width: 2,
                        height: 28,
                        color: AppTheme.neutral200,
                      ),
                  ],
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${copy.puzzleVaultChamberLabel(i + 1)} · ${_labelFor(step.type, copy)}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          step.displayTitle,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textDark,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }
}
