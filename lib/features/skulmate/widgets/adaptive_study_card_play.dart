import 'package:flutter/material.dart';
import 'package:prepskul/core/theme/app_theme.dart';

import '../l10n/skulmate_copy.dart';
import '../models/revision_deck_model.dart';
import 'deck_card_shared.dart';
import 'deck_term_highlight_text.dart';
import 'skulmate_surface_styles.dart';
import 'skulmate_typography.dart';

/// Gizmo-soft study card for Memorise play — separate from scroll slides.
class AdaptiveStudyCardPlay extends StatelessWidget {
  final RevisionDeckCard card;
  final bool revealed;
  final String? selectedOption;
  final bool showMcqResult;
  final bool compact;
  final VoidCallback? onTap;
  final ValueChanged<String>? onOptionSelected;

  const AdaptiveStudyCardPlay({
    super.key,
    required this.card,
    this.revealed = false,
    this.selectedOption,
    this.showMcqResult = false,
    this.compact = false,
    this.onTap,
    this.onOptionSelected,
  });

  @override
  Widget build(BuildContext context) {
    final copy = SkulMateCopy.of(context);
    final badge = DeckCardShared.typeBadge(card);
    final pad = compact ? 14.0 : 20.0;
    final titleSize = compact ? 15.0 : 17.0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(SkulMateSurfaceStyles.deckRadius),
        child: Ink(
          decoration: SkulMateSurfaceStyles.homeCard(
            radius: SkulMateSurfaceStyles.deckRadius,
          ),
          child: Padding(
            padding: EdgeInsets.all(pad),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    if (badge != null) ...[
                      DeckCardShared.badgeChip(badge),
                      const SizedBox(width: 8),
                    ],
                    Expanded(child: _buildPrompt(titleSize)),
                    if (onTap != null &&
                        !DeckCardShared.usesMcqInteraction(card))
                      Icon(
                        revealed
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        size: 18,
                        color: AppTheme.textMedium,
                      ),
                  ],
                ),
                DeckCardShared.dashedDivider(),
                if (DeckCardShared.usesMcqInteraction(card))
                  _buildMcqOptions(titleSize)
                else if (DeckCardShared.isTrueFalse(card) && !revealed)
                  Text(
                    copy.memoriseSwipeTrueFalse,
                    style: SkulMateTypography.cardMeta(
                      color: AppTheme.primaryColor,
                    ),
                  )
                else if (!revealed)
                  Text(
                    copy.tapToRevealAnswer,
                    style: SkulMateTypography.cardMeta(
                      color: AppTheme.primaryColor,
                    ),
                  )
                else
                  _buildRevealed(titleSize),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPrompt(double titleSize) {
    switch (card.cardType) {
      case RevisionDeckCardType.cloze:
        return Text(
          card.prompt.replaceAll('____', '______'),
          style: SkulMateTypography.gameCardTitle(size: titleSize),
        );
      case RevisionDeckCardType.pair:
        return Row(
          children: [
            Expanded(
              child: Text(
                card.prompt,
                style: SkulMateTypography.gameCardTitle(size: titleSize),
              ),
            ),
            Icon(Icons.arrow_forward_rounded, size: 16, color: AppTheme.textMedium),
          ],
        );
      case RevisionDeckCardType.mcq:
        return Text(
          card.prompt,
          style: SkulMateTypography.gameCardTitle(size: titleSize),
        );
      default:
        return DeckTermHighlightText(
          text: card.prompt,
          highlight: DeckCardShared.primaryHighlight(card),
          fontSize: titleSize,
          fontWeight: FontWeight.w700,
        );
    }
  }

  Widget _buildMcqOptions(double titleSize) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: card.mcqOptions.map((option) {
        final isSelected = selectedOption == option;
        final isCorrect =
            option.toLowerCase() == card.answer.toLowerCase();
        Color border = AppTheme.neutral200;
        Color fill = AppTheme.neutral100;
        if (showMcqResult && isCorrect) {
          border = AppTheme.accentGreen;
          fill = AppTheme.accentGreen.withValues(alpha: 0.12);
        } else if (showMcqResult && isSelected && !isCorrect) {
          border = Colors.red.shade400;
          fill = Colors.red.withValues(alpha: 0.08);
        } else if (isSelected) {
          border = AppTheme.accentPurple;
          fill = AppTheme.accentPurple.withValues(alpha: 0.08);
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: showMcqResult ? null : () => onOptionSelected?.call(option),
              borderRadius: BorderRadius.circular(12),
              child: Ink(
                decoration: BoxDecoration(
                  color: fill,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: border),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Text(
                  option,
                  style: SkulMateTypography.gameCardTitle(size: titleSize - 1),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildRevealed(double titleSize) {
    switch (card.cardType) {
      case RevisionDeckCardType.cloze:
        return DeckTermHighlightText(
          text: card.prompt.replaceAll('____', card.answer),
          highlight: card.answer,
          fontSize: titleSize - 1,
          fontWeight: FontWeight.w800,
        );
      case RevisionDeckCardType.pair:
        return Row(
          children: [
            Expanded(
              child: Text(
                card.prompt,
                style: SkulMateTypography.gameCardTitle(size: titleSize - 1),
              ),
            ),
            Icon(Icons.link_rounded, size: 16, color: AppTheme.accentGreen),
            const SizedBox(width: 6),
            Expanded(
              child: DeckTermHighlightText(
                text: card.answer,
                highlight: card.answer,
                fontSize: titleSize - 1,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        );
      default:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DeckTermHighlightText(
              text: card.answer,
              highlight: DeckCardShared.primaryHighlight(card),
              fontSize: titleSize - 1,
              fontWeight: FontWeight.w800,
            ),
            if (card.explanation?.isNotEmpty == true) ...[
              const SizedBox(height: 8),
              Text(card.explanation!, style: SkulMateTypography.cardMeta()),
            ],
          ],
        );
    }
  }
}
