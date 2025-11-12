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
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:prepskul/core/services/supabase_service.dart';
import 'package:prepskul/core/services/push_notification_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:prepskul/firebase_options.dart';
import 'package:prepskul/core/widgets/initial_loading_screen.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:app_links/app_links.dart';
import 'package:prepskul/core/navigation/navigation_service.dart';
import 'dart:async';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // CRITICAL: Initialize Firebase BEFORE runApp() on web
    // On Flutter web, Firebase must be initialized synchronously before the app starts
    // Check if already initialized to prevent double initialization on hot restart
    if (kIsWeb) {
      // Web-specific: Make Firebase initialization resilient to module loading failures
      try {
        // Try to get Firebase options - may fail if firebase_options.dart module doesn't load
        final firebaseOptions = DefaultFirebaseOptions.currentPlatform;
        try {
          await Firebase.initializeApp(options: firebaseOptions);
          print('✅ Firebase initialized');
        } catch (e) {
          // If already initialized, Firebase will throw an error
          // This is fine - just continue
          if (e.toString().contains('already been initialized') ||
              e.toString().contains('already initialized')) {
            print('✅ Firebase already initialized');
          } else {
            rethrow;
          }
        }
      } catch (e) {
        // If firebase_options.dart module fails to load, log warning but continue
        // This allows app to start even if Firebase module has loading issues
        print('⚠️ Firebase options not available (module loading issue): $e');
        print(
          'ℹ️ App will continue without Firebase - some features may be limited',
        );
      }
    } else {
      // Mobile platforms: Standard initialization
      try {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
        print('✅ Firebase initialized');
      } catch (e) {
        // If already initialized, Firebase will throw an error
        // This is fine - just continue
        if (e.toString().contains('already been initialized') ||
            e.toString().contains('already initialized')) {
          print('✅ Firebase already initialized');
        } else {
          rethrow;
        }
      }
    }

    // Initialize Supabase
    await Supabase.initialize(
      url: 'https://cpzaxdfxbamdsshdgjyg.supabase.co',
      anonKey:
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNwemF4ZGZ4YmFtZHNzaGRnanlnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjE1MDUwMDYsImV4cCI6MjA3NzA4MTAwNn0.FWBFrseEeYqFaJ7FGRUAYtm10sz0JqPyerJ0BfoYnCU',
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
    );
    print('✅ Supabase initialized');

    // Initialize LanguageService - make resilient to module loading failures
    try {
      await LanguageService.initialize();
      print('✅ LanguageService initialized');
    } catch (e) {
      // If LanguageService module fails to load, log warning but continue
      // This allows app to start even if localization module has loading issues
      print('⚠️ LanguageService not available (module loading issue): $e');
      print('ℹ️ App will continue with default locale (English)');
    }

    // Initialize auth state listener
    try {
      AuthService.initAuthListener();
      print('✅ AuthService initialized');
    } catch (e) {
      print('⚠️ AuthService not available (module loading issue): $e');
      print('ℹ️ App will continue without auth state listener');
    }

    // Initialize push notifications in background (non-blocking)
    // Web-specific: Only initialize if not on web, or if on web and Firebase is available
    if (!kIsWeb || (kIsWeb && Firebase.apps.isNotEmpty)) {
      // Don't await - let splash screen transition happen
      _initializePushNotifications().catchError((error) {
        print(
          '⚠️ Push notification initialization error (non-blocking): $error',
        );
      });
    } else {
      print(
        'ℹ️ Skipping push notification initialization on web (Firebase not available)',
      );
    }

    print('✅ App initialization complete');
  } catch (e) {
    print('❌ Error initializing app: $e');
    // Even if initialization fails, run the app so user sees error screen
  }

  // Run app AFTER all critical initialization is complete
  runApp(const PrepSkulApp());
}

/// Initialize push notifications
Future<void> _initializePushNotifications() async {
  try {
    await PushNotificationService().initialize(
      onNotificationTap: (message) {
        // Handle notification tap navigation
        // This will be handled by the navigation system
        final data = message?.data;
        if (data != null) {
          print('📱 Notification tapped: ${data.toString()}');
        } else {
          print('📱 Notification tapped (no data)');
        }
      },
    );
    print('✅ Push notifications initialized');
  } catch (e) {
    print('❌ Error initializing push notifications: $e');
  }
}

