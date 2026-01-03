import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:prepskul/core/services/log_service.dart';

/// Service class to handle Supabase operations
class SupabaseService {
  // Get the Supabase client instance (safely, returns null if not initialized)
  static SupabaseClient? get _clientSafe {
    try {
      return Supabase.instance.client;
    } catch (e) {
      // Supabase not initialized yet
      return null;
    }
  }

  /// Check if Supabase client is available (public method)
  static bool get isClientAvailable {
    return _clientSafe != null;
  }

  // Get the Supabase client instance (throws if not initialized)
  static SupabaseClient get client {
    final client = _clientSafe;
    if (client == null) {
      // Provide a more helpful error message
      throw Exception(
        'Unable to connect to the server. Please check your internet connection and try again. If the problem persists, the app may need to be updated.',
      );
    }
    return client;
  }

  // User Management

  /// Get current user (safely)
  static User? get currentUser {
    try {
      return _clientSafe?.auth.currentUser;
    } catch (e) {
      return null;
    }
  }

  /// Check if user is authenticated (safely)
  static bool get isAuthenticated {
    try {
      return _clientSafe?.auth.currentUser != null;
    } catch (e) {
      return false;
    }
  }

  /// Sign up with email and password
  static Future<AuthResponse> signUp({
    required String email,
    required String password,
    Map<String, dynamic>? userData,
  }) async {
    final response = await client.auth.signUp(
      email: email,
      password: password,
      data: userData,
    );
    return response;
  }

  /// Sign in with email and password
  static Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    final response = await client.auth.signInWithPassword(
      email: email,
      password: password,
    );
    return response;
  }

  /// Sign out
  static Future<void> signOut() async {
    await client.auth.signOut();
  }

  // Phone Authentication

  /// Send OTP to phone number
  static Future<void> sendPhoneOTP(String phoneNumber) async {
    try {
      await client.auth.signInWithOtp(phone: phoneNumber);
      LogService.success('OTP sent successfully to: $phoneNumber');
    } catch (e) {
      LogService.error('Error sending OTP: $e');
      rethrow;
    }
  }

  /// Verify OTP for phone authentication
  static Future<AuthResponse> verifyPhoneOTP({
    required String phone,
    required String token,
  }) async {
    try {
      LogService.debug('🔐 Verifying OTP for: $phone with code: $token');
      final response = await client.auth.verifyOTP(
        phone: phone,
        token: token,
        type: OtpType.sms,
      );
      LogService.success('OTP verified successfully!');
      return response;
    } catch (e) {
      LogService.error('Error verifying OTP: $e');
      final errorStr = e.toString().toLowerCase();
      
      // Provide helpful error messages
      if (errorStr.contains('expired') || errorStr.contains('otp_expired')) {
        throw Exception('This verification code has expired. Please tap "Resend Code" to get a new one.');
      } else if (errorStr.contains('invalid') || errorStr.contains('wrong')) {
        throw Exception('Invalid verification code. Please check the code and try again.');
      }
      
      rethrow;
    }
  }

  // Google Sign-In

  /// Sign in with Google (OAuth)
  static Future<bool> signInWithGoogle() async {
    return await client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: 'io.supabase.prepskul://login-callback/',
    );
  }

  // Auth State Management

  /// Listen to auth state changes (safely - returns empty stream if not initialized)
  static Stream<AuthState> get authStateChanges {
    try {
      return client.auth.onAuthStateChange;
    } catch (e) {
      // Return empty stream if Supabase not initialized
      // This allows the app to continue without errors
      return const Stream<AuthState>.empty();
    }
  }

  // Database Operations

  /// Insert data into a table
  static Future<void> insertData({
    required String table,
    required Map<String, dynamic> data,
  }) async {
    await client.from(table).insert(data);
  }

  /// Update data in a table
  static Future<void> updateData({
    required String table,
    required Map<String, dynamic> data,
    required String field,
    required dynamic value,
  }) async {
    await client.from(table).update(data).eq(field, value);
  }

  /// Get data from a table
  static Future<List<Map<String, dynamic>>> getData({
    required String table,
    String? field,
    dynamic value,
  }) async {
    if (field != null && value != null) {
      return await client.from(table).select().eq(field, value);
    }
    return await client.from(table).select();
  }

  /// Delete data from a table
  static Future<void> deleteData({
    required String table,
    required String field,
    required dynamic value,
  }) async {
    await client.from(table).delete().eq(field, value);
  }
}