import 'package:flutter/material.dart';
import 'package:prepskul/core/services/log_service.dart';
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
import 'package:prepskul/features/auth/screens/forgot_password_email_screen.dart';
import 'package:prepskul/features/auth/screens/reset_password_screen.dart';
import 'package:prepskul/features/auth/screens/reset_password_otp_screen.dart';
import 'package:prepskul/features/auth/screens/otp_verification_screen.dart';
import 'package:prepskul/features/auth/screens/auth_method_selection_screen.dart';
import 'package:prepskul/features/auth/screens/role_selection_screen.dart';
import 'package:prepskul/features/auth/screens/email_signup_screen.dart';
import 'package:prepskul/features/auth/screens/email_login_screen.dart';
import 'package:prepskul/features/auth/screens/email_confirmation_screen.dart';
import 'package:prepskul/features/tutor/screens/tutor_onboarding_screen.dart';
import 'package:prepskul/features/tutor/screens/tutor_onboarding_choice_screen.dart';
import 'package:prepskul/features/payment/screens/payment_route_loader.dart';
import 'package:prepskul/features/payment/screens/payment_history_screen.dart';
import 'package:prepskul/features/booking/screens/my_sessions_screen.dart';
import 'package:prepskul/features/booking/screens/session_feedback_flow_screen.dart';
import 'package:prepskul/core/services/auth_service.dart';
import 'package:prepskul/core/widgets/language_switcher.dart';
import 'package:prepskul/core/navigation/main_navigation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:prepskul/core/services/supabase_service.dart';
import 'package:prepskul/core/services/push_notification_service.dart';
import 'package:prepskul/core/services/notification_navigation_service.dart';
import 'package:prepskul/core/config/app_config.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:prepskul/firebase_options.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:prepskul/core/widgets/initial_loading_screen.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:prepskul/core/config/app_config.dart';
import 'package:app_links/app_links.dart';
import 'package:prepskul/core/navigation/navigation_service.dart';
import 'package:prepskul/core/services/web_splash_service.dart';
import 'package:prepskul/features/skulmate/screens/skulmate_upload_screen.dart';
import 'package:prepskul/features/skulmate/screens/game_library_screen.dart';
import 'package:prepskul/features/skulmate/screens/character_selection_screen.dart';
import 'package:prepskul/features/skulmate/screens/leaderboard_screen.dart';
import 'package:prepskul/features/discovery/screens/tutor_detail_screen.dart';
import 'package:prepskul/core/services/tutor_service.dart';
import 'package:prepskul/features/group_classes/services/group_class_api_service.dart';
import 'package:prepskul/features/group_classes/screens/group_classes_discovery_screen.dart';
import 'package:prepskul/features/sessions/screens/agora_video_session_screen.dart';
import 'dart:async';
import 'package:prepskul/core/services/supabase_service.dart';
import 'package:prepskul/core/services/connectivity_service.dart';
import 'package:prepskul/core/services/offline_cache_service.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:prepskul/core/services/notification_permission_nudge_service.dart';
import 'package:prepskul/features/skulmate/services/skulmate_streak_reminder_service.dart';
import 'package:prepskul/features/payment/services/payment_local_reminder_service.dart';
import 'package:prepskul/core/services/startup_schema_service.dart';
import 'package:prepskul/features/sessions/services/agora_service.dart';

/// Set by password reset deep link handler before exchangeCodeForSession.
/// Auth listener skips handleEmailConfirmation when true (recovery sign-in must go to reset-password screen).
bool _pendingPasswordRecoverySignIn = false;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Allow Poppins-Italic and other font variants to load at runtime when needed.
  // With false, FontStyle.italic on Poppins throws if variant not in assets.
  GoogleFonts.config.allowRuntimeFetching = true;

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
          LogService.success('Firebase initialized');
        } catch (e) {
          // If already initialized, Firebase will throw an error
          // This is fine - just continue
          if (e.toString().contains('already been initialized') ||
              e.toString().contains('already initialized')) {
            LogService.success('Firebase already initialized');
          } else {
            rethrow;
          }
        }
      } catch (e) {
        // If firebase_options.dart module fails to load, log warning but continue
        // This allows app to start even if Firebase module has loading issues
        LogService.warning(
          'Firebase options not available (module loading issue): $e',
        );
        LogService.debug(
          'ℹ️ App will continue without Firebase - some features may be limited',
        );
      }
    } else {
      // Mobile platforms: Standard initialization
      try {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
        LogService.success('Firebase initialized');
      } catch (e) {
        // If already initialized, Firebase will throw an error
        // This is fine - just continue
        if (e.toString().contains('already been initialized') ||
            e.toString().contains('already initialized')) {
          LogService.success('Firebase already initialized');
        } else {
          rethrow;
        }
      }
    }

    // Load environment variables (if .env file exists)
    bool envLoaded = false;
    try {
      await dotenv.load(fileName: ".env");
      envLoaded = true;
      LogService.success('✅ Environment variables loaded from .env');
    } catch (e) {
      LogService.error('❌ Failed to load .env file: $e');
      LogService.warning(
        '⚠️ App will continue but Supabase may not initialize',
      );
    }

    // Print current configuration
    AppConfig.printConfig();

    // Initialize Supabase with AppConfig
    final supabaseUrl = AppConfig.supabaseUrl;
    final supabaseAnonKey = AppConfig.supabaseAnonKey;

    if (supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty) {
      await Supabase.initialize(
        url: supabaseUrl,
        anonKey: supabaseAnonKey,
        authOptions: const FlutterAuthClientOptions(
          authFlowType: AuthFlowType.pkce,
        ),
      );
      LogService.success('✅ Supabase initialized (${AppConfig.environment})');
    } else {
      // Fallback to hardcoded values if env not set (for backward compatibility)
      await Supabase.initialize(
        url: 'https://cpzaxdfxbamdsshdgjyg.supabase.co',
        anonKey:
            'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNwemF4ZGZ4YmFtZHNzaGRnanlnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjE1MDUwMDYsImV4cCI6MjA3NzA4MTAwNn0.FWBFrseEeYqFaJ7FGRUAYtm10sz0JqPyerJ0BfoYnCU',
        authOptions: const FlutterAuthClientOptions(
          authFlowType: AuthFlowType.pkce,
        ),
      );
      LogService.warning(
        'Supabase initialized with fallback values (set SUPABASE_URL_DEV/PROD in .env)',
      );
    }

    // Give Supabase time to restore session from secure storage (especially important on iOS)
    // This prevents users from being logged out after hot restart
    await Future.delayed(const Duration(milliseconds: 300));
    if (SupabaseService.isAuthenticated) {
      LogService.debug('✅ Supabase session restored from storage');
    }

    // Initialize LanguageService - make resilient to module loading failures
    try {
      await LanguageService.initialize();
      LogService.success('LanguageService initialized');
    } catch (e) {
      // If LanguageService module fails to load, log warning but continue
      // This allows app to start even if localization module has loading issues
      LogService.warning(
        'LanguageService not available (module loading issue): $e',
      );
      LogService.info('App will continue with default locale (English)');
    }

    // Initialize auth state listener
    try {
      AuthService.initAuthListener();
      LogService.success('AuthService initialized');
    } catch (e) {
      LogService.warning(
        'AuthService not available (module loading issue): $e',
      );
      LogService.info('App will continue without auth state listener');
    }

    // Non-blocking startup schema diagnostics for critical tables/columns.
    unawaited(StartupSchemaService.runChecks());
    // Web hot-restart guard: tear down stale getUserMedia / iris session before widgets mount.
    // Must await on web — fire-and-forget races the first frame and leaves the camera LED on.
    await AgoraService().forceWebCleanupOnStartup();

    // Initialize push notifications in background (non-blocking)
    // Web-specific: Only initialize if not on web, or if on web and Firebase is available
    if (!kIsWeb || (kIsWeb && Firebase.apps.isNotEmpty)) {
      // Don't await - let splash screen transition happen
      _initializePushNotifications().catchError((error) {
        LogService.debug(
          '⚠️ Push notification initialization error (non-blocking): $error',
        );
      });
    } else {
      LogService.debug(
        'ℹ️ Skipping push notification initialization on web (Firebase not available)',
      );
    }

    LogService.success('App initialization complete');
  } catch (e) {
    LogService.error('Error initializing app: $e');
    // Even if initialization fails, run the app so user sees error screen
  }

  // Run app AFTER all critical initialization is complete
  runApp(const PrepSkulApp());

  // CRITICAL: Don't remove HTML splash screen here on web
  // The InitialLoadingWrapper will handle removing it after navigation completes
  // This prevents white screen flash between HTML splash and Flutter content
}

