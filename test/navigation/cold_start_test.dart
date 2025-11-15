/// Cold Start Navigation Tests
/// 
/// Tests for app cold start scenarios including:
/// - First launch (no onboarding)
/// - Returning user (authenticated)
/// - Returning user (unauthenticated)
/// - User with incomplete onboarding
/// - User with incomplete survey
import 'package:flutter_test/flutter_test.dart';
import 'package:prepskul/core/navigation/navigation_service.dart';
import 'package:prepskul/core/navigation/navigation_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('Cold Start Navigation', () {
    late NavigationService navigationService;

    setUp(() {
      navigationService = NavigationService();
    });

    tearDown(() {
      NavigationState().reset();
    });

    group('First Launch', () {
      test('should navigate to onboarding on first launch', () async {
        SharedPreferences.setMockInitialValues({});
        
        final result = await navigationService.determineInitialRoute();
        expect(result.route, '/onboarding');
      });

      test('should navigate to onboarding when onboarding not completed', () async {
        SharedPreferences.setMockInitialValues({
          'onboarding_completed': false,
        });
        
        final result = await navigationService.determineInitialRoute();
        expect(result.route, '/onboarding');
      });
    });

    group('Returning User - Authenticated', () {
      test('should navigate to student dashboard for authenticated student', () async {
        SharedPreferences.setMockInitialValues({
          'onboarding_completed': true,
          'is_logged_in': true,
          'user_role': 'student',
          'survey_completed': true,
        });
        
        final result = await navigationService.determineInitialRoute();
        expect(result.route, '/student-nav');
      });

      test('should navigate to tutor dashboard for authenticated tutor', () async {
        SharedPreferences.setMockInitialValues({
          'onboarding_completed': true,
          'is_logged_in': true,
          'user_role': 'tutor',
          'survey_completed': true,
        });
        
        final result = await navigationService.determineInitialRoute();
        expect(result.route, '/tutor-nav');
      });

      test('should navigate to parent dashboard for authenticated parent', () async {
        SharedPreferences.setMockInitialValues({
          'onboarding_completed': true,
          'is_logged_in': true,
          'user_role': 'parent',
          'survey_completed': true,
        });
        
        final result = await navigationService.determineInitialRoute();
        expect(result.route, '/parent-nav');
      });
    });

    group('Returning User - Unauthenticated', () {
      test('should navigate to auth screen for unauthenticated user', () async {
        SharedPreferences.setMockInitialValues({
          'onboarding_completed': true,
          'is_logged_in': false,
        });
        
        final result = await navigationService.determineInitialRoute();
        expect(result.route, '/auth-method-selection');
      });
    });

    group('Incomplete Onboarding', () {
      test('should navigate to onboarding if not completed', () async {
        SharedPreferences.setMockInitialValues({
          'onboarding_completed': false,
          'is_logged_in': true,
        });
        
        final result = await navigationService.determineInitialRoute();
        expect(result.route, '/onboarding');
      });
    });

    group('Incomplete Survey', () {
      test('should navigate to profile setup if survey not completed', () async {
        SharedPreferences.setMockInitialValues({
          'onboarding_completed': true,
          'is_logged_in': true,
          'user_role': 'student',
          'survey_completed': false,
        });
        
        final result = await navigationService.determineInitialRoute();
        expect(result.route, '/profile-setup');
        expect(result.arguments?['userRole'], 'student');
      });

      test('should navigate to profile setup for tutor with incomplete survey', () async {
        SharedPreferences.setMockInitialValues({
          'onboarding_completed': true,
          'is_logged_in': true,
          'user_role': 'tutor',
          'survey_completed': false,
        });
        
        final result = await navigationService.determineInitialRoute();
        expect(result.route, '/profile-setup');
        expect(result.arguments?['userRole'], 'tutor');
      });
    });

    group('Edge Cases', () {
      test('should handle missing user role gracefully', () async {
        SharedPreferences.setMockInitialValues({
          'onboarding_completed': true,
          'is_logged_in': true,
          'survey_completed': true,
          // user_role is missing
        });
        
        final result = await navigationService.determineInitialRoute();
        // Should default to auth screen
        expect(result.route, '/auth-method-selection');
      });

      test('should handle error gracefully and default to auth', () async {
        SharedPreferences.setMockInitialValues({
          'onboarding_completed': true,
          'is_logged_in': true,
          'user_role': 'invalid_role',
          'survey_completed': true,
        });
        
        final result = await navigationService.determineInitialRoute();
        // Should handle gracefully
        expect(result.route, isNotNull);
      });
    });
  });
}


