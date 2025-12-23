import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/core/utils/safe_set_state.dart';
import 'package:prepskul/core/services/log_service.dart';
import 'package:prepskul/core/services/supabase_service.dart';
import 'package:prepskul/core/services/auth_service.dart';
import 'package:prepskul/core/services/tutor_onboarding_progress_service.dart';
import 'package:prepskul/core/services/notification_service.dart';
import 'package:prepskul/core/widgets/branded_snackbar.dart';
import 'package:prepskul/core/navigation/navigation_service.dart';
import 'package:prepskul/core/localization/app_localizations.dart';
import 'forgot_password_email_screen.dart';

class EmailLoginScreen extends StatefulWidget {
  const EmailLoginScreen({Key? key}) : super(key: key);

  @override
  State<EmailLoginScreen> createState() => _EmailLoginScreenState();
}

class _EmailLoginScreenState extends State<EmailLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  // Cooldown timer
  DateTime? _lastLoginAttempt;
  static const int _cooldownSeconds = 60;

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
                          'Log in',
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
                          'Welcome back!',
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
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 50),
                        Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Email Field
                              Text(
                                t.authEmail,
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: AppTheme.textDark,
                                ),
                              ),
                              const SizedBox(height: 5),
                              TextFormField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return t.authFieldRequired;
                                  }
                                  if (!value.contains('@')) {
                                    return t.authInvalidEmail;
                                  }
                                  return null;
                                },
                                decoration: InputDecoration(
                                  hintText: 'your.email@example.com',
                                  hintStyle: GoogleFonts.poppins(
                                    color: AppTheme.textLight,
                                    fontSize: 14,
                                  ),
                                  filled: true,
                                  fillColor: AppTheme.softCard,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(20),
                                    borderSide: const BorderSide(
                                      color: AppTheme.softBorder,
                                      width: 1,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(20),
                                    borderSide: const BorderSide(
                                      color: AppTheme.softBorder,
                                      width: 1,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(20),
                                    borderSide: const BorderSide(
                                      color: AppTheme.primaryColor,
                                      width: 2,
                                    ),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 16,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),

                              // Password Field
                              Text(
                                'Password',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: AppTheme.textDark,
                                ),
                              ),
                              const SizedBox(height: 5),
                              TextFormField(
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter your password';
                                  }
                                  return null;
                                },
                                decoration: InputDecoration(
                                  hintText: 'Enter your password',
                                  hintStyle: GoogleFonts.poppins(
                                    color: AppTheme.textLight,
                                    fontSize: 14,
                                  ),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                    ),
                                    onPressed: () {
                                      safeSetState(() {
                                        _obscurePassword = !_obscurePassword;
                                      });
                                    },
                                  ),
                                  filled: true,
                                  fillColor: AppTheme.softCard,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(20),
                                    borderSide: const BorderSide(
                                      color: AppTheme.softBorder,
                                      width: 1,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(20),
                                    borderSide: const BorderSide(
                                      color: AppTheme.softBorder,
                                      width: 1,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(20),
                                    borderSide: const BorderSide(
                                      color: AppTheme.primaryColor,
                                      width: 2,
                                    ),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 16,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),

                              // Forgot Password
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const ForgotPasswordEmailScreen(),
                                      ),
                                    );
                                  },
                                  child: Text(
                                    t.authForgotPassword,
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: AppTheme.primaryColor,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 32),

                              // Login Button
                              SizedBox(
                                width: double.infinity,
                                height: 56,
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _handleLogin,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.primaryColor,
                                    foregroundColor: Colors.white,
                                    elevation: 2,
                                    shadowColor: AppTheme.primaryColor
                                        .withOpacity(0.3),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(28),
                                    ),
                                  ),
                                  child: _isLoading
                                      ? const SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                  Colors.white,
                                                ),
                                          ),
                                        )
                                      : Text(
                                          'Log in',
                                          style: GoogleFonts.poppins(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(height: 24),

                              // Sign up link
                              Center(
                                child: Column(
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          t.authNoAccount,
                                          style: GoogleFonts.poppins(
                                            fontSize: 14,
                                            color: AppTheme.textMedium,
                                          ),
                                        ),
                                        GestureDetector(
                                          onTap: () {
                                            Navigator.pushReplacementNamed(
                                              context,
                                              '/email-signup',
                                            );
                                          },
                                          child: Text(
                                            t.authSignUp,
                                            style: GoogleFonts.poppins(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: AppTheme.primaryColor,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    TextButton(
                                      onPressed: () {
                                        Navigator.pushNamedAndRemoveUntil(
                                          context,
                                          '/auth-method-selection',
                                          (route) => false,
                                        );
                                      },
                                      child: Text(
                                        t.authTryAnotherMethod,
                                        style: GoogleFonts.poppins(
                                          fontSize: 14,
                                          color: AppTheme.primaryColor,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
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

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    safeSetState(() => _isLoading = true);

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text;

      // Sign in with email/password
      final response = await SupabaseService.client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user == null) {
        throw Exception('Login failed');
      }

      // Get user profile
      var profile = await SupabaseService.client
          .from('profiles')
          .select()
          .eq('id', response.user!.id)
          .maybeSingle();

      // Declare userRole early - will be set from profile
      String userRole = '';
      
      if (profile == null) {
        // Profile doesn't exist - user needs to complete signup
        // Redirect to profile setup instead of throwing error
        if (mounted) {
          Navigator.pushReplacementNamed(
            context,
            '/profile-setup',
            arguments: {'userRole': 'learner'}, // Default to learner
          );
        }
        return; // Exit early, don't throw error
      }

      // Debug: Log profile data to help diagnose user_type issues
      final authEmail = response.user!.email?.toLowerCase().trim() ?? '';
      final profileEmail = profile['email']?.toString().toLowerCase().trim() ?? '';
      
      LogService.debug('[EMAIL_LOGIN] ========== PROFILE VERIFICATION ==========');
      LogService.debug('[EMAIL_LOGIN] Auth User ID: ${response.user!.id}');
      LogService.debug('[EMAIL_LOGIN] Auth Email: $authEmail');
      LogService.debug('[EMAIL_LOGIN] Profile Email: $profileEmail');
      LogService.debug('[EMAIL_LOGIN] Profile user_type: ${profile['user_type']}');
      LogService.debug('[EMAIL_LOGIN] Profile full_name: ${profile['full_name']}');
      LogService.debug('[EMAIL_LOGIN] Profile ID: ${profile?['id']}');
      
      // Set userRole from profile
      userRole = profile?['user_type']?.toString().trim() ?? '';
      
      // CRITICAL: Verify email matches between auth and profile
      if (authEmail.isNotEmpty && profileEmail.isNotEmpty && authEmail != profileEmail) {
        LogService.warning('[EMAIL_LOGIN] ⚠️ EMAIL MISMATCH DETECTED! ⚠️');
        LogService.warning('[EMAIL_LOGIN] Auth email ($authEmail) does not match profile email ($profileEmail)');
        LogService.warning('[EMAIL_LOGIN] This indicates a data integrity issue - profile may belong to different account');
        
        // Try to find profile by auth email instead
        try {
          final correctProfile = await SupabaseService.client
              .from('profiles')
              .select()
              .eq('email', authEmail)
              .maybeSingle();
          
          if (correctProfile != null) {
            LogService.success('[EMAIL_LOGIN] Found profile matching auth email: ${correctProfile['id']}');
            LogService.success('[EMAIL_LOGIN] Correct profile user_type: ${correctProfile['user_type']}');
            LogService.success('[EMAIL_LOGIN] Correct profile name: ${correctProfile['full_name']}');
            
            // Check if correct profile's user_id matches auth user_id
            if (correctProfile['id'] == response.user!.id) {
              LogService.success('[EMAIL_LOGIN] Profile IDs match - using correct profile');
              // Use the correct profile
              final correctUserRole = correctProfile['user_type']?.toString().trim() ?? 'learner';
              LogService.success('[EMAIL_LOGIN] Using user_type from correct profile: $correctUserRole');
              
              // Save session with correct data
              await AuthService.saveSession(
                userId: response.user!.id,
                userRole: correctUserRole,
                phone: correctProfile['phone_number'] ?? '',
                fullName: correctProfile['full_name'] ?? '',
                surveyCompleted: correctProfile['survey_completed'] ?? false,
                rememberMe: true,
              );
              
              // Continue with navigation using correct role
              final surveyCompleted = correctProfile['survey_completed'] ?? false;
              if (mounted) {
                // Navigate based on correct user role
                if (correctUserRole == 'tutor') {
                  Navigator.pushReplacementNamed(context, '/tutor-nav');
                } else if (correctUserRole == 'parent') {
                  Navigator.pushReplacementNamed(context, '/parent-nav');
                } else {
                  Navigator.pushReplacementNamed(context, '/student-nav');
                }
              }
              return; // Exit early with correct profile
            } else {
              LogService.warning('[EMAIL_LOGIN] Profile with matching email has different user_id');
              LogService.warning('[EMAIL_LOGIN] This suggests multiple accounts with similar emails');
              LogService.warning('[EMAIL_LOGIN] Current auth user ID: ${response.user!.id}');
              LogService.warning('[EMAIL_LOGIN] Profile user ID: ${correctProfile['id']}');
            }
          } else {
            // No profile found with matching email - update current profile to match auth email
            LogService.warning('[EMAIL_LOGIN] No profile found with auth email - updating current profile');
            try {
              // Check if user is a tutor by checking tutor_profiles table
              final tutorProfile = await SupabaseService.client
                  .from('tutor_profiles')
                  .select('user_id, status')
                  .eq('user_id', response.user!.id)
                  .maybeSingle();
              
              String? correctUserType;
              if (tutorProfile != null) {
                correctUserType = 'tutor';
                LogService.success('[EMAIL_LOGIN] Found tutor_profiles entry - user is a tutor');
                userRole = 'tutor'; // Set userRole immediately
              }
              
              // Update profile with correct email and user_type
              final updateData = <String, dynamic>{
                'email': authEmail,
              };
              if (correctUserType != null) {
                updateData['user_type'] = correctUserType;
              }
              
              await SupabaseService.client
                  .from('profiles')
                  .update(updateData)
                  .eq('id', response.user!.id);
              
              LogService.success('[EMAIL_LOGIN] Updated profile email to match auth email');
              if (correctUserType != null) {
                LogService.success('[EMAIL_LOGIN] Updated profile user_type to: $correctUserType');
              }
              
              // Reload profile to get updated data
              final updatedProfile = await SupabaseService.client
                  .from('profiles')
                  .select()
                  .eq('id', response.user!.id)
                  .maybeSingle();
              if (updatedProfile != null) {
                // Use updated profile
                profile = updatedProfile;
                // Update userRole from updated profile if not already set
                if (userRole.isEmpty) {
                  userRole = updatedProfile['user_type']?.toString().trim() ?? '';
                }
              }
            } catch (updateError) {
              LogService.warning('[EMAIL_LOGIN] Error updating profile: $updateError');
            }
          }
        } catch (e) {
          LogService.warning('[EMAIL_LOGIN] Error searching for profile by email: $e');
        }
      }
      
      // Set userRole from profile (if not already set from email mismatch check)
      if (userRole.isEmpty) {
        userRole = profile?['user_type']?.toString().trim() ?? '';
      }
      
      if (userRole.isEmpty || userRole == 'null') {
        LogService.warning('[EMAIL_LOGIN] user_type is missing or invalid, checking auth metadata...');
        userRole = response.user!.userMetadata?['user_type']?.toString() ?? 'learner';
        LogService.debug('[EMAIL_LOGIN] Using user_type from metadata: $userRole');
        
        // Update profile with correct user_type if we found it
        if (userRole != 'learner' && userRole.isNotEmpty) {
          try {
            await SupabaseService.client
                .from('profiles')
                .update({'user_type': userRole})
                .eq('id', response.user!.id);
            LogService.success('[EMAIL_LOGIN] Updated profile user_type to: $userRole');
          } catch (e) {
            LogService.warning('[EMAIL_LOGIN] Failed to update user_type: $e');
          }
        }
      }
      
      // Final fallback
      if (userRole.isEmpty) {
        userRole = 'learner';
        LogService.warning('[EMAIL_LOGIN] Using default user_type: learner');
      }
      
      LogService.debug('[EMAIL_LOGIN] ===========================================');

      // Save session
      await AuthService.saveSession(
        userId: response.user!.id,
        userRole: userRole,
        phone: profile?['phone_number'] ?? '',
        fullName: profile?['full_name'] ?? '',
        surveyCompleted: profile?['survey_completed'] ?? false,
        rememberMe: true,
      );

      // Check if survey is completed
      final surveyCompleted = profile?['survey_completed'] ?? false;

      if (mounted) {
        // Check if there's a pending deep link to navigate to (e.g., from rejection email)
        final prefs = await SharedPreferences.getInstance();
        final pendingDeepLink = prefs.getString('pending_deep_link');
        
        if (pendingDeepLink != null && pendingDeepLink.isNotEmpty) {
          // Clear the pending deep link
          await prefs.remove('pending_deep_link');
          LogService.debug('🔗 [EMAIL_LOGIN] Found pending deep link: $pendingDeepLink');
          
          // Navigate to the pending deep link
          final navService = NavigationService();
          if (navService.isReady) {
            await navService.navigateToRoute(pendingDeepLink, replace: true);
          } else {
            // Queue the deep link for later processing
            navService.queueDeepLink(Uri.parse(pendingDeepLink));
            // Fallback to default navigation if deep link fails
            if (surveyCompleted) {
              if (userRole == 'tutor') {
                Navigator.pushReplacementNamed(context, '/tutor-nav');
              } else if (userRole == 'parent') {
                Navigator.pushReplacementNamed(context, '/parent-nav');
              } else {
                Navigator.pushReplacementNamed(context, '/student-nav');
              }
            } else {
              Navigator.pushReplacementNamed(
                context,
                '/profile-setup',
                arguments: {'userRole': userRole},
              );
            }
          }
          return; // Exit early after handling deep link
        }

        // No pending deep link, use default navigation
        // Use NavigationService to determine correct route (handles intro screen, onboarding, etc.)
        final navService = NavigationService();
        if (navService.isReady) {
          // Send onboarding notification if needed (only once per day) for tutors
          if (userRole == 'tutor') {
            _sendOnboardingNotificationIfNeeded(response.user!.id);
          }
          
          final routeResult = await navService.determineInitialRoute();
          navService.navigateToRoute(
            routeResult.route, 
            arguments: routeResult.arguments,
            replace: true
          );
        } else {
          // Fallback manual navigation
          if (userRole == 'tutor') {
            _sendOnboardingNotificationIfNeeded(response.user!.id);
            Navigator.pushReplacementNamed(context, '/tutor-nav');
          } else if (surveyCompleted) {
            if (userRole == 'parent') {
              Navigator.pushReplacementNamed(context, '/parent-nav');
            } else {
              Navigator.pushReplacementNamed(context, '/student-nav');
            }
          } else {
            // Check intro seen
            final prefs = await SharedPreferences.getInstance();
            final introSeen = prefs.getBool('survey_intro_seen') ?? false;
            
            if (!introSeen) {
              Navigator.pushReplacementNamed(
                context, 
                '/survey-intro',
                arguments: {'userType': userRole},
              );
            } else {
              Navigator.pushReplacementNamed(
                context,
                '/profile-setup',
                arguments: {'userRole': userRole},
              );
            }
          }
        }
      }
    } catch (e) {
      LogService.error('Email login error: $e');
      if (mounted) {
        final errorMessage = AuthService.parseAuthError(e);
        final isWarning = errorMessage.toLowerCase().contains('too many attempts') || 
                          errorMessage.toLowerCase().contains('wait');

        if (isWarning) {
          BrandedSnackBar.showInfo(context, errorMessage);
        } else {
          BrandedSnackBar.showError(context, errorMessage);
        }
      }
    } finally {
      if (mounted) {
        safeSetState(() => _isLoading = false);
      }
    }
  }

  /// Send onboarding notification if needed (only once per day)
  Future<void> _sendOnboardingNotificationIfNeeded(String userId) async {
    try {
      // Verify user is actually a tutor before sending notification
      final userRole = await AuthService.getUserRole();
      if (userRole != 'tutor') {
        LogService.debug('Skipping onboarding notification for non-tutor user: $userId (role: $userRole)');
        return;
      }
      
      // Check if onboarding is incomplete or skipped
      final onboardingSkipped = await TutorOnboardingProgressService.isOnboardingSkipped(userId);
      final onboardingComplete = await TutorOnboardingProgressService.isOnboardingComplete(userId);
      
      if (onboardingSkipped || !onboardingComplete) {
        // Check if we've already sent this notification today (avoid spam)
        final prefs = await SharedPreferences.getInstance();
        final lastNotificationDate = prefs.getString('onboarding_notification_date');
        final today = DateTime.now().toIso8601String().split('T')[0];
        
        if (lastNotificationDate != today) {
          // Send professional notification
          await NotificationService.createNotification(
            userId: userId,
            type: 'onboarding_reminder',
            title: 'Complete Your Profile to Get Verified',
            message: onboardingSkipped
                ? 'Your profile isn\'t visible to students yet. Complete your onboarding to get verified and start connecting with students who match your expertise.'
                : 'Finish your profile setup to get verified and start connecting with students who need your expertise. Complete your onboarding to become visible and start teaching.',
            priority: 'high',
            actionUrl: '/tutor-onboarding',
            actionText: 'Complete Profile',
            icon: '🎓',
            metadata: {
              'onboarding_skipped': onboardingSkipped,
              'onboarding_complete': onboardingComplete,
            },
          );
          
          // Save today's date to avoid sending multiple notifications per day
          await prefs.setString('onboarding_notification_date', today);
          LogService.success('Onboarding notification sent to tutor: $userId');
        }
      }
    } catch (e) {
      LogService.warning('Error sending onboarding notification: $e');
      // Don't block login if notification fails
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
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
