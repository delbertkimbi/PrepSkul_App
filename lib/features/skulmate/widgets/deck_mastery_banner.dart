import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';

import '../services/deck_mastery_service.dart';
import 'skulmate_surface_styles.dart';

/// Path A — topic mastery + due reviews on the deck hub.
class DeckMasteryBanner extends StatelessWidget {
  final DeckMasterySnapshot snapshot;
  final bool loading;

  const DeckMasteryBanner({
    super.key,
    required this.snapshot,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Container(
        height: 72,
        margin: const EdgeInsets.fromLTRB(16, 4, 16, 0),
        decoration: SkulMateSurfaceStyles.deckMasteryBanner(),
        alignment: Alignment.center,
        child: const SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (!snapshot.hasMastery && !snapshot.hasDueReviews) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: SkulMateSurfaceStyles.deckMasteryBanner(),
      child: Row(
        children: [
          if (snapshot.hasMastery) ...[
            _MasteryRing(percent: snapshot.masteryPercent!),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Topic mastery',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textMedium,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    snapshot.bandLabel,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: snapshot.bandColor,
                    ),
                  ),
                ],
              ),
            ),
          ] else
            Expanded(
              child: Text(
                'Play a study mode to track mastery',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textMedium,
                ),
              ),
            ),
          if (snapshot.hasDueReviews)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.accentOrange.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.accentOrange.withValues(alpha: 0.35),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.schedule_rounded,
                    size: 16,
                    color: AppTheme.accentOrange,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${snapshot.dueReviewCount} due',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.accentOrange,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _MasteryRing extends StatelessWidget {
  final int percent;

  const _MasteryRing({required this.percent});

  @override
  Widget build(BuildContext context) {
    final value = (percent.clamp(0, 100)) / 100;
    return SizedBox(
      width: 48,
      height: 48,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: value,
            strokeWidth: 5,
            backgroundColor: AppTheme.neutral100,
            color: AppTheme.primaryColor,
          ),
          Text(
            '$percent%',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: AppTheme.textDark,
            ),
          ),
        ],
      ),
    );
  }
}
