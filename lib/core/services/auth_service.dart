import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

/// Comprehensive authentication service for PrepSkul
class AuthService {
  // Session Management Keys
  static const String _keyIsLoggedIn = 'is_logged_in';
  static const String _keyUserRole = 'user_role';
  static const String _keyUserId = 'user_id';
  static const String _keyUserPhone = 'user_phone';
  static const String _keyUserName = 'user_name';
  static const String _keySurveyCompleted = 'survey_completed';
  static const String _keyRememberMe = 'remember_me';

  /// Check if user is currently logged in
  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    final isLogged = prefs.getBool(_keyIsLoggedIn) ?? false;
    final hasSupabaseSession = SupabaseService.isAuthenticated;

    // If local says logged in but no Supabase session, clear local
    if (isLogged && !hasSupabaseSession) {
      await logout();
      return false;
    }

    return isLogged && hasSupabaseSession;
  }

  /// Get current user's role
  static Future<String?> getUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUserRole);
  }

  /// Get current user's ID
  static Future<String?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUserId);
  }

  /// Get current user's phone
  static Future<String?> getUserPhone() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUserPhone);
  }

  /// Get current user's name
  static Future<String?> getUserName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUserName);
  }

  /// Check if survey is completed
  static Future<bool> isSurveyCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keySurveyCompleted) ?? false;
  }

  /// Check if "Remember Me" is enabled
  static Future<bool> shouldRememberUser() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyRememberMe) ?? false;
  }

  /// Save login session
  static Future<void> saveSession({
    required String userId,
    required String userRole,
    required String phone,
    required String fullName,
    bool surveyCompleted = false,
    bool rememberMe = true,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIsLoggedIn, true);
    await prefs.setString(_keyUserRole, userRole);
    await prefs.setString(_keyUserId, userId);
    await prefs.setString(_keyUserPhone, phone);
    await prefs.setString(_keyUserName, fullName);
    await prefs.setBool(_keySurveyCompleted, surveyCompleted);
    await prefs.setBool(_keyRememberMe, rememberMe);

    print('✅ Session saved for user: $fullName ($userRole)');
  }

  /// Update survey completion status
  static Future<void> markSurveyComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keySurveyCompleted, true);
    print('✅ Survey marked as completed');
  }

  /// Logout user (clear session and Supabase auth)
  static Future<void> logout() async {
    try {
      // Sign out from Supabase
      await SupabaseService.signOut();

      // Clear local session
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyIsLoggedIn);
      await prefs.remove(_keyUserRole);
      await prefs.remove(_keyUserId);
      await prefs.remove(_keyUserPhone);
      await prefs.remove(_keyUserName);
      await prefs.remove(_keySurveyCompleted);
      // Keep remember_me for convenience

      print('✅ User logged out successfully');
    } catch (e) {
      print('❌ Error during logout: $e');
      rethrow;
    }
  }

  /// Alias for logout (for consistency with clearSession naming)
  static Future<void> clearSession() => logout();

  /// Get current user data (from local session)
  static Future<Map<String, dynamic>> getCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'userId': prefs.getString(_keyUserId),
      'userRole': prefs.getString(_keyUserRole),
      'phone': prefs.getString(_keyUserPhone),
      'fullName': prefs.getString(_keyUserName),
      'surveyCompleted': prefs.getBool(_keySurveyCompleted) ?? false,
    };
  }

  /// Get user's full profile from database
  static Future<Map<String, dynamic>?> getUserProfile() async {
    try {
      final userId = await getUserId();
      if (userId == null) return null;

      final profiles = await SupabaseService.getData(
        table: 'profiles',
        field: 'id',
        value: userId,
      );

      if (profiles.isEmpty) return null;
      return profiles.first;
    } catch (e) {
      print('❌ Error fetching user profile: $e');
      return null;
    }
  }

  /// Send password reset OTP (for phone auth)
  static Future<void> sendPasswordResetOTP(String phone) async {
    try {
      // Format phone number
      String formattedPhone = phone;
      if (!formattedPhone.startsWith('+')) {
        if (formattedPhone.startsWith('237')) {
          formattedPhone = '+$formattedPhone';
        } else if (formattedPhone.startsWith('0')) {
          formattedPhone = '+237${formattedPhone.substring(1)}';
        } else {
          formattedPhone = '+237$formattedPhone';
        }
      }

      // Check if user exists
      final userProfile = await SupabaseService.getData(
        table: 'profiles',
        field: 'phone_number',
        value: formattedPhone,
      );

      if (userProfile.isEmpty) {
        throw Exception('No account found with this phone number');
      }

      // Send OTP
      await SupabaseService.sendPhoneOTP(formattedPhone);
      print('✅ Password reset OTP sent to: $formattedPhone');
    } catch (e) {
      print('❌ Error sending password reset OTP: $e');
      rethrow;
    }
  }

  /// Send password reset email (for email auth)
  static Future<void> sendPasswordResetEmail(String email) async {
    try {
      await SupabaseService.client.auth.resetPasswordForEmail(
        email,
        redirectTo: 'https://operating-axis-420213.web.app/reset-password',
      );
      print('✅ Password reset email sent to: $email');
    } catch (e) {
      print('❌ Error sending password reset email: $e');
      rethrow;
    }
  }

  /// Verify password reset OTP and update password
  static Future<void> resetPassword({
    required String phone,
    required String otp,
    required String newPassword,
  }) async {
    try {
      // Format phone number
      String formattedPhone = phone;
      if (!formattedPhone.startsWith('+')) {
        if (formattedPhone.startsWith('237')) {
          formattedPhone = '+$formattedPhone';
        } else if (formattedPhone.startsWith('0')) {
          formattedPhone = '+237${formattedPhone.substring(1)}';
        } else {
          formattedPhone = '+237$formattedPhone';
        }
      }

      // Verify OTP
      final response = await SupabaseService.verifyPhoneOTP(
        phone: formattedPhone,
        token: otp,
      );

      if (response.user == null) {
        throw Exception('Invalid OTP code');
      }

      // Update password in Supabase Auth
      await SupabaseService.client.auth.updateUser(
        UserAttributes(password: newPassword),
      );

      print('✅ Password reset successful');
    } catch (e) {
      print('❌ Error resetting password: $e');
      rethrow;
    }
  }

  /// Listen to auth state changes (for auto-logout on session expiry)
  static Stream<AuthState> get authStateChanges =>
      SupabaseService.authStateChanges;

  /// Initialize auth listener (call in main.dart)
  static void initAuthListener() {
    authStateChanges.listen((AuthState state) async {
      final event = state.event;

      if (event == AuthChangeEvent.signedOut) {
        // Clear local session when Supabase session expires
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_keyIsLoggedIn, false);
        print('🔒 Session expired - user signed out');
      } else if (event == AuthChangeEvent.signedIn) {
        print('✅ User signed in');
      } else if (event == AuthChangeEvent.tokenRefreshed) {
        print('🔄 Auth token refreshed');
      }
    });
  }
}
