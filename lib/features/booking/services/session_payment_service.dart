import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:prepskul/core/services/supabase_service.dart';
import 'package:prepskul/core/services/log_service.dart';
import 'package:prepskul/core/services/notification_service.dart';
import 'package:prepskul/core/services/notification_helper_service.dart';
import 'package:prepskul/features/payment/services/fapshi_service.dart';
import 'package:prepskul/features/payment/models/fapshi_transaction_model.dart';
import 'package:prepskul/features/booking/services/quality_assurance_service.dart';

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
          .maybeSingle();

      if (session == null) {
        throw Exception('Session not found: $sessionId');
      }

      final recurringData =
          session['recurring_sessions'] as Map<String, dynamic>;
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
          .maybeSingle();
      
      if (paymentResponse == null) {
        throw Exception('Failed to create session payment');
      }

      final paymentId = paymentResponse['id'] as String;

      // Create tutor_earnings record
      final earningsData = <String, dynamic>{
        'tutor_id': session['tutor_id'],
        'session_id': sessionId,
        'session_fee': sessionFee,
        'platform_fee': platformFee,
        'tutor_earnings': tutorEarnings,
        'earnings_status':
            'pending', // Will become 'active' when payment confirmed
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
      await _addToPendingBalance(
        session['tutor_id'] as String,
        tutorEarnings,
        paymentId,
      );

      // Send notification to tutor about earnings
      try {
        await _notifyTutorEarningsAdded(
          tutorId: session['tutor_id'] as String,
          sessionId: sessionId,
          earnings: tutorEarnings,
        );
      } catch (e) {
        LogService.warning('Error sending earnings notification: $e');
        // Don't fail payment creation if notification fails
      }

      LogService.success('Payment record created for session: $sessionId');
      LogService.debug(
        '✅ Earnings: ${tutorEarnings.toStringAsFixed(2)} XAF (85% of ${sessionFee.toStringAsFixed(2)} XAF)',
      );
      return paymentId;
    } catch (e) {
      LogService.error('Error creating session payment: $e');
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
            .maybeSingle();

        if (newPayment == null) {
          throw Exception('Payment not found for session: $sessionId');
        }

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
          .maybeSingle();

      if (finalPayment == null) {
        throw Exception('Payment not found for session: $sessionId');
      }

      final sessionFee = (finalPayment['session_fee'] as num).toDouble();
      final amount = sessionFee.toInt();

      // Verify authorization - must be student or parent
      final session =
          payment?['individual_sessions'] ??
          (await _supabase
              .from('individual_sessions')
              .select('learner_id, parent_id')
              .eq('id', sessionId)
              .maybeSingle());
      
      if (session == null) {
        throw Exception('Session not found: $sessionId');
      }

      final isStudent = session['learner_id'] == userId;
      final isParent = session['parent_id'] == userId;

      if (!isStudent && !isParent) {
        throw Exception(
          'Unauthorized: Only the student or parent can initiate payment',
        );
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

      LogService.debug(
        '✅ Payment initiated for session: $sessionId (Fapshi: ${paymentResponse.transId})',
      );
      return paymentResponse;
    } catch (e) {
      LogService.error('Error initiating payment: $e');
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
        LogService.warning('Payment not found for transaction: $transactionId');
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

        LogService.success('Payment confirmed for session: $sessionId');
      } else if (status == 'FAILED' ||
          status == 'failed' ||
          status == 'EXPIRED') {
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

        LogService.warning('Payment failed for session: $sessionId');
      }
    } catch (e) {
      LogService.error('Error handling payment webhook: $e');
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
          .maybeSingle();

      if (payment == null) {
        throw Exception('Payment not found for session: $sessionId');
      }

      if (payment['payment_status'] != 'paid') {
        throw Exception('Cannot refund: Payment not confirmed');
      }

      // Note: Fapshi refund API may not be available yet
      // When available, implement refund via Fapshi API:
      // final refundAmountValue = refundAmount ?? (payment['session_fee'] as num).toDouble();
      // final fapshiTransId = payment['fapshi_trans_id'] as String?;
      // await FapshiService.processRefund(transId: fapshiTransId, amount: refundAmountValue);
      
      // For now, mark as refunded in database (manual refund processing)
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

      // Note: Wallet balance reversal will be implemented when wallet system is complete
      // For now, earnings are cancelled which prevents payout

      LogService.success('Refund processed for session: $sessionId');
    } catch (e) {
      LogService.error('Error processing refund: $e');
      rethrow;
    }
  }

  /// Get payment status for a session
  static Future<Map<String, dynamic>?> getSessionPayment(
    String sessionId,
  ) async {
    try {
      final payment = await _supabase
          .from('session_payments')
          .select('*')
          .eq('session_id', sessionId)
          .maybeSingle();

      return payment;
    } catch (e) {
      LogService.error('Error fetching session payment: $e');
      return null;
    }
  }

  /// Get tutor's wallet balances
  ///
  /// Calculates pending and active balances from tutor_earnings
  /// Also processes any pending earnings that are ready to move to active (24-48h quality assurance period)
  static Future<Map<String, dynamic>> getTutorWalletBalances(
    String tutorId,
  ) async {
    try {
      // Process pending earnings that are ready to move to active balance
      // This runs automatically when tutor checks their wallet
      try {
        await QualityAssuranceService.processPendingEarningsToActive(qualityAssuranceHours: 24);
      } catch (e) {
        LogService.warning('Error processing pending earnings (non-blocking): $e');
        // Don't fail wallet balance fetch if processing fails
      }
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
      LogService.error('Error fetching wallet balances: $e');
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

      LogService.success('Added $amount XAF to pending balance for tutor: $tutorId');
    } catch (e) {
      LogService.warning('Error adding to pending balance: $e');
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
            'earnings_status': 'active',
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

      LogService.success('Moved $amount XAF to active balance for tutor: $tutorId');
    } catch (e) {
      LogService.warning('Error moving to active balance: $e');
    }
  }

  /// Process pending earnings that are ready to move to active balance
  /// 
  /// Checks for earnings that have been in pending status for 24-48 hours
  /// and automatically moves them to active balance after quality assurance period
  /// 
  /// This should be called periodically (e.g., on app startup, or via scheduled task)
  static Future<int> processPendingEarningsToActive({
    int qualityAssuranceHours = 24, // Default 24 hours, can be 24-48
  }) async {
    try {
      final now = DateTime.now();
      final cutoffTime = now.subtract(Duration(hours: qualityAssuranceHours));
      final cutoffTimeStr = cutoffTime.toIso8601String();

      LogService.debug('🔄 Processing pending earnings older than $qualityAssuranceHours hours...');

      // Find earnings that are:
      // 1. Status is 'pending'
      // 2. Payment was confirmed (payment_confirmed_at exists)
      // 3. Payment confirmed more than qualityAssuranceHours ago
      // 4. Not yet moved to active balance
      
      // First, find session_payments that were confirmed more than qualityAssuranceHours ago
      final confirmedPaymentsResponse = await _supabase
          .from('session_payments')
          .select('id, payment_confirmed_at')
          .eq('payment_status', 'paid')
          .not('payment_confirmed_at', 'is', null)
          .lt('payment_confirmed_at', cutoffTimeStr);
      
      final confirmedPayments = confirmedPaymentsResponse as List;
      
      if (confirmedPayments.isEmpty) {
        LogService.success('No confirmed payments older than $qualityAssuranceHours hours');
        return 0;
      }
      
      // Create a map of payment_id -> payment_confirmed_at for quick lookup
      final confirmedPaymentMap = <String, String>{};
      for (final payment in confirmedPayments) {
        final paymentId = payment['id'] as String;
        final confirmedAt = payment['payment_confirmed_at'] as String?;
        if (confirmedAt != null) {
          confirmedPaymentMap[paymentId] = confirmedAt;
        }
      }
      
      if (confirmedPaymentMap.isEmpty) {
        return 0;
      }
      
      // Get all pending earnings
      final allPendingEarningsResponse = await _supabase
          .from('tutor_earnings')
          .select('id, tutor_id, tutor_earnings, session_payment_id')
          .eq('earnings_status', 'pending')
          .eq('added_to_active_balance', false);
      
      final allPendingEarnings = allPendingEarningsResponse as List;
      
      // Filter to only those linked to confirmed payments
      final pendingEarnings = allPendingEarnings.where((earning) {
        final paymentId = earning['session_payment_id'] as String?;
        return paymentId != null && confirmedPaymentMap.containsKey(paymentId);
      }).toList();

      if (pendingEarnings.isEmpty) {
        LogService.success('No pending earnings ready to move to active balance');
        return 0;
      }

      LogService.info('Found ${pendingEarnings.length} pending earnings ready to move to active');

      int movedCount = 0;
      for (final earning in pendingEarnings) {
        try {
          final earningId = earning['id'] as String;
          final tutorId = earning['tutor_id'] as String;
          final tutorEarnings = (earning['tutor_earnings'] as num).toDouble();
          final paymentId = earning['session_payment_id'] as String?;

          if (paymentId == null) {
            LogService.warning('Skipping earning $earningId: no payment_id');
            continue;
          }

          // Move to active balance
          await _moveToActiveBalance(tutorId, tutorEarnings, paymentId);

          // Send notification to tutor
          try {
            await NotificationService.createNotification(
              userId: tutorId,
              type: 'earnings_activated',
              title: '💰 Earnings Available',
              message: '${tutorEarnings.toStringAsFixed(0)} XAF has been moved to your active balance and is now available for withdrawal.',
              priority: 'normal',
              actionUrl: '/earnings',
              actionText: 'View Earnings',
              icon: '💰',
              metadata: {
                'earning_id': earningId,
                'amount': tutorEarnings,
                'payment_id': paymentId,
              },
            );
          } catch (e) {
            LogService.warning('Error sending earnings activation notification: $e');
            // Don't fail the move if notification fails
          }

          movedCount++;
        } catch (e) {
          LogService.warning('Error processing earning ${earning['id']}: $e');
          // Continue with next earning
        }
      }

      LogService.success('Moved $movedCount earnings from pending to active balance');
      return movedCount;
    } catch (e) {
      LogService.error('Error processing pending earnings: $e');
      return 0;
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
        message:
            'Payment for your session has been confirmed. Earnings are now available.',
        priority: 'normal',
        actionUrl: '/earnings',
        actionText: 'View Earnings',
        icon: '💰',
        metadata: {'session_id': sessionId},
      );

      // Get student ID to notify
      final session = await _supabase
          .from('individual_sessions')
          .select('learner_id, parent_id')
          .eq('id', sessionId)
          .maybeSingle();

      if (session == null) {
        throw Exception('Session not found: $sessionId');
      }

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
          metadata: {'session_id': sessionId},
        );
      }
    } catch (e) {
      LogService.warning('Error sending payment confirmed notifications: $e');
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
          .maybeSingle();

      if (session == null) {
        throw Exception('Session not found: $sessionId');
      }

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
          metadata: {'session_id': sessionId},
        );
      }
    } catch (e) {
      LogService.warning('Error sending payment failed notification: $e');
    }
  }

  /// Notify tutor when earnings are added to pending balance
  static Future<void> _notifyTutorEarningsAdded({
    required String tutorId,
    required String sessionId,
    required double earnings,
  }) async {
    try {
      // Create in-app notification
      await NotificationService.createNotification(
        userId: tutorId,
        type: 'earnings_added',
        title: '💰 Earnings Added',
        message:
            '${earnings.toStringAsFixed(2)} XAF has been added to your pending balance. It will become active after payment confirmation.',
        priority: 'normal',
        actionUrl: '/earnings',
        actionText: 'View Earnings',
        icon: '💰',
        metadata: {
          'session_id': sessionId,
          'earnings': earnings,
          'status': 'pending',
        },
      );

      // Send email/push notification via API (if available)
      try {
        await NotificationHelperService.notifyTutorEarningsAdded(
          tutorId: tutorId,
          sessionId: sessionId,
          earnings: earnings,
        );
      } catch (e) {
        // Silently fail - in-app notification already sent
        LogService.warning('Could not send email/push notification for earnings: $e');
      }
    } catch (e) {
      LogService.warning('Error sending earnings notification: $e');
    }
  }
}
