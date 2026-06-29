import 'package:flutter/material.dart';
import 'package:prepskul/core/theme/app_theme.dart';

import '../models/revision_deck_model.dart';
import 'skulmate_typography.dart';

/// Shared Gizmo deck card chrome — badges, dashed dividers, type labels.
class DeckCardShared {
  DeckCardShared._();

  static String? typeBadge(RevisionDeckCard card) {
    if (card.tags.contains('true_false')) return 'True/False';
    switch (card.cardType) {
      case RevisionDeckCardType.mcq:
        return 'Quiz';
      case RevisionDeckCardType.cloze:
        return 'Fill in';
      case RevisionDeckCardType.pair:
        return 'Match';
      case RevisionDeckCardType.order:
        return 'Order';
      case RevisionDeckCardType.termDef:
        final answer = card.answer.toLowerCase();
        if (answer == 'true' || answer == 'false') return 'True/False';
        return 'Recall';
      default:
        return null;
    }
  }

  static String primaryHighlight(RevisionDeckCard card) {
    if (card.tags.contains('true_false')) return card.answer;
    if (card.cardType == RevisionDeckCardType.termDef) return card.prompt;
    return card.answer;
  }

  static Widget badgeChip(String label, {Color? color}) {
    final accent = color ?? AppTheme.accentPurple;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: SkulMateTypography.cardMeta(color: accent),
      ),
    );
  }

  static Widget dashedDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return CustomPaint(
            size: Size(constraints.maxWidth, 1),
            painter: DeckCardDashedLinePainter(),
          );
        },
      ),
    );
  }

  static bool isTrueFalse(RevisionDeckCard card) {
    if (card.tags.contains('true_false')) return true;
    if (card.cardType != RevisionDeckCardType.termDef) return false;
    final answer = card.answer.toLowerCase();
    return answer == 'true' || answer == 'false';
  }

  static bool usesMcqInteraction(RevisionDeckCard card) {
    return card.cardType == RevisionDeckCardType.mcq && card.mcqOptions.length >= 2;
  }

  static bool usesRevealThenSwipe(RevisionDeckCard card) {
    return !usesMcqInteraction(card) && !isTrueFalse(card);
  }
}

class DeckCardDashedLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const dashWidth = 5.0;
    const dashSpace = 4.0;
    final paint = Paint()
      ..color = AppTheme.neutral200
      ..strokeWidth = 1;
    var start = 0.0;
    while (start < size.width) {
      canvas.drawLine(Offset(start, 0), Offset(start + dashWidth, 0), paint);
      start += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

enum MemoriseInteraction {
  mcq,
  trueFalseSwipe,
  revealSwipe,
  legacyFlip,
}

MemoriseInteraction interactionFor(RevisionDeckCard? card) {
  if (card == null) return MemoriseInteraction.legacyFlip;
  if (DeckCardShared.usesMcqInteraction(card)) {
    return MemoriseInteraction.mcq;
  }
  if (DeckCardShared.isTrueFalse(card)) return MemoriseInteraction.trueFalseSwipe;
  return MemoriseInteraction.revealSwipe;
}
