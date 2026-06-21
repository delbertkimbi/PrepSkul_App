import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import '../l10n/skulmate_copy.dart';
import '../services/skulmate_welcome_service.dart';
import 'skulmate_hero_mascot.dart';
import 'skulmate_sheet_scaffold.dart';
import 'skulmate_surface_styles.dart';

class SkulMateWelcomeSheet {
  static Future<void> show(
    BuildContext context, {
    bool isParent = false,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => _SkulMateWelcomeSheetContent(isParent: isParent),
    );
  }
}

class _SkulMateWelcomeSheetContent extends StatelessWidget {
  final bool isParent;

  const _SkulMateWelcomeSheetContent({required this.isParent});

  Future<void> _onContinue(BuildContext context) async {
    await SkulMateWelcomeService.markSeen();
    if (context.mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final copy = SkulMateCopy.read(context);

    return SkulMateSheetScaffold(
      title: copy.welcomeSheetTitle,
      showWandIcon: false,
      maxHeightFactor: 0.82,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Center(child: SkulMateHeroMascot()),
          const SizedBox(height: 8),
          Text(
            copy.welcomeHeadline(isParent: isParent),
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppTheme.textDark,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 18),
          _BenefitRow(
            icon: Icons.auto_awesome_rounded,
            text: copy.welcomeBenefitNotes(isParent: isParent),
          ),
          const SizedBox(height: 12),
          _BenefitRow(
            icon: Icons.play_circle_outline_rounded,
            text: copy.welcomeBenefitResume(isParent: isParent),
          ),
          const SizedBox(height: 12),
          _BenefitRow(
            icon: Icons.emoji_events_outlined,
            text: copy.welcomeBenefitLeaderboard(isParent: isParent),
          ),
          const SizedBox(height: 16),
          Text(
            copy.welcomeAiLine(isParent: isParent),
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: AppTheme.textMedium,
              height: 1.45,
            ),
          ),
        ],
      ),
      footer: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () => _onContinue(context),
          style: SkulMateSurfaceStyles.sheetPrimaryButton(),
          child: Text(
            copy.welcomeCta,
            style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _BenefitRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _BenefitRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: SkulMateSurfaceStyles.homeCard(radius: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: AppTheme.primaryColor),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppTheme.textDark,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
