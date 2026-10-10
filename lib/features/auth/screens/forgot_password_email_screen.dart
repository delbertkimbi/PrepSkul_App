import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/core/utils/safe_set_state.dart';
import 'package:prepskul/core/utils/status_bar_utils.dart';
import 'package:prepskul/core/services/log_service.dart';
import 'package:prepskul/core/services/auth_service.dart';
import 'package:prepskul/core/widgets/offline_dialog.dart';
import 'package:prepskul/features/onboarding/learner/learner_onboarding_chrome.dart';

class ForgotPasswordEmailScreen extends StatefulWidget {
  const ForgotPasswordEmailScreen({
    Key? key,
    this.linkExpiredError = false,
  }) : super(key: key);

  /// When true, shows an error that the reset link expired and a "Request new link" action
  final bool linkExpiredError;

  @override
  State<ForgotPasswordEmailScreen> createState() =>
      _ForgotPasswordEmailScreenState();
}

class _ForgotPasswordEmailScreenState extends State<ForgotPasswordEmailScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isLoading = false;
  bool _emailSent = false;

  Future<void> _handleSendResetEmail() async {
    if (!_formKey.currentState!.validate()) return;

    safeSetState(() => _isLoading = true);

    try {
      final email = _emailController.text.trim();

      // Send password reset email
      await AuthService.sendPasswordResetEmail(email);

      if (mounted) {
        safeSetState(() => _emailSent = true);
      }
    } catch (e) {
      if (mounted) {
        final errorMessage = AuthService.parseAuthError(e);
        
        // Check if this is an offline error - show branded offline dialog
        if (errorMessage == 'OFFLINE_ERROR' || AuthService.isOfflineError(e)) {
          await OfflineDialog.show(
            context,
            message: 'Unable to send password reset email. Please check your internet connection and try again.',
          );
        } else {
          // Show regular error as SnackBar
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage, style: GoogleFonts.poppins()),
              backgroundColor: AppTheme.primaryColor,
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.all(16),
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    } finally {
      if (mounted) {
        safeSetState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StatusBarUtils.withLightStatusBar(
      Scaffold(
      backgroundColor: OnboardPalette.cream,
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          // Curved wave background at top
          
          // Main content
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const AuthPaperHeader(
                    title: 'Reset password',
                    subtitle: 'We’ll send a link to your email.',
                  ),

                  // Link expired error banner
                  if (widget.linkExpiredError) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'The reset link expired. Request a new one below.',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: AppTheme.textDark,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Email icon
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(60),
                    ),
                    child: Icon(
                      _emailSent
                          ? Icons.mark_email_read_outlined
                          : Icons.lock_reset_outlined,
                      size: 60,
                      color: Colors.white,
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Title
                  Text(
                    _emailSent ? 'Check your email' : 'Reset Password',
                    style: GoogleFonts.poppins(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textDark,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 16),

                  // Subtitle
                  if (_emailSent) ...[
                    Text(
                      'We\'ve sent password reset instructions to',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                        color: AppTheme.textMedium,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _emailController.text.trim(),
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    // Helpful tips
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppTheme.primaryColor.withOpacity(0.2),
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
                                color: AppTheme.primaryColor,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Didn\'t receive the email?',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                                '• Check your spam/junk folder\n• Wait a few minutes (emails can take 1-5 minutes)\n• Make sure you used the correct email address\n• Link expired? Request a new one below\n',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: AppTheme.textDark,
                              height: 1.6,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextButton.icon(
                      onPressed: _isLoading ? null : _handleSendResetEmail,
                      icon: const Icon(Icons.refresh),
                      label: Text(
                        'Request new link',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ] else ...[
                    Text(
                      'Enter your email address and we\'ll send you a link to reset your password',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                        color: AppTheme.textMedium,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],

                  if (!_emailSent) ...[
                    const SizedBox(height: 12),
                    Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Email Field
                          Text(
                            'Email Address',
                            style: onboardFont(size: 14, weight: FontWeight.w800),
                          ),
                          const SizedBox(height: 5),
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter your email address';
                              }
                              if (!RegExp(
                                r'^[^@]+@[^@]+\.[^@]+',
                              ).hasMatch(value.trim())) {
                                return 'Please enter a valid email address';
                              }
                              return null;
                            },
                            decoration: paperFieldDecoration(hintText: 'your.email@example.com'),
                            style: onboardFont(size: 14, weight: FontWeight.w800),
                          ),

                          const SizedBox(height: 32),

                          // Send Reset Email Button
                          OnboardPrimaryButton(
                            label: 'Send Reset Link',
                            busy: _isLoading,
                            onTap: _handleSendResetEmail,
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),

                  // Reset with phone instead
                  Center(
                    child: TextButton(
                      onPressed: () {
                        Navigator.pushReplacementNamed(
                          context,
                          '/forgot-password',
                        );
                      },
                      child: Text(
                        'Reset with phone instead?',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.textMedium,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Back to Login
                  Center(
                    child: TextButton(
                      onPressed: () {
                        if (Navigator.canPop(context)) {
                          Navigator.pop(context);
                        } else {
                          Navigator.pushReplacementNamed(context, '/email-login');
                        }
                      },
                      child: Text(
                        'Back to Login',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }
}

