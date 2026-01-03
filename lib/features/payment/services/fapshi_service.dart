import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:prepskul/core/services/log_service.dart';
import 'package:prepskul/core/config/app_config.dart';
import '../models/fapshi_transaction_model.dart';

/// Fapshi Payment Service
/// 
/// Handles all Fapshi payment API interactions
/// Documentation: docs/FAPSHI_API_DOCUMENTATION.md
/// 
/// Environment is controlled by AppConfig.isProduction

class FapshiService {
  // Base URLs - Uses AppConfig
  static String get _baseUrl => AppConfig.fapshiBaseUrl;

  /// Public accessor so UI layers can know if we are running against live environment
  static bool get isProduction => AppConfig.isProd;

  // API Credentials - Collection Service (for receiving payments)
  static String get _apiUser => AppConfig.fapshiApiUser;

  static String get _apiKey => AppConfig.fapshiApiKey;

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
    try {
      // Validate API credentials
      if (_apiUser.isEmpty || _apiKey.isEmpty) {
        LogService.error('Fapshi API credentials are missing. Check your .env file.');
        throw Exception('Payment service is not configured. Please contact support.');
      }

      // Validate amount
      if (amount < 100) {
        throw Exception('Amount must be at least 100 XAF');
      }

      // Validate and normalize phone number
      final normalizedPhone = _normalizePhoneNumber(phone);
      if (normalizedPhone == null) {
        throw Exception('Please enter a valid phone number. Use format: 67XXXXXXX or 69XXXXXXX (MTN or Orange Cameroon)');
      }

      // Warn if using sandbox test number (they auto-succeed without sending payment requests)
      if (!isProduction && _isSandboxTestNumber(normalizedPhone)) {
        LogService.warning('⚠️ Using sandbox test number: $normalizedPhone. Payment will auto-succeed/fail without sending actual payment request.');
      }

      // Prepare request body
      final requestBody = <String, dynamic>{
        'amount': amount,
        'phone': normalizedPhone,
        if (medium != null) 'medium': medium,
        if (name != null) 'name': name,
        if (email != null) 'email': email,
        if (userId != null) 'userId': userId,
        'externalId': externalId,
        if (message != null) 'message': message,
      };

      LogService.debug('📤 Fapshi payment request: ${jsonEncode(requestBody)}');
      LogService.debug('🌐 Fapshi API URL: $_baseUrl/direct-pay');
      LogService.debug('🔑 API User: ${_apiUser.isNotEmpty ? "${_apiUser.substring(0, 3)}..." : "EMPTY"}');

      // Make API request
      final response = await http.post(
        Uri.parse('$_baseUrl/direct-pay'),
        headers: {
          'Content-Type': 'application/json',
          'apiuser': _apiUser,
          'apikey': _apiKey,
        },
        body: jsonEncode(requestBody),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Payment request timed out. Please check your internet connection and try again.');
        },
      );

      LogService.debug('📥 Fapshi response status: ${response.statusCode}');
      LogService.debug('📥 Fapshi response body: ${response.body}');

