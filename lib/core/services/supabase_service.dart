import 'package:supabase_flutter/supabase_flutter.dart';

/// Service class to handle Supabase operations
class SupabaseService {
  static final SupabaseClient _client = Supabase.instance.client;

  // Get the Supabase client instance
  static SupabaseClient get client => _client;

  // User Management

  /// Get current user
  static User? get currentUser => _client.auth.currentUser;

  /// Check if user is authenticated
  static bool get isAuthenticated => currentUser != null;

  /// Sign up with email and password
  static Future<AuthResponse> signUp({
    required String email,
    required String password,
    Map<String, dynamic>? userData,
  }) async {
    final response = await _client.auth.signUp(
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
    final response = await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
    return response;
  }

  /// Sign out
  static Future<void> signOut() async {
    await _client.auth.signOut();
  }

  // Phone Authentication

  /// Send OTP to phone number
  static Future<void> sendPhoneOTP(String phoneNumber) async {
    try {
      await _client.auth.signInWithOtp(phone: phoneNumber);
      print('✅ OTP sent successfully to: $phoneNumber');
    } catch (e) {
      print('❌ Error sending OTP: $e');
      rethrow;
    }
  }

  /// Verify OTP for phone authentication
  static Future<AuthResponse> verifyPhoneOTP({
    required String phone,
    required String token,
  }) async {
    try {
      print('🔐 Verifying OTP for: $phone with code: $token');
      final response = await _client.auth.verifyOTP(
        phone: phone,
        token: token,
        type: OtpType.sms,
      );
      print('✅ OTP verified successfully!');
      return response;
    } catch (e) {
      print('❌ Error verifying OTP: $e');
      rethrow;
    }
  }

  // Google Sign-In

  /// Sign in with Google (OAuth)
  static Future<bool> signInWithGoogle() async {
    return await _client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: 'io.supabase.prepskul://login-callback/',
    );
  }

  // Auth State Management

  /// Listen to auth state changes
  static Stream<AuthState> get authStateChanges =>
      _client.auth.onAuthStateChange;

  // Database Operations

  /// Insert data into a table
  static Future<void> insertData({
    required String table,
    required Map<String, dynamic> data,
  }) async {
    await _client.from(table).insert(data);
  }

  /// Update data in a table
  static Future<void> updateData({
    required String table,
    required Map<String, dynamic> data,
    required String field,
    required dynamic value,
  }) async {
    await _client.from(table).update(data).eq(field, value);
  }

  /// Get data from a table
  static Future<List<Map<String, dynamic>>> getData({
    required String table,
    String? field,
    dynamic value,
  }) async {
    if (field != null && value != null) {
      return await _client.from(table).select().eq(field, value);
    }
    return await _client.from(table).select();
  }

  /// Delete data from a table
  static Future<void> deleteData({
    required String table,
    required String field,
    required dynamic value,
  }) async {
    await _client.from(table).delete().eq(field, value);
  }
}
