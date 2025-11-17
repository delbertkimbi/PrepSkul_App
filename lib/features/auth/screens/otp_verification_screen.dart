import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/core/services/supabase_service.dart';
import 'package:prepskul/core/services/auth_service.dart';
import 'package:prepskul/core/services/notification_helper_service.dart';

class OTPVerificationScreen extends StatefulWidget {
  final String phoneNumber;
  final String fullName;
  final String userRole;

  const OTPVerificationScreen({
    Key? key,
    required this.phoneNumber,
    required this.fullName,
    required this.userRole,
  }) : super(key: key);

  @override
  State<OTPVerificationScreen> createState() => _OTPVerificationScreenState();
}

class _OTPVerificationScreenState extends State<OTPVerificationScreen> {
  final List<TextEditingController> _otpControllers = List.generate(
    6,
    (index) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(6, (index) => FocusNode());
  bool _isVerifying = false;
  bool _isResending = false;
  int _countdownSeconds = 60;
  bool _canResend = false;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  @override
  void dispose() {
    for (var controller in _otpControllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _startCountdown() {
    setState(() {
      _countdownSeconds = 60;
      _canResend = false;
    });

    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) {
        setState(() {
          if (_countdownSeconds > 0) {
            _countdownSeconds--;
          } else {
            _canResend = true;
          }
        });
        return _countdownSeconds > 0;
      }
      return false;
    });
  }

  String get _otpCode {
    return _otpControllers.map((c) => c.text).join();
  }

  Future<void> _verifyOTP() async {
    if (_otpCode.length != 6) {
      _showError('Please enter the complete 6-digit code');
      return;
    }

    setState(() => _isVerifying = true);

    try {
      // Verify OTP with Supabase
      final response = await SupabaseService.verifyPhoneOTP(
        phone: widget.phoneNumber,
        token: _otpCode,
      );

      if (response.user != null) {
        // Check if this is a new user (signup) or existing user (login)
        final userProfile = await SupabaseService.getData(
          table: 'profiles',
          field: 'phone_number',
          value: widget.phoneNumber,
        );

        bool isNewUser = userProfile.isEmpty;

        if (isNewUser) {
          // Save user data to profiles table (signup flow)
          await SupabaseService.insertData(
            table: 'profiles',
            data: {
              'id': response.user!.id,
              'email': response.user!.email, // Optional - can be null
              'full_name': widget.fullName,
              'phone_number': widget.phoneNumber,
              'avatar_url': null, // Optional - can be added later
              'user_type': widget.userRole,
              // survey_completed, is_admin, last_seen have defaults in DB
            },
          );

          // Notify admins about new user signup (async, don't block)
          NotificationHelperService.notifyAdminsAboutNewUserSignup(
            userId: response.user!.id,
            userType: widget.userRole,
            userName: widget.fullName,
            userEmail:
                response.user!.email ??
                widget.phoneNumber, // Use phone if email is null
          ).catchError((e) {
            print('⚠️ Error notifying admins about new user signup: $e');
            // Don't block signup if notification fails
          });
        }

        // Save session using AuthService
        await AuthService.saveSession(
          userId: response.user!.id,
          userRole: widget.userRole,
          phone: widget.phoneNumber,
          fullName: widget.fullName,
          surveyCompleted: false,
          rememberMe: true,
        );

        // Check if survey is completed
        bool surveyCompleted = await AuthService.isSurveyCompleted();
        String userRole = await AuthService.getUserRole() ?? widget.userRole;

        // For new users, ensure survey_intro_seen is cleared so they see the intro screen
        final prefs = await SharedPreferences.getInstance();
        if (isNewUser) {
          // Clear survey_intro_seen for new users to ensure they see the intro screen
          await prefs.setBool('survey_intro_seen', false);
          print('🆕 New user signup - cleared survey_intro_seen flag');
        }

        // Navigate based on survey status
        if (mounted) {
          if (surveyCompleted) {
            // Existing user with completed survey → go to role-based navigation
            print('✅ Survey completed - navigating to dashboard for $userRole');
            if (userRole == 'tutor') {
              Navigator.pushReplacementNamed(context, '/tutor-nav');
            } else if (userRole == 'parent') {
              Navigator.pushReplacementNamed(context, '/parent-nav');
            } else {
              Navigator.pushReplacementNamed(context, '/student-nav');
            }
          } else {
            // New user or incomplete survey → check for survey intro screen first
            // This ensures survey intro screen is shown if not seen before
            final surveyIntroSeen = prefs.getBool('survey_intro_seen') ?? false;

            print('📋 Survey not completed');
            print('👤 User role: $userRole');
            print('👀 Survey intro seen: $surveyIntroSeen');
            print('🆕 Is new user: $isNewUser');

            // For students and parents, show intro screen first (if not seen)
            // For tutors, go directly to onboarding
            if ((userRole == 'student' ||
                    userRole == 'learner' ||
                    userRole == 'parent') &&
                !surveyIntroSeen) {
              print('✅ Navigating to survey intro screen for $userRole');
              Navigator.pushReplacementNamed(
                context,
                '/survey-intro',
                arguments: {'userType': userRole},
              );
            } else {
              // Survey intro already seen or user is tutor → go to profile setup
              print('⏭️ Skipping survey intro - navigating to profile setup');
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
      print('❌ OTP Verification Error: $e');
      _showError(
        'Invalid code. Error: ${e.toString().length > 50 ? e.toString().substring(0, 50) : e.toString()}',
      );
      // Clear OTP fields
      for (var controller in _otpControllers) {
        controller.clear();
      }
      _focusNodes[0].requestFocus();
    } finally {
      if (mounted) {
        setState(() => _isVerifying = false);
      }
    }
  }

  Future<void> _resendOTP() async {
    setState(() => _isResending = true);

    try {
      await SupabaseService.sendPhoneOTP(widget.phoneNumber);

      if (mounted) {
        _startCountdown(); // Restart countdown
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Verification code sent to ${widget.phoneNumber}',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: AppTheme.primaryColor,
          ),
        );
      }
    } catch (e) {
      _showError('Failed to resend code. Please try again.');
    } finally {
      if (mounted) {
        setState(() => _isResending = false);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.poppins()),
        backgroundColor: AppTheme.primaryColor,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
      ),
    );
  }

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
                  padding: const EdgeInsets.fromLTRB(24.0, 20.0, 24.0, 20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 15),
                      Text(
                        'Verify Phone',
                        style: GoogleFonts.poppins(
                          fontSize: 32,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'Enter the 6-digit code sent to',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: Colors.white.withOpacity(0.95),
                        ),
                      ),
                      Text(
                        widget.phoneNumber,
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
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
                        const SizedBox(height: 60),

                        // OTP Input Fields
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: List.generate(
                            6,
                            (index) => _buildOTPField(index),
                          ),
                        ),

                        const SizedBox(height: 40),

                        // Verify Button
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: _isVerifying ? null : _verifyOTP,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryColor,
                              foregroundColor: Colors.white,
                              elevation: 2,
                              shadowColor: AppTheme.primaryColor.withOpacity(
                                0.3,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(28),
                              ),
                            ),
                            child: _isVerifying
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(
                                    'Verify & Continue',
                                    style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                        ),

