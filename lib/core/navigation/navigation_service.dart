/// Navigation Service
///
/// Centralized navigation logic with route determination, guards, and deep link queue
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:prepskul/core/services/auth_service.dart';
import 'package:prepskul/core/services/supabase_service.dart';
import 'package:prepskul/core/services/tutor_onboarding_progress_service.dart';
import 'package:prepskul/core/navigation/route_guards.dart';
import 'package:prepskul/core/navigation/navigation_state.dart';
import 'package:prepskul/core/navigation/navigation_analytics.dart';

class NavigationService {
  static final NavigationService _instance = NavigationService._internal();
  factory NavigationService() => _instance;
  NavigationService._internal();

  final List<Uri> _pendingDeepLinks = [];
  bool _isNavigationReady = false;
  GlobalKey<NavigatorState>? _navigatorKey;
  final NavigationState _state = NavigationState();
  final NavigationAnalytics _analytics = NavigationAnalytics();

  /// Get current route from navigation state
  String? get currentRoute => _state.currentRoute;

  /// Initialize navigation service with navigator key
  void initialize(GlobalKey<NavigatorState> navigatorKey) {
    _navigatorKey = navigatorKey;
    _isNavigationReady = true;
    _analytics.initialize();
    print('✅ [NAV_SERVICE] Navigation service initialized');
  }

  /// Check if navigation is ready
  bool get isReady => _isNavigationReady && _navigatorKey != null;

  /// Get navigator key
  GlobalKey<NavigatorState>? get navigatorKey => _navigatorKey;

  /// Get current context
  BuildContext? get context => _navigatorKey?.currentContext;

