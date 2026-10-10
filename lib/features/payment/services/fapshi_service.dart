import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:prepskul/core/services/log_service.dart';
import 'package:prepskul/core/config/app_config.dart';
import 'package:prepskul/core/services/supabase_service.dart';
import '../models/fapshi_transaction_model.dart';

/// Fapshi Payment Service
/// 
/// Handles all Fapshi payment API interactions
/// Documentation: docs/FAPSHI_API_DOCUMENTATION.md
/// 
/// Environment is controlled by AppConfig.isProduction

class FapshiService {
  static String get _endpoint => '${AppConfig.effectiveApiBaseUrl}/payments/fapshi';
  static bool get isProduction => AppConfig.isProd;

  static Map<String, String> _headers() {
    final token = SupabaseService.client.auth.currentSession?.accessToken;
    if (token == null || token.isEmpty) throw Exception('Please sign in to manage payments.');
    return {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'};
  }

  static Map<String, dynamic> _result(http.Response response) {
    if (!response.headers['content-type'].toString().contains('application/json')) {
      throw Exception('Payments are temporarily unavailable. Please try again later.');
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      throw Exception(body['error'] as String? ?? 'Payment request could not be completed.');
    }
    return body;
  }

  /// Initiate direct payment request
  /// 
  /// Sends payment request directly to user's mobile device
  /// 
  /// Parameters:
  /// - [amount]: Payment amount in XAF (minimum 100)
  /// - [phone]: Phone number (e.g., "670000000")
  /// - [medium]: Payment medium - "mobile money" or "orange money" (optional, auto-detect if omitted)
  /// - [name]: Payer's name (optional)
  /// - [email]: Email for receipt (optional)
  /// - [userId]: Your system's user ID (optional, 1-100 chars, alphanumeric, -, _)
  /// - [externalId]: Transaction/order ID for reconciliation (optional, 1-100 chars, alphanumeric, -, _)
  /// - [message]: Reason for payment (optional)
  static Future<FapshiPaymentResponse> initiateDirectPayment({
    required int amount,
    required String phone,
    String? medium,
    String? name,
    String? email,
    String? userId,
    required String externalId,
    String? message,
  }) async {
    final normalizedPhone = _normalizePhoneNumber(phone);
    if (normalizedPhone == null) throw Exception('Please enter a valid Cameroon mobile number.');
    final response = await http.post(Uri.parse(_endpoint), headers: _headers(),
      body: jsonEncode({'action': 'initiate', 'externalId': externalId,
        'amount': amount, 'phone': normalizedPhone}),
    ).timeout(const Duration(seconds: 30));
    return FapshiPaymentResponse.fromJson(_result(response));
  }

  static String? detectPhoneProvider(String phone) {
    final normalized = _normalizePhoneNumber(phone);
    if (normalized == null) return null;
    
    // MTN prefixes: 67, 65, 66, 68
    if (normalized.startsWith('67') || 
        normalized.startsWith('65') || 
        normalized.startsWith('66') || 
        normalized.startsWith('68')) {
      return 'mtn';
    }
    
    // Orange prefix: 69
    if (normalized.startsWith('69')) {
      return 'orange';
    }
    
    return null;
  }

  /// Check if phone number is a sandbox test number
  /// Sandbox test numbers auto-succeed/fail without sending actual payment requests
  static String? _normalizePhoneNumber(String phone) {
    // Remove all non-digit characters
    final digitsOnly = phone.replaceAll(RegExp(r'[^\d]'), '');
    
    // Handle different formats
    String normalized;
    if (digitsOnly.startsWith('237')) {
      // International format: 23767XXXXXXX -> 67XXXXXXX
      normalized = digitsOnly.substring(3);
    } else if (digitsOnly.startsWith('67') ||
        digitsOnly.startsWith('69') ||
        digitsOnly.startsWith('65') ||
        digitsOnly.startsWith('66') ||
        digitsOnly.startsWith('68')) {
      // Already in correct format: 67XXXXXXX or 69XXXXXXX
      normalized = digitsOnly;
    } else {
      return null; // Invalid format
    }
    
    // Validate length (should be 9 digits for Cameroon)
    if (normalized.length != 9) {
      return null;
    }
    
    // Validate it starts with valid Cameroon mobile prefix
    final validPrefixes = ['67', '69', '65', '66', '68'];
    if (!validPrefixes.any((prefix) => normalized.startsWith(prefix))) {
      return null;
    }
    
    return normalized;
  }
  
  /// Convert Fapshi API error messages to user-friendly messages
  /// Similar to Stripe's approach: clear, actionable, non-technical
  static Future<FapshiPaymentStatus> getPaymentStatus(String transId) async {
    final response = await http.get(Uri.parse(_endpoint).replace(queryParameters: {'transId': transId}),
      headers: _headers()).timeout(const Duration(seconds: 30));
    return FapshiPaymentStatus.fromJson(_result(response));
  }

  /// Poll payment status with retry logic
  /// 
  /// Continuously checks payment status until it's no longer pending
  /// 
  /// Parameters:
  /// - [transId]: Transaction ID to poll
  /// - [maxAttempts]: Maximum number of polling attempts (default: 40)
  /// - [interval]: Time between polling attempts (default: 3 seconds)
  /// - [minWaitTime]: Minimum time to wait before accepting success
  ///                   - Sandbox: 10 seconds (to detect auto-success)
  ///                   - Production: 5 seconds (to ensure request was sent)
  static Future<FapshiPaymentStatus> pollPaymentStatus(
    String transId, {
    int maxAttempts = 40,
    Duration interval = const Duration(seconds: 3),
    Duration? minWaitTime,
  }) async {
    int attempts = 0;
    final startTime = DateTime.now();
    
    // Use longer wait time in sandbox to detect auto-success
    // In production, wait longer to ensure payment request was actually sent
    final effectiveMinWaitTime = minWaitTime ?? 
        (isProduction 
            ? const Duration(seconds: 10) // Production: wait 10s to ensure request was sent
            : const Duration(seconds: 10)); // Sandbox: also 10s to detect auto-success

    while (attempts < maxAttempts) {
      try {
        final status = await getPaymentStatus(transId);

        LogService.debug('📊 Payment status check (attempt ${attempts + 1}/$maxAttempts): ${status.status}');

        // If payment is no longer pending (SUCCESSFUL or FAILED)
        if (!status.isPending) {
          // For SUCCESSFUL payments, ensure minimum wait time has passed
          // This prevents false positives from sandbox auto-success
          // and ensures user has time to receive payment request
          if (status.isSuccessful) {
            final elapsed = DateTime.now().difference(startTime);
            if (elapsed < effectiveMinWaitTime) {
              final remainingWait = effectiveMinWaitTime - elapsed;
              LogService.warning(
                '⚠️ Payment marked as SUCCESSFUL too quickly (${elapsed.inSeconds}s). '
                'In sandbox, this usually means auto-success without sending payment request. '
                'Waiting ${remainingWait.inSeconds}s before accepting...'
              );
              await Future.delayed(remainingWait);
              // Re-check status after wait - if still successful, it's likely real
              final recheckedStatus = await getPaymentStatus(transId);
              LogService.info('✅ Payment status after wait: ${recheckedStatus.status}');
              
              // In sandbox, if it succeeded immediately, warn user
              if (!isProduction && recheckedStatus.isSuccessful) {
                LogService.warning(
                  '⚠️ SANDBOX: Payment succeeded without phone notification. '
                  'This is normal in sandbox - payments auto-succeed. '
                  'In production, you will receive a payment request on your phone.'
                );
              }
              
              return recheckedStatus;
            }
          }
          
          LogService.info('✅ Payment status finalized: ${status.status}');
          return status;
        }

        // Wait before next attempt
        await Future.delayed(interval);
        attempts++;

        LogService.debug('⏳ Polling payment status (attempt $attempts/$maxAttempts)...');
      } catch (e) {
        // For configuration / parsing / provider errors we surface the error
        // immediately so the UI can show feedback instead of spinning forever.
        LogService.warning('Error polling payment status: $e');
        rethrow;
      }
    }

    // If max attempts reached, get final status
    LogService.info('⏱️ Max polling attempts reached, getting final status...');
    final finalStatus = await getPaymentStatus(transId);
    LogService.info('📊 Final payment status: ${finalStatus.status}');
    return finalStatus;
  }

  /// Expire a payment transaction
  /// 
  /// Cancels a pending payment transaction
  /// 
  /// Parameters:
  /// - [transId]: Transaction ID to expire
  static Future<void> expirePayment(String transId) async {
    final response = await http.post(Uri.parse(_endpoint), headers: _headers(),
      body: jsonEncode({'action': 'expire', 'transId': transId}),
    ).timeout(const Duration(seconds: 30));
    _result(response);
  }
}