/// Initialize push notifications
Future<void> _initializePushNotifications() async {
  try {
    await PushNotificationService().initialize(
      
            onNotificationTap: (message) {
        // Handle notification tap navigation (deep links).
        // This is critical for message notifications: user expects to land in the DM.
        try {
          Map<String, dynamic>? data;
          if (message == null) {
            data = null;
          } else if (message is Map) {
            // Local-notification tap payload may be parsed into a Map.
            final raw = message['data'] ?? message;
            if (raw is Map) data = Map<String, dynamic>.from(raw);
          } else {
            // RemoteMessage-style object
            final raw = (message as dynamic).data;
            if (raw is Map) data = Map<String, dynamic>.from(raw);
          }

          if (data != null) {
            LogService.debug('📱 Notification tapped: ${data.toString()}');
            final actionUrl =
                data['actionUrl']?.toString() ?? data['action_url']?.toString();
            final type = data['type']?.toString();
            // Use the same navigation logic as in-app notifications.
            NotificationNavigationService.navigateToAction(
              context: NavigationService().context,
              actionUrl: actionUrl,
              notificationType: type,
              metadata: data,
            );
          } else {
            LogService.debug('📱 Notification tapped (no data)');
          }
        } catch (e) {
          LogService.warning('Error handling notification tap: $e');
        }
      },
    );
    LogService.success('Push notifications initialized');

    // DEBUG ONLY: proactively request permission so we can verify token + delivery
    // without waiting on onboarding flags / specific login paths.
    if (!kIsWeb && kDebugMode) {
      Future.delayed(const Duration(seconds: 2), () async {
        try {
          await PushNotificationService().requestPermission();
        } catch (e) {
          LogService.debug('⚠️ Debug push permission request failed: $e');
        }
      });
    }

    // Ensure daily streak reminder is scheduled app-wide, even if user
    // doesn't open the SkulMate library screen in this app session.
    SkulMateStreakReminderService.rescheduleIfNeeded();
    // Ensure payment due reminders are also scheduled locally for pending requests.
    PaymentLocalReminderService.reschedulePendingForCurrentUser();
  } catch (e) {
    LogService.error('Error initializing push notifications: $e');
  }
}

