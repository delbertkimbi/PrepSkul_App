import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';

class NotificationPermissionSheet extends StatelessWidget {
  final bool isDeniedPermanently;
  final bool isRequestInProgress;
  final VoidCallback onPrimaryAction;
  final VoidCallback onNotNow;

  const NotificationPermissionSheet({
    super.key,
    required this.isDeniedPermanently,
    required this.isRequestInProgress,
    required this.onPrimaryAction,
    required this.onNotNow,
  });

  @override
  Widget build(BuildContext context) {
    final title = isDeniedPermanently ? 'Turn on notifications in Settings' : 'Turn on notifications';
    final primaryLabel = isDeniedPermanently ? 'Open Settings' : 'Enable notifications';

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.neutral300,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(15),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.notifications_active, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                      color: AppTheme.textDark,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Get the right updates at the right time.',
              style: GoogleFonts.poppins(
                fontSize: 13,
                height: 1.4,
                color: AppTheme.textMedium,
              ),
            ),
            const SizedBox(height: 14),
            _BenefitRow(
              icon: Icons.chat_bubble_outline,
              title: 'Messages',
              subtitle: 'Don’t miss replies from tutors/students.',
            ),
            const SizedBox(height: 10),
            _BenefitRow(
              icon: Icons.event_available,
              title: 'Session reminders',
              subtitle: 'Get reminded before lessons and trials.',
            ),
            const SizedBox(height: 10),
            _BenefitRow(
              icon: Icons.payments_outlined,
              title: 'Booking updates',
              subtitle: 'Approvals, changes, and important updates.',
            ),
            if (isDeniedPermanently) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.neutral50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.neutral200),
                ),
                child: Text(
                  'You previously denied notifications. To enable them, open Settings and turn on notifications for PrepSkul.',
                  style: GoogleFonts.poppins(
                    fontSize: 12.5,
                    height: 1.45,
                    color: AppTheme.textMedium,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isRequestInProgress ? null : onPrimaryAction,
                child: isRequestInProgress
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(primaryLabel),
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: isRequestInProgress ? null : onNotNow,
                child: Text(
                  'Not now',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.neutral700,
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

class _BenefitRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _BenefitRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: AppTheme.skyBlueLight,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 18, color: AppTheme.primaryColor),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textDark,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                subtitle,
                style: GoogleFonts.poppins(
                  fontSize: 12.5,
                  height: 1.35,
                  color: AppTheme.textMedium,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

