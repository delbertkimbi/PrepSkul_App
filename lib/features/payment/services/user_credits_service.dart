import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:prepskul/core/services/supabase_service.dart';
import 'package:prepskul/core/services/log_service.dart';
import 'package:prepskul/core/services/notification_helper_service.dart';
import 'package:prepskul/features/payment/services/payment_request_service.dart';

/// User Credits Service
///
/// Handles the tiered credits system where:
/// - 1 credit = 100 XAF
/// - Credits are deducted per session based on tutor's per-session cost
/// - Credits are displayed as abstract units (e.g., "400 credits" not "40,000 XAF")
class UserCreditsService {
  static SupabaseClient get _supabase => SupabaseService.client;

  /// Credit conversion rate: 1 credit = 100 XAF
  static const int creditsPerXaf = 100;

  /// Convert XAF payment to credits
  ///
  /// Called after successful payment
  /// Formula: credits = (XAF_amount / 100).round()
  /// Example: 40,000 XAF = 400 credits
  /// 
  /// Idempotent: Checks if credits were already converted for this payment request
  static Future<int> convertPaymentToCredits(
    String paymentRequestId,
    double amountXaf,
  ) async {
    try {
      LogService.info('Converting payment to credits: $paymentRequestId, ${amountXaf}XAF');

      // Check if credits were already converted for this payment request (idempotency)
      final existingTransaction = await _supabase
          .from('credit_transactions')
          .select('id, amount')
          .eq('reference_id', paymentRequestId)
          .eq('reference_type', 'payment_request')
          .eq('type', 'purchase')
          .maybeSingle();

      if (existingTransaction != null) {
        final existingCredits = existingTransaction['amount'] as int;
        LogService.info('Credits already converted for payment request $paymentRequestId: $existingCredits credits');
        return existingCredits;
      }

      // Calculate credits: round to nearest integer
      final credits = (amountXaf / creditsPerXaf).round();
      
      if (credits <= 0) {
        throw Exception('Invalid credit amount: $credits (from ${amountXaf}XAF)');
      }

      // Get payment request to find user_id
      final paymentRequest = await _supabase
          .from('payment_requests')
          .select('student_id, status')
          .eq('id', paymentRequestId)
          .maybeSingle();

      if (paymentRequest == null) {
        throw Exception('Payment request not found: $paymentRequestId');
      }

      // Verify payment is actually paid
      final paymentStatus = paymentRequest['status'] as String?;
      if (paymentStatus != 'paid') {
        throw Exception('Payment request is not paid (status: $paymentStatus). Cannot convert to credits.');
      }

      final userId = paymentRequest['student_id'] as String;

      // Verify the authenticated user is the student who made the payment
      final currentUserId = SupabaseService.currentUser?.id;
      if (currentUserId != userId) {
        LogService.warning('Payment conversion: authenticated user ($currentUserId) does not match payment student ($userId). This may cause RLS issues.');
      }

      // Initialize user credits if doesn't exist
      await _initializeUserCredits(userId);

      // Get current balance
      final currentBalance = await getUserBalance(userId);

      // Calculate new balance
      final newBalance = currentBalance + credits;

      // Get current total_purchased to increment
      final currentCredits = await _supabase
          .from('user_credits')
          .select('total_purchased')
          .eq('user_id', userId)
          .maybeSingle();
      
      final currentTotalPurchased = (currentCredits?['total_purchased'] as num?)?.toInt() ?? 0;
      
      // Update user credits
      await _supabase
          .from('user_credits')
          .update({
            'balance': newBalance,
            'total_purchased': currentTotalPurchased + credits,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('user_id', userId);

      // Create transaction record
      await _createTransaction(
        userId: userId,
        type: 'purchase',
        amount: credits,
        amountXaf: amountXaf,
        balanceBefore: currentBalance,
        balanceAfter: newBalance,
        referenceId: paymentRequestId,
        referenceType: 'payment_request',
        description: 'Payment converted to credits',
      );

      LogService.success('Payment converted to credits: ${amountXaf}XAF = $credits credits (balance: $newBalance)');
      return credits;
    } catch (e) {
      LogService.error('Error converting payment to credits: $e');
      rethrow;
    }
  }

  /// Deduct credits for a completed session
  ///
  /// Called when session completes
  /// Formula: creditsNeeded = (sessionCostXaf / 100).ceil() (round up)
  /// Example: 5,000 XAF session = 50 credits
  static Future<bool> deductCreditsForSession(
    String sessionId,
    double sessionCostXaf,
  ) async {
    try {
      LogService.info('Deducting credits for session: $sessionId, ${sessionCostXaf}XAF');

      // Calculate credits needed (round UP to ensure full coverage)
      final creditsNeeded = (sessionCostXaf / creditsPerXaf).ceil();

      // Get session to find user_id
      final session = await _supabase
          .from('individual_sessions')
          .select('learner_id, parent_id, tutor_id')
          .eq('id', sessionId)
          .maybeSingle();

      if (session == null) {
        throw Exception('Session not found: $sessionId');
      }

      // Use learner_id or parent_id (whoever booked the session)
      final userId = session['learner_id'] as String? ?? session['parent_id'] as String?;
      if (userId == null) {
        throw Exception('No user ID found for session: $sessionId');
      }

      // Initialize user credits if doesn't exist
      await _initializeUserCredits(userId);

      // Get current balance
      final currentBalance = await getUserBalance(userId);

      // Check if sufficient credits
      if (currentBalance < creditsNeeded) {
        LogService.warning('Insufficient credits: need $creditsNeeded, have $currentBalance');
        return false;
      }

      // Calculate new balance
      final newBalance = currentBalance - creditsNeeded;

      // Get current total_spent to increment
      final currentCredits = await _supabase
          .from('user_credits')
          .select('total_spent')
          .eq('user_id', userId)
          .maybeSingle();
      
      final currentTotalSpent = (currentCredits?['total_spent'] as num?)?.toInt() ?? 0;

      // Update user credits
      await _supabase
          .from('user_credits')
          .update({
            'balance': newBalance,
            'total_spent': currentTotalSpent + creditsNeeded,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('user_id', userId);

      // Create transaction record
      final transactionId = await _createTransaction(
        userId: userId,
        type: 'deduction',
        amount: creditsNeeded,
        amountXaf: sessionCostXaf,
        balanceBefore: currentBalance,
        balanceAfter: newBalance,
        referenceId: sessionId,
        referenceType: 'session',
        description: 'Session completed - credits deducted',
      );

      // Create deduction record
      await _supabase.from('credit_deductions').insert({
        'session_id': sessionId,
        'user_id': userId,
        'credits_deducted': creditsNeeded,
        'session_cost_xaf': sessionCostXaf,
        'transaction_id': transactionId,
        'created_at': DateTime.now().toIso8601String(),
      });

      LogService.success('Credits deducted: $creditsNeeded credits (${sessionCostXaf}XAF) for session $sessionId (balance: $newBalance)');
      return true;
    } catch (e) {
      LogService.error('Error deducting credits for session: $e');
      rethrow;
    }
  }

  /// Get current credit balance for user
  ///
  /// Returns balance as integer credits (not XAF)
  static Future<int> getUserBalance(String userId) async {
    try {
      final credits = await _supabase
          .from('user_credits')
          .select('balance')
          .eq('user_id', userId)
          .maybeSingle();

      if (credits == null) {
        // Initialize if doesn't exist
        await _initializeUserCredits(userId);
        return 0;
      }

      return (credits['balance'] as num?)?.toInt() ?? 0;
    } catch (e) {
      LogService.error('Error getting user balance: $e');
      return 0;
    }
  }

  /// Check if balance is low and send notification if needed
  ///
  /// Threshold: 20% of monthly total (in credits)
  /// Example: 40,000 XAF monthly = 400 credits, threshold = 80 credits
  static Future<void> checkAndNotifyLowBalance(
    String userId,
    double monthlyTotalXaf,
  ) async {
    try {
      // Convert monthly total to credits
      final monthlyCredits = (monthlyTotalXaf / creditsPerXaf).round();
      
      // Calculate threshold (20% of monthly total in credits)
      final thresholdCredits = (monthlyCredits * 0.2).round();
      
      // Get current balance
      final balance = await getUserBalance(userId);

      LogService.debug('Checking low balance: balance=$balance, threshold=$thresholdCredits (monthly=$monthlyCredits credits)');

      if (balance < thresholdCredits) {
        // Check if notification already sent recently (prevent spam)
        final credits = await _supabase
            .from('user_credits')
            .select('last_low_balance_notification_at')
            .eq('user_id', userId)
            .maybeSingle();

        final lastNotification = credits?['last_low_balance_notification_at'] as String?;
        if (lastNotification != null) {
          final lastNotificationTime = DateTime.parse(lastNotification);
          final hoursSinceLastNotification = DateTime.now().difference(lastNotificationTime).inHours;
          
          // Don't send if notification sent in last 24 hours
          if (hoursSinceLastNotification < 24) {
            LogService.debug('Low balance notification already sent ${hoursSinceLastNotification}h ago, skipping');
            return;
          }
        }

        // Get recurring session to determine payment plan
        final recurringSession = await _supabase
            .from('recurring_sessions')
            .select('id, payment_plan, monthly_total')
            .eq('student_id', userId)
            .eq('status', 'active')
            .maybeSingle();

        String? paymentRequestId;
        if (recurringSession != null) {
          // Create payment request for next payment
          try {
            // Get booking request to create payment request
            final bookingRequest = await _supabase
                .from('booking_requests')
                .select('*')
                .eq('student_id', userId)
                .eq('status', 'approved')
                .order('created_at', ascending: false)
                .limit(1)
                .maybeSingle();

            if (bookingRequest != null) {
              // Import BookingRequest model to use it
              // For now, we'll create a minimal payment request
              final paymentPlan = recurringSession['payment_plan'] as String? ?? 'monthly';
              final monthlyTotal = (recurringSession['monthly_total'] as num).toDouble();
              
              // Calculate payment amount based on plan
              double paymentAmount;
              if (paymentPlan == 'weekly') {
                paymentAmount = monthlyTotal / 4;
              } else if (paymentPlan == 'biweekly' || paymentPlan == 'bi-weekly') {
                paymentAmount = monthlyTotal / 2;
              } else {
                paymentAmount = monthlyTotal; // monthly
              }

              // Create payment request
              final paymentRequest = await _supabase
                  .from('payment_requests')
                  .insert({
                    'student_id': userId,
                    'tutor_id': bookingRequest['tutor_id'],
                    'amount': paymentAmount,
                    'original_amount': monthlyTotal,
                    'payment_plan': paymentPlan,
                    'status': 'pending',
                    'due_date': DateTime.now().add(const Duration(days: 7)).toIso8601String(),
                    'description': 'Top up credits - low balance',
                    'metadata': {
                      'low_balance_trigger': true,
                      'current_balance': balance,
                      'threshold': thresholdCredits,
                    },
                    'created_at': DateTime.now().toIso8601String(),
                  })
                  .select('id')
                  .maybeSingle();

              paymentRequestId = paymentRequest?['id'] as String?;
            }
          } catch (e) {
            LogService.warning('Error creating payment request for low balance: $e');
          }
        }

        // Update last notification timestamp
        await _supabase
            .from('user_credits')
            .update({
              'last_low_balance_notification_at': DateTime.now().toIso8601String(),
            })
            .eq('user_id', userId);

        // Send notification
        await NotificationHelperService.notifyLowCreditsBalance(
          userId: userId,
          balance: balance.toDouble(),
          threshold: thresholdCredits.toDouble(),
          paymentRequestId: paymentRequestId,
        );

        LogService.info('Low balance notification sent: $balance credits remaining (threshold: $thresholdCredits)');
      }
    } catch (e) {
      LogService.error('Error checking low balance: $e');
      // Don't throw - this is a background check
    }
  }

  /// Calculate credits needed for a session
  ///
  /// Helper method to convert XAF session cost to credits
  /// Formula: (sessionCostXaf / 100).ceil() (round up)
  static int calculateCreditsForSession(double sessionCostXaf) {
    return (sessionCostXaf / creditsPerXaf).ceil();
  }

  /// Get credit transaction history
  ///
  /// Returns list of transactions (all amounts in credits)
  static Future<List<Map<String, dynamic>>> getCreditHistory(String userId) async {
    try {
      final transactions = await _supabase
          .from('credit_transactions')
          .select('*')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(50);

      return List<Map<String, dynamic>>.from(transactions);
    } catch (e) {
      LogService.error('Error getting credit history: $e');
      return [];
    }
  }

  /// Refund credits (for cancelled/rescheduled sessions)
  ///
  /// Refunds credits back to user's balance
  static Future<void> refundCredits(
    String userId,
    int credits,
    double amountXaf,
    String referenceId,
    String referenceType,
    String description,
  ) async {
    try {
      LogService.info('Refunding credits: $userId, $credits credits (${amountXaf}XAF)');

      // Initialize user credits if doesn't exist
      await _initializeUserCredits(userId);

      // Get current balance
      final currentBalance = await getUserBalance(userId);

      // Calculate new balance
      final newBalance = currentBalance + credits;

      // Get current total_spent to decrement (don't go negative)
      final currentCredits = await _supabase
          .from('user_credits')
          .select('total_spent')
          .eq('user_id', userId)
          .maybeSingle();
      
      final currentTotalSpent = (currentCredits?['total_spent'] as num?)?.toInt() ?? 0;
      final newTotalSpent = (currentTotalSpent - credits).clamp(0, double.infinity).toInt();

      // Update user credits
      await _supabase
          .from('user_credits')
          .update({
            'balance': newBalance,
            'total_spent': newTotalSpent,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('user_id', userId);

      // Create transaction record
      await _createTransaction(
        userId: userId,
        type: 'refund',
        amount: credits,
        amountXaf: amountXaf,
        balanceBefore: currentBalance,
        balanceAfter: newBalance,
        referenceId: referenceId,
        referenceType: referenceType,
        description: description,
      );

      LogService.success('Credits refunded: $credits credits (balance: $newBalance)');
    } catch (e) {
      LogService.error('Error refunding credits: $e');
      rethrow;
    }
  }

  /// Initialize user credits record if doesn't exist
  static Future<void> _initializeUserCredits(String userId) async {
    try {
      await _supabase
          .from('user_credits')
          .insert({
            'user_id': userId,
            'balance': 0,
            'total_purchased': 0,
            'total_spent': 0,
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .select()
          .maybeSingle();
    } catch (e) {
      // Ignore if already exists (unique constraint violation)
      if (!e.toString().contains('duplicate key')) {
        LogService.warning('Error initializing user credits (may already exist): $e');
      }
    }
  }

  /// Create a credit transaction record
  static Future<String> _createTransaction({
    required String userId,
    required String type,
    required int amount,
    required double amountXaf,
    required int balanceBefore,
    required int balanceAfter,
    String? referenceId,
    String? referenceType,
    String? description,
    Map<String, dynamic>? metadata,
  }) async {
    final transaction = await _supabase
        .from('credit_transactions')
        .insert({
          'user_id': userId,
          'type': type,
          'amount': amount,
          'amount_xaf': amountXaf,
          'balance_before': balanceBefore,
          'balance_after': balanceAfter,
          'reference_id': referenceId,
          'reference_type': referenceType,
          'description': description,
          'metadata': metadata,
          'created_at': DateTime.now().toIso8601String(),
        })
        .select('id')
        .maybeSingle();

    return transaction?['id'] as String? ?? '';
  }
}