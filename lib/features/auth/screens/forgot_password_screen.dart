import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/core/utils/status_bar_utils.dart';
import 'package:prepskul/core/services/auth_service.dart';
import 'package:prepskul/core/widgets/offline_dialog.dart';
import 'package:prepskul/core/localization/app_localizations.dart';
import 'package:prepskul/features/onboarding/learner/learner_onboarding_chrome.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({Key? key}) : super(key: key);

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  bool _isLoading = false;

  Future<void> _handleSendOTP() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // Format phone number
      final phone = '+237${_phoneController.text.trim()}';

      // Send OTP
      await AuthService.sendPasswordResetOTP(phone);

      if (mounted) {
        // Navigate to OTP step (same UI as OTP verification: 6 boxes + countdown)
        Navigator.pushNamed(
          context,
          '/reset-password-otp',
          arguments: {'phone': phone},
        );
      }
    } catch (e) {
      if (mounted) {
        final errorMessage = AuthService.parseAuthError(e);
        
        // Check if this is an offline error - show branded offline dialog
        if (errorMessage == 'OFFLINE_ERROR' || AuthService.isOfflineError(e)) {
          await OfflineDialog.show(
            context,
            message: 'Unable to reset password. Please check your internet connection and try again.',
          );
        } else {
          // Show regular error as SnackBar
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                errorMessage,
                style: GoogleFonts.poppins(),
              ),
              backgroundColor: AppTheme.primaryColor,
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.all(16),
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
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return StatusBarUtils.withLightStatusBar(
      Scaffold(
      backgroundColor: OnboardPalette.cream,
      body: Stack(
        children: [
          // Curved wave background at top
          
          // Main content
          SafeArea(
            child: Column(
              children: [
                AuthPaperHeader(
                  title: t.authForgotPasswordTitle,
                  subtitle: t.authForgotPasswordSubtitle,
                ),

                // Form content - below the wave
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 12),
                        // Form
                        Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Phone Number Field
                              Text(
                                'Phone Number',
                                style: onboardFont(size: 14, weight: FontWeight.w800),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  // Country code
                                  Container(
                                    width: 80,
                                    height: 56,
                                    decoration: BoxDecoration(
                                      color: AppTheme.softBackground,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: AppTheme.softBorder,
                                        width: 1,
                                      ),
                                    ),
                                    child: Center(
                                      child: Text(
                                        '+237',
                                        style: onboardFont(size: 14, weight: FontWeight.w800),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  // Phone number input
                                  Expanded(
                                    child: TextFormField(
                                      controller: _phoneController,
                                      keyboardType: TextInputType.phone,
                                      decoration: paperFieldDecoration(hintText: '6 53 30 19 97'),
                                      style: onboardFont(size: 14, weight: FontWeight.w800),
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return t.authEnterPhoneNumber;
                                        }
                                        if (value.length != 9) {
                                          return t.authPhoneNumberLength;
                                        }
                                        return null;
                                      },
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 12),

                              // Send OTP Button
                              OnboardPrimaryButton(
                                label: 'Send OTP',
                                busy: _isLoading,
                                onTap: _handleSendOTP,
                              ),

                              const SizedBox(height: 16),

                              // Reset with email instead
                              Center(
                                child: TextButton(
                                  onPressed: () {
                                    Navigator.pushReplacementNamed(
                                      context,
                                      '/forgot-password-email',
                                    );
                                  },
                                  child: Text(
                                    'Reset with email instead?',
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: AppTheme.textMedium,
                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 24),

                              // Back to Login
                              Center(
                                child: TextButton(
                                  onPressed: () {
                                    Navigator.pop(context);
                                  },
                                  child: Text(
                                    t.authBackToLogin,
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.primaryColor,
                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 12),
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

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }
}

