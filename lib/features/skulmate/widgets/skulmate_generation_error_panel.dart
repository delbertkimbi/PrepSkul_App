import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';

import '../l10n/skulmate_copy.dart';
import 'skulmate_surface_styles.dart';

enum SkulMateGenerationErrorKind {
  content,
  network,
  limits,
  server,
}

/// Unified error card for game generation and lecture transcription.
class SkulMateGenerationErrorPanel extends StatelessWidget {
  final String title;
  final String? details;
  final SkulMateGenerationErrorKind kind;
  final bool retryable;
  final String? suggestedGameTypeLabel;
  final VoidCallback? onRetry;
  final VoidCallback? onBack;
  final VoidCallback? onPaywall;
  final VoidCallback? onManualText;
  final VoidCallback? onTrySuggested;
  final VoidCallback? onContactSupport;

  const SkulMateGenerationErrorPanel({
    super.key,
    required this.title,
    this.details,
    this.kind = SkulMateGenerationErrorKind.server,
    this.retryable = true,
    this.suggestedGameTypeLabel,
    this.onRetry,
    this.onBack,
    this.onPaywall,
    this.onManualText,
    this.onTrySuggested,
    this.onContactSupport,
  });

  static SkulMateGenerationErrorKind kindFromMessage(String combined) {
    final lower = combined.toLowerCase();
    if (lower.contains('daily free limit') ||
        lower.contains('free plan limit') ||
        lower.contains('free limit reached') ||
        lower.contains('insufficient credits') ||
        lower.contains('top up')) {
      return SkulMateGenerationErrorKind.limits;
    }
    if (lower.contains('network') ||
        lower.contains('connection') ||
        lower.contains('failed to fetch') ||
        lower.contains('failed host lookup') ||
        lower.contains('timeout')) {
      return SkulMateGenerationErrorKind.network;
    }
    if (lower.contains('fileurl') ||
        lower.contains('text is required') ||
        lower.contains('too large') ||
        lower.contains('invalid') ||
        lower.contains('provide content')) {
      return SkulMateGenerationErrorKind.content;
    }
    return SkulMateGenerationErrorKind.server;
  }

  IconData get _icon {
    switch (kind) {
      case SkulMateGenerationErrorKind.content:
        return Icons.description_outlined;
      case SkulMateGenerationErrorKind.network:
        return Icons.wifi_off_rounded;
      case SkulMateGenerationErrorKind.limits:
        return Icons.account_balance_wallet_outlined;
      case SkulMateGenerationErrorKind.server:
        return Icons.error_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final copy = SkulMateCopy.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: SkulMateSurfaceStyles.homeCard(radius: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(_icon, size: 36, color: AppTheme.primaryColor),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: AppTheme.textDark,
            ),
            textAlign: TextAlign.center,
          ),
          if (details != null && details!.isNotEmpty) ...[
            const SizedBox(height: 10),
            _detailsText(details!),
          ],
          const SizedBox(height: 18),
          if (kind == SkulMateGenerationErrorKind.limits && onPaywall != null)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onPaywall,
                style: SkulMateSurfaceStyles.sheetPrimaryButton(),
                child: Text(
                  copy.errorAddCredits,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          if (onManualText != null) ...[
            if (kind == SkulMateGenerationErrorKind.limits) const SizedBox(height: 10),
            TextButton.icon(
              onPressed: onManualText,
              icon: const Icon(Icons.edit_note_rounded, size: 20),
              label: Text(
                copy.errorManualText,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              if (onBack != null)
                Expanded(
                  child: OutlinedButton(
                    onPressed: onBack,
                    style: SkulMateSurfaceStyles.sheetSecondaryButton(),
                    child: Text(
                      copy.errorGoBack,
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              if (suggestedGameTypeLabel != null && onTrySuggested != null) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onTrySuggested,
                    style: SkulMateSurfaceStyles.sheetPrimaryButton(),
                    child: Text(
                      'Try $suggestedGameTypeLabel',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ] else if (retryable && onRetry != null) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onRetry,
                    style: SkulMateSurfaceStyles.sheetPrimaryButton(),
                    child: Text(
                      copy.errorTryAgain,
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _detailsText(String text) {
    const key = 'contact support';
    final lower = text.toLowerCase();
    final index = lower.indexOf(key);
    if (index < 0 || onContactSupport == null) {
      return Text(
        text,
        style: GoogleFonts.poppins(
          fontSize: 14,
          color: AppTheme.textMedium,
          height: 1.5,
        ),
        textAlign: TextAlign.center,
      );
    }
    final before = text.substring(0, index);
    final clickable = text.substring(index, index + key.length);
    final after = text.substring(index + key.length);
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: before),
          TextSpan(
            text: clickable,
            style: const TextStyle(
              color: AppTheme.primaryColor,
              fontWeight: FontWeight.w600,
              decoration: TextDecoration.underline,
            ),
            recognizer: TapGestureRecognizer()..onTap = onContactSupport,
          ),
          TextSpan(text: after),
        ],
      ),
      style: GoogleFonts.poppins(
        fontSize: 14,
        color: AppTheme.textMedium,
        height: 1.5,
      ),
      textAlign: TextAlign.center,
    );
  }
}
