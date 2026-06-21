import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';

import '../l10n/skulmate_copy.dart';
import '../services/skulmate_credits_service.dart';
import 'skulmate_surface_styles.dart';

/// Credits balance or today's free revision quota (only when relevant).
class SkulMateUsageMeter extends StatelessWidget {
  final SkulmateCreditsSnapshot? snapshot;

  const SkulMateUsageMeter({super.key, this.snapshot});

  @override
  Widget build(BuildContext context) {
    final copy = SkulMateCopy.of(context);
    final data = snapshot;

    if (data == null) return const SizedBox.shrink();

    if (data.hasCredits) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: SkulMateSurfaceStyles.homeCard(radius: 14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.bolt_rounded,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    copy.paywallCreditsBalance(data.creditsBalance),
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    copy.paywallCreditsActiveHint,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: AppTheme.textMedium,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: SkulMateSurfaceStyles.homeCard(radius: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            copy.paywallUsageTitle,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.textDark,
            ),
          ),
          const SizedBox(height: 10),
          _bar(
            copy.paywallDocLabel,
            data.docUsed,
            data.docLimit,
          ),
          const SizedBox(height: 8),
          _bar(
            copy.paywallImageLabel,
            data.imageUsed,
            data.imageLimit,
          ),
        ],
      ),
    );
  }

  Widget _bar(String label, int used, int limit) {
    final safeLimit = limit <= 0 ? 1 : limit;
    final progress = (used / safeLimit).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: AppTheme.textMedium,
                ),
              ),
            ),
            Text(
              '$used / $limit',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.textDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            backgroundColor: AppTheme.neutral100,
            valueColor: const AlwaysStoppedAnimation<Color>(
              AppTheme.primaryColor,
            ),
          ),
        ),
      ],
    );
  }
}
