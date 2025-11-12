import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:prepskul/core/services/supabase_service.dart';
import 'package:prepskul/core/services/notification_service.dart';
import 'package:prepskul/features/payment/services/fapshi_service.dart';
import 'package:prepskul/features/payment/models/fapshi_transaction_model.dart';

/// Session Payment Service
///
/// Handles payment processing for individual recurring sessions:
/// - Create payment records when session completes
/// - Initiate payment via Fapshi
/// - Handle payment webhooks
/// - Update payment status
/// - Calculate and update tutor earnings (85%)
/// - Update wallet balances (pending → active)
/// - Handle refunds
class SessionPaymentService {
  static SupabaseClient get _supabase => SupabaseService.client;

  /// Create payment record for a completed session
  ///
  /// Called automatically when session is completed
  /// Creates session_payment and tutor_earnings records
  static Future<String> createSessionPayment(String sessionId) async {
    try {
      // Get session and recurring session details
      final session = await _supabase
          .from('individual_sessions')
          .select('''
            id,
            tutor_id,
            learner_id,
            parent_id,
            recurring_session_id,
            recurring_sessions!inner(
              monthly_total,
              frequency
            )
          ''')
          .eq('id', sessionId)
          .single();

      final recurringData = session['recurring_sessions'] as Map<String, dynamic>;
      final monthlyTotal = (recurringData['monthly_total'] as num).toDouble();
      final frequency = recurringData['frequency'] as int;

      // Calculate session fee (monthly_total / (frequency * 4))
      // Assuming 4 weeks per month
      final sessionFee = (monthlyTotal / (frequency * 4)).toDouble();
      final platformFee = sessionFee * 0.15; // 15%
      final tutorEarnings = sessionFee * 0.85; // 85%

      final now = DateTime.now();

      // Create session_payment record
      final paymentData = <String, dynamic>{
        'session_id': sessionId,
        'session_fee': sessionFee,
        'platform_fee': platformFee,
        'tutor_earnings': tutorEarnings,
        'payment_status': 'unpaid',
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      };

      if (session['recurring_session_id'] != null) {
        paymentData['recurring_session_id'] = session['recurring_session_id'];
      }

      final paymentResponse = await _supabase
          .from('session_payments')
          .insert(paymentData)
          .select('id')
          .single();

      final paymentId = paymentResponse['id'] as String;

      // Create tutor_earnings record
      final earningsData = <String, dynamic>{
        'tutor_id': session['tutor_id'],
        'session_id': sessionId,
        'session_fee': sessionFee,
        'platform_fee': platformFee,
        'tutor_earnings': tutorEarnings,
        'earnings_status': 'pending', // Will become 'active' when payment confirmed
        'session_payment_id': paymentId,
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      };

      if (session['recurring_session_id'] != null) {
        earningsData['recurring_session_id'] = session['recurring_session_id'];
      }

      await _supabase.from('tutor_earnings').insert(earningsData);

      // Update session with payment_id
      await _supabase
          .from('individual_sessions')
          .update({'payment_id': paymentId})
          .eq('id', sessionId);

      // Add to pending balance
      await _addToPendingBalance(session['tutor_id'] as String, tutorEarnings, paymentId);

      print('✅ Payment record created for session: $sessionId');
      return paymentId;
    } catch (e) {
      print('❌ Error creating session payment: $e');
      rethrow;
    }
  }

