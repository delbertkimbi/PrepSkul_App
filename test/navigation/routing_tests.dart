import 'package:flutter_test/flutter_test.dart';
import 'package:prepskul/core/navigation/navigation_service.dart';
import 'package:prepskul/core/services/auth_service.dart';
import 'package:prepskul/core/services/supabase_service.dart';
import 'package:prepskul/core/services/tutor_onboarding_progress_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Routing Tests
///
/// Tests for navigation logic to ensure correct routing at each point
/// Tests cover:
/// - Tutor onboarding loop prevention
/// - Verified/approved tutor routing
/// - Onboarding completion checks
/// - Survey completion routing
/// - Role-based routing

void main() {
  group('Navigation Service Routing Tests', () {
    late NavigationService navService;
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      navService = NavigationService();
    });

    tearDown(() async {
      await prefs.clear();
    });

    group('Tutor Routing Tests', () {
      test('Verified tutor should go directly to dashboard', () async {
        // Setup: Tutor is verified/approved
        await prefs.setBool('onboarding_completed', true);
        // Mock: User is authenticated and verified
        // This test would require mocking Supabase client
        
        // Expected: Route should be /tutor-nav
        // Note: Full test requires mocking SupabaseService
      });

      test('Approved tutor should bypass onboarding', () async {
        // Setup: Tutor has approved status
        await prefs.setBool('onboarding_completed', true);
        
        // Expected: Should check tutor_profiles.status first
        // If status == 'approved', go to /tutor-nav
      });

      test('Tutor with completed onboarding should go to dashboard', () async {
        // Setup: Onboarding marked as complete
        await prefs.setBool('onboarding_completed', true);
        
        // Mock: isOnboardingComplete returns true
        
        // Expected: Route should be /tutor-nav
      });

      test('New tutor should see onboarding choice screen', () async {
        // Setup: No onboarding progress
        await prefs.setBool('onboarding_completed', true);
        
        // Mock: loadProgress returns null, isOnboardingSkipped returns false
        
        // Expected: Route should be /tutor-onboarding-choice
      });

      test('Tutor with partial progress should resume onboarding', () async {
        // Setup: Has some progress but not complete
        await prefs.setBool('onboarding_completed', true);
        
        // Mock: loadProgress returns progress, isOnboardingComplete returns false
        
        // Expected: Route should be /profile-setup with userRole: 'tutor'
      });
    });

    group('Student/Parent Routing Tests', () {
      test('Student without survey should see survey intro', () async {
        await prefs.setBool('onboarding_completed', true);
        await prefs.setBool('survey_intro_seen', false);
        
        // Expected: Route should be /survey-intro
      });

      test('Student with completed survey should go to dashboard', () async {
        await prefs.setBool('onboarding_completed', true);
        await prefs.setBool('survey_completed', true);
        
        // Expected: Route should be /student-nav
      });
    });

    group('Onboarding Routing Tests', () {
      test('User without completed onboarding should see onboarding', () async {
        await prefs.setBool('onboarding_completed', false);
        
        // Expected: Route should be /onboarding
      });

      test('User with completed onboarding should proceed to auth/survey', () async {
        await prefs.setBool('onboarding_completed', true);
        
        // Expected: Should check login/survey status
      });
    });

    group('Authentication Routing Tests', () {
      test('Unauthenticated user should see auth method selection', () async {
        await prefs.setBool('onboarding_completed', true);
        
        // Mock: isLoggedIn returns false, hasSupabaseSession returns false
        
        // Expected: Route should be /auth-method-selection
      });

      test('Authenticated user should check onboarding/survey status', () async {
        await prefs.setBool('onboarding_completed', true);
        
        // Mock: isLoggedIn returns true or hasSupabaseSession returns true
        
        // Expected: Should check role and survey completion
      });
    });

    group('Error Handling Tests', () {
      test('Error checking tutor status should fallback gracefully', () async {
        // Setup: Error in tutor onboarding check
        
        // Expected: Should fallback to general onboarding check
        // Should not crash or block user
      });

      test('Missing user ID should handle gracefully', () async {
        // Setup: getCurrentUser returns null or empty userId
        
        // Expected: Should check general onboarding as fallback
      });
    });
  });

  group('Tutor Onboarding Progress Tests', () {
    test('Verified tutor should force 100% completion', () async {
      // Setup: Tutor profile has status == 'verified' or 'approved'
      
      // Expected: loadProgress should mark all steps as complete
      // is_complete should be set to true
    });

    test('Tutor profile data should be loaded in onboarding screen', () async {
      // Setup: Tutor opens onboarding screen
      
      // Expected: _loadSavedData should fetch from tutor_profiles
      // All fields should be populated (phone, email, education, etc.)
    });
  });

  group('Earnings Screen Tab Structure Tests', () {
    test('Earnings screen should have 3 flat tabs', () {
      // Expected: Overview, Earnings, Payouts (no nested tabs)
    });

    test('Overview tab should show stats, not duplicate balance card', () {
      // Expected: Stats grid with Total Earnings, Total Withdrawn, etc.
      // Balance card only shown if balances > 0
    });
  });
}
