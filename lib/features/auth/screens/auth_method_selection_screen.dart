import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/core/utils/safe_set_state.dart';
import 'package:prepskul/core/services/log_service.dart';
import 'package:prepskul/core/localization/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:prepskul/core/services/auth_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'beautiful_login_screen.dart' hide WaveClipper;
import 'beautiful_signup_screen.dart' hide WaveClipper;
import 'email_login_screen.dart';
import 'email_signup_screen.dart';

class AuthMethodSelectionScreen extends StatefulWidget {
  final bool isLogin;
  const AuthMethodSelectionScreen({Key? key, this.isLogin = true}) : super(key: key);

  @override
  State<AuthMethodSelectionScreen> createState() => _AuthMethodSelectionScreenState();
}

class _AuthMethodSelectionScreenState extends State<AuthMethodSelectionScreen> {
  late bool _isLogin;

  @override
  void initState() {
    super.initState();
    _isLogin = widget.isLogin;
  }

  Future<void> _launchURL(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenHeight < 700;
    final isVerySmallScreen = screenHeight < 600;
    
    // Responsive dimensions
    final headerHeight = isVerySmallScreen ? 150.0 : (isSmallScreen ? 175.0 : 200.0);
    final headerTopPadding = isVerySmallScreen ? 15.0 : (isSmallScreen ? 22.0 : 29.0);
    final headerBottomPadding = isVerySmallScreen ? 20.0 : (isSmallScreen ? 25.0 : 30.0);
    final titleFontSize = isVerySmallScreen ? 26.0 : (isSmallScreen ? 28.0 : 32.0);
    final subtitleFontSize = isVerySmallScreen ? 12.0 : 14.0;
    final contentTopSpacing = isVerySmallScreen ? 40.0 : (isSmallScreen ? 60.0 : 90.0);
    
    return Scaffold(
      backgroundColor: Colors.white,
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
                height: headerHeight,
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
                  padding: EdgeInsets.fromLTRB(24.0, headerTopPadding, 24.0, headerBottomPadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 15),
                      Center(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          transitionBuilder: (Widget child, Animation<double> animation) {
                            return FadeTransition(opacity: animation, child: child);
                          },
                        child: Text(
                            _isLogin ? t.authWelcomeBack : t.authJoinPrepSkul,
                            key: ValueKey<bool>(_isLogin),
                          style: GoogleFonts.poppins(
                            fontSize: titleFontSize,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Center(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                        child: Text(
                            _isLogin ? t.authSignInToContinue : t.authCreateAccount,
                            key: ValueKey<String>(_isLogin ? 'signin-sub' : 'signup-sub'),
                          style: GoogleFonts.poppins(
                            fontSize: subtitleFontSize,
                            fontWeight: FontWeight.w400,
                            color: Colors.white.withOpacity(0.95),
                            ),
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
                        SizedBox(height: contentTopSpacing),

                        // Google Sign In Button - Primary
                        _AuthMethodButton(
                          icon: Icons.g_mobiledata, // Will replace with Google logo asset if available
                          label: t.authContinueWithGoogle,
                          isPrimary: false, // Changed to false to keep outlined style but distinct
                          onTap: () async {
                            try {
                              await AuthService.signInWithGoogle();
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Google Sign-In failed: ${e.toString()}'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          },
                        ),

                        const SizedBox(height: 24),

                        // Divider with "OR"
                        Row(
                          children: [
                            const Expanded(child: Divider(color: AppTheme.softBorder)),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Text(
                                t.authOr,
                                style: GoogleFonts.poppins(
                                  fontSize: subtitleFontSize,
                                  color: AppTheme.textLight,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            const Expanded(child: Divider(color: AppTheme.softBorder)),
                          ],
                        ),

                        const SizedBox(height: 24),

                        // Auth Method Buttons - Navigate to SIGNIN screens
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: Column(
                            key: ValueKey<bool>(_isLogin),
                            children: [
                              _AuthMethodButton(
                                icon: Icons.email_outlined,
                                label: _isLogin ? t.authSignInWithEmail : t.authSignUpWithEmail,
                          onTap: () async {
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.setString('auth_method', 'email');

                            if (context.mounted) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                        builder: (context) => _isLogin 
                                            ? const EmailLoginScreen()
                                            : const EmailSignupScreen(),
                                ),
                              );
                            }
                          },
                        ),

                        const SizedBox(height: 16),

                        _AuthMethodButton(
                          icon: Icons.phone_outlined,
                                label: _isLogin ? t.authSignInWithPhone : t.authSignUpWithPhone,
                          onTap: () async {
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.setString('auth_method', 'phone');

                            if (context.mounted) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                        builder: (context) => _isLogin
                                            ? const BeautifulLoginScreen()
                                            : const BeautifulSignupScreen(),
                                ),
                              );
                            }
                          },
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 32),

                        // Switch between Login/Signup
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 300),
                              child: Text(
                                _isLogin ? '${t.authNoAccount} ' : '${t.authHaveAccount} ',
                                key: ValueKey<String>(_isLogin ? 'no-account' : 'has-account'),
                              style: GoogleFonts.poppins(
                                fontSize: subtitleFontSize,
                                color: AppTheme.textMedium,
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                safeSetState(() {
                                  _isLogin = !_isLogin;
                                });
                              },
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 300),
                              child: Text(
                                  _isLogin ? t.authSignUp : t.authLogin,
                                  key: ValueKey<String>(_isLogin ? 'signup-btn' : 'signin-btn'),
                                style: GoogleFonts.poppins(
                                  fontSize: subtitleFontSize,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.primaryColor,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 40),

                        // Terms
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32.0),
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            child: RichText(
                              key: ValueKey<bool>(_isLogin),
                              textAlign: TextAlign.center,
                              text: TextSpan(
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: AppTheme.textLight,
                                  height: 1.4,
                                ),
                                children: [
                                  TextSpan(
                                    text: '${t.authAgreeToTerms} ',
                                  ),
                                  TextSpan(
                                    text: t.authTermsOfService,
                                    style: GoogleFonts.poppins(
                                      color: AppTheme.primaryColor,
                                      fontWeight: FontWeight.w600,
                                      decoration: TextDecoration.underline,
                                    ),
                                    recognizer: TapGestureRecognizer()
                                      ..onTap = () => _launchURL('https://prepskul.com/en/terms'),
                                  ),
                                  TextSpan(text: ' ${t.authAnd} '),
                                  TextSpan(
                                    text: t.authPrivacyPolicy,
                                    style: GoogleFonts.poppins(
                                      color: AppTheme.primaryColor,
                                      fontWeight: FontWeight.w600,
                                      decoration: TextDecoration.underline,
                                    ),
                                    recognizer: TapGestureRecognizer()
                                      ..onTap = () => _launchURL('https://prepskul.com/en/privacy-policy'),
                                  ),
                                ],
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
        ],
      ),
    );
  }
}

class _AuthMethodButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isPrimary;

  const _AuthMethodButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          side: BorderSide(
            color: isPrimary ? AppTheme.primaryColor : AppTheme.softBorder,
            width: isPrimary ? 2.0 : 1.5,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          backgroundColor: isPrimary ? AppTheme.softCard : Colors.white,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (label.contains('Google'))
              // Use a more specific Google-like icon presentation or asset
              Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                ),
                child: Image.network(
                  'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/240px-Google_%22G%22_logo.svg.png',
                  height: 24,
                  width: 24,
                  errorBuilder: (context, error, stackTrace) => Icon(
                    Icons.g_mobiledata,
                    size: 32,
                    color: AppTheme.textDark,
                  ),
                ),
              )
            else
            Icon(icon, size: 24, color: AppTheme.textDark),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textDark,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Reuse WaveClipper from beautiful_login_screen
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