                        const SizedBox(height: 30),

                        // Resend OTP
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "Didn't receive the code? ",
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: AppTheme.textMedium,
                              ),
                            ),
                            TextButton(
                              onPressed: (_isResending || !_canResend)
                                  ? null
                                  : _resendOTP,
                              child: _isResending
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Text(
                                      _canResend
                                          ? 'Resend'
                                          : 'Resend in ${_countdownSeconds}s',
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: _canResend
                                            ? AppTheme.primaryColor
                                            : AppTheme.textLight,
                                      ),
                                    ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),

                        // Back to signup
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(
                            'Change Phone Number',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: AppTheme.textMedium,
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
        ],
      ),
    );
  }

  Widget _buildOTPField(int index) {
    return Container(
      width: 45,
      height: 55,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _otpControllers[index].text.isEmpty
              ? AppTheme.softBorder
              : AppTheme.primaryColor,
          width: 2,
        ),
      ),
      child: Center(
        child: TextFormField(
          controller: _otpControllers[index],
          focusNode: _focusNodes[index],
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          maxLength: 1,
          style: GoogleFonts.poppins(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: AppTheme.textDark,
          ),
          decoration: const InputDecoration(
            counterText: '',
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            disabledBorder: InputBorder.none,
            errorBorder: InputBorder.none,
            focusedErrorBorder: InputBorder.none,
            contentPadding: EdgeInsets.zero,
          ),
          onChanged: (value) {
            if (value.length == 1 && index < 5) {
              _focusNodes[index + 1].requestFocus();
            } else if (value.isEmpty && index > 0) {
              _focusNodes[index - 1].requestFocus();
            }
            setState(() {}); // Update border color

            // Auto-verify when all digits entered
            if (index == 5 && value.isNotEmpty) {
              _verifyOTP();
            }
          },
        ),
      ),
    );
  }
}

// Custom wave clipper (same as signup screen)
class WaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    var path = Path();
    path.lineTo(0, size.height - 50);
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
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
