import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/core/utils/safe_set_state.dart';
import 'package:prepskul/core/utils/status_bar_utils.dart';
import 'package:prepskul/core/services/web_splash_service.dart';
import 'package:prepskul/core/localization/app_localizations.dart';
import 'package:prepskul/features/onboarding/learner/learner_onboarding_chrome.dart';
import 'package:prepskul/features/primar/presentation/mascot.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:prepskul/core/services/auth_service.dart';
import 'package:prepskul/core/config/app_config.dart';
import 'package:url_launcher/url_launcher.dart';
import 'beautiful_login_screen.dart';
import 'beautiful_signup_screen.dart';
import 'email_login_screen.dart';
import 'email_signup_screen.dart';

class AuthMethodSelectionScreen extends StatefulWidget {
  final bool isLogin;
  const AuthMethodSelectionScreen({Key? key, this.isLogin = true}) : super(key: key);

  @override
  State<AuthMethodSelectionScreen> createState() => _AuthMethodSelectionScreenState();
}

class _AuthMethodSelectionScreenState extends State<AuthMethodSelectionScreen>
    with WidgetsBindingObserver {
  late bool _isLogin;
  bool _googleLaunchInFlight = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _isLogin = widget.isLogin;
    // Clear stale OAuth loading state when this screen is shown.
    // Users may return from external OAuth without completing account selection.
    AuthService.isGoogleSignInInProgress = false;
    // On web: remove HTML splash only after this screen has painted (prevents blank auth screen)
    if (kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        WebSplashService.removeSplash();
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Returning from external OAuth without selecting an account may leave
      // stale in-progress state; clear it so Google button remains usable.
      AuthService.isGoogleSignInInProgress = false;
      if (mounted) {
        safeSetState(() {
          _googleLaunchInFlight = false;
        });
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
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
    final headerTopPadding = isVerySmallScreen ? 8.0 : (isSmallScreen ? 12.0 : 16.0);
    final headerBottomPadding = isVerySmallScreen ? 8.0 : 12.0;
    final titleFontSize = isVerySmallScreen ? 24.0 : 28.0;
    final subtitleFontSize = isVerySmallScreen ? 13.0 : 15.0;
    final contentTopSpacing = isVerySmallScreen ? 12.0 : 20.0;
    
    return StatusBarUtils.withLightStatusBar(
      Scaffold(
        backgroundColor: OnboardPalette.cream,
        body: Stack(
          children: [
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(24.0, headerTopPadding, 24.0, headerBottomPadding),
                  child: Column(
                    children: [
                      prepMate(mood: Mood.wave, size: isVerySmallScreen ? 88 : 108),
                      const SizedBox(height: 10),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: Text(
                          _isLogin ? t.authWelcomeBack : t.authJoinPrepSkul,
                          key: ValueKey<bool>(_isLogin),
                          textAlign: TextAlign.center,
                          style: onboardDisplay(size: titleFontSize),
                        ),
                      ),
                      const SizedBox(height: 6),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: Text(
                          _isLogin ? t.authSignInToContinue : t.authCreateAccount,
                          key: ValueKey<String>(_isLogin ? 'signin-sub' : 'signup-sub'),
                          textAlign: TextAlign.center,
                          style: onboardFont(
                            size: subtitleFontSize + 1,
                            weight: FontWeight.w700,
                            color: AppTheme.textMedium,
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

                        // Google Sign In Button - Primary (only show if enabled)
                        if (AppConfig.enableGoogleSignIn) ...[
                          _AuthMethodButton(
                            icon: Icons.g_mobiledata, // Will replace with Google logo asset if available
                            label: t.authContinueWithGoogle,
                            isPrimary: false, // Changed to false to keep outlined style but distinct
                            onTap: () async {
                              if (_googleLaunchInFlight) return;
                              safeSetState(() => _googleLaunchInFlight = true);
                              try {
                                await AuthService.signInWithGoogle();
                              } catch (e) {
                                AuthService.isGoogleSignInInProgress = false;
                                safeSetState(() => _googleLaunchInFlight = false);
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
                        ],

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
          // Intentionally no blocking OAuth overlay here.
          // External OAuth can bounce back to this screen even when user cancels,
          // and blocking text ("Completing Google sign-in…") creates confusing UX.
        ],
      ),
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
    return OnboardPaperButton(
      label: label,
      onTap: onTap,
      leading: label.contains('Google')
          ? SizedBox(
              width: 22,
              height: 22,
              child: Image.asset(
                'assets/images/google.png',
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Icon(icon, size: 22, color: AppTheme.primaryColor);
                },
              ),
            )
          : Icon(icon, size: 22, color: AppTheme.primaryColor),
    );
  }
}

