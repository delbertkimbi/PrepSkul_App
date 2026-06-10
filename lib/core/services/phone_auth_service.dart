import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:prepskul/core/config/app_config.dart';
import 'package:prepskul/core/services/log_service.dart';
import 'package:prepskul/core/services/supabase_service.dart';
import 'package:prepskul/core/utils/phone_auth_utils.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Password-based phone auth without OTP or email inbox steps.
class PhoneAuthService {
  static Future<AuthResponse> signUpWithPhone({
    required String phoneNumber,
    required String password,
    required String fullName,
  }) async {
    final aliasEmail = PhoneAuthUtils.aliasEmail(phoneNumber);

    await _createConfirmedPhoneAccount(
      phoneNumber: phoneNumber,
      password: password,
      fullName: fullName,
      aliasEmail: aliasEmail,
    );

    return _signInWithAlias(aliasEmail, password);
  }

  static Future<AuthResponse> signInWithPhone({
    required String phoneNumber,
    required String password,
  }) async {
    final aliasEmail = PhoneAuthUtils.aliasEmail(phoneNumber);

    try {
      return await _signInWithAlias(aliasEmail, password);
    } catch (e) {
      if (!PhoneAuthUtils.isEmailNotConfirmedError(e)) {
        rethrow;
      }

      LogService.debug(
        '[PHONE_AUTH] Unconfirmed alias account — auto-confirming: $aliasEmail',
      );
      await _confirmPhoneAlias(aliasEmail);
      return _signInWithAlias(aliasEmail, password);
    }
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

  static Future<void> _createConfirmedPhoneAccount({
    required String phoneNumber,
    required String password,
    required String fullName,
    required String aliasEmail,
  }) async {
    final url = Uri.parse(
      '${AppConfig.effectiveApiBaseUrl}/mobile/auth/phone-signup',
    );

    final response = await http.post(
      url,
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'phoneNumber': phoneNumber,
        'password': password,
        'fullName': fullName,
        'aliasEmail': aliasEmail,
      }),
    );

    if (response.statusCode == 409) {
      throw Exception(
        'This phone number is already linked to another account. Please log in instead.',
      );
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }

    // Fallback for local dev when the API route is unavailable.
    LogService.warning(
      '[PHONE_AUTH] phone-signup API failed (${response.statusCode}); falling back to client signUp',
    );
    await _clientSignUpFallback(
      aliasEmail: aliasEmail,
      password: password,
      fullName: fullName,
      phoneNumber: phoneNumber,
    );
  }

  static Future<void> _clientSignUpFallback({
    required String aliasEmail,
    required String password,
    required String fullName,
    required String phoneNumber,
  }) async {
    final response = await SupabaseService.client.auth.signUp(
      email: aliasEmail,
      password: password,
      data: {
        'full_name': fullName,
        'phone_number': phoneNumber,
      },
    );

    if (response.session != null || SupabaseService.currentUser != null) {
      return;
    }

    await _confirmPhoneAlias(aliasEmail);
  }

  static Future<void> _confirmPhoneAlias(String aliasEmail) async {
    if (!PhoneAuthUtils.isPhoneAliasEmail(aliasEmail)) {
      throw Exception('Invalid phone alias email');
    }

    try {
      await SupabaseService.client.rpc(
        'confirm_phone_alias_auth',
        params: {'p_email': aliasEmail},
      );
      return;
    } catch (e) {
      LogService.warning(
        '[PHONE_AUTH] RPC confirm failed, trying API fallback: $e',
      );
    }

    final url = Uri.parse(
      '${AppConfig.effectiveApiBaseUrl}/mobile/auth/confirm-phone-alias',
    );

    final response = await http.post(
      url,
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'aliasEmail': aliasEmail}),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }

    throw Exception(
      'Could not activate phone account. Please try again in a moment.',
    );
  }
}
