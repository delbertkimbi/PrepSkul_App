import 'package:flutter/material.dart';
import 'package:prepskul/core/theme/app_theme.dart';

import '../l10n/skulmate_copy.dart';
import '../services/skulmate_onboarding_prefs.dart';
import '../services/skulmate_welcome_service.dart';
import 'skulmate_surface_styles.dart';
import 'skulmate_typography.dart';

/// First-visit intro when the learner opens the SkulMate tab.
class SkulMateWelcomeSheet {
  SkulMateWelcomeSheet._();

  static Future<void> showIfNeeded(BuildContext context) async {
    if (await SkulMateOnboardingPrefs.hasSeenWelcome()) return;
    if (await SkulMateWelcomeService.hasSeenWelcome()) return;
    if (!context.mounted) return;
    await show(context);
  }

  static Future<void> show(
    BuildContext context, {
    bool isParent = false,
  }) async {
    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _WelcomeBody(isParent: isParent),
    );
    await SkulMateOnboardingPrefs.markWelcomeSeen();
    await SkulMateWelcomeService.markSeen();
  }
}

class _WelcomeBody extends StatelessWidget {
  final bool isParent;

  const _WelcomeBody({this.isParent = false});

  @override
  Widget build(BuildContext context) {
    final copy = SkulMateCopy.of(context);
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppTheme.textDark.withValues(alpha: 0.1),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(24, 20, 24, 16 + bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.neutral200,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                copy.welcomeSheetTitle,
                textAlign: TextAlign.center,
                style: SkulMateTypography.screenTitle(),
              ),
              const SizedBox(height: 8),
              Text(
                copy.welcomeHeadline(),
                textAlign: TextAlign.center,
                style: SkulMateTypography.body(color: AppTheme.textMedium),
              ),
              const SizedBox(height: 20),
              _BenefitRow(
                icon: Icons.upload_file_rounded,
                text: copy.welcomeBenefitNotes(),
              ),
              const SizedBox(height: 10),
              _BenefitRow(
                icon: Icons.replay_rounded,
                text: copy.welcomeBenefitResume(),
              ),
              const SizedBox(height: 10),
              _BenefitRow(
                icon: Icons.auto_awesome_rounded,
                text: copy.welcomeAiLine(),
              ),
              const SizedBox(height: 22),
              FilledButton(
                onPressed: () => Navigator.pop(context),
                style: SkulMateSurfaceStyles.deckAccentButton(),
                child: Text(copy.welcomeCta),
              ),
            ],
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppTheme.skyBlueLight.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 20, color: AppTheme.primaryColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: SkulMateTypography.body(),
          ),
        ),
      ],
    );
  }
}
