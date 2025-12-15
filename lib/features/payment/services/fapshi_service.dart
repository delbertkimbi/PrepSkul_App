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
        final userFriendlyMessage = _convertToUserFriendlyError(errorMessage);
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
      final userFriendlyMessage = _convertToUserFriendlyError(e.toString());
      throw Exception(userFriendlyMessage);
    }
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
  static String _convertToUserFriendlyError(String errorMessage) {
    final lowerError = errorMessage.toLowerCase();
    
    if (lowerError.contains('phone') && (lowerError.contains('valid') || lowerError.contains('mtn') || lowerError.contains('orange'))) {
      return 'Please enter a valid phone number. Use format: 67XXXXXXX (MTN) or 69XXXXXXX (Orange).';
    }
    
    if (lowerError.contains('amount') && lowerError.contains('minimum')) {
      return 'Payment amount must be at least 100 XAF.';
    }
    
    if (lowerError.contains('credentials') || lowerError.contains('authentication') || lowerError.contains('forbidden')) {
      return 'Payment service configuration error. Please contact support.';
    }
    
    if (lowerError.contains('network') || lowerError.contains('connection') || lowerError.contains('timeout')) {
      return 'Network error. Please check your internet connection and try again.';
    }
    
    if (lowerError.contains('expired')) {
      return 'Payment link has expired. Please initiate a new payment.';
    }
    
    if (lowerError.contains('failed') || lowerError.contains('error')) {
      return 'Payment request failed. Please check your phone number and try again.';
    }
    
    // Default user-friendly message
    return 'Unable to process payment. Please check your phone number and try again. If the problem persists, contact support.';
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
  static Future<FapshiPaymentStatus> pollPaymentStatus(
    String transId, {
    int maxAttempts = 40,
    Duration interval = const Duration(seconds: 3),
  }) async {
    int attempts = 0;

    while (attempts < maxAttempts) {
      try {
        final status = await getPaymentStatus(transId);

        // If payment is no longer pending, return status
        if (!status.isPending) {
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
    final finalStatus = await getPaymentStatus(transId);
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

