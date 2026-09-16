import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/features/primar/presentation/mascot.dart';

enum KycMascotVariant { intro, submitted, pending, rejected }

/// Cartoon Mate for KYC — same egg rig as onboarding, not photoreal PNGs.
class KycMascotIllustration extends StatelessWidget {
  final KycMascotVariant variant;

  const KycMascotIllustration({super.key, required this.variant});

  Mood get _mood => switch (variant) {
        KycMascotVariant.intro => Mood.idle,
        KycMascotVariant.submitted => Mood.happy,
        KycMascotVariant.pending => Mood.thinking,
        KycMascotVariant.rejected => Mood.encourage,
      };

  String get _caption => switch (variant) {
        KycMascotVariant.intro => 'One-time safety check',
        KycMascotVariant.submitted => 'Submitted for review',
        KycMascotVariant.pending => 'Review in progress',
        KycMascotVariant.rejected => 'Please resubmit',
      };

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 4 / 3,
      child: Container(
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
              child: Center(
                child: Mate(
                  mood: _mood,
                  size: 148,
                  ink: AppTheme.primaryColor,
                  body: AppTheme.skyBlue,
                  belly: AppTheme.skyBlueLight,
                  accent: AppTheme.softYellow,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
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
      ),
    );
  }
}
