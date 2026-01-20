// Temporary helper to debug navigation
import 'package:flutter/material.dart';
import 'package:prepskul/core/services/log_service.dart';
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

      LogService.info('[NAV] State: onboarding=$hasCompletedOnboarding, loggedIn=$isLoggedIn, supabase=$hasSupabaseSession, survey=$hasCompletedSurvey, role=$userRole');

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
      LogService.error('[NAV] Error determining route: $e');
      return '/auth-method-selection';
    }
  }

  static Future<bool> tryRestoreSession() async {
    try {
      final hasSupabaseSession = SupabaseService.isAuthenticated;
      
      // CRITICAL: Always verify against Supabase's actual current user
      // This prevents account switching when sessions change
      if (hasSupabaseSession) {
        final user = SupabaseService.currentUser;
        if (user != null) {
          // Verify if local session matches Supabase session
          final localUserId = await AuthService.getUserId();
          
          // If user IDs don't match, sync with Supabase (this handles account switching)
          if (localUserId != user.id) {
            LogService.warning(
              '[NAV] User ID mismatch detected during session restore! '
              'Local: $localUserId, Supabase: ${user.id}. Syncing...'
            );
          }
          
          // Always sync with Supabase's current session to prevent mismatches
          final profile = await SupabaseService.client
              .from('profiles')
              .select()
              .eq('id', user.id)
              .maybeSingle();

          if (profile != null) {
            await AuthService.saveSession(
              userId: user.id,
              userRole: profile['user_type'] ?? 'learner',
              phone: profile['phone_number'] ?? user.phone ?? '',
              fullName: profile['full_name'] ?? user.email ?? 'User',
              surveyCompleted: profile['survey_completed'] ?? false,
            );
            LogService.success('[NAV] Session restored and synced with Supabase');
            return true;
          } else {
            // Profile not found - use Supabase user data
            await AuthService.saveSession(
              userId: user.id,
              userRole: user.userMetadata?['user_type'] ?? 'student',
              phone: user.phone ?? '',
              fullName: user.userMetadata?['full_name'] ?? user.email ?? 'User',
              surveyCompleted: false,
            );
            LogService.warning('[NAV] Profile not found, using Supabase user data');
            return true;
          }
        }
      } else {
        // No Supabase session - clear local session if it exists
        final isLoggedIn = await AuthService.isLoggedIn();
        if (isLoggedIn) {
          LogService.warning('[NAV] No Supabase session but local session exists - clearing local session');
          await AuthService.logout();
        }
      }
      return false;
    } catch (e) {
      LogService.warning('[NAV] Error restoring session: $e');
      return false;
    }
  }
}
