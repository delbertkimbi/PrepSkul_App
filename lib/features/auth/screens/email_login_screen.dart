import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/core/services/supabase_service.dart';
import 'package:prepskul/core/services/auth_service.dart';
import 'package:prepskul/core/services/log_service.dart';
import 'package:prepskul/core/config/app_config.dart';
import 'package:prepskul/core/navigation/navigation_service.dart';
import 'package:prepskul/core/utils/status_bar_utils.dart';
import 'package:prepskul/core/widgets/offline_dialog.dart';
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

  @override
  Widget build(BuildContext context) {
    return StatusBarUtils.withDarkStatusBar(
      Scaffold(
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
                decoration: const BoxDecoration(
                  gradient: AppTheme.headerGradient,
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
                                'Email Address',
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
                                    return 'Please enter your email';
                                  }
                                  if (!value.contains('@')) {
                                    return 'Please enter a valid email';
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
                                      setState(() {
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
                                    'Forgot Password?',
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
                                  onPressed: _isLoading ? () {} : _handleLogin,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.primaryColor,
                                    foregroundColor: Colors.white,
                                    disabledBackgroundColor: AppTheme.primaryColor, // Keep blue when disabled
                                    disabledForegroundColor: Colors.white, // Keep white text when disabled
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
                                            strokeWidth: 2.5,
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
                                            color: Colors.white,
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
                                          'Don\'t have an account? ',
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
                                            'Sign up',
                                            style: GoogleFonts.poppins(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: AppTheme.primaryColor,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    // Phone login option - only show if enabled
                                    if (AppConfig.enablePhoneSignIn) ...[
                                    const SizedBox(height: 16),
                                    TextButton(
                                      onPressed: () {
                                        Navigator.pushReplacementNamed(
                                          context,
                                          '/beautiful-login',
                                        );
                                      },
                                      child: Text(
                                        'Use phone number instead',
                                        style: GoogleFonts.poppins(
                                          fontSize: 14,
                                          color: AppTheme.primaryColor,
                                        ),
                                      ),
                                    ),
                                    ],
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
    ),
    );
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text;

      // Check if Supabase is initialized before attempting sign in
      if (!SupabaseService.isClientAvailable) {
        LogService.error('❌ [LOGIN] Supabase client not available');
        throw Exception(
          'Unable to connect to the server. Please check your internet connection and try again.',
        );
      }

      // Log Supabase configuration for debugging
      try {
        final supabaseUrl = AppConfig.supabaseUrl;
        LogService.debug('🔍 [LOGIN] Attempting login with Supabase URL: $supabaseUrl');
        LogService.debug('🔍 [LOGIN] Email: $email');
      } catch (e) {
        LogService.warning('⚠️ [LOGIN] Could not log Supabase URL: $e');
      }

      // Sign in with email/password
      final response = await SupabaseService.client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user == null) {
        throw Exception('Login failed');
      }

      // Get user profile
      final profile = await SupabaseService.client
          .from('profiles')
          .select()
          .eq('id', response.user!.id)
          .maybeSingle();

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

      // Save session
      await AuthService.saveSession(
        userId: response.user!.id,
        userRole: profile['user_type'] ?? 'learner',
        phone: profile['phone_number'] ?? '',
        fullName: profile['full_name'] ?? '',
        surveyCompleted: profile['survey_completed'] ?? false,
        rememberMe: true,
      );

      // Check if survey is completed
      final surveyCompleted = profile['survey_completed'] ?? false;
      final userRole = profile['user_type'] ?? 'learner';

      if (mounted) {
        // Check if there's a pending deep link to navigate to (e.g., from rejection email)
        final prefs = await SharedPreferences.getInstance();
        final pendingDeepLink = prefs.getString('pending_deep_link');
        
        if (pendingDeepLink != null && pendingDeepLink.isNotEmpty) {
          // Clear the pending deep link
          await prefs.remove('pending_deep_link');
          print('🔗 [EMAIL_LOGIN] Found pending deep link: $pendingDeepLink');
          
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
        if (surveyCompleted) {
          // Navigate to role-based dashboard
          if (userRole == 'tutor') {
            Navigator.pushReplacementNamed(context, '/tutor-nav');
          } else if (userRole == 'parent') {
            Navigator.pushReplacementNamed(context, '/parent-nav');
          } else {
            Navigator.pushReplacementNamed(context, '/student-nav');
          }
        } else {
          // Navigate to profile setup/survey
          Navigator.pushReplacementNamed(
            context,
            '/profile-setup',
            arguments: {'userRole': userRole},
          );
        }
      }
    } catch (e, stackTrace) {
      // Log detailed error information for debugging
      LogService.error('❌ Email login error: $e');
      LogService.error('❌ Error type: ${e.runtimeType}');
      LogService.error('❌ Stack trace: $stackTrace');
      LogService.error('❌ Error toString: ${e.toString()}');
      
      // Check if it's the HTML response error
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('<!doctype') || 
          (errorStr.contains('formatexception') && errorStr.contains('unexpected token'))) {
        LogService.error('🔍 [DIAGNOSIS] HTML Response Error Detected');
        LogService.error('   This means Supabase returned HTML instead of JSON');
        LogService.error('   Possible causes:');
        LogService.error('   1. Production domain not in Supabase allowed origins');
        LogService.error('   2. Wrong Supabase URL in root .env (check SUPABASE_URL_PROD)');
        LogService.error('   3. Root .env not bundled (check pubspec.yaml has .env in assets)');
        LogService.error('   4. Supabase project paused or deleted');
        LogService.error('   Current Supabase URL: ${AppConfig.supabaseUrl}');
      }
      
      if (mounted) {
        final errorMessage = AuthService.parseAuthError(e);
        
        // Check if this is an offline error - show branded offline dialog
        if (errorMessage == 'OFFLINE_ERROR' || AuthService.isOfflineError(e)) {
          await OfflineDialog.show(
            context,
            message: 'Unable to sign in. Please check your internet connection and try again.',
          );
        } else {
          // Show regular error as SnackBar
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
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
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
