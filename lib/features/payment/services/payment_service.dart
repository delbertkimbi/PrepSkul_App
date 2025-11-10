import '../services/fapshi_service.dart';
import '../models/fapshi_transaction_model.dart';
import '../../booking/models/trial_session_model.dart';
import '../../booking/services/trial_session_service.dart';

/// High-Level Payment Service
/// 
/// Abstraction layer for payment operations
/// Uses FapshiService internally

class PaymentService {
  /// Process trial session payment
  /// 
  /// Initiates payment for a trial session and polls for status
  /// 
  /// Returns the final payment status
  static Future<FapshiPaymentStatus> processTrialPayment({
    required String trialSessionId,
    required String phoneNumber,
    required double amount,
  }) async {
    try {
      // Get trial session for external ID
      final trial = await TrialSessionService.getTrialSessionById(trialSessionId);
      
      // Initiate payment
      final paymentResponse = await FapshiService.initiateDirectPayment(
        amount: amount.toInt(),
        phone: phoneNumber,
        externalId: 'trial_$trialSessionId',
        userId: trial.learnerId,
        message: 'Trial session fee - ${trial.subject}',
      );

      // Poll for payment status (max 2 minutes = 40 attempts × 3 seconds)
      final status = await FapshiService.pollPaymentStatus(
        paymentResponse.transId,
        maxAttempts: 40,
        interval: const Duration(seconds: 3),
      );

      return status;
    } catch (e) {
      print('❌ Error processing trial payment: $e');
      rethrow;
    }
  }

  /// Process booking payment
  /// 
  /// Initiates payment for a booking request
  /// 
  /// Returns the final payment status
  static Future<FapshiPaymentStatus> processBookingPayment({
    required String bookingRequestId,
    required String phoneNumber,
    required double amount,
    required String paymentPlan,
  }) async {
    try {
      // Initiate payment
      final paymentResponse = await FapshiService.initiateDirectPayment(
        amount: amount.toInt(),
        phone: phoneNumber,
        externalId: 'booking_$bookingRequestId',
        message: 'Booking payment - $paymentPlan plan',
      );

      // Poll for payment status
      final status = await FapshiService.pollPaymentStatus(
        paymentResponse.transId,
        maxAttempts: 40,
        interval: const Duration(seconds: 3),
      );

      return status;
    } catch (e) {
      print('❌ Error processing booking payment: $e');
      rethrow;
    }
  }

  /// Verify payment status
  /// 
  /// Checks if a payment transaction was successful
  /// 
  /// Returns true if payment is successful, false otherwise
  static Future<bool> verifyPayment(String transactionId) async {
    try {
      final status = await FapshiService.getPaymentStatus(transactionId);
      return status.isSuccessful;
    } catch (e) {
      print('❌ Error verifying payment: $e');
      return false;
    }
  }
}

