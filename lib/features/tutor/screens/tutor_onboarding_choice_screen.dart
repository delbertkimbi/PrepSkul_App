import 'package:flutter/material.dart';
import 'package:prepskul/core/services/log_service.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/tutor_onboarding_progress_service.dart';
import '../../../core/services/notification_service.dart';
import 'tutor_onboarding_screen.dart';

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

      // Send notification about completing onboarding
      await NotificationService.createNotification(
        userId: userId,
        type: 'onboarding_reminder',
        title: 'Complete Your Profile to Get Verified',
        message: 'Your profile isn\'t visible to students yet. Complete your onboarding to get verified and start connecting with students who match your expertise.',
        priority: 'high',
        actionUrl: '/tutor-onboarding',
        actionText: 'Complete Profile',
        icon: '🎓',
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
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 24),
              // PrepSkul Logo
              Image.asset(
                'assets/images/app_logo(blue).png',
                width: 90,
                height: 90,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  // Fallback if image fails to load
                  return const Icon(
                  Icons.school,
                  size: 45,
                    color: AppTheme.primaryColor,
                  );
                },
              ),
              const SizedBox(height: 20),
              // Title
              Text(
                'Welcome to PrepSkul!',
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textDark,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              // Subtitle
              Text(
                'Tell us more about yourself so we can match you with the right students and get you approved on the platform.',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: AppTheme.textMedium,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              // Proceed Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _proceedWithOnboarding,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    elevation: 2,
                    shadowColor: AppTheme.primaryColor.withOpacity(0.3),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : Text(
                          'Proceed with Onboarding',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 16),
              // Skip Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: OutlinedButton(
                  onPressed: _isLoading ? null : _skipForLater,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.textDark,
                    side: BorderSide(
                      color: AppTheme.softBorder,
                      width: 2,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    'Skip for Later',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              // Info Box
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.grey[300]!,
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Colors.grey[700],
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Important Note',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textDark,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'If you skip onboarding:\n\n• Your profile will not be visible to students\n• You will need to complete onboarding to access all features\n• You can complete it anytime from your profile',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
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
