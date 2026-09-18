import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/core/utils/safe_set_state.dart';
import 'package:prepskul/core/utils/status_bar_utils.dart';
import 'package:prepskul/core/services/log_service.dart';
import 'package:prepskul/core/services/supabase_service.dart';
import 'package:prepskul/core/config/app_config.dart';
import 'package:prepskul/core/localization/app_localizations.dart';
import 'package:prepskul/core/services/auth_service.dart';
import 'package:prepskul/core/services/profile_bootstrap_service.dart';
import 'package:prepskul/core/services/phone_auth_service.dart';
import 'package:prepskul/core/navigation/navigation_service.dart';
import 'package:prepskul/core/models/phone_country.dart';
import 'package:prepskul/core/widgets/phone_country_code_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:prepskul/features/auth/screens/otp_verification_screen.dart';
import 'package:prepskul/features/onboarding/learner/learner_onboarding_chrome.dart';

class BeautifulSignupScreen extends StatefulWidget {
  const BeautifulSignupScreen({Key? key}) : super(key: key);

  @override
  State<BeautifulSignupScreen> createState() => _BeautifulSignupScreenState();
}

class _BeautifulSignupScreenState extends State<BeautifulSignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  PhoneCountry _selectedCountry = PhoneCountry.cameroon;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return StatusBarUtils.withLightStatusBar(
      Scaffold(
      backgroundColor: OnboardPalette.cream,
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          // Curved gradient hero header
          
          // Main content
          SafeArea(
            child: Column(
              children: [
                AuthPaperHeader(
                  title: t.authSignUpTitle,
                  subtitle: 'Parents count as students too.',
                ),

                // Form content - below the wave
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(height: 12),
                        // Form
                        Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Full Name Field
                              Text(
                                t.authFullName,
                                style: onboardFont(size: 14, weight: FontWeight.w800),
                              ),
                              const SizedBox(height: 5),
                              TextFormField(
                                controller: _nameController,
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return t.authFieldRequired;
                                  }
                                  if (value.trim().length < 3) {
                                    return 'Name must be at least 3 characters';
                                  }
                                  return null;
                                },
                                decoration: paperFieldDecoration(hintText: t.authFullNameHint),
                                style: onboardFont(size: 14, weight: FontWeight.w800),
                              ),

                              const SizedBox(height: 15),

                              // Phone Number Field
                              Text(
                                'Phone Number',
                                style: onboardFont(size: 14, weight: FontWeight.w800),
                              ),
                              const SizedBox(height: 5),
                              Row(
                                children: [
                                  PhoneCountryCodePicker(
                                    selected: _selectedCountry,
                                    onChanged: (country) {
                                      safeSetState(() => _selectedCountry = country);
                                    },
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: TextFormField(
                                      controller: _phoneController,
                                      keyboardType: TextInputType.phone,
                                      validator: (value) =>
                                          PhoneCountry.validateLocalNumber(
                                            _selectedCountry,
                                            value ?? '',
                                          ),
                                      decoration: paperFieldDecoration(hintText: t.authPhoneHint),
                                      style: onboardFont(size: 14, weight: FontWeight.w800),
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 15),

                              // Password Field
                              Text(
                                t.authPassword,
                                style: onboardFont(size: 14, weight: FontWeight.w800),
                              ),
                              const SizedBox(height: 5),
                              TextFormField(
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return t.authFieldRequired;
                                  }
                                  if (value.length < 6) {
                                    return t.authInvalidPassword;
                                  }
                                  return null;
                                },
                                decoration: paperFieldDecoration(
                                  hintText: t.authPasswordHint,
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
                                ),
                                style: onboardFont(size: 14, weight: FontWeight.w800),
                              ),

                              const SizedBox(height: 15),

                              // Confirm Password Field
                              Text(
                                'Confirm password',
                                style: onboardFont(size: 14, weight: FontWeight.w800),
                              ),
                              const SizedBox(height: 5),
                              TextFormField(
                                controller: _confirmPasswordController,
                                obscureText: _obscureConfirmPassword,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please confirm password';
                                  }
                                  if (value != _passwordController.text) {
                                    return 'Passwords do not match';
                                  }
                                  return null;
                                },
                                decoration: paperFieldDecoration(
                                  hintText: 'Confirm Password',
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscureConfirmPassword
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                    ),
                                    onPressed: () {
                                      safeSetState(() {
                                        _obscureConfirmPassword =
                                            !_obscureConfirmPassword;
                                      });
                                    },
                                  ),
                                ),
                                style: onboardFont(size: 14, weight: FontWeight.w800),
                              ),

                              const SizedBox(height: 27),

                              // Sign Up Button
                              OnboardPrimaryButton(
                                label: 'Sign up',
                                busy: _isLoading,
                                onTap: _handleSignup,
                              ),

                              const SizedBox(height: 32),

                              Center(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
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
                                          '/beautiful-login',
                                        );
                                      },
                                      child: Text(
                                        'Log in',
                                        style: GoogleFonts.poppins(
                                          fontSize: 14,
                                          color: AppTheme.primaryColor,
                                          fontWeight: FontWeight.w600,
                                          decoration: TextDecoration.underline,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 16),

                              Center(
                                child: TextButton(
                                  onPressed: () {
                                    Navigator.pushNamedAndRemoveUntil(
                                      context,
                                      '/auth-method-selection',
                                      (route) => false,
                                    );
                                  },
                                  child: Text(
                                    'Try another auth method',
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.primaryColor,
                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 32),
                            ],
                          ),
                        ),

                        const SizedBox(height: 32),
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

  Future<void> _handleSignup() async {
    // Validate form
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Check if passwords match
    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Passwords do not match', style: GoogleFonts.poppins()),
          backgroundColor: AppTheme.primaryColor,
        ),
      );
      return;
    }

    final phoneNumber = PhoneCountry.formatFullNumber(
      _selectedCountry,
      _phoneController.text.trim(),
    );

    LogService.debug('📱 Formatted phone number: $phoneNumber');

    safeSetState(() => _isLoading = true);

    try {
      // Always verify phone number is not already attributed to an existing account.
      final matchingProfiles = await SupabaseService.client
          .from('profiles')
          .select('id')
          .eq('phone_number', phoneNumber)
          .limit(2);

      if (matchingProfiles.isNotEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'This phone number is already linked to another account. Please log in instead.',
                style: GoogleFonts.poppins(),
              ),
              backgroundColor: AppTheme.primaryColor,
            ),
          );
        }
        return;
      }

      // Toggle OTP flow from AppConfig.
      if (AppConfig.enablePhoneOtpVerification) {
        await SupabaseService.sendPhoneOTP(phoneNumber);
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => OTPVerificationScreen(
                phoneNumber: phoneNumber,
                fullName: _nameController.text.trim(),
              ),
            ),
          );
        }
        return;
      }

      // Password-based phone signup (no OTP, no inbox): admin-confirmed alias account.
      final response = await PhoneAuthService.signUpWithPhone(
        phoneNumber: phoneNumber,
        password: _passwordController.text,
        fullName: _nameController.text.trim(),
      );

      final user = SupabaseService.currentUser ?? response.user;
      if (user == null) {
        throw Exception('Could not create account');
      }

      await ProfileBootstrapService.upsertProfile(
        userId: user.id,
        fullName: _nameController.text.trim(),
        email: user.email,
        phoneNumber: phoneNumber,
      );

      // No OTP: account is created but user must sign in before role selection.
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('signup_full_name', _nameController.text.trim());
      await SupabaseService.client.auth.signOut();
      await prefs.remove('is_logged_in');
      await prefs.remove('user_role');
      await prefs.remove('user_id');
      await prefs.remove('user_phone');
      await prefs.remove('user_name');
      await prefs.remove('survey_completed');

      if (mounted) {
        NavigationService.resetStackNamed(
          context,
          '/beautiful-login',
          arguments: {
            'phone': _phoneController.text.trim(),
            'countryIso': _selectedCountry.isoCode,
            'accountCreatedMessage':
                'Account created! Sign in with your phone and password to continue.',
          },
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AuthService.parseAuthError(e),
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: AppTheme.primaryColor,
          ),
        );
      }
    } finally {
      if (mounted) {
        safeSetState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
}