class PrepSkulApp extends StatefulWidget {
  const PrepSkulApp({super.key});

  @override
  State<PrepSkulApp> createState() => _PrepSkulAppState();
}

class _PrepSkulAppState extends State<PrepSkulApp> {
  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    // Initialize NavigationService with navigator key
    NavigationService().initialize(_navigatorKey);
    _initDeepLinks();
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  /// Initialize deep link handling for email notifications
  Future<void> _initDeepLinks() async {
    // Handle initial link (if app was opened from a link)
    try {
      final initialLink = await _appLinks.getInitialLink();
      if (initialLink != null) {
        _handleDeepLink(initialLink);
      }
    } catch (e) {
      print('⚠️ Error getting initial link: $e');
    }

    // Listen for incoming links while app is running
    _linkSubscription = _appLinks.uriLinkStream.listen(
      (Uri uri) {
        _handleDeepLink(uri);
      },
      onError: (err) {
        print('❌ Error listening to deep links: $err');
      },
    );
  }

  /// Handle deep link navigation from email notifications
  void _handleDeepLink(Uri uri) {
    print('🔗 Deep link received: $uri');

    // Extract path from URL
    // Examples:
    // - https://app.prepskul.com/bookings/123 → /bookings/123
    // - prepskul://bookings/123 → /bookings/123
    String path = uri.path;

    // If it's a full URL with host, use the path
    if (uri.host == 'app.prepskul.com' || uri.host.isEmpty) {
      path = uri.path;
    }

    if (path.isEmpty) {
      return;
    }

    // Queue deep link in NavigationService (will process when app is ready)
    final navService = NavigationService();
    if (navService.isReady) {
      // App is ready, process immediately
      navService.navigateToRoute(path);
    } else {
      // Queue for later processing
      navService.queueDeepLink(uri);
      print('📥 [DEEP_LINK] Deep link queued, will process when app is ready');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Try to use Provider, but fallback if module doesn't load (web DDC issue)
    try {
      return ChangeNotifierProvider(
        create: (context) {
          final notifier = LanguageNotifier();
          notifier.initialize();
          return notifier;
        },
        child: Consumer<LanguageNotifier>(
          builder: (context, languageNotifier, child) {
            return _buildMaterialApp(languageNotifier.currentLocale);
          },
        ),
      );
    } catch (e) {
      // If Provider module fails to load, use fallback without Provider
      // This allows app to start even if state management package has loading issues
      print('⚠️ Provider not available (module loading issue): $e');
      print('ℹ️ App will continue without Provider - using default locale');
      // Get locale - make resilient to LanguageService module loading failures
      Locale defaultLocale;
      try {
        defaultLocale = LanguageService.currentLocale;
      } catch (e) {
        // Fallback to English if LanguageService module fails to load
        print('⚠️ LanguageService.currentLocale not available, using English');
        defaultLocale = const Locale('en');
      }
      return _buildMaterialApp(defaultLocale);
    }
  }

  /// Build MaterialApp with given locale (used by both Provider and fallback)
  Widget _buildMaterialApp(Locale locale) {
    // Get supported locales - make resilient to LanguageService module loading failures
    List<Locale> supportedLocales;
    try {
      supportedLocales = LanguageService.supportedLocales;
    } catch (e) {
      // Fallback to default locales if LanguageService module fails to load
      print(
        '⚠️ LanguageService.supportedLocales not available, using defaults',
      );
      supportedLocales = const [Locale('en'), Locale('fr')];
    }

    // Get theme - make resilient to AppTheme module loading failures
    ThemeData appTheme;
    try {
      appTheme = AppTheme.lightTheme;
    } catch (e) {
      // Fallback to default theme if AppTheme module fails to load
      print('⚠️ AppTheme not available, using default theme');
      appTheme = ThemeData(primarySwatch: Colors.blue, useMaterial3: true);
    }

    return MaterialApp(
      title: 'PrepSkul',
      navigatorKey: _navigatorKey,
      theme: appTheme,
      home: const InitialLoadingWrapper(),
      debugShowCheckedModeBanner: false,

      // Localization setup - make resilient to module loading failures
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: supportedLocales,
      locale: locale,

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
              builder: (context) => const TutorOnboardingScreen(basicInfo: {}),
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
          return MaterialPageRoute(builder: (context) => const StudentSurvey());
        }
        if (settings.name == '/tutor-onboarding') {
          final args = settings.arguments as Map<String, dynamic>?;
          return MaterialPageRoute(
            builder: (context) => TutorOnboardingScreen(basicInfo: args ?? {}),
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

      // Fallback locale - make resilient to LanguageService module loading failures
      localeResolutionCallback: (locale, supportedLocales) {
        if (locale != null && supportedLocales.contains(locale)) {
          return locale;
        }
        try {
          return LanguageService.getFallbackLocale();
        } catch (e) {
          // Fallback to English if LanguageService module fails to load
          return const Locale('en');
        }
      },
    );
  }
}

/// Initial Loading Wrapper
///
/// Shows the animated logo loading screen during app initialization.
/// Shows for a minimum of 3 seconds, then transitions to the splash screen.
class InitialLoadingWrapper extends StatefulWidget {
  const InitialLoadingWrapper({super.key});

  @override
  State<InitialLoadingWrapper> createState() => _InitialLoadingWrapperState();
}

class _InitialLoadingWrapperState extends State<InitialLoadingWrapper> {
  bool _showSplash = false;
  bool _initializationComplete = false;
  bool _navigationDetermined = false;
  DateTime? _startTime;

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();

    // Listen for initialization completion and determine navigation
    _waitForInitializationAndNavigate();
  }

  Future<void> _waitForInitializationAndNavigate() async {
    // Reduced minimum wait time to 600ms for faster perceived load
    await Future.delayed(const Duration(milliseconds: 600));

    // Check if Supabase is ready (non-blocking, with timeout)
    int attempts = 0;
    final maxAttempts = 15; // 3 seconds max wait (15 * 200ms)
    while (attempts < maxAttempts && !_initializationComplete) {
      await Future.delayed(const Duration(milliseconds: 200));
      try {
        // Check if Supabase is initialized
        SupabaseService.client; // This will throw if not ready
        _initializationComplete = true;
        break;
      } catch (e) {
        // Supabase not ready yet, continue waiting
      }
      attempts++;
    }

    // Ensure minimum 600ms has passed for smooth transition
    final elapsed = DateTime.now().difference(_startTime!);
    if (elapsed.inMilliseconds < 600) {
      await Future.delayed(
        Duration(milliseconds: 600 - elapsed.inMilliseconds),
      );
    }

    // Determine navigation route BEFORE showing splash screen
    // This prevents the flash of wrong screen
    if (mounted) {
      try {
        final navService = NavigationService();
        if (navService.isReady) {
          final result = await navService.determineInitialRoute();
          _navigationDetermined = true;

          // Navigate directly to the target route, skipping splash screen
          // This prevents the 2-second flash of sign-in screen
          await navService.navigateToRoute(
            result.route,
            arguments: result.arguments,
            replace: true,
          );

          // Don't show splash screen - we've already navigated
          return;
        }
      } catch (e) {
        print('⚠️ [INIT_LOAD] Error determining route: $e');
        // Fall through to show splash screen as fallback
      }
    }

    // Fallback: Show splash screen if navigation determination failed
    if (mounted && !_navigationDetermined) {
      setState(() {
        _showSplash = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show initial loading screen first, then splash
    // Use AnimatedSwitcher for smooth transition (no black screen)
    if (!_showSplash) {
      return const InitialLoadingScreen();
    }
    // Smooth fade transition to prevent black screen
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      transitionBuilder: (Widget child, Animation<double> animation) {
        return FadeTransition(opacity: animation, child: child);
      },
      child: const SplashScreen(key: ValueKey('splash')),
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

  /// Initialize splash screen - Simplified using NavigationService
  Future<void> _initializeSplash() async {
    print('🚀 [SPLASH] Initializing...');

    // Start background tasks (non-blocking)
    _preloadOnboardingImages();
    _setupAuthListeners();
    if (kIsWeb) {
      _checkPasswordResetCallback();
      _checkEmailConfirmationCallback();
    }

    // Reduced delay - start navigation immediately
    // Navigation checks are fast, no need to wait
    await Future.delayed(const Duration(milliseconds: 100));

    // Navigate using NavigationService (single source of truth)
    print('🚀 [SPLASH] Starting navigation check...');
    if (mounted) {
      _navigateToNextScreen();
    }

    // Safety timeout - force navigation after 500ms if nothing happened
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        final navService = NavigationService();
        if (navService.isReady && navService.currentRoute == null) {
          print('⏰ [SPLASH] TIMEOUT - Forcing navigation to auth screen');
          navService.navigateToRoute('/auth-method-selection', replace: true);
        }
      }
    });
  }

  /// Simplified navigation logic using NavigationService
  Future<void> _navigateToNextScreen() async {
    if (!mounted) return;

    try {
      final navService = NavigationService();
      if (!navService.isReady) {
        print('⚠️ [SPLASH] NavigationService not ready yet');
        return;
      }

      // Use NavigationService to determine route (single source of truth)
      final result = await navService.determineInitialRoute();

      print('🚀 [SPLASH] Determined route: ${result.route}');

      // Navigate using NavigationService (handles guards and state)
      await navService.navigateToRoute(
        result.route,
        arguments: result.arguments,
        replace: true,
      );

      // Process any pending deep links after initial navigation
      Future.delayed(const Duration(milliseconds: 500), () {
        navService.processPendingDeepLinks();
      });
    } catch (e) {
      print('❌ [SPLASH] Navigation error: $e');
      // On any error, go to auth
      if (mounted) {
        final navService = NavigationService();
        await navService.navigateToRoute(
          '/auth-method-selection',
          replace: true,
        );
      }
    }
  }

  /// Preload onboarding images in background
  void _preloadOnboardingImages() {
    // Preload images in background without blocking
    final images = [
      'assets/images/onboarding1.png',
      'assets/images/onboarding2.png',
      'assets/images/onboarding3.jpg',
    ];

    // Start preloading in background (don't await)
    Future.microtask(() async {
      for (final imagePath in images) {
        // Check if widget is still mounted before using context
        if (!mounted) {
          return; // Widget unmounted, stop preloading
        }
        try {
          await precacheImage(AssetImage(imagePath), context);
        } catch (e) {
          // Ignore errors if widget is unmounted (expected during navigation)
          if (mounted) {
            print('Warning: Could not preload $imagePath: $e');
          }
        }
      }
    });
  }

  /// Setup auth state listeners
  void _setupAuthListeners() {
    if (_isInitialized) return;
    _isInitialized = true;

    // Listen to auth state changes for email confirmation
    _authStateSubscription = SupabaseService.authStateChanges.listen((data) {
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

    // Navigate using NavigationService
    final navService = NavigationService();
    if (mounted && navService.isReady) {
      if (!hasCompletedSurvey) {
        print('📝 Navigating directly to survey based on role: $userRole');
        await navService.navigateToRoute(
          '/profile-setup',
          arguments: {'userRole': userRole},
          clearStack: true,
        );
      } else {
        print('🏠 Navigating directly to dashboard based on role: $userRole');
        await navService.navigateToDashboard(clearStack: true);
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
            // Main content with animated logo
            Center(child: _SplashContent(tagline: l10n.tagline)),

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
      duration: const Duration(
        milliseconds: 800,
      ), // Reduced from 1500ms for faster animation
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
        // Animated logo with Hero animation - use network image for web, local asset for mobile
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: Opacity(
                opacity: _fadeAnimation.value,
                child: Hero(
                  tag: 'prepskul-logo',
                  transitionOnUserGestures: false,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    // Use local asset for both web and mobile to avoid network delays
                    // This ensures instant loading and no black screen during transition
                    child: Image.asset(
                      'assets/images/app_logo(blue).png',
                      width: 120,
                      height: 120,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        // Fallback if image fails to load
                        return const Icon(
                          Icons.school,
                          size: 120,
                          color: AppTheme.primaryColor,
                        );
                      },
                    ),
                  ),
                ),
              ),
            );
          },
        ),

        const SizedBox(height: 16),

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

        const SizedBox(height: 12),

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

        const SizedBox(height: 24),

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
