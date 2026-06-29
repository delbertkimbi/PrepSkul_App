import 'package:flutter/material.dart';
import 'package:prepskul/core/theme/app_theme.dart';

import '../l10n/skulmate_copy.dart';
import '../models/revision_deck_model.dart';
import 'deck_card_shared.dart';
import 'deck_term_highlight_text.dart';
import 'skulmate_surface_styles.dart';
import 'skulmate_typography.dart';

/// Gizmo-style deck card with type-aware layout and tap-to-reveal.
class GizmoDeckCard extends StatefulWidget {
  final RevisionDeckCard card;
  final Future<void> Function() onRevealed;

  const GizmoDeckCard({
    super.key,
    required this.card,
    required this.onRevealed,
  });

  @override
  State<GizmoDeckCard> createState() => _GizmoDeckCardState();
}

class _GizmoDeckCardState extends State<GizmoDeckCard> {
  bool _revealed = false;

  Future<void> _toggleReveal() async {
    final next = !_revealed;
    setState(() => _revealed = next);
    if (next) await widget.onRevealed();
  }

  String? _typeBadge(RevisionDeckCard card) => DeckCardShared.typeBadge(card);

  @override
  Widget build(BuildContext context) {
    final copy = SkulMateCopy.of(context);
    final card = widget.card;
    final badge = _typeBadge(card);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(SkulMateSurfaceStyles.deckRadius),
        onTap: _toggleReveal,
        child: Ink(
          decoration: SkulMateSurfaceStyles.homeCard(),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (badge != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.accentPurple.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(
                          badge,
                          style: SkulMateTypography.cardMeta(
                            color: AppTheme.accentPurple,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Expanded(child: _buildPrompt(card)),
                    Icon(
                      _revealed
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      size: 18,
                      color: AppTheme.textMedium,
                    ),
                  ],
                ),
                DeckCardShared.dashedDivider(),
                AnimatedCrossFade(
                  duration: const Duration(milliseconds: 200),
                  crossFadeState: _revealed
                      ? CrossFadeState.showSecond
                      : CrossFadeState.showFirst,
                  firstChild: Text(
                    copy.tapToRevealAnswer,
                    style: SkulMateTypography.cardMeta(
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  secondChild: _buildRevealed(card),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPrompt(RevisionDeckCard card) {
    switch (card.cardType) {
      case RevisionDeckCardType.cloze:
        return Text(
          card.prompt.replaceAll('____', '______'),
          style: SkulMateTypography.gameCardTitle(size: 15),
        );
      case RevisionDeckCardType.pair:
        return Row(
          children: [
            Expanded(
              child: Text(
                card.prompt,
                style: SkulMateTypography.gameCardTitle(size: 15),
              ),
            ),
            Icon(Icons.arrow_forward_rounded, size: 16, color: AppTheme.textMedium),
          ],
        );
      case RevisionDeckCardType.mcq:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              card.prompt,
              style: SkulMateTypography.gameCardTitle(size: 15),
            ),
            if (!_revealed && card.mcqOptions.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: card.mcqOptions
                    .map(
                      (option) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.neutral100,
                          borderRadius: BorderRadius.circular(99),
                          border: Border.all(color: AppTheme.neutral200),
                        ),
                        child: Text(
                          option,
                          style: SkulMateTypography.cardMeta(),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
          ],
        );
      default:
        return DeckTermHighlightText(
          text: card.prompt,
          highlight: _primaryHighlight(card),
          fontSize: 15,
          fontWeight: FontWeight.w700,
        );
    }
  }

  Widget _buildRevealed(RevisionDeckCard card) {
    switch (card.cardType) {
      case RevisionDeckCardType.mcq:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ...card.mcqOptions.map((option) {
              final isCorrect =
                  option.toLowerCase() == card.answer.toLowerCase();
              return Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isCorrect
                      ? AppTheme.accentGreen.withValues(alpha: 0.15)
                      : AppTheme.neutral100,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isCorrect
                        ? AppTheme.accentGreen.withValues(alpha: 0.5)
                        : AppTheme.neutral200,
                  ),
                ),
                child: Text(
                  option,
                  style: SkulMateTypography.gameCardTitle(size: 14).copyWith(
                    color: isCorrect ? AppTheme.accentGreen : AppTheme.textDark,
                  ),
                ),
              );
            }),
          ],
        );
      case RevisionDeckCardType.cloze:
        return DeckTermHighlightText(
          text: card.prompt.replaceAll('____', card.answer),
          highlight: card.answer,
          fontSize: 14,
          fontWeight: FontWeight.w800,
        );
      case RevisionDeckCardType.pair:
        return Row(
          children: [
            Expanded(
              child: Text(
                card.prompt,
                style: SkulMateTypography.gameCardTitle(size: 14),
              ),
            ),
            Icon(Icons.link_rounded, size: 16, color: AppTheme.accentGreen),
            const SizedBox(width: 6),
            Expanded(
              child: DeckTermHighlightText(
                text: card.answer,
                highlight: card.answer,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        );
      case RevisionDeckCardType.order:
        final steps = [card.prompt, card.answer]
            .expand((part) => part.split(RegExp(r'[,;|]\s*')))
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < steps.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppTheme.accentPurple.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${i + 1}',
                        style: SkulMateTypography.cardMeta(
                          color: AppTheme.accentPurple,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        steps[i],
                        style: SkulMateTypography.body(),
                      ),
                    ),
                  ],
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
              highlight: _primaryHighlight(card),
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
            if (card.explanation?.isNotEmpty == true) ...[
              const SizedBox(height: 8),
              Text(
                card.explanation!,
                style: SkulMateTypography.cardMeta(),
              ),
            ],
            if (card.sourceQuote?.isNotEmpty == true) ...[
              const SizedBox(height: 8),
              Text(
                card.sourceQuote!,
                style: SkulMateTypography.cardMeta(),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        );
    }
  }

  String _primaryHighlight(RevisionDeckCard card) =>
      DeckCardShared.primaryHighlight(card);
}