      // Handle response
      if (response.statusCode == 200) {
        try {
        final jsonResponse = jsonDecode(response.body) as Map<String, dynamic>;
        
        // Check for Direct Pay not enabled error in message
        final message = jsonResponse['message'] as String? ?? '';
        if (message.toLowerCase().contains('direct pay') && 
            (message.toLowerCase().contains('disabled') || 
             message.toLowerCase().contains('not enabled') ||
             message.toLowerCase().contains('not available'))) {
          LogService.error('Direct Pay is not enabled in production. Please contact Fapshi support to enable it.');
          throw Exception(
            'Direct Pay is not enabled for your account. Please contact support@fapshi.com to enable Direct Pay in production mode.'
          );
        }
        
        return FapshiPaymentResponse.fromJson(jsonResponse);
        } on FormatException catch (e) {
          LogService.error('Failed to parse Fapshi success response: $e');
          LogService.error('Response body: ${response.body}');
          throw Exception('Received an invalid response from the payment provider. Please try again.');
        }
      } else {
        // Try to parse error response
        String errorMessage = 'Payment request failed';
        try {
        final errorResponse = jsonDecode(response.body) as Map<String, dynamic>;
          errorMessage = errorResponse['message'] as String? ?? 
                        errorResponse['error'] as String? ?? 
                        'Payment request failed';
          LogService.error('Fapshi API error: $errorMessage (Status: ${response.statusCode})');
        } on FormatException {
          // Response is not valid JSON
          LogService.error('Fapshi API returned non-JSON error response (Status: ${response.statusCode})');
          LogService.error('Response body: ${response.body}');
          
          // Try to extract meaningful error from HTML or plain text
          if (response.body.toLowerCase().contains('unauthorized') || 
              response.body.toLowerCase().contains('forbidden') ||
              response.statusCode == 401 || 
              response.statusCode == 403) {
            errorMessage = 'Payment service authentication failed. Please contact support.';
          } else if (response.statusCode == 400) {
            errorMessage = 'Invalid payment request. Please check your phone number and try again.';
          } else if (response.statusCode >= 500) {
            errorMessage = 'Payment service is temporarily unavailable. Please try again later.';
          } else {
            errorMessage = 'Payment request failed. Please try again.';
          }
        }
        
        // Convert Fapshi error messages to user-friendly messages
        final userFriendlyMessage = _convertToUserFriendlyError(errorMessage, response.statusCode);
        throw Exception(userFriendlyMessage);
      }
    } on http.ClientException catch (e) {
      LogService.error('Network error initiating Fapshi payment: $e');
      throw Exception('Network error. Please check your internet connection and try again.');
    } on FormatException catch (e) {
      LogService.error('JSON parsing error: $e');
      throw Exception('Invalid response from payment provider. Please try again.');
    } catch (e) {
      LogService.error('Error initiating Fapshi payment: $e');
      // If it's already a user-friendly message, rethrow as-is
      if (e.toString().contains('Please enter') || 
          e.toString().contains('valid phone') ||
          e.toString().contains('contact support') ||
          e.toString().contains('check your internet') ||
          e.toString().contains('timed out')) {
      rethrow;
      }
      // Otherwise, convert to user-friendly message
      final userFriendlyMessage = _convertToUserFriendlyError(e.toString(), null);
      throw Exception(userFriendlyMessage);
    }
  }
  
  /// Detect phone provider (MTN or Orange) based on phone number prefix
  /// 
  /// Returns 'mtn' for MTN numbers (67, 65, 66, 68) or 'orange' for Orange (69)
  /// Returns null if provider cannot be determined
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
  static bool _isSandboxTestNumber(String phone) {
    final testNumbers = [
      '670000000', '670000002', '650000000', // MTN success
      '690000000', '690000002', '656000000', // Orange success
      '670000001', '670000003', '650000001', // MTN failure
      '690000001', '690000003', '656000001', // Orange failure
    ];
    return testNumbers.contains(phone);
  }

  /// Normalize phone number to Fapshi format
  /// 
  /// Accepts formats:
  /// - 67XXXXXXX (MTN)
  /// - 69XXXXXXX (Orange)
  /// - +23767XXXXXXX
  /// - 23767XXXXXXX
  /// 
  /// Returns normalized phone (9 digits starting with 6) or null if invalid
  static String? _normalizePhoneNumber(String phone) {
    // Remove all non-digit characters
    final digitsOnly = phone.replaceAll(RegExp(r'[^\d]'), '');
    
    // Handle different formats
    String normalized;
    if (digitsOnly.startsWith('237')) {
      // International format: 23767XXXXXXX -> 67XXXXXXX
      normalized = digitsOnly.substring(3);
    } else if (digitsOnly.startsWith('67') || digitsOnly.startsWith('69') || digitsOnly.startsWith('65') || digitsOnly.startsWith('66')) {
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
  static String _convertToUserFriendlyError(String errorMessage, [int? statusCode]) {
    final lowerError = errorMessage.toLowerCase();
    
    // Phone number validation errors - provide clear format guidance
    if (lowerError.contains('phone') && (lowerError.contains('valid') || lowerError.contains('mtn') || lowerError.contains('orange'))) {
      return 'Please enter a valid phone number.\n\nFormat: 67XXXXXXX (MTN) or 69XXXXXXX (Orange)\n\nExample: 670000000 or 690000000';
    }
    
    // Amount validation errors
    if (lowerError.contains('amount') && lowerError.contains('minimum')) {
      return 'The minimum payment amount is 100 XAF. Please try again with a higher amount.';
    }
    
    // Direct Pay not activated (403 Forbidden) - most common issue
    if (statusCode == 403 || 
        (lowerError.contains('forbidden') && lowerError.contains('direct pay')) ||
        (lowerError.contains('forbidden') && lowerError.contains('activate'))) {
      return 'Payment processing is temporarily unavailable. Our team has been notified and is working to resolve this. Please try again in a few minutes, or contact support if the issue persists.';
    }
    
    // Authentication/configuration errors - don't expose technical details
    if (lowerError.contains('credentials') || 
        lowerError.contains('authentication') || 
        lowerError.contains('forbidden') ||
        statusCode == 401 ||
        statusCode == 403) {
      return 'We\'re having trouble processing your payment right now. Please try again in a moment. If this continues, contact our support team for assistance.';
    }
    
    // Network/connection errors - actionable guidance
    if (lowerError.contains('network') || 
        lowerError.contains('connection') || 
        lowerError.contains('timeout')) {
      return 'Connection issue detected. Please check your internet connection and try again.';
    }
    
    // Expired payment links
    if (lowerError.contains('expired')) {
      return 'This payment link has expired. Please start a new payment to continue.';
    }
    
    // Generic payment failures - provide actionable next steps
    if (lowerError.contains('failed') || lowerError.contains('error')) {
      return 'We couldn\'t process your payment. Please check your phone number and try again.';
    }
    
    // Default user-friendly message - clear, helpful, actionable
    return 'We couldn\'t process your payment. Please check your phone number and try again.\n\nIf the problem continues, contact our support team for help.';
  }

  /// Get payment transaction status
  /// 
  /// Checks the status of a payment transaction
  /// 
  /// Parameters:
  /// - [transId]: Transaction ID from direct-pay response
  static Future<FapshiPaymentStatus> getPaymentStatus(String transId) async {
    try {
      final response = await http.get(
        // As per Fapshi docs: GET /payment-status/:transId
        Uri.parse('$_baseUrl/payment-status/$transId'),
        headers: {
          'apiuser': _apiUser,
          'apikey': _apiKey,
        },
      );

      // Some sandbox / web misconfigurations can return HTML instead of JSON.
      final contentType = response.headers['content-type'] ?? '';
      if (!contentType.toLowerCase().contains('application/json')) {
        final snippet = response.body.length > 200
            ? response.body.substring(0, 200)
            : response.body;
        LogService.debug(
            '⚠️ Fapshi payment-status returned non-JSON response (status ${response.statusCode}): $snippet');
        throw Exception(
          'Unexpected response from payment provider while checking status. Please try again shortly.',
        );
      }

      if (response.statusCode == 200) {
        try {
          final jsonResponse =
              jsonDecode(response.body) as Map<String, dynamic>;
          return FapshiPaymentStatus.fromJson(jsonResponse);
        } on FormatException catch (e) {
          LogService.error('JSON parse error for Fapshi payment status: $e');
          throw Exception(
            'Received an invalid response from the payment provider while checking status.',
          );
        }
      } else {
        try {
          final errorResponse =
              jsonDecode(response.body) as Map<String, dynamic>;
          final errorMessage =
              errorResponse['message'] as String? ?? 'Failed to get payment status';
          throw Exception('Fapshi API Error: $errorMessage');
        } on FormatException {
          throw Exception(
            'Payment status request failed with status ${response.statusCode}. Please try again.',
          );
        }
      }
    } catch (e) {
      LogService.error('Error getting Fapshi payment status: $e');
      rethrow;
    }
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
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/expire-pay'),
        headers: {
          'Content-Type': 'application/json',
          'apiuser': _apiUser,
          'apikey': _apiKey,
        },
        body: jsonEncode({'transId': transId}),
      );

      if (response.statusCode != 200) {
        final errorResponse = jsonDecode(response.body) as Map<String, dynamic>;
        final errorMessage = errorResponse['message'] as String? ?? 'Failed to expire payment';
        throw Exception('Fapshi API Error: $errorMessage');
      }
    } catch (e) {
      LogService.error('Error expiring Fapshi payment: $e');
      rethrow;
    }
  }
}
