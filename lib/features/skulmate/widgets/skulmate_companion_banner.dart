import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';

enum CompanionTone { tip, success, warning, neutral }

class SkulMateCompanionBanner extends StatelessWidget {
  final CompanionTone tone;
  final String message;
  final bool celebrate;
  final bool showLabelMascotIcon;
  final bool useBrandMascot;

  const SkulMateCompanionBanner({
    super.key,
    required this.tone,
    required this.message,
    this.celebrate = false,
    this.showLabelMascotIcon = false,
    this.useBrandMascot = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = _toneScheme(tone);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: scheme.border.withValues(alpha: 0.8)),
            ),
            child: Icon(
              celebrate ? Icons.auto_awesome_rounded : scheme.icon,
              size: 17,
              color: scheme.iconColor,
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (showLabelMascotIcon) ...[
                  Row(
                    children: [
                      Text(
                        'SkulMate',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textDark,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        useBrandMascot
                            ? Icons.school_rounded
                            : Icons.stars_rounded,
                        size: 14,
                        color: AppTheme.primaryColor,
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                ],
                Text(
                  message,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    height: 1.3,
                    color: AppTheme.textDark,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  _CompanionToneScheme _toneScheme(CompanionTone tone) {
    switch (tone) {
      case CompanionTone.success:
        return const _CompanionToneScheme(
          bg: Color(0xFFF0FDF4),
          border: Color(0xFF86EFAC),
          icon: Icons.check_circle_rounded,
          iconColor: Color(0xFF16A34A),
        );
      case CompanionTone.warning:
        return const _CompanionToneScheme(
          bg: Color(0xFFFFF7ED),
          border: Color(0xFFFAC58A),
          icon: Icons.info_rounded,
          iconColor: Color(0xFFEA580C),
        );
      case CompanionTone.neutral:
        return const _CompanionToneScheme(
          bg: Color(0xFFF8FAFC),
          border: Color(0xFFE2E8F0),
          icon: Icons.lightbulb_rounded,
          iconColor: Color(0xFF64748B),
        );
      case CompanionTone.tip:
        return const _CompanionToneScheme(
          bg: Color(0xFFEFF6FF),
          border: Color(0xFFBFDBFE),
          icon: Icons.tips_and_updates_rounded,
          iconColor: Color(0xFF2563EB),
        );
    }
  }
}

class _CompanionToneScheme {
  final Color bg;
  final Color border;
  final IconData icon;
  final Color iconColor;

  const _CompanionToneScheme({
    required this.bg,
    required this.border,
    required this.icon,
    required this.iconColor,
  });
}
