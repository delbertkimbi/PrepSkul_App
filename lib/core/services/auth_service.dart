import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:async';
import 'supabase_service.dart';
import 'push_notification_service.dart';
import 'email_rate_limit_service.dart';
import 'notification_helper_service.dart';

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

  static StreamSubscription<AuthState>? _authStateSubscription;

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

    // Initialize push notifications after login
    try {
      await PushNotificationService().initialize(
        onNotificationTap: (message) {
          // Handle notification tap navigation
          final data = message?.data;
          if (data != null) {
            print('📱 Notification tapped after login: ${data.toString()}');
          } else {
            print('📱 Notification tapped after login (no data)');
          }
        },
      );
      print('✅ Push notifications initialized after login');

      // Request permission after login if onboarding is completed
      // Delay the request slightly to ensure user sees the app first
      final hasCompletedOnboarding =
          prefs.getBool('onboarding_completed') ?? false;
      if (hasCompletedOnboarding) {
        Future.delayed(const Duration(seconds: 2), () async {
          try {
            await PushNotificationService().requestPermission();
          } catch (e) {
            print(
              '⚠️ Error requesting notification permission after login: $e',
            );
          }
        });
      }
    } catch (e) {
      print('⚠️ Error initializing push notifications after login: $e');
      // Don't fail login if push notifications fail
    }
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
      // Deactivate push notification tokens
      try {
        await PushNotificationService().deactivateAllTokens();
      } catch (e) {
        print('⚠️ Error deactivating push notification tokens: $e');
      }

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
        throw Exception('We couldn\'t find an account with this phone number.');
      }

      // Send OTP
      await SupabaseService.sendPhoneOTP(formattedPhone);
      print('✅ Password reset OTP sent to: $formattedPhone');
    } catch (e) {
      print('❌ Error sending password reset OTP: $e');
      rethrow;
    }
  }

  /// Send password reset email (for email auth) with rate limiting and retry
  static Future<void> sendPasswordResetEmail(String email) async {
    // Normalize email for rate limiting
    final normalizedEmail = email.toLowerCase().trim();

    // If we're still in cooldown, treat as success (email already sent)
    if (await EmailRateLimitService.isInCooldown(normalizedEmail) ||
        !await EmailRateLimitService.canSendEmail(normalizedEmail)) {
      final remaining = await EmailRateLimitService.getRemainingCooldown(
        normalizedEmail,
      );
      print(
        'ℹ️ Password reset email already sent recently. Remaining cooldown: ${remaining ?? Duration.zero}',
      );
      return;
    }

    // Retry logic with exponential backoff
    int retryCount = await EmailRateLimitService.getRetryCount(normalizedEmail);
    Exception? lastError;

    while (retryCount < 3) {
      try {
        print(
          '🔍 [DEBUG] Sending password reset email to: $email (attempt ${retryCount + 1})',
        );

        // Get platform-appropriate redirect URL
        final redirectUrl = getRedirectUrl();
        print('🔍 [DEBUG] Using redirect URL: $redirectUrl');

        // Send password reset email (returns void, just checks for exceptions)
        await SupabaseService.client.auth.resetPasswordForEmail(
          email,
          redirectTo: redirectUrl,
        );

        // Success - record email sent and clear retry count
        await EmailRateLimitService.recordEmailSent(normalizedEmail);

        print('✅ Password reset email sent successfully to: $email');
        print('📧 [INFO] Email sent! Check inbox and spam folder.');
        return;
      } catch (e) {
        lastError = e is Exception ? e : Exception(e.toString());
        print(
          '❌ Error sending password reset email (attempt ${retryCount + 1}): $e',
        );

        // Check if it's a rate limit error
        if (EmailRateLimitService.isRateLimitError(e)) {
          // Set cooldown period
          await EmailRateLimitService.setCooldown(normalizedEmail);

          // Increment retry count
          retryCount = await EmailRateLimitService.incrementRetryCount(
            normalizedEmail,
          );

          // Calculate retry delay
          final retryDelay = EmailRateLimitService.calculateRetryDelay(
            retryCount,
          );

          print(
            '⏳ Rate limit detected. Retrying in ${retryDelay.inSeconds} seconds...',
          );

          // Wait before retrying (if we haven't exceeded max retries)
          if (retryCount < 3) {
            await Future.delayed(retryDelay);
            continue;
          } else {
            // Max retries exceeded
            final remaining = await EmailRateLimitService.getRemainingCooldown(
              normalizedEmail,
            );
            if (remaining != null) {
              print(
                'ℹ️ Password reset email already sent. Cooldown remaining: $remaining',
              );
            }
            // Treat as success even if we hit the limit
            return;
          }
        }

        // Not a rate limit error - check for other errors
        final errorStr = e.toString().toLowerCase();
        if (errorStr.contains('user not found') ||
            errorStr.contains('email not found') ||
            errorStr.contains('no account found')) {
          throw Exception(
            'No account found with this email address. Please check and try again.',
          );
        }

        // For other errors, don't retry - throw immediately
        throw Exception(parseAuthError(e));
      }
    }

    // If we get here, all retries failed
    if (lastError != null) {
      throw lastError;
    }

    throw Exception(
      'We couldn’t send the reset email. Please try again shortly.',
    );
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
        throw Exception('The code you entered is incorrect. Please try again.');
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
    _authStateSubscription?.cancel();
    _authStateSubscription = authStateChanges.listen((AuthState state) async {
      final event = state.event;

      if (event == AuthChangeEvent.signedOut) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_keyIsLoggedIn, false);
        print('🔒 Session expired - user signed out');
      } else if (event == AuthChangeEvent.signedIn) {
        final user = state.session?.user;
        print('✅ User signed in');
        if (user != null) {
          await _handleSupabaseSignedIn(user);
        }
      } else if (event == AuthChangeEvent.tokenRefreshed) {
        print('🔄 Auth token refreshed');
      }
    });
  }

  static Future<void> _handleSupabaseSignedIn(User user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pendingEmail = prefs.getString('signup_email');
      final pendingRole = prefs.getString('signup_user_role');
      final pendingName = prefs.getString('signup_full_name');

      if (pendingEmail == null && pendingRole == null && pendingName == null) {
        return;
      }

      await completeEmailVerification(user);
    } catch (e) {
      print('⚠️ Error handling Supabase signed-in event: $e');
    }
  }

  static Future<void> completeEmailVerification(User user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pendingRole = prefs.getString('signup_user_role');
      final pendingName = prefs.getString('signup_full_name');
      final pendingEmail = prefs.getString('signup_email');

      if (pendingRole == null && pendingName == null && pendingEmail == null) {
        print('ℹ️ No pending signup data found, skipping verification handler');
        return;
      }

      final role = pendingRole ?? 'student';
      final email = pendingEmail ?? user.email ?? '';
      final fullName =
          pendingName ??
          user.userMetadata?['full_name']?.toString() ??
          (email.isNotEmpty ? email : 'PrepSkul User');

      await SupabaseService.client.from('profiles').upsert({
        'id': user.id,
        'email': email,
        'full_name': fullName,
        'phone_number': null,
        'user_type': role,
        'survey_completed': false,
        'is_admin': false,
      }, onConflict: 'id');

      await saveSession(
        userId: user.id,
        userRole: role,
        phone: '',
        fullName: fullName,
        surveyCompleted: false,
        rememberMe: true,
      );

      await prefs.setBool('survey_intro_seen', false);
      await prefs.remove('signup_user_role');
      await prefs.remove('signup_full_name');
      await prefs.remove('signup_email');

      await NotificationHelperService.notifyAdminsAboutNewUserSignup(
        userEmail: email,
        userId: user.id,
        userName: fullName,
        userType: role,
      );
    } catch (e) {
      print('⚠️ Error completing email verification: $e');
      rethrow;
    }
  }

  /// Get platform-appropriate redirect URL for email verification
  static String getRedirectUrl() {
    if (kIsWeb) {
      // For web, use current origin or fallback to production URL
      try {
        // This will work when app is running
        final origin = Uri.base.origin;

        // IMPORTANT: Return FULL URL (with protocol) to avoid Supabase treating it as relative path
        // For password reset, Supabase redirects to this URL with a code parameter
        // The URL must EXACTLY match what's in Supabase's allowed redirect URLs
        if (origin.contains('localhost') || origin.contains('127.0.0.1')) {
          // Local development - return exact origin (e.g., http://localhost:53790)
          // NOTE: Supabase needs http://localhost:* (with wildcard) in redirect URLs
          print('🔍 [DEBUG] Local development - redirect URL: $origin');
          return origin; // Return without trailing slash
        }
        // Production - must match exactly what's in Supabase
        print('🔍 [DEBUG] Production - redirect URL: https://app.prepskul.com');
        return 'https://app.prepskul.com';
      } catch (e) {
        // Fallback for production
        return 'https://app.prepskul.com';
      }
    } else {
      // For mobile, use deep link scheme
      return 'io.supabase.prepskul://login-callback';
    }
  }

  /// Check if email already exists in Supabase
  /// Note: This is a helper method, but the best way is to catch signUp errors
  static Future<bool> emailExists(String email) async {
    try {
      // Query the auth.users table via admin API or try to sign in
      // For now, we'll rely on signUp throwing an error if email exists
      // This method is kept for backward compatibility but may not be reliable
      try {
        final response = await SupabaseService.client.auth.signInWithPassword(
          email: email,
          password: 'dummy_check_password_12345!',
        );
        // If sign in succeeds (unlikely with dummy password), email exists
        return response.user != null;
      } catch (signInError) {
        final errorString = signInError.toString().toLowerCase();
        // If error mentions credentials or email not confirmed, email likely exists
        if (errorString.contains('invalid login credentials') ||
            errorString.contains('email not confirmed') ||
            errorString.contains('invalid_credentials')) {
          return true; // Email exists but password wrong
        }
        // If explicitly says user not found, email doesn't exist
        if (errorString.contains('user not found') ||
            errorString.contains('no user found') ||
            errorString.contains('invalid_grant')) {
          return false;
        }
        // Default: assume email doesn't exist (let signUp handle the real check)
        return false;
      }
    } catch (e) {
      // On any error, default to false - let signUp handle the validation
      return false;
    }
  }

  /// Parse and return user-friendly error message
  static String parseAuthError(dynamic error) {
    if (error == null) return 'An unexpected error occurred';

    print('🔍 [DEBUG] parseAuthError called with: ${error.runtimeType}');
    print('🔍 [DEBUG] Error toString: ${error.toString()}');

    // If error is already a friendly Exception we created, extract the message
    final errorStr = error.toString();
    print('🔍 [DEBUG] Checking if friendly exception: $errorStr');

    // Check for friendly messages we created (Exception: message format)
    // When we throw Exception('message'), toString() becomes "Exception: message"
    if (errorStr.startsWith('Exception: ')) {
      final friendlyMessage = errorStr.substring(
        11,
      ); // Remove "Exception: " prefix
      print('🔍 [DEBUG] Extracted from Exception: $friendlyMessage');

      // Check if it's a friendly user-facing message (not a technical error)
      // Friendly messages usually have these characteristics:
      // - Contain action words like "Please", "wait", "sign in"
      // - Are complete sentences
      // - Don't contain technical terms like "auth", "api", "exception", "code"
      final lowerMessage = friendlyMessage.toLowerCase();
      final isTechnical =
          lowerMessage.contains('authapi') ||
          lowerMessage.contains('authexception') ||
          lowerMessage.contains('api exception') ||
          lowerMessage.contains('exception:') ||
          lowerMessage.contains('code:') ||
          lowerMessage.contains('statuscode:');

      // If it's NOT technical AND contains friendly keywords, return it
      final hasFriendlyKeywords =
          lowerMessage.contains('already registered') ||
          lowerMessage.contains('please') ||
          lowerMessage.contains('too many') ||
          lowerMessage.contains('wait') ||
          lowerMessage.contains('sign in') ||
          lowerMessage.contains('valid email') ||
          lowerMessage.contains('try again');

      if (!isTechnical &&
          (hasFriendlyKeywords || friendlyMessage.length > 20)) {
        // This looks like a friendly message - return it
        print(
          '🔍 [DEBUG] ✅ Returning friendly exception message: $friendlyMessage',
        );
        return friendlyMessage;
      } else {
        print('🔍 [DEBUG] ⚠️ Exception looks technical, will parse further');
      }
    }

    // Also check if error has a message property (some Exception types)
    // Note: Exception is a base class, so we check using dynamic type checking

    // Handle Supabase AuthException/AuthApiException properly
    String errorMessage = error.toString();
    String errorCode = '';
    String statusCode = '';

    // Handle AuthApiException format: AuthApiException(message: ..., statusCode: ..., code: ...)
    final originalErrorString = error.toString();
    print('🔍 [DEBUG] Original error string: $originalErrorString');

    if (originalErrorString.contains('AuthApiException')) {
      print('🔍 [DEBUG] Detected AuthApiException format');

      // Extract message from the original error string
      final messageMatch = RegExp(
        r'message:\s*([^,]+)',
      ).firstMatch(originalErrorString);
      if (messageMatch != null) {
        errorMessage = messageMatch.group(1)?.trim() ?? errorMessage;
        print('🔍 [DEBUG] Extracted message: $errorMessage');
      } else {
        print('🔍 [DEBUG] No message match found');
      }

      // Extract code from the original error string
      final codeMatch = RegExp(
        r'code:\s*([^\s,)]+)',
      ).firstMatch(originalErrorString);
      if (codeMatch != null) {
        errorCode = codeMatch.group(1)?.trim() ?? '';
        print('🔍 [DEBUG] Extracted code: $errorCode');
      } else {
        print('🔍 [DEBUG] No code match found');
      }

      // Extract statusCode from the original error string
      final statusMatch = RegExp(
        r'statusCode:\s*([^,]+)',
      ).firstMatch(originalErrorString);
      if (statusMatch != null) {
        statusCode = statusMatch.group(1)?.trim() ?? '';
        print('🔍 [DEBUG] Extracted statusCode: $statusCode');
      } else {
        print('🔍 [DEBUG] No statusCode match found');
      }
    }
    // Handle AuthException format (legacy)
    else if (errorMessage.contains('AuthException')) {
      final match = RegExp(
        r'AuthException\([^,]+,\s*([^)]+)\)',
      ).firstMatch(errorMessage);
      if (match != null) {
        errorMessage = match.group(1)?.replaceAll("'", "") ?? errorMessage;
      }
      final codeMatch = RegExp(r'code:\s*([^,}]+)').firstMatch(errorMessage);
      if (codeMatch != null) {
        errorCode = codeMatch.group(1)?.trim().replaceAll("'", "") ?? '';
      }
    }

    final errorString = errorMessage.toLowerCase();
    errorCode = errorCode.toLowerCase();
    statusCode = statusCode.toLowerCase();

    print('🔍 [DEBUG] Final values:');
    print('🔍 [DEBUG]   errorMessage: $errorMessage');
    print('🔍 [DEBUG]   errorString: $errorString');
    print('🔍 [DEBUG]   errorCode: $errorCode');
    print('🔍 [DEBUG]   statusCode: $statusCode');

    // Email-related errors - check both message and code
    if (errorString.contains('user already registered') ||
        errorString.contains('email already registered') ||
        errorString.contains('already been registered') ||
        errorString.contains('user already exists') ||
        errorString.contains('email_address_already_exists') ||
        errorString.contains('duplicate') && errorString.contains('email') ||
        errorCode == 'email_address_already_exists' ||
        errorCode == 'signup_disabled' ||
        errorString.contains('email address is already registered')) {
      return 'This email is already registered. Please sign in instead.';
    }

    if (errorString.contains('invalid email') ||
        errorString.contains('email format')) {
      return 'Please enter a valid email address.';
    }

    if (errorString.contains('email not confirmed') ||
        errorString.contains('email not verified')) {
      return 'Please verify your email first. Check your inbox for the confirmation link.';
    }

    // Password-related errors
    // Note: Supabase returns "invalid_credentials" for both non-existent users and wrong passwords
    // for security reasons (to prevent email enumeration). We can't differentiate between them.
    // However, we can check if the error code is specifically "invalid_credentials" and provide
    // a more helpful message that covers both cases.
    if (errorString.contains('invalid login credentials') ||
        errorString.contains('invalid password') ||
        errorString.contains('wrong password') ||
        errorCode == 'invalid_credentials') {
      // Check if we can determine if it's a user not found vs wrong password
      // Supabase doesn't differentiate, but we can provide a more helpful message
      if (errorString.contains('user not found') ||
          errorString.contains('no user found') ||
          errorString.contains('email not found')) {
        return 'No account found with this email address. Please sign up first.';
      }
      // For invalid_credentials, it could be either wrong password or non-existent user
      // Provide a message that covers both cases
      return 'The email or password you entered is incorrect. Please check and try again, or sign up if you don\'t have an account.';
    }

    if (errorString.contains('password') && errorString.contains('weak')) {
      return 'Password is too weak. Please use a stronger password.';
    }

    // Rate limiting - check BEFORE other generic errors
    print('🔍 [DEBUG] Checking rate limit conditions...');
    final isRateLimit =
        errorString.contains('rate limit') ||
        errorString.contains('over_email_send_rate_limit') ||
        errorCode == 'over_email_send_rate_limit' ||
        errorString.contains('email rate limit exceeded') ||
        statusCode == '429' ||
        errorString.contains('429');
    print('🔍 [DEBUG] Rate limit check result: $isRateLimit');

    if (isRateLimit) {
      print('🔍 [DEBUG] ✅ Returning rate limit message');
      return 'Almost done! Please check your inbox and try resending in a minute if needed.';
    }

    // Too many requests (generic)
    if (errorString.contains('too many requests')) {
      return 'Too many attempts. Please wait a moment before trying again.';
    }

    // Network errors
    if (errorString.contains('network') ||
        errorString.contains('connection') ||
        errorString.contains('timeout')) {
      return 'Connection error. Please check your internet connection.';
    }

    // User not found
    if (errorString.contains('user not found') ||
        errorString.contains('no user found')) {
      return 'No account found with this email. Please sign up first.';
    }

    // Profile not found - user needs to complete signup
    if (errorString.contains('profile not found')) {
      return 'Your account is not fully set up. Please complete your profile setup first.';
    }

    // Expired token
    if (errorString.contains('expired') ||
        errorString.contains('otp_expired')) {
      return 'Verification link has expired. Please request a new one.';
    }

    // Default fallback - always return a friendly, generic message
    print(
      '🔍 [DEBUG] ⚠️ No matching error pattern found, using friendly fallback message',
    );
    print('🔍 [DEBUG] Original error was: ${error.toString()}');

    return 'Something went wrong. Please try again in a moment.';
  }

  /// Resend email verification with rate limiting and retry
  static Future<void> resendEmailVerification(String email) async {
    // Normalize email for rate limiting
    final normalizedEmail = email.toLowerCase().trim();

    if (await EmailRateLimitService.isInCooldown(normalizedEmail) ||
        !await EmailRateLimitService.canSendEmail(normalizedEmail)) {
      final remaining = await EmailRateLimitService.getRemainingCooldown(
        normalizedEmail,
      );
      print(
        'ℹ️ Verification email already sent recently. Remaining cooldown: ${remaining ?? Duration.zero}',
      );
      return;
    }

    // Retry logic with exponential backoff
    int retryCount = await EmailRateLimitService.getRetryCount(normalizedEmail);
    Exception? lastError;

    while (retryCount < 3) {
      try {
        print(
          '🔍 [DEBUG] Resending verification email to: $email (attempt ${retryCount + 1})',
        );

        await SupabaseService.client.auth.resend(
          type: OtpType.signup,
          email: email,
          emailRedirectTo: getRedirectUrl(),
        );

        // Success - record email sent and clear retry count
        await EmailRateLimitService.recordEmailSent(normalizedEmail);

        print('✅ Verification email resent to: $email');
        return;
      } catch (e) {
        lastError = e is Exception ? e : Exception(e.toString());
        print(
          '❌ Error resending verification email (attempt ${retryCount + 1}): $e',
        );

        // Check if it's a rate limit error
        if (EmailRateLimitService.isRateLimitError(e)) {
          // Set cooldown period
          await EmailRateLimitService.setCooldown(normalizedEmail);

          // Increment retry count
          retryCount = await EmailRateLimitService.incrementRetryCount(
            normalizedEmail,
          );

          // Calculate retry delay
          final retryDelay = EmailRateLimitService.calculateRetryDelay(
            retryCount,
          );

          print(
            '⏳ Rate limit detected. Retrying in ${retryDelay.inSeconds} seconds...',
          );

          // Wait before retrying (if we haven't exceeded max retries)
          if (retryCount < 3) {
            await Future.delayed(retryDelay);
            continue;
          } else {
            // Max retries exceeded
            final remaining = await EmailRateLimitService.getRemainingCooldown(
              normalizedEmail,
            );
            if (remaining != null) {
              print(
                'ℹ️ Verification email already sent. Cooldown remaining: $remaining',
              );
            }
            return;
          }
        }

        // Not a rate limit error - check for other errors
        final errorStr = e.toString().toLowerCase();
        if (errorStr.contains('email') && errorStr.contains('not found')) {
          throw Exception('Email not found. Please check your email address.');
        }

        // For other errors, don't retry - throw immediately
        throw Exception(parseAuthError(e));
      }
    }

    // If we get here, all retries failed
    if (lastError != null) {
      throw lastError;
    }

    throw Exception(
      'Failed to resend verification email. Please try again later.',
    );
  }
}
