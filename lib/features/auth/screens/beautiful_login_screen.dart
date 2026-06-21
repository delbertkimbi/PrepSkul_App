import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/core/utils/safe_set_state.dart';
import 'package:prepskul/core/utils/status_bar_utils.dart';
import 'package:prepskul/core/services/log_service.dart';
import 'package:prepskul/core/services/supabase_service.dart';
import 'package:prepskul/core/services/web_splash_service.dart';
import 'package:prepskul/core/config/app_config.dart';
import 'package:prepskul/core/localization/app_localizations.dart';
import 'package:prepskul/core/services/auth_service.dart';
import 'package:prepskul/core/services/phone_auth_service.dart';
import 'package:prepskul/core/navigation/navigation_service.dart';
import 'package:prepskul/core/models/phone_country.dart';
import 'package:prepskul/core/widgets/phone_country_code_picker.dart';
import 'package:prepskul/features/auth/screens/otp_verification_screen.dart';

class BeautifulLoginScreen extends StatefulWidget {
  final String? initialPhone;
  final String? initialCountryIso;
  final String? accountCreatedMessage;

  const BeautifulLoginScreen({
    Key? key,
    this.initialPhone,
    this.initialCountryIso,
    this.accountCreatedMessage,
  }) : super(key: key);

  @override
  State<BeautifulLoginScreen> createState() => _BeautifulLoginScreenState();
}

