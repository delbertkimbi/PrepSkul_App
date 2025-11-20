import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/core/services/supabase_service.dart';
import 'package:prepskul/core/services/auth_service.dart';
import 'package:prepskul/core/services/notification_helper_service.dart';
import 'package:prepskul/core/services/email_rate_limit_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'email_confirmation_screen.dart';

// Email validation regex
final _emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');

class EmailSignupScreen extends StatefulWidget {
  const EmailSignupScreen({super.key});

  @override
  State<EmailSignupScreen> createState() => _EmailSignupScreenState();
}

class _EmailSignupScreenState extends State<EmailSignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _selectedRole;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
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
                height: 180,
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
                  padding: const EdgeInsets.fromLTRB(24.0, 40.0, 24.0, 10.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Text(
                          'Sign up',
                          style: GoogleFonts.poppins(
                            fontSize: 32,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Center(
                        child: Text(
                          'Create your account with email',
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
                        const SizedBox(height: 45),
                        Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Full Name Field
                              Text(
                                'Full Name',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: AppTheme.textDark,
                                ),
                              ),
                              const SizedBox(height: 5),
                              TextFormField(
                                controller: _nameController,
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Please enter your full name';
                                  }
                                  if (value.trim().length < 3) {
                                    return 'Name must be at least 3 characters';
                                  }
                                  return null;
                                },
                                decoration: InputDecoration(
                                  hintText: 'Enter your name',
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
                                  if (!_emailRegex.hasMatch(value.trim())) {
                                    return 'Please enter a valid email address';
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
                                    return 'Please enter a password';
                                  }
                                  if (value.length < 6) {
                                    return 'Password must be at least 6 characters';
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
                              const SizedBox(height: 20),

                              // Confirm Password Field
                              Text(
                                'Confirm Password',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: AppTheme.textDark,
                                ),
                              ),
                              const SizedBox(height: 5),
                              TextFormField(
                                controller: _confirmPasswordController,
                                obscureText: _obscureConfirmPassword,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please confirm your password';
                                  }
                                  if (value != _passwordController.text) {
                                    return 'Passwords do not match';
                                  }
                                  return null;
                                },
                                decoration: InputDecoration(
                                  hintText: 'Confirm your password',
                                  hintStyle: GoogleFonts.poppins(
                                    color: AppTheme.textLight,
                                    fontSize: 14,
                                  ),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscureConfirmPassword
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _obscureConfirmPassword =
                                            !_obscureConfirmPassword;
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
                              const SizedBox(height: 32),

                              // Role Selection
                              Text(
                                'I am a...',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: AppTheme.textDark,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildRoleChip(
                                      'Student',
                                      'learner',
                                      Icons.school_outlined,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _buildRoleChip(
                                      'Parent',
                                      'parent',
                                      Icons.family_restroom_outlined,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _buildRoleChip(
                                      'Tutor',
                                      'tutor',
                                      Icons.person_outline,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 40),

                              // Signup Button
                              SizedBox(
                                width: double.infinity,
                                height: 56,
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _handleSignup,
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
                                          'Create Account',
                                          style: GoogleFonts.poppins(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(height: 24),

                              // Already have account?
                              Center(
                                child: Column(
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          'Already have an account? ',
                                          style: GoogleFonts.poppins(
                                            fontSize: 14,
                                            color: AppTheme.textMedium,
                                          ),
                                        ),
                                        GestureDetector(
                                          onTap: () {
                                            Navigator.pushReplacementNamed(
                                              context,
                                              '/email-login',
                                            );
                                          },
                                          child: Text(
                                            'Sign in',
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
                                        Navigator.pushReplacementNamed(
                                          context,
                                          '/beautiful-signup',
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

  Future<void> _handleSignup() async {
    // Validate form
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Check if role is selected
    if (_selectedRole == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please select your role',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: AppTheme.primaryColor,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
        ),
      );
      return;
    }

    // Check if passwords match
    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Passwords do not match', style: GoogleFonts.poppins()),
          backgroundColor: AppTheme.primaryColor,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text;
      final fullName = _nameController.text.trim();

      // Validate email format
      if (!_emailRegex.hasMatch(email)) {
        throw Exception('Please enter a valid email address');
      }

      // Check if email already exists in profiles table
      try {
        final existingProfile = await SupabaseService.client
            .from('profiles')
            .select('email')
            .eq('email', email)
            .maybeSingle();

        if (existingProfile != null) {
          throw Exception(
            'This email is already registered. Please sign in instead.',
          );
        }
      } catch (checkError) {
        // If the check itself fails, continue (don't block signup)
        // But if we got a profile, re-throw
        final errorStr = checkError.toString().toLowerCase();
        if (errorStr.contains('already registered') ||
            errorStr.contains('email')) {
          rethrow;
        }
      }

      // Get redirect URL for email verification
      final redirectUrl = AuthService.getRedirectUrl();
      final normalizedEmail = email.toLowerCase().trim();

      // Sign up with email/password
      AuthResponse? response;
      bool emailSent = false;
      bool rateLimitHit = false;

      try {
        response = await SupabaseService.client.auth.signUp(
          email: email,
          password: password,
          emailRedirectTo: redirectUrl,
        );

        if (response.user == null) {
          throw Exception('Failed to create account');
        }

        // Email was sent successfully
        emailSent = true;
        await EmailRateLimitService.recordEmailSent(normalizedEmail);
      } catch (signupError) {
        // Check if it's a rate limit error
        if (EmailRateLimitService.isRateLimitError(signupError)) {
          print('⚠️ Rate limit hit during signup - handling gracefully');
          rateLimitHit = true;

          // Set cooldown
          await EmailRateLimitService.setCooldown(normalizedEmail);

          // Supabase often creates the user account even if email sending fails
          // Try to get the current user (might have been created)
          final currentUser = SupabaseService.currentUser;
          if (currentUser != null &&
              currentUser.email?.toLowerCase() == normalizedEmail) {
            // User was created! Create response object
            response = AuthResponse(
              user: currentUser,
              session: SupabaseService.client.auth.currentSession,
            );
            print('✅ User account created despite rate limit');
          } else {
            // User wasn't created - wait a moment and retry once
            print('⏳ User not created yet, waiting before retry...');
            await Future.delayed(const Duration(seconds: 3));

            try {
              response = await SupabaseService.client.auth.signUp(
                email: email,
                password: password,
                emailRedirectTo: redirectUrl,
              );

              if (response.user != null) {
                emailSent = true;
                await EmailRateLimitService.recordEmailSent(normalizedEmail);
                print('✅ User created on retry');
              }
            } catch (retryError) {
              // Still rate limited - check if user exists now
              final retryUser = SupabaseService.currentUser;
              if (retryUser != null &&
                  retryUser.email?.toLowerCase() == normalizedEmail) {
                response = AuthResponse(
                  user: retryUser,
                  session: SupabaseService.client.auth.currentSession,
                );
                print('✅ User found after retry');
              } else {
                // User still not created - this is rare but possible
                // Show friendly message and ask to try again
                throw Exception(
                  'We\'re experiencing high demand. Please wait a moment and try again.',
                );
              }
            }
          }
        } else {
          // Not a rate limit error - rethrow
          rethrow;
        }
      }

      // Ensure we have a user and response
      if (response == null) {
        throw Exception('Failed to create account. Please try again.');
      }

      // Verify user exists (AuthResponse.user can be null)
      final user = response.user;
      if (user == null) {
        throw Exception('Failed to create account. Please try again.');
      }

      // At this point, we know user is not null, so we can use it safely

      // CRITICAL: Save profile data immediately (before email confirmation)
      // This ensures profile exists when user clicks email verification link
      try {
        await SupabaseService.client.from('profiles').upsert({
          'id': user.id,
          'email': email,
          'full_name': fullName,
          'phone_number': null,
          'user_type': _selectedRole,
          'avatar_url': null,
          'survey_completed': false,
          'is_admin': false,
        }, onConflict: 'id');
        print('✅ Profile created/updated for user: ${user.id}');

        // Notify admins about new user signup (async, don't block)
        NotificationHelperService.notifyAdminsAboutNewUserSignup(
          userId: user.id,
          userType: _selectedRole!,
          userName: fullName,
          userEmail: email,
        ).catchError((e) {
          print('⚠️ Error notifying admins about new user signup: $e');
          // Don't block signup if notification fails
        });
      } catch (e) {
        print('⚠️ Error creating profile: $e');
        // Continue anyway - profile might already exist or will be created later
      }

      // Store user role in SharedPreferences for email verification redirect
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('signup_user_role', _selectedRole!);
      await prefs.setString('signup_full_name', fullName);
      await prefs.setString('signup_email', email);
      await prefs.setString('auth_method', 'email');

      // Check if email confirmation is required
      final emailConfirmed = user.emailConfirmedAt != null;

      // If email is confirmed, navigate directly to survey
      if (emailConfirmed) {
        // Save session
        await AuthService.saveSession(
          userId: user.id,
          userRole: _selectedRole!,
          phone: '',
          fullName: fullName,
          surveyCompleted: false,
          rememberMe: true,
        );

        // Navigate to profile setup/survey
        if (mounted) {
          Navigator.pushReplacementNamed(
            context,
            '/profile-setup',
            arguments: {'userRole': _selectedRole},
          );
        }
      } else {
        // Email confirmation required - show confirmation screen
        if (mounted) {
          // Show success message (even if email wasn't sent due to rate limit)
          if (rateLimitHit && !emailSent) {
            // Subtle message that email will be sent soon
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Account created! Verification email will be sent shortly. You can also resend it from the next screen.',
                        style: GoogleFonts.poppins(fontSize: 14),
                      ),
                    ),
                  ],
                ),
                backgroundColor: AppTheme.primaryColor,
                behavior: SnackBarBehavior.floating,
                margin: const EdgeInsets.all(16),
                duration: const Duration(seconds: 5),
              ),
            );
          } else {
            // Normal success message
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(
                      Icons.check_circle_outline,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Account created! Please check your email to verify your account.',
                        style: GoogleFonts.poppins(fontSize: 14),
                      ),
                    ),
                  ],
                ),
                backgroundColor: Colors.green,
                behavior: SnackBarBehavior.floating,
                margin: const EdgeInsets.all(16),
                duration: const Duration(seconds: 3),
              ),
            );
          }

          // Navigate to confirmation screen
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => EmailConfirmationScreen(
                email: email,
                fullName: fullName,
                userRole: _selectedRole!,
              ),
            ),
          );
        }
      }
    } catch (e) {
      print('❌ Email signup error: $e');
      if (mounted) {
        // Check if it's a rate limit error - handle gracefully
        if (EmailRateLimitService.isRateLimitError(e)) {
          // Don't show rate limit error to user - navigate to confirmation screen anyway
          // The user account might have been created, and they can resend email
          final normalizedEmail = _emailController.text.trim().toLowerCase();

          // Check if user was created despite the error
          final existingUser = SupabaseService.currentUser;
          if (existingUser != null) {
            final existingEmail = existingUser.email?.toLowerCase();
            if (existingEmail == normalizedEmail) {
              // User was created - navigate to confirmation screen
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(
                        Icons.info_outline,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Account created! You can resend the verification email from the next screen.',
                          style: GoogleFonts.poppins(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                  backgroundColor: AppTheme.primaryColor,
                  behavior: SnackBarBehavior.floating,
                  margin: const EdgeInsets.all(16),
                  duration: const Duration(seconds: 4),
                ),
              );

              // Store signup data
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString('signup_user_role', _selectedRole!);
              await prefs.setString(
                'signup_full_name',
                _nameController.text.trim(),
              );
              await prefs.setString(
                'signup_email',
                _emailController.text.trim(),
              );
              await prefs.setString('auth_method', 'email');

              // Navigate to confirmation screen
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => EmailConfirmationScreen(
                    email: _emailController.text.trim(),
                    fullName: _nameController.text.trim(),
                    userRole: _selectedRole!,
                  ),
                ),
              );
              return;
            }
          }
        }

        // For other errors, show the error message
        final errorMessage = AuthService.parseAuthError(e);

        // Make error messages more user-friendly
        String friendlyMessage = errorMessage;
        if (errorMessage.toLowerCase().contains('email') &&
            errorMessage.toLowerCase().contains('already')) {
          friendlyMessage =
              'This email is already registered. Please sign in instead.';
        } else if (errorMessage.toLowerCase().contains('password') &&
            errorMessage.toLowerCase().contains('weak')) {
          friendlyMessage =
              'Password is too weak. Please use a stronger password with at least 6 characters.';
        } else if (errorMessage.toLowerCase().contains('network') ||
            errorMessage.toLowerCase().contains('connection')) {
          friendlyMessage =
              'Connection error. Please check your internet connection and try again.';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    friendlyMessage,
                    style: GoogleFonts.poppins(fontSize: 14),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red[600],
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'OK',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildRoleChip(String label, String value, IconData icon) {
    final isSelected = _selectedRole == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedRole = value;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor : AppTheme.softCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : AppTheme.softBorder,
            width: 2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : AppTheme.textMedium,
              size: 18,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isSelected ? Colors.white : AppTheme.textDark,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
}

// Reuse WaveClipper from beautiful_signup_screen
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
