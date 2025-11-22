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
import 'package:prepskul/features/profile/screens/survey_intro_screen.dart';
import 'package:prepskul/features/auth/screens/beautiful_login_screen.dart';
import 'package:prepskul/features/auth/screens/beautiful_signup_screen.dart';
import 'package:prepskul/features/auth/screens/forgot_password_screen.dart';
import 'package:prepskul/features/auth/screens/reset_password_screen.dart';
import 'package:prepskul/features/auth/screens/otp_verification_screen.dart';
import 'package:prepskul/features/auth/screens/auth_method_selection_screen.dart';
import 'package:prepskul/features/auth/screens/email_signup_screen.dart';
import 'package:prepskul/features/auth/screens/email_login_screen.dart';
import 'package:prepskul/features/tutor/screens/tutor_onboarding_screen.dart';
import 'package:prepskul/features/payment/screens/booking_payment_screen.dart';
import 'package:prepskul/features/payment/screens/payment_history_screen.dart';
import 'package:prepskul/features/booking/screens/my_sessions_screen.dart';
import 'package:prepskul/core/services/auth_service.dart';
import 'package:prepskul/core/widgets/language_switcher.dart';
import 'package:prepskul/core/navigation/main_navigation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:prepskul/core/services/supabase_service.dart';
import 'package:prepskul/core/services/push_notification_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:prepskul/firebase_options.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  void _handleDeepLink(Uri uri) async {
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

    // List of protected routes that require authentication
    // These routes should redirect to email login if user is not authenticated
    final protectedRoutes = [
      '/tutor/profile/edit',
      '/tutor/profile',
      '/tutor/dashboard',
      '/tutor/onboarding',
      '/tutor',
      '/student',
      '/parent',
      '/bookings',
      '/payments',
      '/sessions',
    ];

    // Check if this is a protected route
    final isProtectedRoute = protectedRoutes.any(
      (route) => path.startsWith(route),
    );

    // Check if user is authenticated
    final isAuthenticated = SupabaseService.isAuthenticated;
    final user = SupabaseService.currentUser;

    if (isProtectedRoute && (!isAuthenticated || user == null)) {
      // User is not authenticated but trying to access a protected route
      // Store the intended destination and redirect to email login
      print(
        '🔒 [DEEP_LINK] Protected route requires authentication, redirecting to email login',
      );
      print('🔒 [DEEP_LINK] Intended destination: $path');

      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('pending_deep_link', path);
        print('✅ [DEEP_LINK] Stored pending deep link: $path');
      } catch (e) {
        print('⚠️ [DEEP_LINK] Error storing pending deep link: $e');
      }

      // Queue navigation to email login (will process when app is ready)
      final navService = NavigationService();
      if (navService.isReady) {
        // App is ready, redirect to email login immediately
        navService.navigateToRoute('/email-login', replace: true);
      } else {
        // Queue email login navigation
        navService.queueDeepLink(Uri.parse('/email-login'));
        print(
          '📥 [DEEP_LINK] Email login queued, will process when app is ready',
        );
      }
      return;
    }

    // User is authenticated or route is not protected, proceed normally
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
      // Use fade transition for all routes to prevent white screen flash
      themeMode: ThemeMode.light,

      // Localization setup - make resilient to module loading failures
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: supportedLocales,
      locale: locale,

      // Routes - use onGenerateRoute for fade transitions instead
      // This prevents white screen flash during navigation
      routes: <String, WidgetBuilder>{},
      onGenerateRoute: (settings) {
        // Helper to create routes with fade transition (prevents white screen flash)
        PageRoute<T> _createFadeRoute<T>(Widget Function() builder) {
          return PageRouteBuilder<T>(
            settings: settings,
            pageBuilder: (context, animation, secondaryAnimation) => builder(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              // Fade transition keeps old screen visible until new one is ready
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 150),
          );
        }

        // Handle all routes with fade transition to prevent white screen
        switch (settings.name) {
          case '/onboarding':
            return _createFadeRoute(() => const SimpleOnboardingScreen());
          case '/auth-method-selection':
            return _createFadeRoute(() => const AuthMethodSelectionScreen());
          case '/login':
          case '/beautiful-login':
            return _createFadeRoute(() => const BeautifulLoginScreen());
          case '/beautiful-signup':
            return _createFadeRoute(() => const BeautifulSignupScreen());
          case '/email-signup':
            return _createFadeRoute(() => const EmailSignupScreen());
          case '/email-login':
            return _createFadeRoute(() => const EmailLoginScreen());
          case '/forgot-password':
            return _createFadeRoute(() => const ForgotPasswordScreen());
        }

        // Handle navigation routes with optional initialTab argument
        if (settings.name == '/tutor-nav') {
          final args = settings.arguments as Map<String, dynamic>?;
          return _createFadeRoute(
            () => MainNavigation(
              userRole: 'tutor',
              initialTab: args?['initialTab'],
            ),
          );
        }
        if (settings.name == '/student-nav') {
          final args = settings.arguments as Map<String, dynamic>?;
          return _createFadeRoute(
            () => MainNavigation(
              userRole: 'student',
              initialTab: args?['initialTab'],
            ),
          );
        }
        if (settings.name == '/parent-nav') {
          final args = settings.arguments as Map<String, dynamic>?;
          return _createFadeRoute(
            () => MainNavigation(
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
            return _createFadeRoute(
              () => const TutorOnboardingScreen(basicInfo: {}),
            );
          }

          // Use surveys for students and parents
          // Note: NavigationService handles showing intro screen first if needed
          if (userRole == 'learner' || userRole == 'student') {
            return _createFadeRoute(() => const StudentSurvey());
          } else if (userRole == 'parent') {
            return _createFadeRoute(() => const ParentSurvey());
          }

          // Fallback to student survey
          return _createFadeRoute(() => const StudentSurvey());
        }
        if (settings.name == '/survey-intro') {
          final args = settings.arguments as Map<String, dynamic>?;
          final userType = args?['userType'] ?? 'student';
          return _createFadeRoute(() => SurveyIntroScreen(userType: userType));
        }
        if (settings.name == '/tutor-onboarding') {
          final args = settings.arguments as Map<String, dynamic>?;
          return _createFadeRoute(
            () => TutorOnboardingScreen(basicInfo: args ?? {}),
          );
        }
        if (settings.name == '/reset-password') {
          final args = settings.arguments as Map<String, dynamic>?;
          final phone = args?['phone'] ?? '';
          final isEmailRecovery = args?['isEmailRecovery'] ?? false;
          return _createFadeRoute(
            () => ResetPasswordScreen(
              phone: phone,
              isEmailRecovery: isEmailRecovery,
            ),
          );
        }
        if (settings.name == '/otp-verification') {
          final args = settings.arguments as Map<String, dynamic>?;
          return _createFadeRoute(
            () => OTPVerificationScreen(
              phoneNumber: args?['phoneNumber'] ?? '',
              fullName: args?['fullName'] ?? '',
              userRole: args?['userRole'] ?? 'student',
            ),
          );
        }
        // Payment routes
        if (settings.name == '/payments' ||
            settings.name == '/payment-history') {
          return MaterialPageRoute(
            builder: (context) => const PaymentHistoryScreen(),
          );
        }
        if (settings.name?.startsWith('/payments/') == true) {
          final paymentRequestId = settings.name!.split('/').last;
          final args = settings.arguments as Map<String, dynamic>?;
          return MaterialPageRoute(
            builder: (context) => BookingPaymentScreen(
              paymentRequestId: paymentRequestId,
              bookingRequestId: args?['bookingRequestId'] as String?,
            ),
          );
        }
        // My Sessions route
        if (settings.name == '/my-sessions') {
          return MaterialPageRoute(
            builder: (context) => const MySessionsScreen(),
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
  bool _isNavigating = false;
  bool _navigationComplete = false;

  @override
  void initState() {
    super.initState();
    // Start navigation after a brief delay to ensure UI is ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeAndNavigate();
    });
  }

  Future<void> _initializeAndNavigate() async {
    if (_isNavigating || _navigationComplete) return;
    _isNavigating = true;

    // CRITICAL: Check authentication synchronously FIRST to avoid login screen flash
    // This prevents showing login screen for authenticated users during hot restart
    final isAuthenticated = SupabaseService.isAuthenticated;
    final currentUser = SupabaseService.currentUser;

    if (isAuthenticated && currentUser != null) {
      // If URL contains 'code', it might be an email verification in progress
      // We should wait a bit longer for Supabase to process the code and potentially
      // confirm the email, which might trigger navigation handlers in SplashScreen
      if (kIsWeb && Uri.base.queryParameters.containsKey('code')) {
        print('🔗 [INIT_LOAD] Auth code detected in URL - waiting for processing');
        // Give Supabase auth listener time to fire
        await Future.delayed(const Duration(seconds: 2)); 
      }

      print(
        '✅ [INIT_LOAD] User authenticated - checking onboarding/survey status',
      );
      // CRITICAL: Always check onboarding completion before allowing access
      // Wait for navigation service to be ready
      int attempts = 0;
      final maxAttempts = 10; // 2 seconds max wait
      while (attempts < maxAttempts && mounted) {
        final navService = NavigationService();
        if (navService.isReady) {
          try {
            // Always use determineInitialRoute which checks onboarding/survey completion
            final result = await navService.determineInitialRoute();
            print('✅ [INIT_LOAD] Determined route: ${result.route}');
            // Navigate to determined route (could be onboarding, survey, or dashboard)
            await navService.navigateToRoute(
              result.route,
              arguments: result.arguments,
              replace: true,
            );
            if (mounted) {
              setState(() {
                _navigationComplete = true;
              });
            }
            return; // Exit early - navigation complete
          } catch (e) {
            print('⚠️ [INIT_LOAD] Error navigating authenticated user: $e');
            // On error, check onboarding status explicitly before fallback
            final prefs = await SharedPreferences.getInstance();
            final hasCompletedOnboarding =
                prefs.getBool('onboarding_completed') ?? false;
            if (!hasCompletedOnboarding) {
              // Redirect to onboarding if not completed
              if (mounted) {
                final navService = NavigationService();
                if (navService.isReady) {
                  await navService.navigateToRoute(
                    '/onboarding',
                    replace: true,
                  );
                  return;
                }
              }
            }
            // Only fallback to dashboard if onboarding is completed
            // But still check survey completion via determineInitialRoute
            final navService = NavigationService();
            if (navService.isReady) {
              try {
                final result = await navService.determineInitialRoute();
                await navService.navigateToRoute(
                  result.route,
                  arguments: result.arguments,
                  replace: true,
                );
                return;
              } catch (e2) {
                print('⚠️ [INIT_LOAD] Error in fallback navigation: $e2');
              }
            }
          }
        }
        await Future.delayed(const Duration(milliseconds: 200));
        attempts++;
      }
    }

    // If not authenticated, proceed with normal flow (but still check quickly)
    // Check if we have a code first (wait longer if so)
    if (kIsWeb && Uri.base.queryParameters.containsKey('code')) {
       print('🔗 [INIT_LOAD] Auth code detected (unauthenticated) - waiting for processing');
       await Future.delayed(const Duration(seconds: 2));
    } else {
       // Wait for minimum 300ms to show animation (reduced from 500ms)
       await Future.delayed(const Duration(milliseconds: 300));
    }

    // Wait for Supabase to be ready (with timeout)
    int attempts = 0;
    final maxAttempts = 10; // 2 seconds max wait (reduced from 4 seconds)
    while (attempts < maxAttempts) {
      try {
        SupabaseService.client; // This will throw if not ready
        break; // Supabase is ready
      } catch (e) {
        await Future.delayed(const Duration(milliseconds: 200));
        attempts++;
      }
    }

    // Determine and navigate to route
    if (mounted) {
      try {
        final navService = NavigationService();
        if (navService.isReady) {
          final result = await navService.determineInitialRoute();

          // Navigate directly - animated logo will transition smoothly
          await navService.navigateToRoute(
            result.route,
            arguments: result.arguments,
            replace: true,
          );
          if (mounted) {
            setState(() {
              _navigationComplete = true;
            });
          }
        } else {
          // Navigation service not ready - wait a bit and try again
          await Future.delayed(const Duration(milliseconds: 200));
          if (mounted && navService.isReady) {
            final result = await navService.determineInitialRoute();
            await navService.navigateToRoute(
              result.route,
              arguments: result.arguments,
              replace: true,
            );
          }
        }
      } catch (e) {
        print('⚠️ [INIT_LOAD] Error during navigation: $e');
        // Fallback: navigate to auth screen only if not authenticated
        if (mounted && !SupabaseService.isAuthenticated) {
          final navService = NavigationService();
          if (navService.isReady) {
            await navService.navigateToRoute(
              '/auth-method-selection',
              replace: true,
            );
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Always show animated loading screen until navigation completes
    // The navigation will replace this screen, so no need to check _navigationComplete
    // Use a Material widget to ensure proper background color during transition
    return Material(color: Colors.white, child: const InitialLoadingScreen());
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

    // Check for password reset or email confirmation FIRST (web only)
    // If either is detected, they will handle navigation and we should skip normal navigation
    bool handledByCallback = false;
    if (kIsWeb) {
      handledByCallback = await _checkPasswordResetCallback();
      if (!handledByCallback) {
        handledByCallback = await _checkEmailConfirmationCallback();
      }
    }

    // If password reset or email confirmation handled navigation, don't navigate normally
    if (handledByCallback) {
      print(
        '✅ [SPLASH] Navigation handled by password reset or email confirmation',
      );
      return;
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
  /// Returns true if email confirmation was detected and navigation was handled
  Future<bool> _checkEmailConfirmationCallback() async {
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
          return true; // Indicate that navigation was handled
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
    return false; // No email confirmation detected, continue normal navigation
  }

  /// Check if URL contains password reset code (web only)
  /// Returns true if password reset was detected and navigation was handled
  Future<bool> _checkPasswordResetCallback() async {
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
            return true; // Indicate that navigation was handled
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
    return false; // No password reset detected, continue normal navigation
  }

  Future<void> _handleEmailConfirmation() async {
    print('🔐 Handling email confirmation...');
    final user = SupabaseService.currentUser;

    if (user == null) {
      print('⚠️ No user found after email confirmation');
      return;
    }

    // Get stored signup data from SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final storedRole = prefs.getString('signup_user_role');
    final storedName = prefs.getString('signup_full_name');
    final storedEmail = prefs.getString('signup_email');

    // Check if profile already exists
    var existingProfile = await SupabaseService.client
        .from('profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();

    // If profile doesn't exist, create it using stored signup data
    if (existingProfile == null) {
      print('📝 Profile not found - creating from stored signup data');
      try {
        // Create profile using stored signup data
        await SupabaseService.client.from('profiles').upsert({
          'id': user.id,
          'email': storedEmail ?? user.email ?? '',
          'full_name': storedName ?? 'User',
          'phone_number': null,
          'user_type': storedRole ?? 'student',
          'avatar_url': null,
          'survey_completed': false,
          'is_admin': false,
        }, onConflict: 'id');

        // Fetch the created profile
        existingProfile = await SupabaseService.client
            .from('profiles')
            .select()
            .eq('id', user.id)
            .maybeSingle();

        // Clear stored signup data
        await prefs.remove('signup_user_role');
        await prefs.remove('signup_full_name');
        await prefs.remove('signup_email');
      } catch (e) {
        print('⚠️ Error creating profile: $e');
        // Continue anyway - try to use stored data
      }
    } else {
      // Profile exists - update email and name if needed
      final updates = <String, dynamic>{};
      bool needsUpdate = false;

      // Update email if it wasn't set
      if ((existingProfile['email'] == null ||
              existingProfile['email'] == '') &&
          (storedEmail != null || user.email != null)) {
        updates['email'] = storedEmail ?? user.email ?? '';
        needsUpdate = true;
      }

      // CRITICAL: Update name if it's missing or default (Student/User)
      final currentName = existingProfile['full_name']?.toString() ?? '';
      String? nameToUse;

      // Priority order: storedName > auth metadata > user.email (extract name) > currentName
      if (storedName != null &&
          storedName.isNotEmpty &&
          storedName != 'User' &&
          storedName != 'Student') {
        nameToUse = storedName;
      } else if (user.userMetadata?['full_name'] != null) {
        final metadataName = user.userMetadata!['full_name']?.toString() ?? '';
        if (metadataName.isNotEmpty &&
            metadataName != 'User' &&
            metadataName != 'Student') {
          nameToUse = metadataName;
        }
      } else if (user.email != null && currentName.isEmpty) {
        // Extract name from email (before @) as last resort
        final emailName = user.email!.split('@')[0];
        if (emailName.isNotEmpty &&
            emailName != 'user' &&
            emailName != 'student') {
          nameToUse = emailName
              .split('.')
              .map((s) => s[0].toUpperCase() + s.substring(1))
              .join(' ');
        }
      }

      // Update if we found a valid name and current name is invalid
      if (nameToUse != null &&
          (currentName.isEmpty ||
              currentName == 'Student' ||
              currentName == 'User')) {
        updates['full_name'] = nameToUse;
        needsUpdate = true;
        print('✅ Updating profile name from "$currentName" to "$nameToUse"');
      }

      if (needsUpdate) {
        try {
          await SupabaseService.client
              .from('profiles')
              .update(updates)
              .eq('id', user.id);

          // Refresh existingProfile after update
          existingProfile = await SupabaseService.client
              .from('profiles')
              .select()
              .eq('id', user.id)
              .maybeSingle();

          print('✅ Profile updated successfully');
        } catch (e) {
          print('⚠️ Error updating profile: $e');
        }
      }

      // Only clear stored signup data AFTER we've successfully used it or confirmed it's not needed
      // Don't clear if profile still has default name and we couldn't update it
      final finalName = existingProfile?['full_name']?.toString() ?? '';
      if (finalName != 'User' &&
          finalName != 'Student' &&
          finalName.isNotEmpty) {
        // Profile has a valid name now, safe to clear stored data
        await prefs.remove('signup_user_role');
        await prefs.remove('signup_full_name');
        await prefs.remove('signup_email');
      } else {
        // Profile still has invalid name, keep stored data for next attempt
        print(
          '⚠️ Profile still has invalid name "$finalName", keeping stored signup data',
        );
      }
    }

    // Get user role from profile or stored data
    final userRole = existingProfile?['user_type'] ?? storedRole ?? 'student';
    final hasCompletedSurvey = existingProfile?['survey_completed'] ?? false;

    // Get name with proper priority - avoid 'User' or 'Student' defaults
    var fullName = existingProfile?['full_name']?.toString() ?? '';

    // If name is invalid, try other sources
    if (fullName.isEmpty || fullName == 'User' || fullName == 'Student') {
      if (storedName != null &&
          storedName.isNotEmpty &&
          storedName != 'User' &&
          storedName != 'Student') {
        fullName = storedName;
      } else if (user.userMetadata?['full_name'] != null) {
        final metadataName = user.userMetadata!['full_name']?.toString() ?? '';
        if (metadataName.isNotEmpty &&
            metadataName != 'User' &&
            metadataName != 'Student') {
          fullName = metadataName;
        }
      } else if (user.email != null) {
        // Extract name from email as last resort
        final emailName = user.email!.split('@')[0];
        if (emailName.isNotEmpty &&
            emailName != 'user' &&
            emailName != 'student') {
          fullName = emailName
              .split('.')
              .map(
                (s) => s.isNotEmpty && s.length > 1
                    ? s[0].toUpperCase() + s.substring(1)
                    : s.toUpperCase(),
              )
              .where((s) => s.isNotEmpty)
              .join(' ');
        }
      }
    }

    // Final fallback: use role-based default only if we couldn't find anything
    if (fullName.isEmpty || fullName == 'User' || fullName == 'Student') {
      fullName = userRole == 'student'
          ? 'Student'
          : userRole == 'parent'
          ? 'Parent'
          : userRole == 'tutor'
          ? 'Tutor'
          : 'User';
    }

    final phone = existingProfile?['phone_number'] ?? '';

    // Save session
    await AuthService.saveSession(
      userId: user.id,
      userRole: userRole,
      phone: phone,
      fullName: fullName,
      surveyCompleted: hasCompletedSurvey,
      rememberMe: true,
    );

    // Navigate using NavigationService - redirect to role-specific route
    final navService = NavigationService();
    if (mounted && navService.isReady) {
      if (!hasCompletedSurvey) {
        print('📝 Navigating directly to survey based on role: $userRole');
        await navService.navigateToRoute(
          '/profile-setup',
          arguments: {'userRole': userRole},
          replace: true,
        );
      } else {
        print('🏠 Navigating directly to dashboard based on role: $userRole');
        // Navigate to role-specific dashboard
        final route = userRole == 'tutor'
            ? '/tutor-nav'
            : userRole == 'parent'
            ? '/parent-nav'
            : '/student-nav';
        await navService.navigateToRoute(route, replace: true);
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
