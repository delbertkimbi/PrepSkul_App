import 'package:prepskul/core/services/supabase_service.dart';
import 'package:prepskul/features/booking/services/session_payment_service.dart';
import 'package:prepskul/features/payment/services/payment_request_service.dart';
import 'package:prepskul/core/services/notification_helper_service.dart';
import 'package:prepskul/features/sessions/services/meet_service.dart';

/// Fapshi Webhook Service
/// 
/// Centralized handler for all Fapshi payment webhooks
/// Routes to appropriate handler based on externalId pattern:
/// - trial_* → Trial session payment
/// - payment_request_* → Payment request payment
/// - session_* → Session payment
/// 
/// This service should be called from a webhook endpoint (Next.js API route)
/// or can be called directly from Flutter when polling payment status

class FapshiWebhookService {
  static final _supabase = SupabaseService.client;

  /// Handle Fapshi payment webhook
  /// 
  /// Main entry point for processing payment webhooks
  /// 
  /// Parameters:
  /// - [transactionId]: Fapshi transaction ID
  /// - [status]: Payment status (SUCCESS, SUCCESSFUL, FAILED, EXPIRED, etc.)
  /// - [externalId]: External ID used when initiating payment (e.g., "trial_123", "payment_request_456", "session_789")
  /// - [userId]: User ID from Fapshi (optional)
  /// - [amount]: Payment amount (optional, for verification)
  /// - [failureReason]: Reason for failure (optional)
  static Future<void> handleWebhook({
    required String transactionId,
    required String status,
    required String externalId,
    String? userId,
    double? amount,
    String? failureReason,
  }) async {
    try {
      print('🔔 Fapshi webhook received: $transactionId, status: $status, externalId: $externalId');

      // Normalize status
      final normalizedStatus = _normalizeStatus(status);

      // Route to appropriate handler based on externalId pattern
      if (externalId.startsWith('trial_')) {
        await _handleTrialSessionPayment(
          transactionId: transactionId,
          status: normalizedStatus,
          trialSessionId: externalId.replaceFirst('trial_', ''),
          failureReason: failureReason,
        );
      } else if (externalId.startsWith('payment_request_')) {
        await _handlePaymentRequestPayment(
          transactionId: transactionId,
          status: normalizedStatus,
          paymentRequestId: externalId.replaceFirst('payment_request_', ''),
          failureReason: failureReason,
        );
      } else if (externalId.startsWith('session_')) {
        await _handleSessionPayment(
          transactionId: transactionId,
          status: normalizedStatus,
          sessionId: externalId.replaceFirst('session_', ''),
          failureReason: failureReason,
        );
      } else {
        print('⚠️ Unknown externalId pattern: $externalId');
        // Try to find by transaction ID in any payment table
        await _handleByTransactionId(
          transactionId: transactionId,
          status: normalizedStatus,
          failureReason: failureReason,
        );
      }

      print('✅ Webhook processed successfully: $transactionId');
    } catch (e) {
      print('❌ Error processing webhook: $e');
      // Don't rethrow - webhook should not fail
      // Log error for monitoring
    }
  }

  /// Normalize payment status from Fapshi
  static String _normalizeStatus(String status) {
    final upperStatus = status.toUpperCase();
    if (upperStatus == 'SUCCESS' || upperStatus == 'SUCCESSFUL') {
      return 'SUCCESS';
    } else if (upperStatus == 'FAILED' || upperStatus == 'FAILURE') {
      return 'FAILED';
    } else if (upperStatus == 'EXPIRED' || upperStatus == 'TIMEOUT') {
      return 'EXPIRED';
    } else if (upperStatus == 'PENDING' || upperStatus == 'PROCESSING') {
      return 'PENDING';
    }
    return upperStatus;
  }

