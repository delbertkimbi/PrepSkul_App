import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/core/utils/safe_set_state.dart';
import 'package:prepskul/core/utils/status_bar_utils.dart';
import 'package:prepskul/core/services/auth_service.dart';
import 'package:prepskul/core/services/supabase_service.dart';
import 'package:prepskul/core/services/log_service.dart';
import 'package:prepskul/core/widgets/offline_dialog.dart';

/// Step 1 of phone password reset: OTP entry with countdown (same UI as OTP verification).
/// On success → navigate to Set New Password screen (step 2).
class ResetPasswordOTPScreen extends StatefulWidget {
  final String phone;

  const ResetPasswordOTPScreen({
    Key? key,
    required this.phone,
  }) : super(key: key);

  @override
  State<ResetPasswordOTPScreen> createState() => _ResetPasswordOTPScreenState();
}

class _ResetPasswordOTPScreenState extends State<ResetPasswordOTPScreen> {
  final List<TextEditingController> _otpControllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  bool _isVerifying = false;
  bool _isResending = false;
  int _countdownSeconds = 60;
  bool _canResend = false;

  @override
  void initState() {
    super.initState();
    _startCountdown();
    for (var node in _focusNodes) {
      node.addListener(() {
        if (mounted) safeSetState(() {});
      });
    }
  }

  @override
  void dispose() {
    for (var c in _otpControllers) c.dispose();
    for (var n in _focusNodes) n.dispose();
    super.dispose();
  }

  void _startCountdown() {
    safeSetState(() {
      _countdownSeconds = 60;
      _canResend = false;
    });
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      safeSetState(() {
        if (_countdownSeconds > 0) {
          _countdownSeconds--;
        } else {
          _canResend = true;
        }
      });
      return _countdownSeconds > 0;
    });
  }

  String get _otpCode => _otpControllers.map((c) => c.text).join();

  Future<void> _verifyOTP() async {
    if (_otpCode.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please enter the complete 6-digit code',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: AppTheme.primaryColor,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
        ),
      );
      return;
    }

    safeSetState(() => _isVerifying = true);

    try {
      await SupabaseService.verifyPhoneOTP(
        phone: widget.phone,
        token: _otpCode,
      );

      if (!mounted) return;
      LogService.success('Password reset OTP verified – navigating to set new password');
      Navigator.pushReplacementNamed(
        context,
        '/reset-password',
        arguments: {'setNewPasswordOnly': true},
      );
    } catch (e) {
      LogService.error('Reset password OTP error: $e');
      if (mounted) {
        final msg = AuthService.parseAuthError(e);
        if (msg == 'OFFLINE_ERROR' || AuthService.isOfflineError(e)) {
          await OfflineDialog.show(
            context,
            message:
                'Unable to verify. Please check your internet connection and try again.',
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(msg, style: GoogleFonts.poppins()),
              backgroundColor: AppTheme.primaryColor,
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.all(16),
              duration: const Duration(seconds: 4),
            ),
          );
        }
        for (var c in _otpControllers) c.clear();
        _focusNodes[0].requestFocus();
      }
    } finally {
      if (mounted) safeSetState(() => _isVerifying = false);
    }
  }

  Future<void> _resendOTP() async {
    safeSetState(() => _isResending = true);
    try {
      await AuthService.sendPasswordResetOTP(widget.phone);
      if (mounted) {
        _startCountdown();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Code sent to ${widget.phone}',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: AppTheme.primaryColor,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final msg = AuthService.parseAuthError(e);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg, style: GoogleFonts.poppins()),
            backgroundColor: AppTheme.primaryColor,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } finally {
      if (mounted) safeSetState(() => _isResending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StatusBarUtils.withDarkStatusBar(
      Scaffold(
        backgroundColor: Colors.white,
        resizeToAvoidBottomInset: true,
        body: Stack(
          children: [
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: ClipPath(
                clipper: _WaveClipper(),
                child: Container(
                  height: 205,
                  decoration: const BoxDecoration(
                    gradient: AppTheme.headerGradient,
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24.0, 16.0, 24.0, 24.0),
                    child: Column(
                      children: [
                        const SizedBox(height: 8),
                        Text(
                          'Verify code',
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
                          widget.phone,
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const SizedBox(height: 60),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children:
                                List.generate(6, (i) => _buildOTPField(i)),
                          ),
                          const SizedBox(height: 40),
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton(
                              onPressed: _isVerifying ? () {} : _verifyOTP,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryColor,
                                foregroundColor: Colors.white,
                                disabledBackgroundColor: AppTheme.primaryColor,
                                disabledForegroundColor: Colors.white,
                                elevation: 2,
                                shadowColor:
                                    AppTheme.primaryColor.withOpacity(0.3),
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
                                        strokeWidth: 2.5,
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
                              GestureDetector(
                                onTap: (_isResending || !_canResend)
                                    ? null
                                    : _resendOTP,
                                child: _isResending
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: AppTheme.primaryColor,
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
                                          decoration: _canResend
                                              ? TextDecoration.underline
                                              : null,
                                          decorationColor: AppTheme.primaryColor,
                                        ),
                                      ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text(
                              'Change phone number',
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
      ),
    );
  }

  Widget _buildOTPField(int index) {
    final isFocused = _focusNodes[index].hasFocus;
    final hasValue = _otpControllers[index].text.isNotEmpty;

    return Container(
      width: 45,
      height: 55,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color:
              hasValue || isFocused ? AppTheme.primaryColor : AppTheme.softBorder,
          width: 2,
        ),
        boxShadow: (hasValue || isFocused)
            ? [
                BoxShadow(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      clipBehavior: Clip.antiAlias,
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
            contentPadding: EdgeInsets.zero,
            isDense: true,
          ),
          onChanged: (value) {
            if (value.length == 1 && index < 5) {
              _focusNodes[index + 1].requestFocus();
            } else if (value.isEmpty && index > 0) {
              _focusNodes[index - 1].requestFocus();
            }
            safeSetState(() {});
            if (index == 5 && value.isNotEmpty) _verifyOTP();
          },
          onTap: () {
            Clipboard.getData(Clipboard.kTextPlain).then((data) {
              if (data?.text == null) return;
              final digits =
                  data!.text!.replaceAll(RegExp(r'[^\d]'), '');
              if (digits.length >= 6) {
                for (int i = 0; i < 6; i++) {
                  _otpControllers[i].text = digits[i];
                }
                _focusNodes[5].requestFocus();
                _verifyOTP();
              }
              safeSetState(() {});
            });
          },
        ),
      ),
    );
  }
}

class _WaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    var path = Path();
    path.lineTo(0, size.height - 28);
    path.quadraticBezierTo(
      size.width * 0.25,
      size.height - 14,
      size.width * 0.5,
      size.height - 20,
    );
    path.quadraticBezierTo(
      size.width * 0.75,
      size.height - 28,
      size.width,
      size.height - 20,
    );
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
