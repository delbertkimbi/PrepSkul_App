import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/core/localization/app_localizations.dart';
import 'package:prepskul/core/localization/language_service.dart';
import 'package:prepskul/core/localization/language_notifier.dart';
import 'package:prepskul/features/onboarding/screens/simple_onboarding_screen.dart';
import 'package:prepskul/features/profile/screens/student_survey.dart';
import 'package:prepskul/features/profile/screens/parent_survey.dart';
import 'package:prepskul/features/auth/screens/beautiful_login_screen.dart';
import 'package:prepskul/features/auth/screens/beautiful_signup_screen.dart';
import 'package:prepskul/features/auth/screens/forgot_password_screen.dart';
import 'package:prepskul/features/auth/screens/reset_password_screen.dart';
import 'package:prepskul/features/auth/screens/otp_verification_screen.dart';
import 'package:prepskul/features/auth/screens/auth_method_selection_screen.dart';
import 'package:prepskul/features/auth/screens/email_signup_screen.dart';
import 'package:prepskul/features/auth/screens/email_login_screen.dart';
import 'package:prepskul/features/tutor/screens/tutor_onboarding_screen.dart';
import 'package:prepskul/core/services/auth_service.dart';
import 'package:prepskul/core/widgets/language_switcher.dart';
import 'package:prepskul/core/navigation/main_navigation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:prepskul/core/services/supabase_service.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:async';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Show splash screen IMMEDIATELY - don't wait for anything
  runApp(const PrepSkulApp());

  // Initialize in background (non-blocking)
  // This happens asynchronously and doesn't delay the UI
  _initializeAppInBackground();
}

/// Initialize app services in background (non-blocking)
/// This runs asynchronously and doesn't block the UI
Future<void> _initializeAppInBackground() async {
  try {
    print('🔄 Starting background initialization...');

    // Initialize Supabase (this may take a moment)
    await Supabase.initialize(
      url: 'https://cpzaxdfxbamdsshdgjyg.supabase.co',
      anonKey:
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNwemF4ZGZ4YmFtZHNzaGRnanlnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjE1MDUwMDYsImV4cCI6MjA3NzA4MTAwNn0.FWBFrseEeYqFaJ7FGRUAYtm10sz0JqPyerJ0BfoYnCU',
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
    );
    print('✅ Supabase initialized');

    // Initialize language service
    await LanguageService.initialize();
    print('✅ Language service initialized');

    // Initialize auth state listener
    AuthService.initAuthListener();
    print('✅ Auth listener initialized');

    print('✅ App initialization complete');
  } catch (e) {
    print('❌ Error initializing app: $e');
  }
}

