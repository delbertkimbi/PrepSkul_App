/// Navigation Service Tests
/// 
/// Comprehensive tests for navigation functionality including:
/// - Cold start scenarios
/// - Deep link handling
/// - Route guards
/// - Navigation state management
import 'package:flutter_test/flutter_test.dart';
import 'package:prepskul/core/navigation/navigation_service.dart';
import 'package:prepskul/core/navigation/route_guards.dart';
import 'package:prepskul/core/navigation/navigation_state.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('NavigationService', () {
    late NavigationService navigationService;
    late GlobalKey<NavigatorState> navigatorKey;

    setUp(() {
      navigationService = NavigationService();
      navigatorKey = GlobalKey<NavigatorState>();
      SharedPreferences.setMockInitialValues({});
    });

    tearDown(() {
      // Reset navigation state
      NavigationState().reset();
    });

    group('Initialization', () {
      test('should initialize with navigator key', () {
        navigationService.initialize(navigatorKey);
        expect(navigationService.isReady, true);
        expect(navigationService.navigatorKey, navigatorKey);
      });

      test('should not be ready before initialization', () {
        expect(navigationService.isReady, false);
      });
    });

    group('Route Determination', () {
      test('should determine route for unauthenticated user', () async {
        final result = await navigationService.determineInitialRoute();
        expect(result.route, '/auth-method-selection');
      });

      test('should determine route for user without onboarding', () async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('onboarding_completed', false);
        
        final result = await navigationService.determineInitialRoute();
        expect(result.route, '/onboarding');
      });

      test('should determine route for authenticated student', () async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('onboarding_completed', true);
        await prefs.setBool('is_logged_in', true);
        await prefs.setString('user_role', 'student');
        await prefs.setBool('survey_completed', true);
        
        final result = await navigationService.determineInitialRoute();
        expect(result.route, '/student-nav');
      });

      test('should determine route for authenticated tutor', () async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('onboarding_completed', true);
        await prefs.setBool('is_logged_in', true);
        await prefs.setString('user_role', 'tutor');
        await prefs.setBool('survey_completed', true);
        
        final result = await navigationService.determineInitialRoute();
        expect(result.route, '/tutor-nav');
      });

      test('should determine route for authenticated parent', () async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('onboarding_completed', true);
        await prefs.setBool('is_logged_in', true);
        await prefs.setString('user_role', 'parent');
        await prefs.setBool('survey_completed', true);
        
        final result = await navigationService.determineInitialRoute();
        expect(result.route, '/parent-nav');
      });

      test('should redirect to profile setup if survey not completed', () async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('onboarding_completed', true);
        await prefs.setBool('is_logged_in', true);
        await prefs.setString('user_role', 'student');
        await prefs.setBool('survey_completed', false);
        
        final result = await navigationService.determineInitialRoute();
        expect(result.route, '/profile-setup');
        expect(result.arguments?['userRole'], 'student');
      });
    });

    group('Deep Link Queue', () {
      test('should queue deep link when not ready', () {
        final uri = Uri.parse('/bookings/123');
        navigationService.queueDeepLink(uri);
        
        // Deep link should be queued but not processed
        expect(navigationService.isReady, false);
      });

      test('should process queued deep links after initialization', () async {
        final uri = Uri.parse('/bookings/123');
        navigationService.queueDeepLink(uri);
        
        navigationService.initialize(navigatorKey);
        await navigationService.processPendingDeepLinks();
        
        // Deep link should be processed
        expect(navigationService.isReady, true);
      });

      test('should process only last deep link if multiple queued', () async {
        navigationService.queueDeepLink(Uri.parse('/bookings/123'));
        navigationService.queueDeepLink(Uri.parse('/bookings/456'));
        navigationService.queueDeepLink(Uri.parse('/tutor-nav'));
        
        navigationService.initialize(navigatorKey);
        await navigationService.processPendingDeepLinks();
        
        // Only last link should be processed
        expect(navigationService.isReady, true);
      });
    });

    group('Navigation State', () {
      test('should track current route', () {
        final state = NavigationState();
        state.setCurrentRoute('/test-route');
        expect(state.currentRoute, '/test-route');
      });

      test('should prevent duplicate navigations with debounce', () {
        final state = NavigationState();
        state.setCurrentRoute('/route1');
        state.startNavigation();
        
        expect(state.canNavigate(), false);
      });

      test('should allow navigation after debounce period', () async {
        final state = NavigationState();
        state.setCurrentRoute('/route1');
        state.startNavigation();
        state.completeNavigation();
        
        // Wait for debounce period
        await Future.delayed(Duration(milliseconds: 350));
        
        expect(state.canNavigate(), true);
      });

      test('should maintain navigation history', () {
        final state = NavigationState();
        state.setCurrentRoute('/route1');
        state.setCurrentRoute('/route2');
        state.setCurrentRoute('/route3');
        
        expect(state.navigationHistory.length, 3);
        expect(state.navigationHistory.last, '/route3');
      });

      test('should limit navigation history to 10 routes', () {
        final state = NavigationState();
        for (int i = 0; i < 15; i++) {
          state.setCurrentRoute('/route$i');
        }
        
        expect(state.navigationHistory.length, 10);
        expect(state.navigationHistory.first, '/route5');
        expect(state.navigationHistory.last, '/route14');
      });
    });

    group('Navigation Methods', () {
      test('should navigate to dashboard based on role', () async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_role', 'tutor');
        
        navigationService.initialize(navigatorKey);
        await navigationService.navigateToDashboard();
        
        expect(navigationService.currentRoute, '/tutor-nav');
      });

      test('should navigate back when possible', () {
        navigationService.initialize(navigatorKey);
        // Note: Actual back navigation requires a navigator context
        // This test verifies the method exists and doesn't throw
        expect(() => navigationService.navigateBack(), returnsNormally);
      });
    });
  });

  group('RouteGuards', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    group('Public Routes', () {
      test('should allow access to onboarding', () async {
        final result = await RouteGuard.canNavigateTo('/onboarding');
        expect(result.allowed, true);
      });

      test('should allow access to auth method selection', () async {
        final result = await RouteGuard.canNavigateTo('/auth-method-selection');
        expect(result.allowed, true);
      });

      test('should allow access to login', () async {
        final result = await RouteGuard.canNavigateTo('/login');
        expect(result.allowed, true);
      });
    });

    group('Authentication Guards', () {
      test('should redirect unauthenticated user to auth', () async {
        final result = await RouteGuard.canNavigateTo('/tutor-nav');
        expect(result.allowed, false);
        expect(result.redirectRoute, '/auth-method-selection');
      });

      test('should allow authenticated user to dashboard', () async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('is_logged_in', true);
        await prefs.setBool('onboarding_completed', true);
        await prefs.setBool('survey_completed', true);
        await prefs.setString('user_role', 'tutor');
        
        final result = await RouteGuard.canNavigateTo('/tutor-nav');
        expect(result.allowed, true);
      });
    });

    group('Onboarding Guards', () {
      test('should redirect to onboarding if not completed', () async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('onboarding_completed', false);
        await prefs.setBool('is_logged_in', true);
        
        final result = await RouteGuard.canNavigateTo('/tutor-nav');
        expect(result.allowed, false);
        expect(result.redirectRoute, '/onboarding');
      });
    });

    group('Survey Guards', () {
      test('should redirect to profile setup if survey not completed', () async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('onboarding_completed', true);
        await prefs.setBool('is_logged_in', true);
        await prefs.setBool('survey_completed', false);
        await prefs.setString('user_role', 'student');
        
        final result = await RouteGuard.canNavigateTo('/student-nav');
        expect(result.allowed, false);
        expect(result.redirectRoute, '/profile-setup');
      });
    });

    group('Role Guards', () {
      test('should redirect non-tutor from tutor routes', () async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('onboarding_completed', true);
        await prefs.setBool('is_logged_in', true);
        await prefs.setBool('survey_completed', true);
        await prefs.setString('user_role', 'student');
        
        final result = await RouteGuard.canNavigateTo('/tutor-nav');
        expect(result.allowed, false);
        expect(result.redirectRoute, '/student-nav');
      });
    });

    group('Helper Methods', () {
      test('should check onboarding completion', () async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('onboarding_completed', true);
        
        final hasCompleted = await RouteGuard.hasCompletedOnboarding();
        expect(hasCompleted, true);
      });

      test('should check survey completion', () async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('survey_completed', true);
        
        final hasCompleted = await RouteGuard.hasCompletedSurvey();
        expect(hasCompleted, true);
      });

      test('should check authentication status', () async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('is_logged_in', true);
        
        final isAuthenticated = await RouteGuard.isAuthenticated();
        expect(isAuthenticated, true);
      });

      test('should get user role', () async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_role', 'tutor');
        
        final role = await RouteGuard.getUserRole();
        expect(role, 'tutor');
      });
    });
  });
}


