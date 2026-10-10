import 'package:flutter/material.dart';
import 'package:prepskul/core/services/log_service.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/tutor_onboarding_progress_service.dart';
import '../../../core/services/notification_helper_service.dart';
import 'tutor_onboarding_screen.dart';
import 'package:prepskul/core/widgets/alive_mate.dart';
import 'package:prepskul/features/onboarding/learner/learner_onboarding_chrome.dart';

class TutorOnboardingChoiceScreen extends StatefulWidget {
  const TutorOnboardingChoiceScreen({super.key});

  @override
  State<TutorOnboardingChoiceScreen> createState() =>
      _TutorOnboardingChoiceScreenState();
}

class _TutorOnboardingChoiceScreenState
    extends State<TutorOnboardingChoiceScreen> {
  bool _isLoading = false;

  Future<void> _proceedWithOnboarding() async {
    setState(() => _isLoading = true);

    try {
      final user = await AuthService.getCurrentUser();
      final userId = user['userId'] as String;

      // Resume onboarding (clear skip flag if it was set)
      await TutorOnboardingProgressService.resumeOnboarding(userId);

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const TutorOnboardingScreen(basicInfo: {}),
          ),
        );
      }
    } catch (e) {
      LogService.error('Error proceeding with onboarding: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error: ${e.toString()}',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: AppTheme.primaryColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _skipForLater() async {
    setState(() => _isLoading = true);

    try {
      final user = await AuthService.getCurrentUser();
      final userId = user['userId'] as String;

      // Mark onboarding as skipped
      await TutorOnboardingProgressService.skipOnboarding(userId);

      // Verify user is actually a tutor before sending notification
      final userRole = await AuthService.getUserRole();
      if (userRole != 'tutor') {
        LogService.debug('Skipping onboarding notification for non-tutor user: $userId (role: $userRole)');
        // Still allow navigation but skip notification
        if (mounted) {
          Navigator.pushNamedAndRemoveUntil(
            context,
            '/tutor-nav',
            (route) => false,
          );
        }
        return;
      }

      // Mark survey as completed (so they can access the app)
      // But they'll be restricted until they complete onboarding
      await AuthService.saveSession(
        userId: userId,
        userRole: 'tutor',
        phone: user['phone'] ?? '',
        fullName: user['fullName'] ?? 'Tutor',
        surveyCompleted: true, // Allow access but with restrictions
        rememberMe: true,
      );

      // Send onboarding reminder (in-app + email + push via API)
      await NotificationHelperService.sendOnboardingReminder(
        userId: userId,
        title: 'Complete Your Profile to Get Verified',
        message: 'Your profile isn\'t visible to students yet. Complete your onboarding to get verified and start connecting with students who match your expertise.',
        actionUrl: '/tutor-onboarding',
        metadata: {
          'onboarding_skipped': true,
          'onboarding_complete': false,
        },
      );

      if (mounted) {
        // Navigate to tutor dashboard
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/tutor-nav',
          (route) => false,
        );
      }
    } catch (e) {
      LogService.error('Error skipping onboarding: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error: ${e.toString()}',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: AppTheme.primaryColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OnboardPalette.cream,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 12),
              prepMate(mood: Mood.wave, size: 96),
              const SizedBox(height: 16),
              Text(
                'Welcome, tutor',
                style: onboardDisplay(size: 26),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                'Tell us more about yourself so we can match you with the right students and get you approved.',
                style: onboardFont(
                  size: 15,
                  weight: FontWeight.w700,
                  color: AppTheme.textMedium,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              OnboardPrimaryButton(
                label: 'Proceed with Onboarding',
                onTap: _proceedWithOnboarding,
                busy: _isLoading,
              ),
              const SizedBox(height: 16),
              OnboardPaperButton(
                label: 'Skip for Later',
                onTap: _isLoading ? () {} : _skipForLater,
              ),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: OnboardPalette.paperCard,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.info_outline,
                          color: AppTheme.primaryColor,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Important',
                          style: onboardFont(size: 14),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'If you skip onboarding:\n\n• Your profile will not be visible to students\n• You will need to complete onboarding to access all features\n• You can complete it anytime from your profile',
                      style: onboardFont(
                        size: 13,
                        weight: FontWeight.w700,
                        color: AppTheme.textMedium,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