class PrepSkulApp extends StatelessWidget {
  const PrepSkulApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) {
        final notifier = LanguageNotifier();
        notifier.initialize();
        return notifier;
      },
      child: Consumer<LanguageNotifier>(
        builder: (context, languageNotifier, child) {
          return MaterialApp(
            title: 'PrepSkul',
            theme: AppTheme.lightTheme,
            home: const SplashScreen(),
            debugShowCheckedModeBanner: false,

            // Localization setup
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: LanguageService.supportedLocales,
            locale: languageNotifier.currentLocale,

            // Routes
            routes: {
              '/onboarding': (context) => const SimpleOnboardingScreen(),
              '/auth-method-selection': (context) =>
                  const AuthMethodSelectionScreen(),
              '/login': (context) => const BeautifulLoginScreen(),
              '/beautiful-login': (context) => const BeautifulLoginScreen(),
              '/beautiful-signup': (context) => const BeautifulSignupScreen(),
              '/email-signup': (context) => const EmailSignupScreen(),
              '/email-login': (context) => const EmailLoginScreen(),
              '/forgot-password': (context) => const ForgotPasswordScreen(),
            },
            onGenerateRoute: (settings) {
              // Handle navigation routes with optional initialTab argument
              if (settings.name == '/tutor-nav') {
                final args = settings.arguments as Map<String, dynamic>?;
                return MaterialPageRoute(
                  builder: (context) => MainNavigation(
                    userRole: 'tutor',
                    initialTab: args?['initialTab'],
                  ),
                );
              }
              if (settings.name == '/student-nav') {
                final args = settings.arguments as Map<String, dynamic>?;
                return MaterialPageRoute(
                  builder: (context) => MainNavigation(
                    userRole: 'student',
                    initialTab: args?['initialTab'],
                  ),
                );
              }
              if (settings.name == '/parent-nav') {
                final args = settings.arguments as Map<String, dynamic>?;
                return MaterialPageRoute(
                  builder: (context) => MainNavigation(
                    userRole: 'parent',
                    initialTab: args?['initialTab'],
                  ),
                );
              }

              if (settings.name == '/profile-setup') {
                final args = settings.arguments as Map<String, dynamic>?;
                final userRole = args?['userRole'] ?? 'student';

                // Use tutor onboarding for tutors
                if (userRole == 'tutor') {
                  return MaterialPageRoute(
                    builder: (context) =>
                        const TutorOnboardingScreen(basicInfo: {}),
                  );
                }

                // Use surveys for students and parents
                if (userRole == 'learner' || userRole == 'student') {
                  return MaterialPageRoute(
                    builder: (context) => const StudentSurvey(),
                  );
                } else if (userRole == 'parent') {
                  return MaterialPageRoute(
                    builder: (context) => const ParentSurvey(),
                  );
                }

                // Fallback to student survey
                return MaterialPageRoute(
                  builder: (context) => const StudentSurvey(),
                );
              }
              if (settings.name == '/tutor-onboarding') {
                final args = settings.arguments as Map<String, dynamic>?;
                return MaterialPageRoute(
                  builder: (context) =>
                      TutorOnboardingScreen(basicInfo: args ?? {}),
                );
              }
              if (settings.name == '/reset-password') {
                final args = settings.arguments as Map<String, dynamic>?;
                final phone = args?['phone'] ?? '';
                final isEmailRecovery = args?['isEmailRecovery'] ?? false;
                return MaterialPageRoute(
                  builder: (context) => ResetPasswordScreen(
                    phone: phone,
                    isEmailRecovery: isEmailRecovery,
                  ),
                );
              }
              if (settings.name == '/otp-verification') {
                final args = settings.arguments as Map<String, dynamic>?;
                return MaterialPageRoute(
                  builder: (context) => OTPVerificationScreen(
                    phoneNumber: args?['phoneNumber'] ?? '',
                    fullName: args?['fullName'] ?? '',
                    userRole: args?['userRole'] ?? 'student',
                  ),
                );
              }
              return null;
            },

            // Fallback locale
            localeResolutionCallback: (locale, supportedLocales) {
              if (locale != null && supportedLocales.contains(locale)) {
                return locale;
              }
              return LanguageService.getFallbackLocale();
            },
          );
        },
      ),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  StreamSubscription<AuthState>? _authStateSubscription;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeSplash();
  }

  /// Initialize splash screen - show immediately, then check status
  Future<void> _initializeSplash() async {
    // Wait for Supabase to be ready in background (non-blocking)
    Future.microtask(() async {
      int attempts = 0;
      while (!_isSupabaseReady() && attempts < 50) {
        await Future.delayed(const Duration(milliseconds: 100));
        attempts++;
      }

      // Now that we're ready, set up auth listeners
      if (mounted) {
        _setupAuthListeners();
      }

      // Check for URL callbacks (web only)
      if (kIsWeb && mounted) {
        _checkPasswordResetCallback();
        _checkEmailConfirmationCallback();
      }
    });

    // Ensure minimum splash display time (2.5 seconds) to show animation
    // This ensures users see the splash screen even if Supabase is fast
    await Future.delayed(const Duration(milliseconds: 2500));

    // Wait for Supabase to be ready (with timeout) before checking status
    int attempts = 0;
    while (!_isSupabaseReady() && attempts < 50 && mounted) {
      await Future.delayed(const Duration(milliseconds: 100));
      attempts++;
    }

    // Setup listeners if Supabase is ready
    if (_isSupabaseReady() && mounted) {
      _setupAuthListeners();
      if (kIsWeb) {
        _checkPasswordResetCallback();
        _checkEmailConfirmationCallback();
      }
    }

    // Check onboarding status after minimum display time
    if (mounted) {
      _checkOnboardingStatus();
    }
  }

  /// Check if Supabase is ready
  bool _isSupabaseReady() {
    try {
      // Try to access Supabase client
      SupabaseService.client;
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Setup auth state listeners
  void _setupAuthListeners() {
    if (_isInitialized) return;
    _isInitialized = true;

    // Listen to auth state changes for email confirmation
    _authStateSubscription = SupabaseService.client.auth.onAuthStateChange
        .listen((data) {
          final AuthChangeEvent event = data.event;
          final Session? session = data.session;

          print('🔐 Auth state changed: $event');

          // Handle email confirmation
          if (event == AuthChangeEvent.signedIn &&
              session != null &&
              session.user.emailConfirmedAt != null) {
            print('✅ Email confirmed via deep link!');
            Future.microtask(() => _handleEmailConfirmation());
          }
        });
  }

  /// Check if URL contains email confirmation code (web only)
  Future<void> _checkEmailConfirmationCallback() async {
    try {
      final uri = Uri.base;
      final code = uri.queryParameters['code'];
      final type = uri.queryParameters['type'];

      print('🔍 [DEBUG] Checking URL for email confirmation callback');
      print('🔍 [DEBUG] URL: ${uri.toString()}');
      print('🔍 [DEBUG] Code: $code, Type: $type');

      if (code != null && type != 'recovery') {
        // This is likely an email confirmation code
        print('📧 [DEBUG] Email confirmation code detected!');

        try {
          // Exchange code for session
          await SupabaseService.client.auth.exchangeCodeForSession(code);
          print('✅ Email confirmation code verified! Session created.');

          // The auth state change listener will handle navigation
          // But we can also directly navigate here if needed
          Future.microtask(() => _handleEmailConfirmation());
        } catch (e) {
          print('❌ Error verifying email confirmation code: $e');
          // Show error but continue to normal flow
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Email confirmation link expired or invalid. Please request a new one.',
                  style: GoogleFonts.poppins(),
                ),
                backgroundColor: AppTheme.primaryColor,
                behavior: SnackBarBehavior.floating,
                margin: const EdgeInsets.all(16),
                duration: const Duration(seconds: 5),
              ),
            );
          }
        }
      }
    } catch (e) {
      print('⚠️ Error checking email confirmation callback: $e');
    }
  }

  /// Check if URL contains password reset code (web only)
  Future<void> _checkPasswordResetCallback() async {
    try {
      final uri = Uri.base;
      final code = uri.queryParameters['code'];
      final type = uri.queryParameters['type'];

      print('🔍 [DEBUG] Checking URL for password reset callback');
      print('🔍 [DEBUG] URL: ${uri.toString()}');
      print('🔍 [DEBUG] Code: $code, Type: $type');

      if (code != null) {
        // Check if it's a password reset (recovery type)
        if (type == 'recovery' ||
            uri.path.contains('reset') ||
            uri.path.contains('recovery')) {
          print('🔑 [DEBUG] Password reset code detected!');

          try {
            // Exchange code for session - Supabase validates the recovery code
            // For password reset, Supabase creates a temporary session when code is valid
            await SupabaseService.client.auth.exchangeCodeForSession(code);

            print('✅ Password reset code verified! Session created.');
            // User is now authenticated with a recovery session
            // Navigate to password reset screen to change password
            // Note: ResetPasswordScreen needs to handle email recovery (no OTP needed)
            if (mounted) {
              Navigator.of(context).pushReplacementNamed(
                '/reset-password',
                arguments: {'isEmailRecovery': true},
              );
            }
            return;
          } catch (e) {
            print('❌ Error verifying password reset code: $e');
            // Show error and continue to normal flow
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Password reset link expired or invalid. Please request a new one.',
                    style: GoogleFonts.poppins(),
                  ),
                  backgroundColor: AppTheme.primaryColor,
                  behavior: SnackBarBehavior.floating,
                  margin: const EdgeInsets.all(16),
                  duration: const Duration(seconds: 5),
                ),
              );
            }
          }
        }
      }
    } catch (e) {
      print('⚠️ Error checking password reset callback: $e');
    }
  }

  Future<void> _handleEmailConfirmation() async {
    print('🔐 Handling email confirmation...');
    final user = SupabaseService.currentUser;

    if (user == null) {
      print('⚠️ No user found after email confirmation');
      return;
    }

    // Check if profile already exists
    final existingProfile = await SupabaseService.client
        .from('profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();

    // If profile doesn't exist yet, user is still in signup flow
    // Don't navigate yet - let them complete signup
    if (existingProfile == null) {
      print('📝 Profile not found - user still in signup flow');
      // User will complete signup, profile will be created, then they'll see survey
      return;
    }

    final userRole = existingProfile['user_type'] ?? 'student';
    final hasCompletedSurvey = existingProfile['survey_completed'] ?? false;

    // Save session
    await AuthService.saveSession(
      userId: user.id,
      userRole: userRole,
      phone: existingProfile['phone_number'] ?? '',
      fullName: existingProfile['full_name'] ?? '',
      surveyCompleted: hasCompletedSurvey,
      rememberMe: true,
    );

    // Navigate DIRECTLY to appropriate screen based on role and survey status
    // Use pushNamedAndRemoveUntil to prevent going back to splash/onboarding
    if (mounted) {
      if (!hasCompletedSurvey) {
        print('📝 Navigating directly to survey based on role: $userRole');
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/profile-setup',
          (route) => false, // Remove all previous routes
          arguments: {'userRole': userRole},
        );
      } else {
        print('🏠 Navigating directly to dashboard based on role: $userRole');
        String route;
        if (userRole == 'tutor') {
          route = '/tutor-nav';
        } else if (userRole == 'parent') {
          route = '/parent-nav';
        } else {
          route = '/student-nav';
        }
        Navigator.of(context).pushNamedAndRemoveUntil(
          route,
          (route) => false, // Remove all previous routes
        );
      }
    }
  }

  Future<void> _checkOnboardingStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final hasCompletedOnboarding =
        prefs.getBool('onboarding_completed') ?? false;

    // Use AuthService for authentication state
    final isLoggedIn = await AuthService.isLoggedIn();
    final hasCompletedSurvey = await AuthService.isSurveyCompleted();
    final userRole = await AuthService.getUserRole();

    print('Onboarding status: $hasCompletedOnboarding');
    print('Login status: $isLoggedIn');
    print('Survey status: $hasCompletedSurvey');
    print('User role: $userRole');

    if (!hasCompletedOnboarding) {
      // First time user - show onboarding slides
      print('Navigating to onboarding...');
      Navigator.of(context).pushReplacementNamed('/onboarding');
    } else if (!isLoggedIn) {
      // User has seen onboarding but not logged in - go to auth method selection
      print('Navigating to auth method selection...');
      Navigator.of(context).pushReplacementNamed('/auth-method-selection');
    } else if (!hasCompletedSurvey && userRole != null) {
      // User is logged in but hasn't completed survey - redirect to survey
      print('Navigating to survey...');
      Navigator.of(context).pushReplacementNamed(
        '/profile-setup',
        arguments: {'userRole': userRole},
      );
    } else if (isLoggedIn && hasCompletedSurvey) {
      // User is fully onboarded - go to role-based navigation
      print('Navigating to $userRole navigation...');
      if (userRole == 'tutor') {
        Navigator.of(context).pushReplacementNamed('/tutor-nav');
      } else if (userRole == 'parent') {
        Navigator.of(context).pushReplacementNamed('/parent-nav');
      } else {
        Navigator.of(context).pushReplacementNamed('/student-nav');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get localization safely - provide fallback if not ready
    String tagline;
    try {
      final l10n = AppLocalizations.of(context);
      tagline = l10n.tagline;
    } catch (e) {
      // Fallback if localization not ready yet
      tagline = 'Your learning journey starts here';
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            // Main content with animated logo
            Center(child: _SplashContent(tagline: tagline)),

            // Language switcher in top right
            Positioned(top: 20, right: 20, child: const LanguageSwitcher()),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _authStateSubscription?.cancel();
    super.dispose();
  }
}

/// Splash screen content with animated logo
class _SplashContent extends StatefulWidget {
  final String tagline;

  const _SplashContent({required this.tagline});

  @override
  State<_SplashContent> createState() => _SplashContentState();
}

class _SplashContentState extends State<_SplashContent>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.5,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.elasticOut));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));

    // Start animation immediately
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Animated logo - use network image for web, local asset for mobile
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: Opacity(
                opacity: _fadeAnimation.value,
                child: kIsWeb
                    ? Image.network(
                        'https://cpzaxdfxbamdsshdgjyg.supabase.co/storage/v1/object/public/Logos/app_logo(blue).png',
                        width: 120,
                        height: 120,
                        fit: BoxFit.contain,
                        // Pre-cache the image for faster loading
                        cacheWidth: 240, // 2x for retina
                        loadingBuilder: (context, child, loadingProgress) {
                          // Show local asset immediately while network image loads
                          if (loadingProgress == null) return child;
                          return Image.asset(
                            'assets/images/app_logo(blue).png',
                            width: 120,
                            height: 120,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              // Ultimate fallback - show placeholder
                              return Container(
                                width: 120,
                                height: 120,
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Center(
                                  child: Text(
                                    'PS',
                                    style: GoogleFonts.poppins(
                                      color: Colors.white,
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              );
                            },
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          // Fallback to local asset if network fails
                          return Image.asset(
                            'assets/images/app_logo(blue).png',
                            width: 120,
                            height: 120,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              // Ultimate fallback - show placeholder
                              return Container(
                                width: 120,
                                height: 120,
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Center(
                                  child: Text(
                                    'PS',
                                    style: GoogleFonts.poppins(
                                      color: Colors.white,
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      )
                    : Image.asset(
                        'assets/images/app_logo(blue).png',
                        width: 120,
                        height: 120,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          // Fallback placeholder if asset doesn't exist
                          return Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Center(
                              child: Text(
                                'PS',
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            );
          },
        ),

        const SizedBox(height: 24),

        // App name with fade animation
        FadeTransition(
          opacity: _fadeAnimation,
          child: Text(
            'PrepSkul',
            style: GoogleFonts.poppins(
              color: AppTheme.textDark,
              fontSize: 36,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Tagline with fade animation
        FadeTransition(
          opacity: _fadeAnimation,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              widget.tagline,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                color: AppTheme.textMedium,
                fontSize: 14,
                fontWeight: FontWeight.w400,
                height: 1.4,
              ),
            ),
          ),
        ),

        const SizedBox(height: 40),

        // Loading indicator with fade animation
        FadeTransition(
          opacity: _fadeAnimation,
          child: const SizedBox(
            width: 30,
            height: 30,
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
              strokeWidth: 3,
            ),
          ),
        ),
      ],
    );
  }
}
