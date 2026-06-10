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
import 'package:prepskul/features/auth/screens/otp_verification_screen.dart';

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
    return StatusBarUtils.withDarkStatusBar(
      Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          // Curved gradient hero header
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: ClipPath(
              clipper: WaveClipper(),
              child: Container(
                height: 190,
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
                // Header content
                Padding(
                  padding: const EdgeInsets.fromLTRB(24.0, 22.0, 24.0, 18.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 10),
                      Center(
                        child: Text(
                          t.authSignUpTitle,
                          style: GoogleFonts.poppins(
                            fontSize: 30,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 5),
                      // Subtitle
                      Center(
                        child: Text(
                          'Join us to start your learning journey',
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

                // Form content - below the wave
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(height: 48),
                        // Form
                        Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Full Name Field
                              Text(
                                t.authFullName,
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
                                    return t.authFieldRequired;
                                  }
                                  if (value.trim().length < 3) {
                                    return 'Name must be at least 3 characters';
                                  }
                                  return null;
                                },
                                decoration: InputDecoration(
                                  hintText: t.authFullNameHint,
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
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: AppTheme.textDark,
                                ),
                              ),

                              const SizedBox(height: 15),

                              // Phone Number Field
                              Text(
                                'Phone Number',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: AppTheme.textDark,
                                ),
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
                                      decoration: InputDecoration(
                                        hintText: '6 53 30 19 97',
                                        hintStyle: GoogleFonts.poppins(
                                          color: AppTheme.textLight,
                                          fontSize: 14,
                                        ),
                                        filled: true,
                                        fillColor: AppTheme.softCard,
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                          borderSide: const BorderSide(
                                            color: AppTheme.softBorder,
                                            width: 1,
                                          ),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                          borderSide: const BorderSide(
                                            color: AppTheme.softBorder,
                                            width: 1,
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                          borderSide: const BorderSide(
                                            color: AppTheme.primaryColor,
                                            width: 2,
                                          ),
                                        ),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 20,
                                              vertical: 16,
                                            ),
                                      ),
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: AppTheme.textDark,
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 15),

                              // Password Field
                              Text(
                                t.authPassword,
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
                                    return t.authFieldRequired;
                                  }
                                  if (value.length < 6) {
                                    return t.authInvalidPassword;
                                  }
                                  return null;
                                },
                                decoration: InputDecoration(
                                  hintText: t.authPasswordHint,
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
                                  suffixIcon: GestureDetector(
                                    onTap: () {
                                      safeSetState(() {
                                        _obscurePassword = !_obscurePassword;
                                      });
                                    },
                                    child: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_off
                                          : Icons.visibility,
                                      color: AppTheme.textMedium,
                                      size: 20,
                                    ),
                                  ),
                                ),
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: AppTheme.textDark,
                                ),
                              ),

                              const SizedBox(height: 15),

                              // Confirm Password Field
                              Text(
                                'Confirm password',
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
                                    return 'Please confirm password';
                                  }
                                  if (value != _passwordController.text) {
                                    return 'Passwords do not match';
                                  }
                                  return null;
                                },
                                decoration: InputDecoration(
                                  hintText: 'Confirm Password',
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
                                  suffixIcon: GestureDetector(
                                    onTap: () {
                                      safeSetState(() {
                                        _obscureConfirmPassword =
                                            !_obscureConfirmPassword;
                                      });
                                    },
                                    child: Icon(
                                      _obscureConfirmPassword
                                          ? Icons.visibility_off
                                          : Icons.visibility,
                                      color: AppTheme.textMedium,
                                      size: 20,
                                    ),
                                  ),
                                ),
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: AppTheme.textDark,
                                ),
                              ),

                              const SizedBox(height: 27),

                              // Sign Up Button
                              SizedBox(
                                width: double.infinity,
                                height: 56,
                                child: ElevatedButton(
                                  onPressed: _isLoading ? () {} : _handleSignup,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.primaryColor,
                                    foregroundColor: Colors.white,
                                    disabledBackgroundColor: AppTheme.primaryColor, // Keep blue when disabled
                                    disabledForegroundColor: Colors.white, // Keep white text when disabled
                                    elevation: 2,
                                    shadowColor: AppTheme.primaryColor
                                        .withOpacity(0.3),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(22),
                                    ),
                                  ),
                                  child: _isLoading
                                      ? const SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2.5,
                                          ),
                                        )
                                      : Text(
                                          'Sign up',
                                          style: GoogleFonts.poppins(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                ),
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

      await AuthService.saveSession(
        userId: user.id,
        userRole: '',
        phone: phoneNumber,
        fullName: _nameController.text.trim(),
        surveyCompleted: false,
        rememberMe: true,
      );

      if (mounted) {
        final navService = NavigationService();
        if (navService.isReady) {
          final routeResult = await navService.determineInitialRoute();
          await navService.navigateToRoute(
            routeResult.route,
            arguments: routeResult.arguments,
            replace: true,
          );
        } else {
          Navigator.pushReplacementNamed(context, '/role-selection');
        }
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

// Custom wave clipper for the header - Clean and professional
class WaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    var path = Path();

    // Start from top-left corner
    path.lineTo(0, size.height - 50); // Straight down left side

    // Create smooth, gentle wave curve
    var controlPoint1 = Offset(size.width * 0.25, size.height - 30);
    var endPoint1 = Offset(size.width * 0.5, size.height - 40);

    path.quadraticBezierTo(
      controlPoint1.dx,
      controlPoint1.dy,
      endPoint1.dx,
      endPoint1.dy,
    );

    var controlPoint2 = Offset(size.width * 0.75, size.height - 50);
    var endPoint2 = Offset(size.width, size.height - 40);

    path.quadraticBezierTo(
      controlPoint2.dx,
      controlPoint2.dy,
      endPoint2.dx,
      endPoint2.dy,
    );

    // Complete the path
    path.lineTo(size.width, 0);
    path.close();

    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
