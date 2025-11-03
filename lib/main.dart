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
import 'dart:async';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase
  await Supabase.initialize(
    url: 'https://cpzaxdfxbamdsshdgjyg.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNwemF4ZGZ4YmFtZHNzaGRnanlnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjE1MDUwMDYsImV4cCI6MjA3NzA4MTAwNn0.FWBFrseEeYqFaJ7FGRUAYtm10sz0JqPyerJ0BfoYnCU',
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
    ),
  );

  await LanguageService.initialize();

  // Initialize auth state listener
  AuthService.initAuthListener();

  runApp(const PrepSkulApp());
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
                return MaterialPageRoute(
                  builder: (context) => ResetPasswordScreen(phone: phone),
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

  @override
  void initState() {
    super.initState();

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

    // Simulate splash screen delay
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        // Check if user has completed onboarding
        _checkOnboardingStatus();
      }
    });
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

    if (existingProfile == null) {
      print('⚠️ No profile found, this should not happen');
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

    // Navigate based on survey status
    if (mounted) {
      if (!hasCompletedSurvey) {
        print('📝 Navigating to survey...');
        Navigator.of(context).pushReplacementNamed(
          '/profile-setup',
          arguments: {'userRole': userRole},
        );
      } else {
        print('🏠 Navigating to home...');
        if (userRole == 'tutor') {
          Navigator.of(context).pushReplacementNamed('/tutor-nav');
        } else if (userRole == 'parent') {
          Navigator.of(context).pushReplacementNamed('/parent-nav');
        } else {
          Navigator.of(context).pushReplacementNamed('/student-nav');
        }
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
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            // Main content
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // App logo
                  Image.asset(
                    'assets/images/app_logo(blue).png',
                    width: 100,
                    height: 100,
                  ),

                  const SizedBox(height: 20),

                  // App name
                  Text(
                    'PrepSkul',
                    style: GoogleFonts.poppins(
                      color: AppTheme.textDark,
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Tagline
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Text(
                      l10n.tagline,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        color: AppTheme.textMedium,
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        height: 1.4,
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Loading indicator
                  const SizedBox(
                    width: 30,
                    height: 30,
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppTheme.primaryColor,
                      ),
                      strokeWidth: 3,
                    ),
                  ),
                ],
              ),
            ),

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
