import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';

enum KycMascotVariant { intro, submitted, pending, rejected }

/// Hero illustration for KYC screens. Uses flow PNGs when present;
/// otherwise falls back to the PrepSkul brand bear (`default.png`).
class KycMascotIllustration extends StatelessWidget {
  final KycMascotVariant variant;

  const KycMascotIllustration({super.key, required this.variant});

  static const _introAsset = 'assets/images/kyc/kyc_intro.png';
  static const _submittedAsset = 'assets/images/kyc/kyc_submitted.png';
  static const _pendingAsset = 'assets/images/kyc/kyc_pending.png';
  static const _rejectedAsset = 'assets/images/kyc/kyc_rejected.png';
  static const _brandBearFallback = 'assets/characters/mascots/default.png';

  String get _assetPath => switch (variant) {
        KycMascotVariant.intro => _introAsset,
        KycMascotVariant.submitted => _submittedAsset,
        KycMascotVariant.pending => _pendingAsset,
        KycMascotVariant.rejected => _rejectedAsset,
      };

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 4 / 3,
      child: Image.asset(
        _assetPath,
        fit: BoxFit.contain,
        gaplessPlayback: true,
        filterQuality: FilterQuality.medium,
        errorBuilder: (context, error, stackTrace) {
          if (kDebugMode) {
            debugPrint(
              'KycMascotIllustration: failed to load $_assetPath — $error',
            );
          }
          return _KycMascotFallback(variant: variant);
        },
      ),
    );
  }
}

class _KycMascotFallback extends StatelessWidget {
  final KycMascotVariant variant;

  const _KycMascotFallback({required this.variant});

  String get _caption => switch (variant) {
        KycMascotVariant.intro => 'One-time safety check',
        KycMascotVariant.submitted => 'Submitted for review',
        KycMascotVariant.pending => 'Review in progress',
        KycMascotVariant.rejected => 'Please resubmit',
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.skyBlueLight.withValues(alpha: 0.9),
            AppTheme.primaryColor.withValues(alpha: 0.12),
          ],
        ),
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
              child: Image.asset(
                KycMascotIllustration._brandBearFallback,
                fit: BoxFit.contain,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _caption,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primaryColor,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