class _BeautifulLoginScreenState extends State<BeautifulLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  PhoneCountry _selectedCountry = PhoneCountry.cameroon;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        WebSplashService.removeSplash();
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _applyRouteArgs());
  }

  void _applyRouteArgs() {
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final phone = widget.initialPhone ?? args?['phone'] as String?;
    final countryIso =
        widget.initialCountryIso ?? args?['countryIso'] as String?;
    final createdMessage =
        widget.accountCreatedMessage ?? args?['accountCreatedMessage'] as String?;

    if (phone != null && phone.isNotEmpty) {
      _phoneController.text = phone;
    }
    if (countryIso != null && countryIso.isNotEmpty) {
      for (final country in PhoneCountry.all) {
        if (country.isoCode == countryIso) {
          _selectedCountry = country;
          break;
        }
      }
    }
    if (createdMessage != null && createdMessage.isNotEmpty && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(createdMessage, style: GoogleFonts.poppins()),
          backgroundColor: AppTheme.accentGreen,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    if (phone != null || countryIso != null) {
      safeSetState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return StatusBarUtils.withDarkStatusBar(
      Scaffold(
      backgroundColor: Colors.white,
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
                          t.authLogin,
                          style: GoogleFonts.poppins(
                            fontSize: 30,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 3),
                      // Subtitle
                      Center(
                        child: Text(
                          t.authLoginSubtitle,
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
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 48),
                        // Form
                        Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Phone Number Field
                              Text(
                                t.authPhoneNumber,
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: AppTheme.textDark,
                                ),
                              ),
                              const SizedBox(height: 12),
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
                                        hintText: t.authPhoneHint,
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

                              const SizedBox(height: 20),

                              // Password Field
                              Text(
                                t.authPassword,
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: AppTheme.textDark,
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _passwordController,
                                obscureText: _obscurePassword,
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

                              const SizedBox(height: 16),

                              // Forgot Password
                              Align(
                                alignment: Alignment.centerRight,
                                child: GestureDetector(
                                  onTap: () {
                                    Navigator.pushNamed(
                                      context,
                                      '/forgot-password',
                                    );
                                  },
                                  child: Text(
                                    'Forgot Password?',
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.primaryColor,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 40),

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
                                      borderRadius: BorderRadius.circular(24),
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
                                          t.authLoginButton,
                                          style: GoogleFonts.poppins(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                ),
                              ),

                              const SizedBox(height: 32),

                              // Sign Up Link
                              Center(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      '${t.authNoAccount} ',
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        color: AppTheme.textMedium,
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: () {
                                        Navigator.pushReplacementNamed(
                                          context,
                                          '/beautiful-signup',
                                        );
                                      },
                                      child: Text(
                                        t.authSignUp,
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

                              // Try another auth method Link
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
                                    t.authTryAnotherMethod,
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.primaryColor,
                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 40),
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

  Future<void> _handleLogin() async {
    // Validate form
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final phoneNumber = PhoneCountry.formatFullNumber(
      _selectedCountry,
      _phoneController.text.trim(),
    );

    LogService.debug('📱 Formatted phone number: $phoneNumber');

    safeSetState(() => _isLoading = true);

    bool phoneExistsInProfiles = false;

    try {
      if (kDebugMode) {
        final existingProfiles = await SupabaseService.client
            .from('profiles')
            .select('id')
            .eq('phone_number', phoneNumber)
            .limit(1);
        phoneExistsInProfiles = existingProfiles.isNotEmpty;
        LogService.debug(
          '[PHONE_LOGIN_DEBUG] phone=$phoneNumber exists_in_profiles=$phoneExistsInProfiles',
        );
      }

      // Toggle OTP flow from AppConfig.
      if (AppConfig.enablePhoneOtpVerification) {
        await SupabaseService.sendPhoneOTP(phoneNumber);
        final matchingProfiles = await SupabaseService.client
            .from('profiles')
            .select('full_name, user_type')
            .eq('phone_number', phoneNumber)
            .limit(1);
        final profile = matchingProfiles.isNotEmpty ? matchingProfiles.first : null;
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => OTPVerificationScreen(
                phoneNumber: phoneNumber,
                fullName: profile?['full_name']?.toString() ?? '',
                userRole: profile?['user_type']?.toString() ?? 'student',
              ),
            ),
          );
        }
        return;
      }

      // Password-based phone login (OTP disabled, no inbox step).
      late final dynamic response;
      try {
        response = await PhoneAuthService.signInWithPhone(
          phoneNumber: phoneNumber,
          password: _passwordController.text,
        );
      } catch (e) {
        // Backward compatibility for legacy accounts created with phone auth.
        final error = e.toString().toLowerCase();
        if (error.contains('invalid login credentials')) {
          response = await SupabaseService.client.auth.signInWithPassword(
            phone: phoneNumber,
            password: _passwordController.text,
          );
        } else {
          rethrow;
        }
      }

      final user = response.user;
      if (user == null) {
        throw Exception('Login failed');
      }

      // Historical duplicates can exist for phone_number; prioritize the first
      // (oldest) profile row for now instead of blocking login.
      final matchingProfiles = await SupabaseService.client
          .from('profiles')
          .select('id, full_name, user_type, phone_number, survey_completed, created_at')
          .eq('phone_number', phoneNumber)
          .order('created_at', ascending: true)
          .limit(50);
      if (matchingProfiles.isEmpty) {
        await SupabaseService.client.auth.signOut();
        throw Exception(
          'No profile is linked to this phone number. Please sign up first.',
        );
      }
      final prioritizedProfile = matchingProfiles.first;

      final profile = await SupabaseService.client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      final effectiveProfile = profile ?? prioritizedProfile;
      final rawRole = effectiveProfile['user_type']?.toString().trim();
      final userRole =
          (rawRole != null && rawRole.isNotEmpty) ? rawRole : '';
      final surveyCompleted = effectiveProfile['survey_completed'] ?? false;

      await AuthService.saveSession(
        userId: user.id,
        userRole: userRole,
        phone: effectiveProfile['phone_number'] ?? phoneNumber,
        fullName: effectiveProfile['full_name'] ?? '',
        surveyCompleted: surveyCompleted,
        rememberMe: true,
      );

      if (mounted) {
        final navService = NavigationService();
        if (navService.isReady) {
          final routeResult = await navService.determineInitialRoute();
          await navService.navigateToRoute(
            routeResult.route,
            arguments: routeResult.arguments,
            clearStack: true,
          );
        } else {
          if (userRole.isEmpty) {
            NavigationService.resetStackNamed(context, '/role-selection');
          } else if (userRole == 'tutor') {
            NavigationService.resetStackNamed(context, '/tutor-nav');
          } else if (userRole == 'parent') {
            NavigationService.resetStackNamed(context, '/parent-nav');
          } else {
            NavigationService.resetStackNamed(context, '/student-nav');
          }
        }
      }
    } catch (e) {
      if (kDebugMode &&
          e.toString().toLowerCase().contains('invalid login credentials') &&
          phoneExistsInProfiles) {
        LogService.debug(
          '[PHONE_LOGIN_DEBUG] Phone exists, but Supabase rejected credentials. Most likely wrong password for this phone account.',
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AuthService.parseAuthError(e),
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.red,
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
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}

// Custom wave clipper – shallow curve so subtitle stays visible above wave
class WaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    var path = Path();
    path.lineTo(0, size.height - 28);
    var controlPoint1 = Offset(size.width * 0.25, size.height - 14);
    var endPoint1 = Offset(size.width * 0.5, size.height - 20);
    path.quadraticBezierTo(
      controlPoint1.dx,
      controlPoint1.dy,
      endPoint1.dx,
      endPoint1.dy,
    );
    var controlPoint2 = Offset(size.width * 0.75, size.height - 28);
    var endPoint2 = Offset(size.width, size.height - 20);
    path.quadraticBezierTo(
      controlPoint2.dx,
      controlPoint2.dy,
      endPoint2.dx,
      endPoint2.dy,
    );
    path.lineTo(size.width, 0);
    path.close();

    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
