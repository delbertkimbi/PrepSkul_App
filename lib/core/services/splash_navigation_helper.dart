// Temporary helper to debug navigation
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:prepskul/core/services/auth_service.dart';
import 'package:prepskul/core/services/supabase_service.dart';

class SplashNavigationHelper {
  static Future<String> determineRoute() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hasCompletedOnboarding =
          prefs.getBool('onboarding_completed') ?? false;
      final isLoggedIn = await AuthService.isLoggedIn();
      final hasSupabaseSession = SupabaseService.isAuthenticated;
      final hasCompletedSurvey = await AuthService.isSurveyCompleted();
      final userRole = await AuthService.getUserRole();

      print('📊 [NAV] State: onboarding=$hasCompletedOnboarding, loggedIn=$isLoggedIn, supabase=$hasSupabaseSession, survey=$hasCompletedSurvey, role=$userRole');

      if (!hasCompletedOnboarding) {
        return '/onboarding';
      } else if (!isLoggedIn && !hasSupabaseSession) {
        return '/auth-method-selection';
      } else if (!hasCompletedSurvey && userRole != null) {
        return '/profile-setup';
      } else if (isLoggedIn && hasCompletedSurvey && userRole != null) {
        if (userRole == 'tutor') {
          return '/tutor-nav';
        } else if (userRole == 'parent') {
          return '/parent-nav';
        } else {
          return '/student-nav';
        }
      } else {
        return '/auth-method-selection';
      }
    } catch (e) {
      print('❌ [NAV] Error determining route: $e');
      return '/auth-method-selection';
    }
  }

  static Future<bool> tryRestoreSession() async {
    try {
      final hasSupabaseSession = SupabaseService.isAuthenticated;
      final isLoggedIn = await AuthService.isLoggedIn();

      if (hasSupabaseSession && !isLoggedIn) {
        final user = SupabaseService.currentUser;
        if (user != null) {
          final profile = await SupabaseService.client
              .from('profiles')
              .select()
              .eq('id', user.id)
              .maybeSingle();

          if (profile != null) {
            await AuthService.saveSession(
              userId: user.id,
              userRole: profile['user_type'] ?? 'learner',
              phone: profile['phone_number'] ?? '',
              fullName: profile['full_name'] ?? '',
              surveyCompleted: profile['survey_completed'] ?? false,
            );
            return true;
          }
        }
      }
      return false;
    } catch (e) {
      print('⚠️ [NAV] Error restoring session: $e');
      return false;
    }
  }
}

