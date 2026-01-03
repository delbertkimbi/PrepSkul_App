import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/core/utils/safe_set_state.dart';
import 'package:prepskul/core/services/log_service.dart';
import 'package:prepskul/core/services/supabase_service.dart';
import 'package:prepskul/core/services/auth_service.dart' hide LogService;
import 'package:prepskul/core/services/tutor_onboarding_progress_service.dart';
import 'package:prepskul/core/localization/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EmailConfirmationScreen extends StatefulWidget {
  final String email;
  final String fullName;
  final String userRole;

  const EmailConfirmationScreen({
    Key? key,
    required this.email,
    required this.fullName,
    required this.userRole,
  }) : super(key: key);

  @override
  State<EmailConfirmationScreen> createState() =>
      _EmailConfirmationScreenState();
}

class _EmailConfirmationScreenState extends State<EmailConfirmationScreen> {
  bool _isResending = false;
  bool _isProcessingVerification = false;
  int _resendCountdown = 60;
  StreamSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();
    _startCountdown();
    _listenToAuthStateChanges();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  void _listenToAuthStateChanges() {
    _authSubscription = SupabaseService.authStateChanges.listen((
      AuthState state,
    ) async {
      if (!mounted) return;
      if (state.event == AuthChangeEvent.signedIn &&
          state.session?.user != null) {
        safeSetState(() => _isProcessingVerification = true);
        try {
          await AuthService.completeEmailVerification(state.session!.user);
          if (!mounted) return;
          await _navigateAfterVerification();
        } catch (e) {
          final message = AuthService.parseAuthError(e);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(message, style: GoogleFonts.poppins()),
                backgroundColor: AppTheme.primaryColor,
                behavior: SnackBarBehavior.floating,
                margin: const EdgeInsets.all(16),
              ),
            );
          }
        } finally {
          if (mounted) {
            safeSetState(() => _isProcessingVerification = false);
          }
        }
      }
    });
  }

  Future<void> _navigateAfterVerification() async {
    final prefs = await SharedPreferences.getInstance();
    final user = SupabaseService.currentUser;

    if (!mounted) return;
    if (user == null) return;

    try {
      // Wait a moment for profile to be created by completeEmailVerification
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Check if this is a first-time signup by checking profile creation time
      // or if survey_completed is false/null
      // Also check user_type to ensure it was set correctly
      final profile = await SupabaseService.client
          .from('profiles')
          .select('survey_completed, created_at, user_type')
          .eq('id', user.id)
          .maybeSingle();
      
      // If profile doesn't exist or user_type is missing, create it now
      if (profile == null || profile['user_type'] == null || (profile['user_type'] as String).isEmpty) {
        LogService.warning('Profile missing or user_type not set after verification - creating now');
        final storedRole = prefs.getString('signup_user_role') ?? widget.userRole;
        await SupabaseService.client.from('profiles').upsert({
          'id': user.id,
          'email': user.email ?? widget.email,
          'full_name': widget.fullName,
          'phone_number': null,
          'user_type': storedRole,
          'survey_completed': false,
          'is_admin': false,
        }, onConflict: 'id');
        
        // Re-fetch profile
        final updatedProfile = await SupabaseService.client
            .from('profiles')
            .select('survey_completed, created_at, user_type')
            .eq('id', user.id)
            .maybeSingle();
        
        final userRole = updatedProfile?['user_type'] ?? storedRole;
        final surveyCompleted = updatedProfile?['survey_completed'] ?? false;
        final isFirstSignup = !surveyCompleted;
        
        // Continue with navigation using the correct role
        await _navigateBasedOnRole(userRole, isFirstSignup, prefs);
        return;
      }
      
      final userRole = profile['user_type'] ?? widget.userRole;
      final surveyCompleted = profile['survey_completed'] ?? false;
      final isFirstSignup = !surveyCompleted;
      
      // Continue with navigation using the correct role
      await _navigateBasedOnRole(userRole, isFirstSignup, prefs);
    } catch (e) {
      LogService.error('Error navigating after verification', e);
      if (mounted) {
        // Fallback: try to navigate using widget.userRole
        final fallbackRole = widget.userRole;
        LogService.warning('Using fallback role: $fallbackRole');
        await _navigateBasedOnRole(fallbackRole, true, prefs);
      }
    }
  }
  
  /// Navigate based on user role after email verification
  Future<void> _navigateBasedOnRole(String userRole, bool isFirstSignup, SharedPreferences prefs) async {
    final user = SupabaseService.currentUser;
    if (user == null || !mounted) return;
    
    try {
        // Save auth method preference
        await prefs.setString('auth_method', 'email');

        // For new users, ensure survey_intro_seen is cleared so they see the intro screen
        await prefs.setBool('survey_intro_seen', false);
      LogService.info('Email user verification - cleared survey_intro_seen flag');

        // Clear stored signup data (no longer needed)
        await prefs.remove('signup_user_role');
        await prefs.remove('signup_full_name');
        await prefs.remove('signup_email');

        // Navigate based on role
      if (!mounted) return;
      
          if (userRole == 'tutor') {
            // For tutors, check tutor-specific onboarding status
            try {
              final onboardingComplete = await TutorOnboardingProgressService.isOnboardingComplete(user.id);
            final onboardingSkipped = await TutorOnboardingProgressService.isOnboardingSkipped(user.id);
            
              if (onboardingComplete || onboardingSkipped) {
                // Tutor onboarding complete or skipped - go directly to dashboard
                LogService.success('Tutor onboarding complete - navigating to dashboard');
                Navigator.pushReplacementNamed(context, '/tutor-nav');
              } else {
                // Check if it's a new tutor (no progress at all)
                final progress = await TutorOnboardingProgressService.loadProgress(user.id);
            if (progress == null && !onboardingSkipped) {
                  // New tutor - show choice screen
              LogService.success('New tutor signup - navigating to onboarding choice screen');
              Navigator.pushReplacementNamed(context, '/tutor-onboarding-choice');
            } else {
                  // Has some progress - go to dashboard (they can continue from there)
              LogService.success('Tutor with existing progress - navigating to dashboard');
                  Navigator.pushReplacementNamed(context, '/tutor-nav');
                }
              }
            } catch (e) {
              LogService.warning('Error checking tutor onboarding: $e - navigating to dashboard');
              // On error, go to dashboard (better than blocking user)
              Navigator.pushReplacementNamed(context, '/tutor-nav');
            }
      } else if (userRole == 'student' || userRole == 'learner' || userRole == 'parent') {
        // For first-time signup (student/parent/learner), always show survey intro
        if (isFirstSignup) {
          LogService.info('First signup detected - showing survey intro for $userRole');
          Navigator.pushNamedAndRemoveUntil(
            context,
            '/survey-intro',
            (route) => false,
            arguments: {'userType': userRole},
          );
        } else {
            // Show survey intro for students/parents who haven't seen it
            final surveyIntroSeen = prefs.getBool('survey_intro_seen') ?? false;
            if (!surveyIntroSeen) {
              LogService.success('Navigating to survey intro screen for $userRole');
              Navigator.pushReplacementNamed(
              context,
              '/survey-intro',
              arguments: {'userType': userRole},
              );
            } else {
            // Survey intro already seen, go to appropriate dashboard
            final route = userRole == 'parent' ? '/parent-nav' : '/student-nav';
            Navigator.pushReplacementNamed(context, route);
          }
            }
          } else {
        LogService.info('Unknown role - navigating to profile setup');
            Navigator.pushReplacementNamed(
              context,
              '/profile-setup',
              arguments: {'userRole': userRole},
            );
      }
    } catch (e) {
      LogService.error('Error in _navigateBasedOnRole', e);
      if (mounted) {
        // Final fallback: navigate to student dashboard
        Navigator.pushReplacementNamed(context, '/student-nav');
      }
    }
  }

  void _startCountdown() {
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted && _resendCountdown > 0) {
        safeSetState(() => _resendCountdown--);
        _startCountdown();
      }
    });
  }

  Future<void> _resendEmail() async {
    if (_resendCountdown > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please wait ${_resendCountdown} seconds before resending',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: AppTheme.primaryColor,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
        ),
      );
      return;
    }

    safeSetState(() => _isResending = true);

    try {
      // Resend confirmation email with proper redirect URL
      await AuthService.resendEmailVerification(widget.email);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Confirmation email sent to ${widget.email}',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: AppTheme.primaryColor,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 3),
          ),
        );

        safeSetState(() {
          _resendCountdown = 60;
        });
        _startCountdown();
      }
    } catch (e) {
      if (mounted) {
        final errorMessage = AuthService.parseAuthError(e);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage, style: GoogleFonts.poppins()),
            backgroundColor: AppTheme.primaryColor,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        safeSetState(() => _isResending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          // Curved wave background at top
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: ClipPath(
              clipper: WaveClipper(),
              child: Container(
                height: 200,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppTheme.primaryColor,
                      AppTheme.primaryColor.withOpacity(0.85),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Main content
          SafeArea(
            child: Column(
              children: [
                // Header content inside the wave
                Padding(
                  padding: const EdgeInsets.fromLTRB(24.0, 29.0, 24.0, 30.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 15),
                      Center(
                        child: Text(
                          t.authCheckEmailTitle,
                          style: GoogleFonts.poppins(
                            fontSize: 32,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Center(
                        child: Text(
                          t.authCheckEmailSubtitle,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            color: Colors.white.withOpacity(0.95),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Form content
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(height: 50),

                        // Email icon
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(50),
                          ),
                          child: Icon(
                            Icons.mark_email_read_outlined,
                            size: 50,
                            color: AppTheme.primaryColor,
                            ),
                        ),

                        const SizedBox(height: 24),

                        // Email address
                        Text(
                          widget.email,
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primaryColor,
                          ),
                          textAlign: TextAlign.center,
                        ),

                        const SizedBox(height: 8),

                        if (_isProcessingVerification)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      AppTheme.primaryColor,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  t.authDetectedVerification,
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    color: AppTheme.textMedium,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          const SizedBox(height: 24),

                        const SizedBox(height: 20),

                        // Info box
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: AppTheme.primaryColor.withOpacity(0.2),
                              width: 1,
                            ),
                          ),
                          child: Column(
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    color: AppTheme.primaryColor,
                                    size: 24,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'What\'s next?',
                                          style: GoogleFonts.poppins(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: AppTheme.textDark,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          widget.userRole == 'tutor'
                                              ? '1. Check your inbox (and spam folder)\n2. Click the confirmation link\n3. Complete your tutor profile!'
                                              : '1. Check your inbox (and spam folder)\n2. Click the confirmation link\n3. Find your perfect tutor!',
                                          style: GoogleFonts.poppins(
                                            fontSize: 14,
                                            color: AppTheme.textMedium,
                                            height: 1.6,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 32),

                        // Resend email button
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: OutlinedButton.icon(
                            onPressed:
                                _resendCountdown > 0 ||
                                    _isResending ||
                                    _isProcessingVerification
                                ? null
                                : _resendEmail,
                            icon: _isResending
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.refresh_outlined),
                            label: Text(
                              _resendCountdown > 0
                                  ? t.authResendEmail(_resendCountdown)
                                  : t.authResendEmailButton,
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(
                                color: AppTheme.primaryColor,
                                width: 1.5,
                                ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Change email link
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                          child: Text(
                            'Wrong email address?',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.textMedium,
                            ),
                          ),
                        ),

                        const SizedBox(height: 40),

                        // Help text
                        Text(
                          t.authDidntReceiveEmail,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: AppTheme.textLight,
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Reuse WaveClipper
class WaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height * 0.85);
    path.quadraticBezierTo(
      size.width * 0.25,
      size.height,
      size.width * 0.5,
      size.height * 0.85,
    );
    path.quadraticBezierTo(
      size.width * 0.75,
      size.height * 0.7,
      size.width,
      size.height * 0.85,
    );
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