  /// Handle trial session payment webhook
  static Future<void> _handleTrialSessionPayment({
    required String transactionId,
    required String status,
    required String trialSessionId,
    String? failureReason,
  }) async {
    try {
      print('📝 Processing trial session payment: $trialSessionId');

      if (status == 'SUCCESS') {
        // Payment successful
        await _supabase
            .from('trial_sessions')
            .update({
              'payment_status': 'paid',
              'status': 'scheduled', // Update status to scheduled
              'fapshi_trans_id': transactionId,
              'payment_confirmed_at': DateTime.now().toIso8601String(),
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', trialSessionId);

        // Generate Meet link for online trials
        try {
          final trial = await _supabase
              .from('trial_sessions')
              .select('location, tutor_id, learner_id, scheduled_date, scheduled_time, duration_minutes')
              .eq('id', trialSessionId)
              .single();

          if (trial['location'] == 'online') {
            // Generate Meet link
            final meetLink = await MeetService.generateTrialMeetLink(
              trialSessionId: trialSessionId,
              tutorId: trial['tutor_id'] as String,
              studentId: trial['learner_id'] as String,
              scheduledDate: DateTime.parse(trial['scheduled_date'] as String),
              scheduledTime: trial['scheduled_time'] as String,
              durationMinutes: trial['duration_minutes'] as int,
            );

            // Update trial with Meet link
            await _supabase
                .from('trial_sessions')
                .update({'meet_link': meetLink})
                .eq('id', trialSessionId);
          }
        } catch (e) {
          print('⚠️ Error generating Meet link: $e');
          // Don't fail the webhook if Meet link generation fails
        }

        // Send notifications
        await _sendTrialPaymentSuccessNotifications(trialSessionId);

        print('✅ Trial session payment confirmed: $trialSessionId');
      } else if (status == 'FAILED' || status == 'EXPIRED') {
        // Payment failed
        await _supabase
            .from('trial_sessions')
            .update({
              'payment_status': 'unpaid',
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', trialSessionId);

        // Send failure notification
        await _sendTrialPaymentFailureNotification(trialSessionId, failureReason);

        print('⚠️ Trial session payment failed: $trialSessionId');
      }
    } catch (e) {
      print('❌ Error handling trial session payment webhook: $e');
      rethrow;
    }
  }

  /// Handle payment request payment webhook
  static Future<void> _handlePaymentRequestPayment({
    required String transactionId,
    required String status,
    required String paymentRequestId,
    String? failureReason,
  }) async {
    try {
      print('💰 Processing payment request payment: $paymentRequestId');

      if (status == 'SUCCESS') {
        // Payment successful
        await PaymentRequestService.updatePaymentRequestStatus(
          paymentRequestId,
          'paid',
          fapshiTransId: transactionId,
        );

        // Get payment request details for notifications
        final paymentRequest = await PaymentRequestService.getPaymentRequest(paymentRequestId);
        if (paymentRequest != null) {
          final bookingRequestId = paymentRequest['booking_request_id'] as String?;
          final studentId = paymentRequest['student_id'] as String;
          final tutorId = paymentRequest['tutor_id'] as String;

          // Send success notifications
          await NotificationHelperService.notifyPaymentRequestPaid(
            paymentRequestId: paymentRequestId,
            bookingRequestId: bookingRequestId,
            studentId: studentId,
            tutorId: tutorId,
            amount: (paymentRequest['amount'] as num).toDouble(),
          );
        }

        print('✅ Payment request payment confirmed: $paymentRequestId');
      } else if (status == 'FAILED' || status == 'EXPIRED') {
        // Payment failed
        await PaymentRequestService.updatePaymentRequestStatus(
          paymentRequestId,
          'failed',
          fapshiTransId: transactionId,
        );

        // Send failure notification
        final paymentRequest = await PaymentRequestService.getPaymentRequest(paymentRequestId);
        if (paymentRequest != null) {
          final studentId = paymentRequest['student_id'] as String;
          await NotificationHelperService.notifyPaymentRequestFailed(
            paymentRequestId: paymentRequestId,
            studentId: studentId,
            reason: failureReason ?? 'Payment failed',
          );
        }

        print('⚠️ Payment request payment failed: $paymentRequestId');
      }
    } catch (e) {
      print('❌ Error handling payment request payment webhook: $e');
      rethrow;
    }
  }

  /// Handle session payment webhook
  /// 
  /// Delegates to SessionPaymentService.handlePaymentWebhook
  static Future<void> _handleSessionPayment({
    required String transactionId,
    required String status,
    required String sessionId,
    String? failureReason,
  }) async {
    try {
      print('📚 Processing session payment: $sessionId');

      // Use existing session payment webhook handler
      await SessionPaymentService.handlePaymentWebhook(
        transactionId: transactionId,
        status: status,
        failureReason: failureReason,
      );

      print('✅ Session payment webhook processed: $sessionId');
    } catch (e) {
      print('❌ Error handling session payment webhook: $e');
      rethrow;
    }
  }

  /// Handle webhook by transaction ID (fallback)
  /// 
  /// Tries to find the payment in any table by transaction ID
  static Future<void> _handleByTransactionId({
    required String transactionId,
    required String status,
    String? failureReason,
  }) async {
    try {
      // Try trial_sessions
      final trial = await _supabase
          .from('trial_sessions')
          .select('id')
          .eq('fapshi_trans_id', transactionId)
          .maybeSingle();

      if (trial != null) {
        await _handleTrialSessionPayment(
          transactionId: transactionId,
          status: status,
          trialSessionId: trial['id'] as String,
          failureReason: failureReason,
        );
        return;
      }

      // Try payment_requests
      final paymentRequest = await _supabase
          .from('payment_requests')
          .select('id')
          .eq('fapshi_trans_id', transactionId)
          .maybeSingle();

      if (paymentRequest != null) {
        await _handlePaymentRequestPayment(
          transactionId: transactionId,
          status: status,
          paymentRequestId: paymentRequest['id'] as String,
          failureReason: failureReason,
        );
        return;
      }

      // Try session_payments
      final sessionPayment = await _supabase
          .from('session_payments')
          .select('id')
          .eq('fapshi_trans_id', transactionId)
          .maybeSingle();

      if (sessionPayment != null) {
        await SessionPaymentService.handlePaymentWebhook(
          transactionId: transactionId,
          status: status,
          failureReason: failureReason,
        );
        return;
      }

      print('⚠️ Payment not found for transaction: $transactionId');
    } catch (e) {
      print('❌ Error handling by transaction ID: $e');
    }
  }

  /// Send trial payment success notifications
  static Future<void> _sendTrialPaymentSuccessNotifications(String trialSessionId) async {
    try {
      final trial = await _supabase
          .from('trial_sessions')
          .select('learner_id, tutor_id, subject, meet_link')
          .eq('id', trialSessionId)
          .single();

      final learnerId = trial['learner_id'] as String;
      final tutorId = trial['tutor_id'] as String;
      final subject = trial['subject'] as String;
      final meetLink = trial['meet_link'] as String?;

      // Notify learner
      await NotificationHelperService.notifyTrialPaymentCompleted(
        trialSessionId: trialSessionId,
        learnerId: learnerId,
        tutorId: tutorId,
        subject: subject,
        meetLink: meetLink,
      );

      // Notify tutor
      await NotificationHelperService.notifyTrialPaymentReceived(
        trialSessionId: trialSessionId,
        tutorId: tutorId,
        learnerId: learnerId,
        subject: subject,
      );
    } catch (e) {
      print('⚠️ Error sending trial payment success notifications: $e');
    }
  }

  /// Send trial payment failure notification
  static Future<void> _sendTrialPaymentFailureNotification(
    String trialSessionId,
    String? reason,
  ) async {
    try {
      final trial = await _supabase
          .from('trial_sessions')
          .select('learner_id, subject')
          .eq('id', trialSessionId)
          .single();

      final learnerId = trial['learner_id'] as String;
      final subject = trial['subject'] as String;

      await NotificationHelperService.notifyTrialPaymentFailed(
        trialSessionId: trialSessionId,
        learnerId: learnerId,
        subject: subject,
        reason: reason ?? 'Payment failed',
      );
    } catch (e) {
      print('⚠️ Error sending trial payment failure notification: $e');
    }
  }
}