  /// Determine initial route based on user state
  /// This is the single source of truth for route determination
  Future<NavigationResult> determineInitialRoute() async {
    try {
      print('🔍 [NAV_SERVICE] Determining initial route...');

      // PRIORITY 1: Check Supabase session (most reliable)
      final user = SupabaseService.currentUser;
      if (user != null) {
        print('✅ [NAV_SERVICE] User authenticated via Supabase');
        try {
          final profile = await SupabaseService.client
              .from('profiles')
              .select('user_type, survey_completed, full_name, phone_number')
              .eq('id', user.id)
              .maybeSingle();

          if (profile != null) {
            // Sync local session
            final prefs = await SharedPreferences.getInstance();
            final localIsLoggedIn = prefs.getBool('is_logged_in') ?? false;

            if (!localIsLoggedIn) {
              await AuthService.saveSession(
                userId: user.id,
                userRole: profile['user_type'] ?? 'student',
                phone: profile['phone_number'] ?? '',
                fullName: profile['full_name'] ?? '',
                surveyCompleted: profile['survey_completed'] ?? false,
              );
              print('✅ [NAV_SERVICE] Session synced to local storage');
            }

            final userRole = profile['user_type'] ?? 'student';
            final hasCompletedSurvey = profile['survey_completed'] ?? false;
            final hasCompletedOnboarding =
                prefs.getBool('onboarding_completed') ?? false;

            if (!hasCompletedOnboarding) {
              return NavigationResult('/onboarding');
            } else if (!hasCompletedSurvey) {
              // If profile exists but survey not completed, verify if we have user_type
              // If user_type is missing (rare edge case), force profile setup
              // Note: Our previous check profile['user_type'] ?? 'student' defaults to student
              // which is fine as profile-setup will allow them to proceed
              return NavigationResult(
                '/profile-setup',
                arguments: {'userRole': userRole},
              );
            } else {
              final result = _getDashboardRoute(userRole);
              _analytics.trackRouteDetermined(
                result.route,
                metadata: {'user_role': userRole, 'source': 'supabase'},
              );
              return result;
            }
          }
        } catch (e) {
          print('⚠️ [NAV_SERVICE] Error fetching profile: $e');
          _analytics.trackNavigationError(
            '/',
            'Error fetching profile: $e',
            metadata: {'step': 'route_determination'},
          );
        }
      }

      // PRIORITY 2: Check local storage
      final prefs = await SharedPreferences.getInstance();
      final hasCompletedOnboarding =
          prefs.getBool('onboarding_completed') ?? false;
      final isLoggedIn = await AuthService.isLoggedIn();
      final hasSupabaseSession = SupabaseService.isAuthenticated;
      final hasCompletedSurvey = await AuthService.isSurveyCompleted();
      final userRole = await AuthService.getUserRole();

      print(
        '📊 [NAV_SERVICE] State: onboarding=$hasCompletedOnboarding, loggedIn=$isLoggedIn, supabase=$hasSupabaseSession, survey=$hasCompletedSurvey, role=$userRole',
      );

      NavigationResult result;
      if (!hasCompletedOnboarding) {
        result = NavigationResult('/onboarding');
      } else if (!isLoggedIn && !hasSupabaseSession) {
        result = NavigationResult('/auth-method-selection');
      } else if (!hasCompletedSurvey && userRole != null) {
        // Check if user has seen the survey intro screen
        final surveyIntroSeen = prefs.getBool('survey_intro_seen') ?? false;
        
        // For students and parents, show intro screen first (if not seen)
        // For tutors, check onboarding status
        if (userRole == 'tutor') {
          // Check if onboarding was skipped or is incomplete
          try {
            final userId = await AuthService.getCurrentUser();
            final userIdStr = userId['userId'] as String?;
            if (userIdStr != null) {
              final onboardingSkipped = await TutorOnboardingProgressService.isOnboardingSkipped(userIdStr);
              final onboardingComplete = await TutorOnboardingProgressService.isOnboardingComplete(userIdStr);
              
              if (onboardingSkipped || !onboardingComplete) {
                // Check if it's a new tutor (no progress at all)
                final progress = await TutorOnboardingProgressService.loadProgress(userIdStr);
                if (progress == null && !onboardingSkipped) {
                  // New tutor - show choice screen
                  result = NavigationResult('/tutor-onboarding-choice');
                } else {
                  // Resume onboarding
                  result = NavigationResult(
                    '/profile-setup',
                    arguments: {'userRole': userRole},
                  );
                }
              } else {
                // Onboarding complete, go to dashboard
                result = _getDashboardRoute(userRole);
              }
            } else {
              // Fallback to profile setup
              result = NavigationResult(
                '/profile-setup',
                arguments: {'userRole': userRole},
              );
            }
          } catch (e) {
            print('⚠️ Error checking onboarding status: $e');
            // Fallback to profile setup
            result = NavigationResult(
              '/profile-setup',
              arguments: {'userRole': userRole},
            );
          }
        } else if ((userRole == 'student' || userRole == 'learner' || userRole == 'parent') && !surveyIntroSeen) {
          result = NavigationResult(
            '/survey-intro',
            arguments: {'userType': userRole},
          );
        } else {
          result = NavigationResult(
            '/profile-setup',
            arguments: {'userRole': userRole},
          );
        }
      } else if (isLoggedIn && hasCompletedSurvey && userRole != null) {
        result = _getDashboardRoute(userRole);
      } else {
        result = NavigationResult('/auth-method-selection');
      }

      _analytics.trackRouteDetermined(
        result.route,
        metadata: {
          'user_role': userRole,
          'source': 'local_storage',
          'onboarding_completed': hasCompletedOnboarding,
          'is_logged_in': isLoggedIn,
          'survey_completed': hasCompletedSurvey,
        },
      );

      return result;
    } catch (e) {
      print('❌ [NAV_SERVICE] Error determining route: $e');
      _analytics.trackNavigationError(
        '/',
        'Error determining route: $e',
        stackTrace: e.toString(),
      );
      return NavigationResult('/auth-method-selection');
    }
  }

  /// Get dashboard route based on user role
  NavigationResult _getDashboardRoute(String userRole) {
    if (userRole == 'tutor') {
      return NavigationResult('/tutor-nav');
    } else if (userRole == 'parent') {
      return NavigationResult('/parent-nav');
    } else {
      return NavigationResult('/student-nav');
    }
  }