/// Helper function to handle email confirmation (used by both PrepSkulApp and SplashScreen)
Future<void> handleEmailConfirmation() async {
  LogService.debug('🔐 Handling email confirmation...');
  final user = SupabaseService.currentUser;

  if (user == null) {
    LogService.warning('No user found after email confirmation');
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
    LogService.debug('📝 Profile not found - creating from stored signup data');
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
      LogService.warning('Error creating profile: $e');
      // Continue anyway - try to use stored data
    }
  } else {
    // Profile exists - update email and name if needed
    final updates = <String, dynamic>{};
    bool needsUpdate = false;

    // Update email if it wasn't set
    if ((existingProfile['email'] == null || existingProfile['email'] == '') &&
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
      LogService.success(
        'Updating profile name from "$currentName" to "$nameToUse"',
      );
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

        LogService.success('Profile updated successfully');
      } catch (e) {
        LogService.warning('Error updating profile: $e');
      }
    }

    // Only clear stored signup data AFTER we've successfully used it or confirmed it's not needed
    // Don't clear if profile still has default name and we couldn't update it
    final finalName = existingProfile?['full_name']?.toString() ?? '';
    if (finalName != 'User' && finalName != 'Student' && finalName.isNotEmpty) {
      // Profile has a valid name now, safe to clear stored data
      await prefs.remove('signup_user_role');
      await prefs.remove('signup_full_name');
      await prefs.remove('signup_email');
    } else {
      // Profile still has invalid name, keep stored data for next attempt
      LogService.debug(
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
  if (navService.isReady) {
    // Use determineInitialRoute to handle all logic (intro screen, onboarding, etc.)
    final routeResult = await navService.determineInitialRoute();
    LogService.success(
      '[EMAIL_CONFIRM] Navigating to determined route: ${routeResult.route}',
    );

    await navService.navigateToRoute(
      routeResult.route,
      arguments: routeResult.arguments,
      replace: true,
    );
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
    // Track app opens for notification prompt eligibility.
    NotificationPermissionNudgeService.recordAppOpen();
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
      } else if (kIsWeb) {
        // On web, getInitialLink() often returns null when opening a URL directly.
        // Use Uri.base so tutor (and other) deep links work when landing on web.
        final baseUri = Uri.base;
        String path = baseUri.path;
        if (path == '/' && baseUri.fragment.isNotEmpty) {
          final f = baseUri.fragment;
          path = f.startsWith('/') ? f : '/$f';
        }
        if (path.isNotEmpty &&
            (path != '/' || baseUri.queryParameters['tutor'] != null)) {
          final uri = Uri(
            path: path,
            queryParameters: baseUri.queryParameters,
            fragment: baseUri.fragment,
          );
          _handleDeepLink(uri);
        }
      }
    } catch (e) {
      LogService.warning('Error getting initial link: $e');
    }

    // Listen for incoming links while app is running
    _linkSubscription = _appLinks.uriLinkStream.listen(
      (Uri uri) {
        _handleDeepLink(uri);
      },
      onError: (err) {
        LogService.error('Error listening to deep links: $err');
      },
    );
  }

  /// Merge query params with fragment params (Supabase may put auth params in hash)
  Map<String, String> _mergeAuthParams(Uri uri) {
    final merged = Map<String, String>.from(uri.queryParameters);
    if (uri.fragment.isNotEmpty) {
      // Fragment can be:
      // - "code=...&type=..."
      // - "/email-login?code=...&type=..."
      // - "#access_token=..."
      var fragment = uri.fragment.trim();
      if (fragment.startsWith('#')) {
        fragment = fragment.substring(1);
      }
      String fragmentQuery = fragment;
      final questionIdx = fragment.indexOf('?');
      if (questionIdx >= 0 && questionIdx < fragment.length - 1) {
        fragmentQuery = fragment.substring(questionIdx + 1);
      }
      if (fragmentQuery.isNotEmpty && fragmentQuery.contains('=')) {
        try {
          final fragmentParams = Uri.splitQueryString(fragmentQuery);
          for (final e in fragmentParams.entries) {
            merged.putIfAbsent(e.key, () => e.value);
          }
        } catch (e) {
          LogService.debug('🔗 [DEEP_LINK] Unable to parse fragment params: $e');
        }
      }
    }
    return merged;
  }

  /// Handle deep link navigation from email notifications
  void _handleDeepLink(Uri uri) async {
    LogService.debug('🔗 Deep link received: $uri');

    // Merge query + fragment params (Supabase may use hash for auth callbacks)
    final params = _mergeAuthParams(uri);

    // Extract and normalize path from URL
    // Examples:
    // - https://app.prepskul.com/bookings/123        → /bookings/123
    // - prepskul://bookings/123                     → /bookings/123
    // - prepskul://tutor/abc                        → /tutor/abc
    // - prepskul://email-login?code=...             → /email-login
    String path = uri.path;

    // Normalize custom scheme links (prepskul://...)
    // Treat the host as the first path segment so that:
    // - prepskul://tutor/abc        → /tutor/abc
    // - prepskul://email-login/...  → /email-login/...
    if (uri.scheme == 'prepskul' && uri.host.isNotEmpty) {
      final normalizedPath = uri.path.isNotEmpty ? uri.path : '';
      path = '/${uri.host}$normalizedPath';
    }
    // For full HTTPS URLs, just use the path component
    else if (uri.host == 'app.prepskul.com' || uri.host.isEmpty) {
      path = uri.path;
    }

    String? code = params['code'];
    String? type = params['type'];
    String? provider = params['provider'];
    // Defensive fallback: some browsers/app-link bridges can reshape callback
    // payload into mixed query/fragment strings. Parse from raw URI if needed.
    final rawUri = uri.toString();
    String? _extractParamFromRaw(String key) {
      final m = RegExp('(?:[?#&]|^)$key=([^&#]+)').firstMatch(rawUri);
      if (m == null) return null;
      return Uri.decodeQueryComponent(m.group(1)!);
    }
    code ??= _extractParamFromRaw('code');
    type ??= _extractParamFromRaw('type');
    provider ??= _extractParamFromRaw('provider');
    final tutorFromQuery = params['tutor'];
    final error = params['error'];
    final errorCode = params['error_code'];

    // Handle password reset / verification link errors early (e.g. otp_expired when user taps expired link)
    // Redirect: prepskul://email-login with error=access_denied&error_code=otp_expired
    if (uri.host == 'email-login' || path.contains('email-login')) {
      if (error != null &&
          (errorCode == 'otp_expired' || error == 'access_denied')) {
        LogService.debug('🔑 [DEEP_LINK] Auth link expired/invalid');
        final prefs = await SharedPreferences.getInstance();
        final pendingSignupEmail = prefs.getString('signup_email');
        final targetRoute = pendingSignupEmail != null
            ? '/email-confirmation'
            : '/forgot-password-email';
        final targetArgs = pendingSignupEmail != null
            ? {
                'linkExpired': true,
                'email': pendingSignupEmail,
                'fullName': prefs.getString('signup_full_name') ?? 'User',
                'userRole': prefs.getString('signup_user_role') ?? 'student',
              }
            : {'linkExpired': true};
        final navService = NavigationService();
        if (navService.isReady) {
          await navService.navigateToRoute(
            targetRoute,
            arguments: targetArgs,
            replace: true,
          );
          // No snackbar - target screen shows link-expired banner
        } else {
          navService.queueDeepLink(
            Uri(
              path: targetRoute,
              queryParameters: targetArgs.map(
                (k, v) => MapEntry(k, v.toString()),
              ),
            ),
          );
        }
        return;
      }
    }

    // Allow path "/" or empty when query has code+type (e.g. email reset: ?code=...&type=recovery)
    // Only treat as recovery when we have an explicit signal - NOT when host is email-login with
    // missing type (that could be signup verification too; both use the same redirect URL).
    if (path.isEmpty || path == '/') {
      final isExplicitRecovery = code != null && type == 'recovery';
      final isExplicitSignup =
          code != null && type != null && (type == 'signup' || type == 'email');
      if (isExplicitRecovery) {
        path = '/reset-password';
      } else if (isExplicitSignup) {
        // Email verification - handled below, don't return
      } else if (tutorFromQuery == null || tutorFromQuery.trim().isEmpty) {
        return;
      }
    }

    // If a tutor id is present in query params, store it so post-auth can navigate
    // to the tutor detail screen (direct tutor discovery link).
    if (tutorFromQuery != null && tutorFromQuery.trim().isNotEmpty) {
      try {
        await NavigationService.storePendingTutorLink(tutorFromQuery.trim());
        LogService.debug(
          '🔗 [DEEP_LINK] Stored pending tutor from query param: ${tutorFromQuery.trim()}',
        );
      } catch (e) {
        LogService.debug(
          '🔗 [DEEP_LINK] Failed storing tutor query param (non-blocking): $e',
        );
      }
    }

    // Handle tutor detail deep links: /tutor/{tutorId}
    // These are public routes — anyone can view tutor profiles
    if (path.startsWith('/tutor/') &&
        path != '/tutor' &&
        !path.startsWith('/tutor/profile') &&
        !path.startsWith('/tutor/dashboard') &&
        !path.startsWith('/tutor/onboarding')) {
      final tutorId = path.replaceFirst('/tutor/', '').trim().split('/').first;
      if (tutorId.isNotEmpty) {
        LogService.debug('🔗 [DEEP_LINK] Tutor detail link detected: $tutorId');

        // Check if user is authenticated
        final isAuthenticated = SupabaseService.isAuthenticated;

        if (!isAuthenticated) {
          // Store pending tutor link for navigation after signup/login
          LogService.debug(
            '🔗 [DEEP_LINK] User not authenticated, storing pending tutor link: $tutorId',
          );
          await NavigationService.storePendingTutorLink(tutorId);
          // Navigate to auth screen - after auth, they'll be redirected to tutor profile
          final navService = NavigationService();
          if (navService.isReady) {
            await navService.navigateToRoute('/auth-method-selection');
          } else {
            navService.queueDeepLink(Uri(path: '/auth-method-selection'));
          }
          return;
        }

        // User is authenticated - navigate directly to tutor profile
        final navService = NavigationService();
        if (navService.isReady) {
          // If the signed-in user is a tutor account, don't drop them into a tutor-detail booking flow.
          // Take them to tutor dashboard instead (requested behavior).
          try {
            final me = SupabaseService.currentUser;
            if (me != null) {
              final myProfile = await SupabaseService.client
                  .from('profiles')
                  .select('user_type')
                  .eq('id', me.id)
                  .maybeSingle();
              final myUserType = myProfile?['user_type'] as String?;
              if (myUserType == 'tutor') {
                LogService.debug(
                  '🔗 [DEEP_LINK] Auth user is tutor; routing to dashboard instead of tutor detail',
                );
                navService.navigateToRoute('/tutor/dashboard');
                return;
              }
            }
          } catch (e) {
            // Non-blocking; fall back to tutor detail navigation below.
            LogService.debug(
              '🔗 [DEEP_LINK] Could not resolve user_type (non-blocking): $e',
            );
          }

          // Fetch tutor data and navigate to tutor detail screen
          try {
            final tutor = await TutorService.fetchTutorById(tutorId);
            if (tutor != null) {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => TutorDetailScreen(tutor: tutor),
                ),
              );
            } else {
              LogService.warning('🔗 [DEEP_LINK] Tutor not found: $tutorId');
              // Navigate to find tutors if tutor not found
              navService.navigateToRoute('/find-tutors');
            }
          } catch (e) {
            LogService.error('🔗 [DEEP_LINK] Error loading tutor: $e');
            navService.navigateToRoute('/find-tutors');
          }
        } else {
          // Queue for later
          navService.queueDeepLink(uri);
        }
        return;
      }
    }

    // Handle optional group class join deep links: /join/class/{token}
    if (path.startsWith('/join/class/')) {
      if (!AppConfig.enableGroupClasses) {
        LogService.debug('🔗 [DEEP_LINK] Group classes disabled by feature flag');
        return;
      }
      final token = path.replaceFirst('/join/class/', '').trim().split('/').first;
      if (token.isEmpty) return;

      final navService = NavigationService();
      final isAuthenticated = SupabaseService.isAuthenticated;
      if (!isAuthenticated) {
        if (navService.isReady) {
          await navService.navigateToRoute('/auth-method-selection');
        } else {
          navService.queueDeepLink(Uri(path: '/auth-method-selection'));
        }
        return;
      }

      try {
        final result = await GroupClassApiService.resolveJoinToken(token);
        final allowed = result['allowed'] == true;
        final sessionId = result['sessionId']?.toString();
        final role = result['role']?.toString() ?? 'learner';

        if (allowed && sessionId != null && sessionId.isNotEmpty) {
          if (mounted) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => AgoraVideoSessionScreen(
                  sessionId: sessionId,
                  userRole: role == 'tutor' ? 'tutor' : 'learner',
                ),
              ),
            );
          }
          return;
        }

        if (navService.isReady) {
          await navService.navigateToRoute('/find-tutors');
        } else {
          navService.queueDeepLink(Uri.parse('/find-tutors'));
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Class link validated, but join is unavailable right now. Open Group Classes to enroll.',
              ),
            ),
          );
        }
        if (mounted && AppConfig.enableGroupClasses) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const GroupClassesDiscoveryScreen(),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Unable to use class link: $e')),
          );
          if (AppConfig.enableGroupClasses) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const GroupClassesDiscoveryScreen(),
              ),
            );
          }
        }
      }
      return;
    }

    // List of protected routes that require authentication
    // These routes should redirect to email login if user is not authenticated
    final protectedRoutes = [
      '/tutor/profile/edit',
      '/tutor/profile',
      '/tutor/dashboard',
      '/tutor/onboarding',
      '/tutor', // Only /tutor (without ID) is protected
      '/student',
      '/parent',
      '/bookings',
      '/payments',
      '/sessions',
    ];

    // Check if this is a Google OAuth callback
    // Web:   https://app.prepskul.com/?code=...&provider=google
    // Mobile: prepskul://email-login?code=... (PKCE flow, no provider param)
    final token = params['token'];
    // Same redirect host (`prepskul://email-login`) is used for Google OAuth, email verification,
    // and recovery; only treat as Google when the link is not another flow.
    final isGoogleOAuthCallback =
        code != null &&
        type != 'recovery' &&
        type != 'signup' &&
        type != 'email' &&
        (provider == 'google' ||
            uri.host == 'email-login' ||
            path.contains('email-login'));

    // Handle Google OAuth callback (first-time vs returning)
    if (isGoogleOAuthCallback) {
      LogService.debug('🔐 [DEEP_LINK] Google OAuth callback detected');

      try {
        // Exchange PKCE code for a session on both web and mobile. Relying only on
        // supabase_flutter's implicit deeplink handling leaves currentUser null here, which
        // caused fall-through to navigateToRoute('/email-login') for prepskul://email-login.
        try {
          await SupabaseService.client.auth.exchangeCodeForSession(code);
          LogService.success(
            '✅ [DEEP_LINK] Google OAuth code exchanged for session (${kIsWeb ? 'web' : 'mobile'}).',
          );
        } catch (e) {
          // Second exchange can fail if another handler already consumed the code; keep going.
          LogService.debug(
            '🔐 [DEEP_LINK] exchangeCodeForSession (may be duplicate): $e',
          );
        }

        // Ensure Supabase currentUser is populated (async persistence can lag slightly)
        var user = SupabaseService.currentUser;
        if (user == null) {
          LogService.debug(
            '🔐 [DEEP_LINK] Supabase currentUser is null after exchange, waiting...',
          );
          for (int i = 0; i < 8; i++) {
            await Future.delayed(const Duration(milliseconds: 120));
            user = SupabaseService.currentUser;
            if (user != null) {
              LogService.debug(
                '🔐 [DEEP_LINK] Supabase currentUser available after wait (attempt ${i + 1})',
              );
              break;
            }
          }
        }

        // Route directly using the single source of truth to avoid auth-screen
        // flash and duplicate profile lookups during OAuth return.
        if (user != null) {
          final navService = NavigationService();
          if (navService.isReady) {
            final routeResult = await navService.determineInitialRoute();
            LogService.debug(
              '🔐 [DEEP_LINK] Google OAuth resolved route: ${routeResult.route}',
            );
            await navService.navigateToRoute(
              routeResult.route,
              arguments: routeResult.arguments,
              replace: true,
            );
          }
          AuthService.isGoogleSignInInProgress = false;
          return;
        }

        // Session never became available — do not fall through to navigateToRoute(path)
        // (path is /email-login which wrongly sent users to the email sign-in screen).
        LogService.error(
          '❌ [DEEP_LINK] Google OAuth: no session after code exchange; returning to auth',
        );
        AuthService.isGoogleSignInInProgress = false;
        final navService = NavigationService();
        if (navService.isReady) {
          await navService.navigateToRoute(
            '/auth-method-selection',
            replace: true,
          );
        } else {
          navService.queueDeepLink(Uri.parse('/auth-method-selection'));
        }
        return;
      } catch (e) {
        LogService.error(
          '❌ [DEEP_LINK] Error handling Google OAuth callback: $e',
        );
        // On error, redirect to auth method selection
        AuthService.isGoogleSignInInProgress = false;
        final navService = NavigationService();
        if (navService.isReady) {
          await navService.navigateToRoute(
            '/auth-method-selection',
            replace: true,
          );
        } else {
          navService.queueDeepLink(Uri.parse('/auth-method-selection'));
        }
        return;
      }
    }

    // Check if this is a password reset (recovery) link from email (mobile deep link).
    // Only treat as recovery when we have an explicit signal: type=recovery or path contains reset/recovery.
    // Do NOT infer recovery from email-login host + missing type - that could be signup verification.
    if (code != null &&
        (type == 'recovery' ||
            path.contains('reset') ||
            path.contains('recovery'))) {
      LogService.debug(
        '🔑 [DEEP_LINK] Password reset (recovery) link detected',
      );
      try {
        _pendingPasswordRecoverySignIn = true;
        await SupabaseService.client.auth.exchangeCodeForSession(code);
        LogService.success(
          '✅ [DEEP_LINK] Password reset code verified! Navigating to reset screen.',
        );
        final navService = NavigationService();
        if (navService.isReady) {
          await navService.navigateToRoute(
            '/reset-password',
            arguments: {'isEmailRecovery': true},
            replace: true,
          );
        } else {
          navService.queueDeepLink(
            Uri(
              path: '/reset-password',
              queryParameters: {'isEmailRecovery': 'true'},
            ),
          );
        }
        return;
      } catch (e) {
        _pendingPasswordRecoverySignIn = false;
        LogService.error(
          '❌ [DEEP_LINK] Error handling password reset link: $e',
        );
        // If user is already authenticated (e.g. they just completed reset, or hot restart
        // replayed a stale deep link), ignore - don't show error or navigate.
        if (SupabaseService.isAuthenticated) {
          LogService.debug(
            '🔑 [DEEP_LINK] User already logged in - ignoring stale reset link',
          );
          return;
        }
        // User was signing up (waiting for verification) - don't send to forgot-password
        final prefs = await SharedPreferences.getInstance();
        final pendingSignupEmail = prefs.getString('signup_email');
        final targetRoute = pendingSignupEmail != null
            ? '/email-confirmation'
            : '/forgot-password-email';
        final targetArgs = pendingSignupEmail != null
            ? {
                'linkExpired': true,
                'email': pendingSignupEmail,
                'fullName': prefs.getString('signup_full_name') ?? 'User',
                'userRole': prefs.getString('signup_user_role') ?? 'student',
              }
            : {'linkExpired': true};
        final navService = NavigationService();
        if (navService.isReady) {
          await navService.navigateToRoute(
            targetRoute,
            arguments: targetArgs,
            replace: true,
          );
          // No snackbar - target screen shows link-expired banner
        } else {
          navService.queueDeepLink(
            Uri(
              path: targetRoute,
              queryParameters: targetArgs.map(
                (k, v) => MapEntry(k, v.toString()),
              ),
            ),
          );
        }
        return;
      }
    }

    // Check if this is an email verification link from Supabase
    // Supabase verification links: https://[project].supabase.co/auth/v1/verify?token=...&type=signup
    // OR: https://app.prepskul.com/?code=...&type=signup (redirected from Supabase)
    if ((code != null || token != null) &&
        type != null &&
        (type == 'signup' || type == 'email') &&
        type != 'recovery') {
      LogService.debug('📧 [DEEP_LINK] Email verification link detected');

      try {
        // If we have a code, exchange it for a session (web redirect from Supabase)
        if (code != null) {
          LogService.debug('📧 [DEEP_LINK] Exchanging code for session...');

          // Check if user is already on email confirmation screen
          // If so, let that screen handle the navigation via its auth state listener
          final navService = NavigationService();
          final currentRoute = navService.currentRoute;
          final isOnEmailConfirmationScreen =
              currentRoute == '/email-confirmation' ||
              currentRoute?.contains('email-confirmation') == true;

          if (isOnEmailConfirmationScreen) {
            LogService.debug(
              '📧 [DEEP_LINK] User is on email confirmation screen - letting screen handle navigation',
            );
            // Just exchange the code - the email confirmation screen's listener will handle navigation
            await SupabaseService.client.auth.exchangeCodeForSession(code);
            LogService.success(
              '✅ [DEEP_LINK] Email confirmation code verified! Screen will handle navigation.',
            );
            return; // Exit early, email confirmation screen will navigate
          }

          // User is not on email confirmation screen - handle it here
          await SupabaseService.client.auth.exchangeCodeForSession(code);
          LogService.success(
            '✅ [DEEP_LINK] Email confirmation code verified! Session created.',
          );

          // Handle email confirmation and navigate to appropriate screen
          Future.microtask(() => handleEmailConfirmation());
          return; // Exit early, navigation handled by _handleEmailConfirmation
        } else if (token != null) {
          // For mobile deep links with token, we need to verify it differently
          // Store token and let the email confirmation screen handle it
          LogService.debug('📧 [DEEP_LINK] Token-based verification detected');
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('email_verification_token', token);

          // Navigate to email confirmation screen which will handle verification
          final navService = NavigationService();
          if (navService.isReady) {
            // Get user email from stored signup data or try to get from auth
            final storedEmail = prefs.getString('signup_email');
            final user = SupabaseService.currentUser;
            final email = storedEmail ?? user?.email ?? '';

            if (email.isNotEmpty && mounted) {
              Navigator.of(context).pushReplacementNamed(
                '/email-confirmation',
                arguments: {
                  'email': email,
                  'fullName': prefs.getString('signup_full_name') ?? 'User',
                  'userRole': prefs.getString('signup_user_role') ?? 'student',
                },
              );
            } else {
              // No email found, redirect to email login
              await navService.navigateToRoute('/email-login', replace: true);
            }
          } else {
            navService.queueDeepLink(Uri.parse('/email-confirmation'));
          }
          return;
        }
      } catch (e) {
        LogService.error(
          '❌ [DEEP_LINK] Error verifying email confirmation: $e',
        );
        // On error, redirect to email login with error message
        final navService = NavigationService();
        if (navService.isReady) {
          await navService.navigateToRoute('/email-login', replace: true);
        } else {
          navService.queueDeepLink(Uri.parse('/email-login'));
        }
        return;
      }
    }

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
      LogService.debug(
        '🔒 [DEEP_LINK] Protected route requires authentication, redirecting to email login',
      );
      LogService.debug('🔒 [DEEP_LINK] Intended destination: $path');

      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('pending_deep_link', path);
        LogService.success('[DEEP_LINK] Stored pending deep link: $path');
      } catch (e) {
        LogService.warning('[DEEP_LINK] Error storing pending deep link: $e');
      }

      // Queue navigation to email login (will process when app is ready)
      final navService = NavigationService();
      if (navService.isReady) {
        // App is ready, redirect to email login immediately
        navService.navigateToRoute('/email-login', replace: true);
      } else {
        // Queue email login navigation
        navService.queueDeepLink(Uri.parse('/email-login'));
        LogService.debug(
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
      LogService.debug(
        '📥 [DEEP_LINK] Deep link queued, will process when app is ready',
      );
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
      LogService.warning('Provider not available (module loading issue): $e');
      LogService.info(
        'App will continue without Provider - using default locale',
      );
      // Get locale - make resilient to LanguageService module loading failures
      Locale defaultLocale;
      try {
        defaultLocale = LanguageService.currentLocale;
      } catch (e) {
        // Fallback to English if LanguageService module fails to load
        LogService.warning(
          'LanguageService.currentLocale not available, using English',
        );
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
      LogService.debug(
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
      LogService.warning('AppTheme not available, using default theme');
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
          case '/role-selection':
            return _createFadeRoute(() => const RoleSelectionScreen());
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
          case '/forgot-password-email':
            final forgotArgs = settings.arguments as Map<String, dynamic>?;
            final linkExpired = forgotArgs?['linkExpired'];
            return _createFadeRoute(
              () => ForgotPasswordEmailScreen(
                linkExpiredError: linkExpired == true || linkExpired == 'true',
              ),
            );
          case '/email-confirmation':
            final confirmArgs = settings.arguments as Map<String, dynamic>?;
            final linkExpired = confirmArgs?['linkExpired'];
            return _createFadeRoute(
              () => EmailConfirmationScreen(
                email: confirmArgs?['email'] as String? ?? '',
                fullName: confirmArgs?['fullName'] as String? ?? 'User',
                userRole: confirmArgs?['userRole'] as String? ?? 'student',
                linkExpiredError: linkExpired == true || linkExpired == 'true',
              ),
            );
          case '/skulmate/upload':
            // SkulMate controlled by AppConfig feature flag
            if (AppConfig.enableSkulMate) {
              return _createFadeRoute(() => SkulMateUploadScreen());
            } else {
              return _createFadeRoute(
                () => Scaffold(
                  appBar: AppBar(title: const Text('SkulMate')),
                  body: const Center(
                    child: Text(
                      'SkulMate is currently unavailable. Please check back later.',
                    ),
                  ),
                ),
              );
            }
          case '/skulmate/library':
            // SkulMate controlled by AppConfig feature flag
            if (AppConfig.enableSkulMate) {
              final args = settings.arguments as Map<String, dynamic>?;
              return _createFadeRoute(
                () => GameLibraryScreen(
                  initialTab: (args?['initialTab'] as int?) ?? 1,
                  initialGameId: args?['initialGameId'] as String?,
                ),
              );
            } else {
              return _createFadeRoute(
                () => Scaffold(
                  appBar: AppBar(title: const Text('SkulMate')),
                  body: const Center(
                    child: Text(
                      'SkulMate is currently unavailable. Please check back later.',
                    ),
                  ),
                ),
              );
            }
          case '/skulmate/leaderboard':
            if (AppConfig.enableSkulMate) {
              return _createFadeRoute(() => const LeaderboardScreen());
            } else {
              return _createFadeRoute(
                () => Scaffold(
                  appBar: AppBar(title: const Text('SkulMate')),
                  body: const Center(
                    child: Text(
                      'SkulMate is currently unavailable. Please check back later.',
                    ),
                  ),
                ),
              );
            }
          case '/skulmate/character-selection':
            // SkulMate controlled by AppConfig feature flag
            if (AppConfig.enableSkulMate) {
              final args = settings.arguments as Map<String, dynamic>?;
              return _createFadeRoute(
                () => CharacterSelectionScreen(
                  isFirstTime: args?['isFirstTime'] ?? false,
                ),
              );
            } else {
              return _createFadeRoute(
                () => Scaffold(
                  appBar: AppBar(title: const Text('SkulMate')),
                  body: const Center(
                    child: Text(
                      'SkulMate is currently unavailable. Please check back later.',
                    ),
                  ),
                ),
              );
            }
        }

        if (settings.name != null &&
            settings.name!.startsWith('/skulmate/game/')) {
          if (!AppConfig.enableSkulMate) {
            return _createFadeRoute(
              () => Scaffold(
                appBar: AppBar(title: const Text('SkulMate')),
                body: const Center(
                  child: Text(
                    'SkulMate is currently unavailable. Please check back later.',
                  ),
                ),
              ),
            );
          }
          final gameId = settings.name!.replaceFirst('/skulmate/game/', '').trim();
          return _createFadeRoute(
            () => GameLibraryScreen(
              initialTab: 1,
              initialGameId: gameId.isEmpty ? null : gameId,
            ),
          );
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

        if (settings.name == '/tutor-onboarding-choice') {
          return _createFadeRoute(() => const TutorOnboardingChoiceScreen());
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
        if (settings.name == '/reset-password-otp') {
          final args = settings.arguments as Map<String, dynamic>?;
          final phone = args?['phone'] ?? '';
          return _createFadeRoute(() => ResetPasswordOTPScreen(phone: phone));
        }
        if (settings.name == '/reset-password') {
          final args = settings.arguments as Map<String, dynamic>?;
          final phone = args?['phone'] ?? '';
          final isEmailRecovery =
              args?['isEmailRecovery'] == true ||
              args?['isEmailRecovery'] == 'true';
          final setNewPasswordOnly =
              args?['setNewPasswordOnly'] == true ||
              args?['setNewPasswordOnly'] == 'true';
          return _createFadeRoute(
            () => ResetPasswordScreen(
              phone: phone,
              isEmailRecovery: isEmailRecovery,
              setNewPasswordOnly: setNewPasswordOnly,
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
            builder: (context) => PaymentRouteLoader(
              paymentRequestId: paymentRequestId,
              bookingRequestId: args?['bookingRequestId'] as String?,
            ),
          );
        }
        // My Sessions route
        if (settings.name == '/my-sessions') {
          final args = settings.arguments as Map<String, dynamic>?;
          return MaterialPageRoute(
            builder: (context) => MySessionsScreen(
              initialTab: args?['initialTab'] as int?,
              sessionId: args?['sessionId'] as String?,
            ),
          );
        }
        // Session Feedback route: /sessions/{sessionId}/feedback
        if (settings.name?.startsWith('/sessions/') == true &&
            settings.name?.endsWith('/feedback') == true) {
          final pathParts = settings.name!.split('/');
          if (pathParts.length >= 3) {
            final sessionId = pathParts[2]; // /sessions/{sessionId}/feedback
            return MaterialPageRoute(
              settings: const RouteSettings(name: '/session-feedback-flow'),
              builder: (context) =>
                  SessionFeedbackFlowScreen(sessionId: sessionId),
            );
          }
        }
        // Tutor detail route: /tutor/{tutorId}
        if (settings.name?.startsWith('/tutor/') == true &&
            settings.name != '/tutor' &&
            !settings.name!.startsWith('/tutor/profile') &&
            !settings.name!.startsWith('/tutor/dashboard') &&
            !settings.name!.startsWith('/tutor/onboarding')) {
          final tutorId = settings.name!.replaceFirst('/tutor/', '');
          if (tutorId.isNotEmpty) {
            // Auth-first behaviour for web deep links:
            // - If user is not authenticated, remember the tutorId and send them to auth.
            // - After successful signup/login, NavigationService / OTP flows
            //   will read the pending tutor link and open the correct profile.
            final isAuthenticated = SupabaseService.isAuthenticated;
            if (!isAuthenticated) {
              // Fire-and-forget; we don't need to await inside onGenerateRoute.
              NavigationService.storePendingTutorLink(tutorId);
              return MaterialPageRoute(
                settings: const RouteSettings(name: '/auth-method-selection'),
                builder: (context) => const AuthMethodSelectionScreen(),
              );
            }

            final args = settings.arguments as Map<String, dynamic>?;
            return MaterialPageRoute(
              builder: (context) => FutureBuilder<Map<String, dynamic>?>(
                future: TutorService.fetchTutorById(tutorId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Scaffold(
                      appBar: AppBar(title: const Text('Loading Tutor...')),
                      body: const Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (snapshot.hasError || snapshot.data == null) {
                    return Scaffold(
                      appBar: AppBar(title: const Text('Tutor Not Found')),
                      body: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('Tutor profile not found.'),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () => Navigator.pushReplacementNamed(
                                context,
                                '/find-tutors',
                              ),
                              child: const Text('Browse Tutors'),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  return TutorDetailScreen(tutor: snapshot.data!);
                },
              ),
            );
          }
        }
        // Fallback: prevent navigator empty stack crash - always return a valid route
        return PageRouteBuilder<void>(
          settings: settings,
          pageBuilder: (context, animation, secondaryAnimation) =>
              const AuthMethodSelectionScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) =>
              FadeTransition(opacity: animation, child: child),
          transitionDuration: const Duration(milliseconds: 150),
        );
      },
      onUnknownRoute: (settings) {
        // Safety: prevent _history.isNotEmpty crash if a named route is not found
        return PageRouteBuilder<void>(
          settings: settings,
          pageBuilder: (context, animation, secondaryAnimation) =>
              const AuthMethodSelectionScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) =>
              FadeTransition(opacity: animation, child: child),
          transitionDuration: const Duration(milliseconds: 150),
        );
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

  bool _hasPendingAuthCallback() {
    if (!kIsWeb) return false;
    final uri = Uri.base;
    final type = uri.queryParameters['type'];
    final code = uri.queryParameters['code'];
    final hasAuthError =
        uri.queryParameters['error'] != null ||
        uri.queryParameters['error_code'] != null;
    final path = uri.path.toLowerCase();
    final isEmailLoginPath = path.contains('email-login');
    final isAuthType = type == 'signup' || type == 'email' || type == 'recovery';
    return (code != null && isAuthType) || hasAuthError || isEmailLoginPath;
  }

  @override
  void initState() {
    super.initState();
    // On web, keep HTML splash visible until Flutter content is ready
    // This prevents white screen flash
    if (kIsWeb) {
      // Wait for Flutter to render InitialLoadingScreen before removing HTML splash
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Give Flutter time to render the InitialLoadingScreen
        Future.delayed(const Duration(milliseconds: 100), () {
          // Now start navigation
          _initializeAndNavigate();
        });
      });
    } else {
      // Mobile: Start navigation immediately
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _initializeAndNavigate();
      });
    }

    // Safety timeout - ensure loading screen is replaced after maximum 5 seconds
    Future.delayed(const Duration(seconds: 5), () async {
      if (mounted && !_navigationComplete) {
        if (_hasPendingAuthCallback()) {
          LogService.info(
            '[INIT_LOAD] Auth callback detected - skipping timeout fallback',
          );
          return;
        }
        LogService.warning(
          '[INIT_LOAD] Navigation timeout - forcing fallback navigation',
        );
        final navService = NavigationService();
        if (navService.isReady) {
          // CRITICAL: Check authentication before redirecting to auth screen
          // During hot restart, authenticated users should not be sent to auth screen
          final isAuthenticated = SupabaseService.isAuthenticated;
          final currentUser = SupabaseService.currentUser;

          if (isAuthenticated && currentUser != null) {
            // User is authenticated - try to determine proper route
            try {
              final result = await navService.determineInitialRoute();
              if (mounted) {
                await _navigateInstant(result.route, result.arguments);
                // Splash removal is now handled inside _navigateInstant for web
                setState(() {
                  _navigationComplete = true;
                });
              }
            } catch (e) {
              LogService.warning(
                '[INIT_LOAD] Error in timeout fallback for authenticated user: $e',
              );
              // If we can't determine route, try dashboard as last resort
              if (mounted) {
                await _navigateInstant('/dashboard', null);
                // Splash removal is now handled inside _navigateInstant for web
                setState(() {
                  _navigationComplete = true;
                });
              }
            }
          } else {
            // User is not authenticated - redirect to auth screen
            await _navigateInstant('/auth-method-selection', null);
            // Splash removal is now handled inside _navigateInstant for web
            setState(() {
              _navigationComplete = true;
            });
          }
        }
      }
    });
  }

  Future<void> _initializeAndNavigate() async {
    if (_isNavigating || _navigationComplete) return;
    _isNavigating = true;

    // If app was opened via tutor link, store pending tutor BEFORE determining route
    // so we land on tutor detail after auth with no transitional UI.
    try {
      // On web, getInitialLink() often returns null when user opens the URL directly (no link event).
      // Always read Uri.base on web so tutor links work when landing on e.g. /tutor/xyz or #/tutor/xyz.
      if (kIsWeb) {
        final baseUri = Uri.base;
        String path = baseUri.path;
        if (path == '/' && baseUri.fragment.isNotEmpty) {
          final f = baseUri.fragment;
          path = f.startsWith('/') ? f : '/$f';
        }
        if (path.startsWith('/tutor/') &&
            path != '/tutor' &&
            !path.startsWith('/tutor/profile') &&
            !path.startsWith('/tutor/dashboard') &&
            !path.startsWith('/tutor/onboarding')) {
          final tutorId = path
              .replaceFirst('/tutor/', '')
              .trim()
              .split('/')
              .first;
          if (tutorId.isNotEmpty) {
            await NavigationService.storePendingTutorLink(tutorId);
            LogService.debug(
              '[INIT_LOAD] [WEB] Stored pending tutor from Uri.base: $tutorId',
            );
          }
        }
        final tutorFromQuery = baseUri.queryParameters['tutor'];
        if (tutorFromQuery != null && tutorFromQuery.trim().isNotEmpty) {
          await NavigationService.storePendingTutorLink(tutorFromQuery.trim());
          LogService.debug(
            '[INIT_LOAD] [WEB] Stored pending tutor from query: ${tutorFromQuery.trim()}',
          );
        }
      }
      final appLinks = AppLinks();
      final initialUri = await appLinks
          .getInitialLink()
          .timeout(
            const Duration(seconds: 2),
            onTimeout: () => null,
          );
      if (initialUri != null) {
        final path = initialUri.path;
        if (path.startsWith('/tutor/') &&
            path != '/tutor' &&
            !path.startsWith('/tutor/profile') &&
            !path.startsWith('/tutor/dashboard') &&
            !path.startsWith('/tutor/onboarding')) {
          final tutorId = path.replaceFirst('/tutor/', '').trim();
          if (tutorId.isNotEmpty) {
            await NavigationService.storePendingTutorLink(tutorId);
            LogService.debug(
              '[INIT_LOAD] Stored pending tutor from initial link: $tutorId',
            );
          }
        }
        final tutorFromQuery = initialUri.queryParameters['tutor'];
        if (tutorFromQuery != null && tutorFromQuery.trim().isNotEmpty) {
          await NavigationService.storePendingTutorLink(tutorFromQuery.trim());
          LogService.debug(
            '[INIT_LOAD] Stored pending tutor from query: ${tutorFromQuery.trim()}',
          );
        }
      }
    } catch (e) {
      LogService.debug(
        '[INIT_LOAD] Could not parse initial link (non-blocking): $e',
      );
    }

    // Check connectivity FIRST - if offline, use cached data immediately
    bool isOffline = false;
    try {
      final connectivity = ConnectivityService();
      await connectivity.initialize();
      final isOnline = await connectivity.checkConnectivity();
      isOffline = !isOnline;

      if (isOffline) {
        LogService.info(
          '[INIT_LOAD] Offline detected - checking cached auth session',
        );

        // Check for cached auth session
        final prefs = await SharedPreferences.getInstance();
        final cachedIsLoggedIn = prefs.getBool('is_logged_in') ?? false;

        if (cachedIsLoggedIn && SupabaseService.isAuthenticated) {
          LogService.info(
            '[INIT_LOAD] Cached session found - navigating offline without waiting on network',
          );
          var waitedMs = 0;
          while (waitedMs < 4000 && mounted) {
            final navService = NavigationService();
            if (navService.isReady) {
              try {
                final result = await navService.determineInitialRoute();
                if (mounted) {
                  await _navigateInstant(result.route, result.arguments);
                  setState(() {
                    _navigationComplete = true;
                  });
                }
                return;
              } catch (e) {
                LogService.warning(
                  '[INIT_LOAD] Offline fast-path navigation failed: $e',
                );
                break;
              }
            }
            await Future.delayed(const Duration(milliseconds: 50));
            waitedMs += 50;
          }
        } else if (!cachedIsLoggedIn) {
          if (_hasPendingAuthCallback()) {
            LogService.info(
              '[INIT_LOAD] Auth callback detected - skipping offline auth fallback',
            );
            return;
          }
          // No cached session - can't proceed offline, show auth immediately
          LogService.info(
            '[INIT_LOAD] No cached session - showing auth screen immediately',
          );
          if (mounted) {
            await _navigateInstant('/auth-method-selection', null);
            setState(() {
              _navigationComplete = true;
            });
          }
          return;
        }
      }
    } catch (e) {
      LogService.warning(
        '[INIT_LOAD] Error checking connectivity: $e - proceeding normally',
      );
    }

    // CRITICAL: Check authentication synchronously FIRST to avoid login screen flash
    // This prevents showing login screen for authenticated users during hot restart
    final isAuthenticated = SupabaseService.isAuthenticated;
    final currentUser = SupabaseService.currentUser;

    if (isAuthenticated && currentUser != null) {
      // If URL contains 'code', it might be an email verification in progress
      // We should wait a bit longer for Supabase to process the code and potentially
      // confirm the email, which might trigger navigation handlers in SplashScreen
      if (kIsWeb && Uri.base.queryParameters.containsKey('code')) {
        LogService.debug(
          '🔗 [INIT_LOAD] Auth code detected in URL - waiting for processing',
        );
        // Give Supabase auth listener time to fire
        await Future.delayed(const Duration(seconds: 2));
      }

      LogService.debug(
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
            NavigationResult result;
            try {
              result = await navService
                  .determineInitialRoute()
                  .timeout(const Duration(seconds: 12));
            } on TimeoutException {
              LogService.warning(
                '[INIT_LOAD] determineInitialRoute timed out — using emergency prefs route',
              );
              result = await navService.emergencyDashboardFromPrefs();
            }
            LogService.success('[INIT_LOAD] Determined route: ${result.route}');
            // Navigate to determined route (could be onboarding, survey, or dashboard)
            if (mounted) {
              await _navigateInstant(result.route, result.arguments);
              // Splash removal is now handled inside _navigateInstant for web
              // No need to remove here - it will be removed after screen renders
            }
            if (mounted) {
              setState(() {
                _navigationComplete = true;
              });
            }
            return; // Exit early - navigation complete
          } catch (e) {
            LogService.warning(
              '[INIT_LOAD] Error navigating authenticated user: $e',
            );
            // On error, check onboarding status explicitly before fallback
            final prefs = await SharedPreferences.getInstance();
            final hasCompletedOnboarding =
                prefs.getBool('onboarding_completed') ?? false;
            if (!hasCompletedOnboarding) {
              // Redirect to onboarding if not completed
              if (mounted) {
                final navService = NavigationService();
                if (navService.isReady) {
                  await _navigateInstant('/onboarding', null);
                  // Splash removal is now handled inside _navigateInstant for web
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
                if (mounted) {
                  await _navigateInstant(result.route, result.arguments);
                  // Splash removal is now handled inside _navigateInstant for web
                }
                return;
              } catch (e2) {
                LogService.warning(
                  '[INIT_LOAD] Error in fallback navigation: $e2',
                );
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
      LogService.debug(
        '🔗 [INIT_LOAD] Auth code detected (unauthenticated) - waiting for processing',
      );
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
        if (!SupabaseService.isAuthenticated && _hasPendingAuthCallback()) {
          LogService.info(
            '[INIT_LOAD] Pending auth callback on startup - waiting for deep link handler',
          );
          return;
        }
        final navService = NavigationService();
        if (navService.isReady) {
          final result = await navService.determineInitialRoute();

          // Navigate instantly without animation to prevent white flash
          // This ensures the loading screen persists until the new screen is fully rendered
          if (mounted) {
            await _navigateInstant(result.route, result.arguments);
            // Splash removal is now handled inside _navigateInstant for web
            // No need to remove here - it will be removed after screen renders
          }

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
            if (mounted) {
              await _navigateInstant(result.route, result.arguments);
              // Splash removal is now handled inside _navigateInstant for web
              // No need to remove here - it will be removed after screen renders
            }
          }
        }
      } catch (e) {
        LogService.warning('[INIT_LOAD] Error during navigation: $e');
        // Fallback: navigate to auth screen only if not authenticated
        if (mounted && !SupabaseService.isAuthenticated) {
          final navService = NavigationService();
          if (navService.isReady) {
            await _navigateInstant('/auth-method-selection', null);
            // Splash removal is now handled inside _navigateInstant for web
            // No need to remove here - it will be removed after screen renders
          }
        }
      }
    }
  }

  /// Navigate instantly to route without animation
  /// This prevents the "white flash" issue during the initial transition.
  /// For /tutor/xxx we preload tutor in background and show detail in one shot.
  Future<void> _navigateInstant(String routeName, Object? arguments) async {
    if (!mounted) return;

    // /tutor/xxx — keep loading screen, preload tutor, then show detail (no "Loading Tutor…" step)
    final isTutorDetailRoute =
        routeName.startsWith('/tutor/') &&
        routeName != '/tutor' &&
        !routeName.startsWith('/tutor/profile') &&
        !routeName.startsWith('/tutor/dashboard') &&
        !routeName.startsWith('/tutor/onboarding');
    if (isTutorDetailRoute) {
      final rawId = arguments is Map ? (arguments as Map)['tutorId'] : null;
      final tutorId =
          (rawId?.toString() ?? routeName.replaceFirst('/tutor/', '').trim())
              .trim();
      if (tutorId.isNotEmpty) {
        try {
          final tutor = await TutorService.fetchTutorById(tutorId);
          if (!mounted) return;
          if (tutor != null) {
            final page = TutorDetailScreen(tutor: tutor);
            Navigator.of(context).pushReplacement(
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) => page,
                transitionDuration: Duration.zero,
                reverseTransitionDuration: Duration.zero,
              ),
            );
            if (mounted) {
              setState(() => _navigationComplete = true);
              if (kIsWeb) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  Future.delayed(const Duration(milliseconds: 300), () {
                    if (mounted) WebSplashService.removeSplash();
                  });
                });
              }
            }
            return;
          }
        } catch (e) {
          LogService.warning('[NAV] Tutor preload failed for $tutorId: $e');
        }
        if (!mounted) return;
        // Fallback: tutor not found or error — go to student nav
        final navService = NavigationService();
        if (navService.isReady) {
          navService.navigateToRoute(
            '/student-nav',
            arguments: null,
            replace: true,
          );
          if (mounted) {
            setState(() => _navigationComplete = true);
            if (kIsWeb) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                Future.delayed(const Duration(milliseconds: 300), () {
                  if (mounted) WebSplashService.removeSplash();
                });
              });
            }
          }
        }
        return;
      }
    }

    try {
      Widget? page;

      // Map route names to widgets directly
      switch (routeName) {
        case '/onboarding':
          page = const SimpleOnboardingScreen();
          break;
        case '/auth-method-selection':
          page = const AuthMethodSelectionScreen();
          break;
        case '/tutor-nav':
          final args = arguments as Map<String, dynamic>?;
          page = MainNavigation(
            userRole: 'tutor',
            initialTab: args?['initialTab'],
          );
          break;
        case '/student-nav':
          final args = arguments as Map<String, dynamic>?;
          page = MainNavigation(
            userRole: 'student',
            initialTab: args?['initialTab'],
          );
          break;
        case '/parent-nav':
          final args = arguments as Map<String, dynamic>?;
          page = MainNavigation(
            userRole: 'parent',
            initialTab: args?['initialTab'],
          );
          break;
        case '/profile-setup':
          final args = arguments as Map<String, dynamic>?;
          final userRole = args?['userRole'] ?? 'student';
          if (userRole == 'tutor') {
            page = const TutorOnboardingScreen(basicInfo: {});
          } else if (userRole == 'parent') {
            page = const ParentSurvey();
          } else {
            page = const StudentSurvey();
          }
          break;
        case '/tutor-onboarding':
          final args = arguments as Map<String, dynamic>?;
          page = TutorOnboardingScreen(basicInfo: args ?? {});
          break;
        default:
          // Fallback to standard navigation if route not explicitly handled
          // Use NavigationService but ensure we mark navigation as complete
          final navService = NavigationService();
          if (navService.isReady) {
            navService.navigateToRoute(
              routeName,
              arguments: arguments as Map<String, dynamic>?,
              replace: true,
            );
            if (mounted) {
              setState(() {
                _navigationComplete = true;
              });
              // On web, wait briefly for the new screen to render before removing HTML splash
              if (kIsWeb) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  Future.delayed(
                    Duration(milliseconds: kIsWeb ? 600 : 300),
                    () {
                      if (mounted) {
                        WebSplashService.removeSplash();
                      }
                    },
                  );
                });
              }
            }
            return; // Exit early since NavigationService handled it
          } else {
            // NavigationService not ready, fallback to auth screen
            page = const AuthMethodSelectionScreen();
          }
          if (page == null) return;
      }

      if (page != null) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => page!,
            transitionDuration: Duration.zero, // Instant transition
            reverseTransitionDuration: Duration.zero,
          ),
        );
        // Mark navigation as complete
        if (mounted) {
          setState(() {
            _navigationComplete = true;
          });
          // On web, wait for the new screen to paint before removing HTML splash (prevents blank auth screen)
          if (kIsWeb) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              Future.delayed(const Duration(milliseconds: 600), () {
                if (mounted) {
                  WebSplashService.removeSplash();
                }
              });
            });
          }
        }
      } else {
        // If page is null, fallback to auth screen
        LogService.warning(
          '[INIT_LOAD] Page is null for route $routeName, falling back to auth',
        );
        if (mounted) {
          Navigator.of(context).pushReplacement(
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) =>
                  const AuthMethodSelectionScreen(),
              transitionDuration: Duration.zero,
              reverseTransitionDuration: Duration.zero,
            ),
          );
          // On web, wait for the new screen to paint (prevents blank auth screen)
          if (kIsWeb) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              Future.delayed(Duration(milliseconds: kIsWeb ? 600 : 300), () {
                if (mounted) {
                  WebSplashService.removeSplash();
                }
              });
            });
          }
          setState(() {
            _navigationComplete = true;
          });
        }
      }
    } catch (e) {
      LogService.error('[INIT_LOAD] Error in _navigateInstant: $e');
      // Fallback navigation on error
      if (mounted) {
        try {
          Navigator.of(context).pushReplacement(
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) =>
                  const AuthMethodSelectionScreen(),
              transitionDuration: Duration.zero,
              reverseTransitionDuration: Duration.zero,
            ),
          );
          // On web, wait for the new screen to paint (prevents blank auth screen)
          if (kIsWeb) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              Future.delayed(Duration(milliseconds: kIsWeb ? 600 : 300), () {
                if (mounted) {
                  WebSplashService.removeSplash();
                }
              });
            });
          }
          setState(() {
            _navigationComplete = true;
          });
        } catch (e2) {
          LogService.error('[INIT_LOAD] Error in fallback navigation: $e2');
          // Still try to remove splash even if navigation fails (stable refresh)
          if (mounted) {
            Future.delayed(Duration(milliseconds: kIsWeb ? 400 : 100), () {
              if (mounted) {
                WebSplashService.removeSplash();
              }
            });
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // If navigation is complete, show empty container (shouldn't happen as navigation replaces this)
    // Otherwise show loading screen
    if (_navigationComplete) {
      return const SizedBox.shrink();
    }
    // Match HTML splash (white bg) - no switch to deep blue, consistent loading experience.
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
    LogService.debug('🚀 [SPLASH] Initializing...');

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
      LogService.debug(
        '✅ [SPLASH] Navigation handled by password reset or email confirmation',
      );
      return;
    }

    // Reduced delay - start navigation immediately
    // Navigation checks are fast, no need to wait
    await Future.delayed(const Duration(milliseconds: 100));

    // Navigate using NavigationService (single source of truth)
    LogService.debug('🚀 [SPLASH] Starting navigation check...');
    if (mounted) {
      _navigateToNextScreen();
    }

    // Safety timeout - force navigation after 500ms if nothing happened
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        final navService = NavigationService();
        if (navService.isReady && navService.currentRoute == null) {
          LogService.debug(
            '⏰ [SPLASH] TIMEOUT - Forcing navigation to auth screen',
          );
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
        LogService.warning('[SPLASH] NavigationService not ready yet');
        return;
      }

      // Use NavigationService to determine route (single source of truth)
      final result = await navService.determineInitialRoute();

      LogService.debug('🚀 [SPLASH] Determined route: ${result.route}');

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
      LogService.error('[SPLASH] Navigation error: $e');
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
            LogService.debug('Warning: Could not preload $imagePath: $e');
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

      LogService.debug('🔐 Auth state changed: $event');

      // Skip email confirmation when this sign-in is from password recovery.
      // The deep link handler navigates to reset-password instead.
      if (event == AuthChangeEvent.passwordRecovery ||
          _pendingPasswordRecoverySignIn) {
        _pendingPasswordRecoverySignIn = false;
        LogService.debug(
          '🔐 Ignoring signedIn - password recovery flow, reset-password screen will be shown',
        );
        return;
      }

      // Handle email confirmation (new signup / magic link)
      if (event == AuthChangeEvent.signedIn &&
          session != null &&
          session.user.emailConfirmedAt != null) {
        LogService.success('Email confirmed via deep link!');
        Future.microtask(() => handleEmailConfirmation());
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

      LogService.debug('[DEBUG] Checking URL for email confirmation callback');
      LogService.debug('[DEBUG] URL: ${uri.toString()}');
      LogService.debug('[DEBUG] Code: $code, Type: $type');

      if (code != null && type != 'recovery') {
        // This is likely an email confirmation code
        LogService.debug('📧 [DEBUG] Email confirmation code detected!');

        try {
          // Exchange code for session
          await SupabaseService.client.auth.exchangeCodeForSession(code);
          LogService.success(
            'Email confirmation code verified! Session created.',
          );

          // The auth state change listener will handle navigation
          // But we can also directly navigate here if needed
          Future.microtask(() => handleEmailConfirmation());
          return true; // Indicate that navigation was handled
        } catch (e) {
          LogService.error('Error verifying email confirmation code: $e');
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
      LogService.warning('Error checking email confirmation callback: $e');
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

      LogService.debug('[DEBUG] Checking URL for password reset callback');
      LogService.debug('[DEBUG] URL: ${uri.toString()}');
      LogService.debug('[DEBUG] Code: $code, Type: $type');

      if (code != null) {
        // Check if it's a password reset (recovery type)
        if (type == 'recovery' ||
            uri.path.contains('reset') ||
            uri.path.contains('recovery')) {
          LogService.debug('🔑 [DEBUG] Password reset code detected!');

          try {
            // Exchange code for session - Supabase validates the recovery code
            // For password reset, Supabase creates a temporary session when code is valid
            await SupabaseService.client.auth.exchangeCodeForSession(code);

            LogService.success(
              'Password reset code verified! Session created.',
            );
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
            LogService.error('Error verifying password reset code: $e');
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
      LogService.warning('Error checking password reset callback: $e');
    }
    return false; // No password reset detected, continue normal navigation
  }

  // Use global handleEmailConfirmation helper function
  Future<void> _handleEmailConfirmation() async {
    await handleEmailConfirmation();
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
            Center(child: _SplashContent(tagline: l10n?.tagline ?? "")),

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