  /// Initiate payment for a session
  ///
  /// Initiates Fapshi payment and updates payment record
  static Future<FapshiPaymentResponse> initiatePayment({
    required String sessionId,
    required String phoneNumber,
    String? studentName,
    String? studentEmail,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Get payment record
      final payment = await _supabase
          .from('session_payments')
          .select('''
            id,
            session_id,
            session_fee,
            payment_status,
            individual_sessions!inner(
              learner_id,
              parent_id
            )
          ''')
          .eq('session_id', sessionId)
          .maybeSingle();

      if (payment == null) {
        // Create payment record if it doesn't exist
        await createSessionPayment(sessionId);
        // Fetch it again
        final newPayment = await _supabase
            .from('session_payments')
            .select('session_fee, payment_status')
            .eq('session_id', sessionId)
            .single();
        
        if (newPayment['payment_status'] != 'unpaid') {
          throw Exception('Payment already processed');
        }
      } else {
        if (payment['payment_status'] != 'unpaid') {
          throw Exception('Payment already ${payment['payment_status']}');
        }
      }

      // Get final payment details
      final finalPayment = await _supabase
          .from('session_payments')
          .select('id, session_fee')
          .eq('session_id', sessionId)
          .single();

      final sessionFee = (finalPayment['session_fee'] as num).toDouble();
      final amount = sessionFee.toInt();

      // Verify authorization - must be student or parent
      final session = payment?['individual_sessions'] ?? 
          (await _supabase
              .from('individual_sessions')
              .select('learner_id, parent_id')
              .eq('id', sessionId)
              .single());

      final isStudent = session['learner_id'] == userId;
      final isParent = session['parent_id'] == userId;

      if (!isStudent && !isParent) {
        throw Exception('Unauthorized: Only the student or parent can initiate payment');
      }

      // Initiate Fapshi payment
      final paymentResponse = await FapshiService.initiateDirectPayment(
        amount: amount,
        phone: phoneNumber,
        externalId: 'session_$sessionId',
        userId: userId,
        name: studentName,
        email: studentEmail,
        message: 'Session payment - PrepSkul',
      );

      // Update payment record with Fapshi transaction ID
      await _supabase
          .from('session_payments')
          .update({
            'fapshi_trans_id': paymentResponse.transId,
            'payment_status': 'pending',
            'payment_initiated_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', finalPayment['id']);

      print('✅ Payment initiated for session: $sessionId (Fapshi: ${paymentResponse.transId})');
      return paymentResponse;
    } catch (e) {
      print('❌ Error initiating payment: $e');
      rethrow;
    }
  }

  /// Handle payment webhook from Fapshi
  ///
  /// Called when Fapshi sends payment status update
  static Future<void> handlePaymentWebhook({
    required String transactionId,
    required String status,
    String? failureReason,
  }) async {
    try {
      // Find payment by Fapshi transaction ID
      final payment = await _supabase
          .from('session_payments')
          .select('''
            id,
            session_id,
            tutor_earnings,
            payment_status,
            individual_sessions!inner(
              tutor_id
            )
          ''')
          .eq('fapshi_trans_id', transactionId)
          .maybeSingle();

      if (payment == null) {
        print('⚠️ Payment not found for transaction: $transactionId');
        return;
      }

      final paymentId = payment['id'] as String;
      final sessionId = payment['session_id'] as String;
      final tutorId = payment['individual_sessions']['tutor_id'] as String;
      final tutorEarnings = (payment['tutor_earnings'] as num).toDouble();

      final now = DateTime.now();

      if (status == 'SUCCESS' || status == 'success') {
        // Payment successful
        await _supabase
            .from('session_payments')
            .update({
              'payment_status': 'paid',
              'payment_confirmed_at': now.toIso8601String(),
              'updated_at': now.toIso8601String(),
            })
            .eq('id', paymentId);

        // Update tutor earnings to active
        await _supabase
            .from('tutor_earnings')
            .update({
              'earnings_status': 'active',
              'updated_at': now.toIso8601String(),
            })
            .eq('session_payment_id', paymentId);

        // Move from pending to active balance
        await _moveToActiveBalance(tutorId, tutorEarnings, paymentId);

        // Send notifications
        await _sendPaymentConfirmedNotifications(
          sessionId: sessionId,
          tutorId: tutorId,
        );

        print('✅ Payment confirmed for session: $sessionId');
      } else if (status == 'FAILED' || status == 'failed' || status == 'EXPIRED') {
        // Payment failed
        await _supabase
            .from('session_payments')
            .update({
              'payment_status': 'failed',
              'payment_failed_at': now.toIso8601String(),
              'updated_at': now.toIso8601String(),
            })
            .eq('id', paymentId);

        // Send notification
        await _sendPaymentFailedNotification(sessionId: sessionId);

        print('⚠️ Payment failed for session: $sessionId');
      }
    } catch (e) {
      print('❌ Error handling payment webhook: $e');
      // Don't rethrow - webhook should not fail
    }
  }

  /// Process refund for a session
  ///
  /// Handles refund processing via Fapshi
  static Future<void> processRefund({
    required String sessionId,
    required String reason,
    double? refundAmount,
  }) async {
    try {
      final payment = await _supabase
          .from('session_payments')
          .select('id, session_fee, fapshi_trans_id, payment_status')
          .eq('session_id', sessionId)
          .single();

      if (payment['payment_status'] != 'paid') {
        throw Exception('Cannot refund: Payment not confirmed');
      }

      // TODO: Process refund via Fapshi API when available
      // final refundAmountValue = refundAmount ?? (payment['session_fee'] as num).toDouble();
      // final fapshiTransId = payment['fapshi_trans_id'] as String?;
      
      // For now, just mark as refunded
      await _supabase
          .from('session_payments')
          .update({
            'payment_status': 'refunded',
            'refunded_at': DateTime.now().toIso8601String(),
            'refund_reason': reason,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', payment['id']);

      // Cancel tutor earnings
      await _supabase
          .from('tutor_earnings')
          .update({
            'earnings_status': 'cancelled',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('session_payment_id', payment['id']);

      // Remove from wallet (if already added)
      // TODO: Implement wallet balance reversal

      print('✅ Refund processed for session: $sessionId');
    } catch (e) {
      print('❌ Error processing refund: $e');
      rethrow;
    }
  }

  /// Get payment status for a session
  static Future<Map<String, dynamic>?> getSessionPayment(String sessionId) async {
    try {
      final payment = await _supabase
          .from('session_payments')
          .select('*')
          .eq('session_id', sessionId)
          .maybeSingle();

      return payment;
    } catch (e) {
      print('❌ Error fetching session payment: $e');
      return null;
    }
  }

  /// Get tutor's wallet balances
  ///
  /// Calculates pending and active balances from tutor_earnings
  static Future<Map<String, dynamic>> getTutorWalletBalances(String tutorId) async {
    try {
      // Pending balance (earnings_status = 'pending')
      final pendingEarnings = await _supabase
          .from('tutor_earnings')
          .select('tutor_earnings')
          .eq('tutor_id', tutorId)
          .eq('earnings_status', 'pending');

      double pendingBalance = 0;
      if (pendingEarnings.isNotEmpty) {
        for (final earning in pendingEarnings) {
          pendingBalance += (earning['tutor_earnings'] as num).toDouble();
        }
      }

      // Active balance (earnings_status = 'active')
      final activeEarnings = await _supabase
          .from('tutor_earnings')
          .select('tutor_earnings')
          .eq('tutor_id', tutorId)
          .eq('earnings_status', 'active');

      double activeBalance = 0;
      if (activeEarnings.isNotEmpty) {
        for (final earning in activeEarnings) {
          activeBalance += (earning['tutor_earnings'] as num).toDouble();
        }
      }

      return {
        'pending_balance': pendingBalance,
        'active_balance': activeBalance,
        'total_balance': pendingBalance + activeBalance,
      };
    } catch (e) {
      print('❌ Error fetching wallet balances: $e');
      return {
        'pending_balance': 0.0,
        'active_balance': 0.0,
        'total_balance': 0.0,
      };
    }
  }

  // ========================================
  // PRIVATE HELPER METHODS
  // ========================================

  /// Add earnings to pending balance
  static Future<void> _addToPendingBalance(
    String tutorId,
    double amount,
    String paymentId,
  ) async {
    try {
      await _supabase
          .from('tutor_earnings')
          .update({
            'added_to_pending_balance': true,
            'pending_balance_added_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('session_payment_id', paymentId);

      print('✅ Added $amount XAF to pending balance for tutor: $tutorId');
    } catch (e) {
      print('⚠️ Error adding to pending balance: $e');
    }
  }

  /// Move earnings from pending to active balance
  static Future<void> _moveToActiveBalance(
    String tutorId,
    double amount,
    String paymentId,
  ) async {
    try {
      await _supabase
          .from('tutor_earnings')
          .update({
            'added_to_active_balance': true,
            'active_balance_added_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('session_payment_id', paymentId);

      // Also update session_payments
      await _supabase
          .from('session_payments')
          .update({
            'earnings_added_to_wallet': true,
            'wallet_updated_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', paymentId);

      print('✅ Moved $amount XAF to active balance for tutor: $tutorId');
    } catch (e) {
      print('⚠️ Error moving to active balance: $e');
    }
  }

  /// Send payment confirmed notifications
  static Future<void> _sendPaymentConfirmedNotifications({
    required String sessionId,
    required String tutorId,
  }) async {
    try {
      // Notify tutor
      await NotificationService.createNotification(
        userId: tutorId,
        type: 'payment_confirmed',
        title: '💰 Payment Received',
        message: 'Payment for your session has been confirmed. Earnings are now available.',
        priority: 'normal',
        actionUrl: '/earnings',
        actionText: 'View Earnings',
        icon: '💰',
        metadata: {
          'session_id': sessionId,
        },
      );

      // Get student ID to notify
      final session = await _supabase
          .from('individual_sessions')
          .select('learner_id, parent_id')
          .eq('id', sessionId)
          .single();

      final studentId = session['learner_id'] ?? session['parent_id'];
      if (studentId != null) {
        await NotificationService.createNotification(
          userId: studentId as String,
          type: 'payment_confirmed',
          title: '✅ Payment Confirmed',
          message: 'Your session payment has been confirmed.',
          priority: 'normal',
          actionUrl: '/sessions/$sessionId',
          actionText: 'View Session',
          icon: '✅',
          metadata: {
            'session_id': sessionId,
          },
        );
      }
    } catch (e) {
      print('⚠️ Error sending payment confirmed notifications: $e');
    }
  }

  /// Send payment failed notification
  static Future<void> _sendPaymentFailedNotification({
    required String sessionId,
  }) async {
    try {
      final session = await _supabase
          .from('individual_sessions')
          .select('learner_id, parent_id')
          .eq('id', sessionId)
          .single();

      final studentId = session['learner_id'] ?? session['parent_id'];
      if (studentId != null) {
        await NotificationService.createNotification(
          userId: studentId as String,
          type: 'payment_failed',
          title: '⚠️ Payment Failed',
          message: 'Your session payment failed. Please try again.',
          priority: 'high',
          actionUrl: '/sessions/$sessionId/payment',
          actionText: 'Retry Payment',
          icon: '⚠️',
          metadata: {
            'session_id': sessionId,
          },
        );
      }
    } catch (e) {
      print('⚠️ Error sending payment failed notification: $e');
    }
  }
}
