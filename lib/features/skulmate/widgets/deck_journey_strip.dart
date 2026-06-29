import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';

import '../services/deck_study_progress_service.dart';

/// Unicorn Run–inspired journey strip for deck study flow.
class DeckJourneyStrip extends StatelessWidget {
  final List<DeckJourneyStep> completedSteps;

  const DeckJourneyStrip({
    super.key,
    required this.completedSteps,
  });

  @override
  Widget build(BuildContext context) {
    const steps = DeckJourneyStep.values;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your journey',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppTheme.textMedium,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (var i = 0; i < steps.length; i++) ...[
                Expanded(
                  child: _StepNode(
                    step: steps[i],
                    done: completedSteps.contains(steps[i]),
                    active: _isActive(steps[i], completedSteps),
                  ),
                ),
                if (i < steps.length - 1)
                  _Connector(done: completedSteps.contains(steps[i])),
              ],
            ],
          ),
        ],
      ),
    );
  }

  bool _isActive(DeckJourneyStep step, List<DeckJourneyStep> done) {
    if (done.contains(step)) return false;
    final index = DeckJourneyStep.values.indexOf(step);
    if (index == 0) return true;
    return done.contains(DeckJourneyStep.values[index - 1]);
  }
}

class _StepNode extends StatelessWidget {
  final DeckJourneyStep step;
  final bool done;
  final bool active;

  const _StepNode({
    required this.step,
    required this.done,
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    final color = done
        ? AppTheme.accentGreen
        : active
            ? AppTheme.primaryColor
            : AppTheme.neutral200;

    return Column(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: done
                ? AppTheme.accentGreen.withValues(alpha: 0.15)
                : active
                    ? AppTheme.primaryColor.withValues(alpha: 0.12)
                    : AppTheme.neutral100,
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 2),
          ),
          child: Icon(
            done ? Icons.check_rounded : _iconFor(step),
            size: 15,
            color: color,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _labelFor(step),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: done || active ? AppTheme.textDark : AppTheme.textMedium,
          ),
        ),
      ],
    );
  }

  String _labelFor(DeckJourneyStep step) {
    switch (step) {
      case DeckJourneyStep.review:
        return 'Review';
      case DeckJourneyStep.ready:
        return 'Ready';
      case DeckJourneyStep.practice:
        return 'Practice';
      case DeckJourneyStep.master:
        return 'Master';
    }
  }

  IconData _iconFor(DeckJourneyStep step) {
    switch (step) {
      case DeckJourneyStep.review:
        return Icons.style_rounded;
      case DeckJourneyStep.ready:
        return Icons.psychology_alt_rounded;
      case DeckJourneyStep.practice:
        return Icons.sports_esports_rounded;
      case DeckJourneyStep.master:
        return Icons.emoji_events_rounded;
    }
  }
}

class _Connector extends StatelessWidget {
  final bool done;

  const _Connector({required this.done});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 12,
      height: 2,
      margin: const EdgeInsets.only(bottom: 18),
      decoration: BoxDecoration(
        color: done ? AppTheme.accentGreen : AppTheme.neutral200,
        borderRadius: BorderRadius.circular(99),
      ),
    );
  }
}
