import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/fapshi_transaction_model.dart';

/// Fapshi Payment Service
/// 
/// Handles all Fapshi payment API interactions
/// Documentation: docs/FAPSHI_API_DOCUMENTATION.md

class FapshiService {
  // Base URLs
  static String get _baseUrl {
    final environment = dotenv.env['FAPSHI_ENVIRONMENT'] ?? 'sandbox';
    return environment == 'live'
        ? 'https://live.fapshi.com'
        : 'https://sandbox.fapshi.com';
  }

  // Environment detection
  static bool get _isProduction {
    final environment = dotenv.env['FAPSHI_ENVIRONMENT'] ?? 'sandbox';
    return environment == 'live';
  }

  // API Credentials - Collection Service (for receiving payments)
  static String get _apiUser {
    if (_isProduction) {
      return dotenv.env['FAPSHI_COLLECTION_API_USER_LIVE'] ?? 
             '54652088-94b9-4642-8d04-fdab02beb71d';
    } else {
      return dotenv.env['FAPSHI_SANDBOX_API_USER'] ?? 
             '4a148e87-e185-437d-a641-b465e2bd8d17';
    }
  }

  static String get _apiKey {
    if (_isProduction) {
      return dotenv.env['FAPSHI_COLLECTION_API_KEY_LIVE'] ?? 
             'FAK_9194147b613e1fc4ba03237bb6640241';
    } else {
      return dotenv.env['FAPSHI_SANDBOX_API_KEY'] ?? 
             'FAK_TEST_0293bda0f3ef142be85b';
    }
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
    try {
      // Validate amount
      if (amount < 100) {
        throw Exception('Amount must be at least 100 XAF');
      }

      // Prepare request body
      final requestBody = <String, dynamic>{
        'amount': amount,
        'phone': phone,
        if (medium != null) 'medium': medium,
        if (name != null) 'name': name,
        if (email != null) 'email': email,
        if (userId != null) 'userId': userId,
        'externalId': externalId,
        if (message != null) 'message': message,
      };

      // Make API request
      final response = await http.post(
        Uri.parse('$_baseUrl/direct-pay'),
        headers: {
          'Content-Type': 'application/json',
          'apiuser': _apiUser,
          'apikey': _apiKey,
        },
        body: jsonEncode(requestBody),
      );

      // Handle response
      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body) as Map<String, dynamic>;
        return FapshiPaymentResponse.fromJson(jsonResponse);
      } else {
        final errorResponse = jsonDecode(response.body) as Map<String, dynamic>;
        final errorMessage = errorResponse['message'] as String? ?? 'Payment request failed';
        throw Exception('Fapshi API Error: $errorMessage');
      }
    } catch (e) {
      print('❌ Error initiating Fapshi payment: $e');
      rethrow;
    }
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
        Uri.parse('$_baseUrl/payment-status?transId=$transId'),
        headers: {
          'apiuser': _apiUser,
          'apikey': _apiKey,
        },
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body) as Map<String, dynamic>;
        return FapshiPaymentStatus.fromJson(jsonResponse);
      } else {
        final errorResponse = jsonDecode(response.body) as Map<String, dynamic>;
        final errorMessage = errorResponse['message'] as String? ?? 'Failed to get payment status';
        throw Exception('Fapshi API Error: $errorMessage');
      }
    } catch (e) {
      print('❌ Error getting Fapshi payment status: $e');
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

        print('⏳ Polling payment status (attempt $attempts/$maxAttempts)...');
      } catch (e) {
        print('⚠️ Error polling payment status: $e');
        // Continue polling on error
        await Future.delayed(interval);
        attempts++;
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
      print('❌ Error expiring Fapshi payment: $e');
      rethrow;
    }
  }
}