  /// Navigate to route with guards and state management
  Future<void> navigateToRoute(
    String route, {
    Map<String, dynamic>? arguments,
    bool replace = false,
    bool clearStack = false,
  }) async {
    if (!isReady) {
      print('⚠️ [NAV_SERVICE] Navigation not ready, queueing route: $route');
      // Queue for later if not ready
      _pendingDeepLinks.add(
        Uri(
          path: route,
          queryParameters: {
            ...?arguments?.map((k, v) => MapEntry(k, v.toString())),
          },
        ),
      );
      return;
    }

    if (!_state.canNavigate()) {
      print('⚠️ [NAV_SERVICE] Navigation debounced or in progress');
      return;
    }

    // Check route guards
    final guardResult = await RouteGuard.canNavigateTo(route);
    if (!guardResult.allowed) {
      print(
        '🚫 [NAV_SERVICE] Route guard failed, redirecting to: ${guardResult.redirectRoute}',
      );
      _analytics.trackRouteGuardBlocked(
        route,
        guardResult.redirectRoute!,
        metadata: arguments,
      );
      // Recursively navigate to redirect route
      await navigateToRoute(
        guardResult.redirectRoute!,
        arguments: guardResult.arguments,
        replace: true,
      );
      return;
    }

    final context = this.context;
    if (context == null) {
      // This is expected during app initialization - deep links are queued
      // Only log as debug, not error, to reduce noise
      print(
        'ℹ️ [NAV_SERVICE] Navigator not ready yet (deep link will be queued)',
      );
      return;
    }

    _state.startNavigation();
    _state.setCurrentRoute(route);

    try {
      print('🚀 [NAV_SERVICE] Navigating to: $route');
      final startTime = DateTime.now();

      if (clearStack) {
        Navigator.of(context).pushNamedAndRemoveUntil(
          route,
          (route) => false,
          arguments: arguments,
        );
      } else if (replace) {
        // Use pushReplacementNamed with a custom transition
        // The MaterialApp routes will handle the widget building
        // We'll use the default transition which should be smooth
        Navigator.of(context).pushReplacementNamed(route, arguments: arguments);
        // Wait for next frame to ensure route is built before continuing
        await Future.delayed(const Duration(milliseconds: 16));
      } else {
        Navigator.of(context).pushNamed(route, arguments: arguments);
      }

      final loadTime = DateTime.now().difference(startTime);
      _state.completeNavigation();

      _analytics.trackRouteNavigated(
        route,
        metadata: {
          ...?arguments,
          'load_time_ms': loadTime.inMilliseconds,
          'replace': replace,
          'clear_stack': clearStack,
        },
      );
    } catch (e, stackTrace) {
      _state.completeNavigation();
      print('❌ [NAV_SERVICE] Navigation error: $e');
      _analytics.trackNavigationError(
        route,
        e.toString(),
        stackTrace: stackTrace.toString(),
        metadata: arguments,
      );
      rethrow;
    }
  }

  /// Queue deep link for processing after app is ready
  void queueDeepLink(Uri uri) {
    _pendingDeepLinks.add(uri);
    _analytics.trackDeepLinkQueued(
      uri.path,
      metadata: {
        'query_params': uri.queryParameters,
        'queue_size': _pendingDeepLinks.length,
      },
    );
    print('📥 [NAV_SERVICE] Deep link queued: ${uri.path}');
  }

  /// Process all pending deep links
  Future<void> processPendingDeepLinks() async {
    if (!isReady) {
      print('⚠️ [NAV_SERVICE] Navigation not ready, cannot process deep links');
      return;
    }

    if (_pendingDeepLinks.isEmpty) {
      return;
    }

    print(
      '📤 [NAV_SERVICE] Processing ${_pendingDeepLinks.length} pending deep links',
    );

    // Process in order, but only the last one if multiple
    final lastLink = _pendingDeepLinks.last;
    _pendingDeepLinks.clear();

    final path = lastLink.path;
    final queryParams = lastLink.queryParameters;

    // Convert query params to arguments
    final arguments = <String, dynamic>{};
    queryParams.forEach((key, value) {
      arguments[key] = value;
    });

    // Navigate to deep link route
    _analytics.trackDeepLinkProcessed(
      path,
      metadata: {
        'query_params': queryParams,
        'queue_size_before': _pendingDeepLinks.length,
      },
    );
    await navigateToRoute(
      path,
      arguments: arguments.isEmpty ? null : arguments,
    );
  }

  /// Navigate to dashboard based on user role
  Future<void> navigateToDashboard({bool clearStack = true}) async {
    final userRole = await AuthService.getUserRole();
    if (userRole == null) {
      await navigateToRoute('/auth-method-selection', clearStack: clearStack);
      return;
    }

    final route = _getDashboardRoute(userRole).route;
    await navigateToRoute(route, clearStack: clearStack);
  }

  /// Navigate back
  void navigateBack() {
    final context = this.context;
    if (context != null && Navigator.of(context).canPop()) {
      final fromRoute = _state.currentRoute;
      Navigator.of(context).pop();
      final toRoute = _state.getLastRoute() ?? '/';
      _state.setCurrentRoute(toRoute);
      _analytics.trackBackNavigation(fromRoute ?? '/', toRoute);
    }
  }

  /// Check if can navigate back
  bool canNavigateBack() {
    final context = this.context;
    return context != null && Navigator.of(context).canPop();
  }

  /// Get navigation analytics
  NavigationAnalytics get analytics => _analytics;
}

/// Navigation result containing route and arguments
class NavigationResult {
  final String route;
  final Map<String, dynamic>? arguments;

  NavigationResult(this.route, {this.arguments});
}
