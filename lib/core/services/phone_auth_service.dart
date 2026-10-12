import 'package:prepskul/core/services/supabase_service.dart';
import 'package:prepskul/core/utils/phone_auth_utils.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Existing verified phone accounts may still sign in with their password.
/// New phone accounts require a verified ownership flow before activation.
class PhoneAuthService {
  static Future<AuthResponse> signUpWithPhone({
    required String phoneNumber,
    required String password,
    required String fullName,
  }) async {
    throw Exception(
      'Phone signup is temporarily unavailable. Please sign up with email.',
    );
  }

  static Future<AuthResponse> signInWithPhone({
    required String phoneNumber,
    required String password,
  }) async {
    final aliasEmail = PhoneAuthUtils.aliasEmail(phoneNumber);

    return _signInWithAlias(aliasEmail, password);
  }

  static Future<AuthResponse> _signInWithAlias(
    String aliasEmail,
    String password,
  ) async {
    return SupabaseService.client.auth.signInWithPassword(
      email: aliasEmail,
      password: password,
    );
  }
}
