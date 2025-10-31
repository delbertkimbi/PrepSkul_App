import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/core/services/supabase_service.dart';
import 'package:prepskul/core/services/auth_service.dart';
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
  State<EmailConfirmationScreen> createState() => _EmailConfirmationScreenState();
}

class _EmailConfirmationScreenState extends State<EmailConfirmationScreen> {
  bool _isResending = false;
  int _resendCountdown = 60; // Countdown in seconds
  bool _isChecking = false;

  @override
  void initState() {
    super.initState();
    _startCountdown();
    _checkEmailConfirmation(); // Check if email was already confirmed
  }

  Future<void> _checkEmailConfirmation() async {
    // Poll for email confirmation every 5 seconds
    Future.delayed(const Duration(seconds: 5), () async {
      if (!mounted) return;

      setState(() => _isChecking = true);

      try {
        final user = SupabaseService.currentUser;
        if (user != null && user.emailConfirmedAt != null) {
          // Email confirmed - proceed with profile creation
          await _proceedToSurvey();
        } else {
          // Keep checking
          _checkEmailConfirmation();
        }
      } catch (e) {
        print('Error checking email confirmation: $e');
        // Keep checking despite errors
        _checkEmailConfirmation();
      } finally {
        if (mounted) {
          setState(() => _isChecking = false);
        }
      }
    });
  }

  Future<void> _proceedToSurvey() async {
    try {
      final user = SupabaseService.currentUser;
      if (user == null) {
        throw Exception('User not found');
      }

      // Create profile entry
      await SupabaseService.client.from('profiles').insert({
        'id': user.id,
        'email': widget.email,
        'full_name': widget.fullName,
        'phone_number': null,
        'user_type': widget.userRole,
        'avatar_url': null,
        'survey_completed': false,
        'is_admin': false,
      });

      // Save session
      await AuthService.saveSession(
        userId: user.id,
        userRole: widget.userRole,
        phone: '',
        fullName: widget.fullName,
        surveyCompleted: false,
        rememberMe: true,
      );

      // Save auth method preference
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_method', 'email');

      // Navigate to survey
      if (mounted) {
        Navigator.pushReplacementNamed(
          context,
          '/profile-setup',
          arguments: {'userRole': widget.userRole},
        );
      }
    } catch (e) {
      print('Error proceeding to survey: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error: ${e.toString()}',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _startCountdown() {
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted && _resendCountdown > 0) {
        setState(() => _resendCountdown--);
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
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isResending = true);

    try {
      // Resend confirmation email
      await SupabaseService.client.auth.resend(
        type: OtpType.signup,
        email: widget.email,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Confirmation email sent to ${widget.email}',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.green,
          ),
        );

        setState(() {
          _resendCountdown = 60;
        });
        _startCountdown();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to resend email. Please try again.',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isResending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 40),

              // Email icon
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(60),
                ),
                child: Icon(
                  Icons.mark_email_read_outlined,
                  size: 60,
                  color: AppTheme.primaryColor,
                ),
              ),

              const SizedBox(height: 32),

              // Title
              Text(
                'Check your email',
                style: GoogleFonts.poppins(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textDark,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 16),

              // Subtitle
              Text(
                'We\'ve sent a confirmation link to',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  color: AppTheme.textMedium,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 8),

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

              const SizedBox(height: 16),

              // Auto-checking indicator
              if (_isChecking)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
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
                        'Checking for confirmation...',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: AppTheme.textMedium,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                )
              else
                const SizedBox(height: 8),

              const SizedBox(height: 16),

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
                            crossAxisAlignment: CrossAxisAlignment.start,
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
                                '1. Check your inbox (and spam folder)\n2. Click the confirmation link\n3. Start learning with PrepSkul!',
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
                  onPressed: _resendCountdown > 0 || _isResending
                      ? null
                      : _resendEmail,
                  icon: _isResending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh_outlined),
                  label: Text(
                    _resendCountdown > 0
                        ? 'Resend email ($_resendCountdown)'
                        : 'Resend confirmation email',
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
                'Didn\'t receive the email? Check your spam folder or contact support.',
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
    );
  }
}

