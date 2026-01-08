import 'package:prepskul/core/services/supabase_service.dart';
import 'package:prepskul/core/services/log_service.dart';
import 'package:prepskul/features/booking/services/session_payment_service.dart';
import 'package:prepskul/features/payment/services/payment_request_service.dart';
import 'package:prepskul/features/payment/services/user_credits_service.dart';
import 'package:prepskul/core/services/notification_helper_service.dart';
import 'package:prepskul/features/sessions/services/meet_service.dart';
import 'package:prepskul/features/booking/services/recurring_session_service.dart';
import 'package:prepskul/features/booking/models/booking_request_model.dart';
import 'package:prepskul/features/messaging/services/conversation_lifecycle_service.dart';



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
      LogService.debug('🔔 Fapshi webhook received: $transactionId, status: $status, externalId: $externalId');

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
        LogService.warning('Unknown externalId pattern: $externalId');
        // Try to find by transaction ID in any payment table
        await _handleByTransactionId(
          transactionId: transactionId,
          status: normalizedStatus,
          failureReason: failureReason,
        );
      }

      LogService.success('Webhook processed successfully: $transactionId');
    } catch (e) {
      LogService.error('Error processing webhook: $e');
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
      LogService.debug('📝 Processing trial session payment: $trialSessionId');

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
              .maybeSingle();
          
          if (trial == null) {
            throw Exception('Trial session not found: $trialSessionId');
          }

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
          LogService.warning('Error generating Meet link: $e');
          // Don't fail the webhook if Meet link generation fails
        }

        // Create conversation for paid trial session
        try {
          final trial = await _supabase
              .from('trial_sessions')
              .select('learner_id, tutor_id')
              .eq('id', trialSessionId)
              .maybeSingle();
          
          if (trial != null) {
            await ConversationLifecycleService.createConversationForTrial(
              trialSessionId: trialSessionId,
              studentId: trial['learner_id'] as String,
              tutorId: trial['tutor_id'] as String,
            );
            LogService.success('Conversation created for paid trial: $trialSessionId');
          }
        } catch (e) {
          LogService.warning('Failed to create conversation for trial: $e');
          // Don't fail the webhook if conversation creation fails
        }

        // Send notifications
        await _sendTrialPaymentSuccessNotifications(trialSessionId);

        LogService.success('Trial session payment confirmed: $trialSessionId');
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

        LogService.warning('Trial session payment failed: $trialSessionId');
      }
    } catch (e) {
      LogService.error('Error handling trial session payment webhook: $e');
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
      LogService.info('Processing payment request payment: $paymentRequestId');

      // Get payment request first to check current status (idempotency check)
      final paymentRequest = await PaymentRequestService.getPaymentRequest(paymentRequestId);
      if (paymentRequest == null) {
        LogService.warning('Payment request not found: $paymentRequestId');
        return;
      }

      final currentStatus = paymentRequest['status'] as String?;
      final recurringSessionId = paymentRequest['recurring_session_id'] as String?;
      final bookingRequestId = paymentRequest['booking_request_id'] as String?;
      
      // Idempotency: If already paid, check if we still need to create recurring session or generate sessions
      if (currentStatus == 'paid' && status == 'SUCCESS') {
        LogService.info('Payment request already processed as paid: $paymentRequestId.');
        
        // Even if already paid, check if recurring session exists and sessions are generated
        if (recurringSessionId == null && bookingRequestId != null) {
          LogService.warning('⚠️ Payment is paid but recurring_session_id is missing. Creating recurring session...');
          // Continue to process recurring session creation below
        } else if (recurringSessionId != null) {
          // Check if individual sessions exist
          try {
            final existingSessions = await SupabaseService.client
                .from('individual_sessions')
                .select('id')
                .eq('recurring_session_id', recurringSessionId)
                .limit(1);
            
            if (existingSessions.isEmpty) {
              LogService.warning('⚠️ Payment is paid but individual sessions are missing. Generating sessions...');
              // Continue to process session generation below
            } else {
              LogService.info('Payment already processed and sessions exist. Skipping duplicate webhook.');
              return;
            }
          } catch (e) {
            LogService.warning('⚠️ Error checking for existing sessions: $e');
            // Continue to process
          }
        } else {
          LogService.info('Payment already processed. Skipping duplicate webhook.');
          return;
        }
      }

      if (status == 'SUCCESS') {
        // Payment successful - update status first (only if not already paid)
        if (currentStatus != 'paid') {
          await PaymentRequestService.updatePaymentRequestStatus(
            paymentRequestId,
            'paid',
            fapshiTransId: transactionId,
          );
        }

        // Reload payment request to get latest data
        final updatedPaymentRequest = await PaymentRequestService.getPaymentRequest(paymentRequestId);
        if (updatedPaymentRequest != null) {
          final bookingRequestId = updatedPaymentRequest['booking_request_id'] as String?;
          final studentId = updatedPaymentRequest['student_id'] as String;
          final tutorId = updatedPaymentRequest['tutor_id'] as String;
          var recurringSessionId = updatedPaymentRequest['recurring_session_id'] as String?;
          final paymentPlan = updatedPaymentRequest['payment_plan'] as String?;
          final monthlyTotal = updatedPaymentRequest['original_amount'] as num?;

          // If recurring_session_id is null, try to find it from booking_request_id
          // Note: request_id may be NULL due to FK constraint, so we primarily rely on payment_request link
          if (recurringSessionId == null && bookingRequestId != null) {
            LogService.warning('⚠️ recurring_session_id is null in payment request. Looking up from booking_request_id: $bookingRequestId');
            try {
              // Try to find by request_id first (may be NULL due to FK constraint to session_requests)
              var recurringSession = await SupabaseService.client
                  .from('recurring_sessions')
                  .select('id')
                  .eq('request_id', bookingRequestId)
                  .limit(1)
                  .maybeSingle();
              
              // If not found, the recurring session may not exist yet or request_id is NULL
              // We'll create it below if needed
              if (recurringSession != null) {
                recurringSessionId = recurringSession['id'] as String?;
                LogService.info('✅ Found recurring_session_id from request_id: $recurringSessionId');
                
                // Update payment request with the found recurring_session_id
                try {
                  await SupabaseService.client
                      .from('payment_requests')
                      .update({
                        'recurring_session_id': recurringSessionId,
                        'updated_at': DateTime.now().toIso8601String(),
                      })
                      .eq('id', paymentRequestId);
                  LogService.success('✅ Updated payment request with recurring_session_id');
                } catch (e) {
                  LogService.warning('⚠️ Failed to update payment request with recurring_session_id: $e');
                }
              } else {
                // Recurring session doesn't exist - create it now since payment is being made
                LogService.warning('⚠️ Recurring session not found for booking_request_id: $bookingRequestId');
                LogService.info('🔧 Creating missing recurring session from booking request...');
                try {
                  // Get booking request
                  final bookingRequestData = await SupabaseService.client
                      .from('booking_requests')
                      .select()
                      .eq('id', bookingRequestId)
                      .maybeSingle();
                  
                  if (bookingRequestData != null) {
                    // Import BookingRequest model
                    final bookingRequest = BookingRequest.fromJson(bookingRequestData);
                    
                    // Create recurring session
                    final recurringSessionData = await RecurringSessionService.createRecurringSessionFromBooking(
                      bookingRequest,
                      paymentRequestId: paymentRequestId,
                    );
                    
                    recurringSessionId = recurringSessionData['id'] as String;
                    LogService.success('✅ Created recurring session: $recurringSessionId');
                    
                    // Link payment request to recurring session
                    try {
                      await SupabaseService.client
                          .from('payment_requests')
                          .update({
                            'recurring_session_id': recurringSessionId,
                            'updated_at': DateTime.now().toIso8601String(),
                          })
                          .eq('id', paymentRequestId);
                      LogService.success('✅ Linked payment request to recurring session');
                    } catch (e) {
                      LogService.warning('⚠️ Failed to link payment request: $e');
                    }
                    
                    // Immediately generate individual sessions since payment is being made
                    LogService.info('💰 Payment successful - generating individual sessions immediately...');
                    try {
                      final sessionsGenerated = await RecurringSessionService.generateIndividualSessions(
                        recurringSessionId: recurringSessionId,
                        weeksAhead: 8,
                      );
                      LogService.success('✅ Generated $sessionsGenerated individual sessions immediately after payment');
                    } catch (e, stackTrace) {
                      LogService.error('❌ Failed to generate individual sessions immediately: $e');
                      LogService.error('📚 Stack trace: $stackTrace');
                      // Continue - sessions will be generated in the flow below
                    }
                  } else {
                    LogService.error('❌ Booking request not found: $bookingRequestId');
                  }
                } catch (e, stackTrace) {
                  LogService.error('❌ Failed to create recurring session: $e');
                  LogService.error('📚 Stack trace: $stackTrace');
                  // Continue - payment will still be processed
                }
              }
            } catch (e) {
              LogService.error('❌ Error looking up recurring_session_id: $e');
            }
          }

          // CRITICAL: Ensure recurring session is active and generate/activate sessions after payment
          if (recurringSessionId != null) {
            try {
              LogService.info('🔄 Processing recurring session after payment: $recurringSessionId');
              
              // Get recurring session to verify it exists
              final recurringSession = await SupabaseService.client
                  .from('recurring_sessions')
                  .select('id, status, start_date')
                  .eq('id', recurringSessionId)
                  .maybeSingle();
              
              if (recurringSession != null) {
                // Ensure the session is active
                await RecurringSessionService.updateSessionStatus(
                  recurringSessionId,
                  'active',
                );
                LogService.success('✅ Recurring session activated: $recurringSessionId');
                
                // ALWAYS generate sessions after payment (generateIndividualSessions handles duplicates)
                LogService.info('📅 Generating individual sessions after payment (will skip duplicates)');
                LogService.info('📅 Recurring session ID: $recurringSessionId');
                try {
                  LogService.info('🚀 Calling generateIndividualSessions...');
                  final sessionsGenerated = await RecurringSessionService.generateIndividualSessions(
                    recurringSessionId: recurringSessionId,
                    weeksAhead: 8,
                  );
                  LogService.success('✅ Individual sessions generated after payment: $recurringSessionId, count: $sessionsGenerated');
                  
                  // Verify sessions were actually created
                  final verifySessions = await SupabaseService.client
                      .from('individual_sessions')
                      .select('id, scheduled_date, status')
                      .eq('recurring_session_id', recurringSessionId)
                      .limit(10);
                  
                  LogService.info('✅ Verification: Found ${verifySessions.length} total sessions for recurring_session_id: $recurringSessionId');
                  if (verifySessions.isNotEmpty) {
                    LogService.info('✅ Sample session dates: ${verifySessions.take(5).map((s) => '${s['scheduled_date']} (${s['status']})').join(', ')}');
                  } else {
                    LogService.error('❌ CRITICAL: No sessions found after generation! This indicates a problem.');
                  }
                  
                  // Send notification to both tutor and student/parent that sessions are created
                  try {
                    // Get recurring session details for notification
                    final recurringSessionDetails = await SupabaseService.client
                        .from('recurring_sessions')
                        .select('tutor_id, student_id, learner_id, tutor_name, student_name, learner_name, frequency, days')
                        .eq('id', recurringSessionId)
                        .maybeSingle();
                    
                    if (recurringSessionDetails != null) {
                      final tutorId = recurringSessionDetails['tutor_id'] as String;
                      // Handle both student_id and learner_id (schema migration)
                      final studentId = recurringSessionDetails['student_id'] as String? ?? recurringSessionDetails['learner_id'] as String;
                      final tutorName = recurringSessionDetails['tutor_name'] as String? ?? 'Tutor';
                      final studentName = recurringSessionDetails['student_name'] as String? ?? recurringSessionDetails['learner_name'] as String? ?? 'Student';
                      final frequency = recurringSessionDetails['frequency'] as int? ?? 0;
                      final days = (recurringSessionDetails['days'] as List?)?.cast<String>() ?? [];
                      
                      // Notify student/parent
                      await NotificationHelperService.notifySessionsCreated(
                        studentId: studentId,
                        tutorId: tutorId,
                        recurringSessionId: recurringSessionId,
                        tutorName: tutorName,
                        studentName: studentName,
                        sessionCount: sessionsGenerated,
                        frequency: frequency,
                        days: days,
                      );
                      
                      // Notify tutor
                      await NotificationHelperService.notifyTutorSessionsCreated(
                        tutorId: tutorId,
                        studentId: studentId,
                        recurringSessionId: recurringSessionId,
                        studentName: studentName,
                        tutorName: tutorName,
                        sessionCount: sessionsGenerated,
                        frequency: frequency,
                        days: days,
                      );
                      
                      LogService.success('✅ Notifications sent for created sessions');
                    }
                  } catch (e) {
                    LogService.error('❌ Failed to send session creation notifications: $e');
                    // Don't fail payment if notification fails
                  }
                } catch (e, stackTrace) {
                  LogService.error('❌ Failed to generate individual sessions after payment: $e');
                  LogService.error('📚 Stack trace: $stackTrace');
                  // Don't fail payment if session generation fails - can be retried
                }
              } else {
                LogService.warning('⚠️ Recurring session not found: $recurringSessionId');
              }
            } catch (e) {
              LogService.error('❌ Error processing recurring session after payment: $e');
              // Don't fail the payment confirmation if session processing fails
            }
          } else {
            LogService.warning('⚠️ No recurring_session_id found in payment request: $paymentRequestId');
          }

          // Convert payment to credits (with idempotency check inside)
          try {
            final amount = (updatedPaymentRequest['amount'] as num).toDouble();
            final credits = await UserCreditsService.convertPaymentToCredits(
              paymentRequestId,
              amount,
            );
            LogService.success('Payment converted to credits: ${amount}XAF = $credits credits');
          } catch (e) {
            // Check if error is due to duplicate conversion (idempotency)
            if (e.toString().contains('already converted') || 
                e.toString().contains('duplicate')) {
              LogService.info('Credits already converted for payment request: $paymentRequestId');
            } else {
              LogService.warning('Error converting payment to credits: $e');
              // Don't fail the payment if credit conversion fails
            }
          }

          // Send success notifications
          await NotificationHelperService.notifyPaymentRequestPaid(
            paymentRequestId: paymentRequestId,
            bookingRequestId: bookingRequestId,
            studentId: studentId,
            tutorId: tutorId,
            amount: (updatedPaymentRequest['amount'] as num).toDouble(),
          );
        }

        LogService.success('Payment request payment confirmed: $paymentRequestId');
      } else if (status == 'FAILED' || status == 'EXPIRED') {
        // Payment failed - only update if not already failed (idempotency)
        if (currentStatus != 'failed') {
          await PaymentRequestService.updatePaymentRequestStatus(
            paymentRequestId,
            'failed',
            fapshiTransId: transactionId,
          );

          // Send failure notification
          if (paymentRequest != null) {
            final studentId = paymentRequest['student_id'] as String;
            await NotificationHelperService.notifyPaymentRequestFailed(
              paymentRequestId: paymentRequestId,
              studentId: studentId,
              reason: failureReason ?? 'Payment failed',
            );
          }
        }

        LogService.warning('Payment request payment failed: $paymentRequestId');
      }
    } catch (e) {
      LogService.error('Error handling payment request payment webhook: $e');
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
      LogService.debug('📚 Processing session payment: $sessionId');

      // Use existing session payment webhook handler
      await SessionPaymentService.handlePaymentWebhook(
        transactionId: transactionId,
        status: status,
        failureReason: failureReason,
      );

      LogService.success('Session payment webhook processed: $sessionId');
    } catch (e) {
      LogService.error('Error handling session payment webhook: $e');
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

      LogService.warning('Payment not found for transaction: $transactionId');
    } catch (e) {
      LogService.error('Error handling by transaction ID: $e');
    }
  }

  /// Send trial payment success notifications
  static Future<void> _sendTrialPaymentSuccessNotifications(String trialSessionId) async {
    try {
      final trial = await _supabase
          .from('trial_sessions')
          .select('learner_id, tutor_id, subject, meet_link, scheduled_date, scheduled_time, duration_minutes')
          .eq('id', trialSessionId)
          .maybeSingle();

      if (trial == null) {
        throw Exception('Trial session not found: $trialSessionId');
      }

      final learnerId = trial['learner_id'] as String;
      final tutorId = trial['tutor_id'] as String;
      final subject = trial['subject'] as String;
      final meetLink = trial['meet_link'] as String?;
      final scheduledDate = DateTime.parse(trial['scheduled_date'] as String);
      final scheduledTime = trial['scheduled_time'] as String;
      final durationMinutes = trial['duration_minutes'] as int? ?? 60;

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

      // Schedule session countdown reminders (24h, 1h, 15min before session)
      // This ensures reminders are scheduled for ALL paid sessions
      try {
        // Get names for reminders
        String tutorName = 'Tutor';
        String studentName = 'Student';
        
        try {
          final tutorProfile = await _supabase
              .from('profiles')
              .select('full_name')
              .eq('id', tutorId)
              .maybeSingle();
          tutorName = tutorProfile?['full_name'] as String? ?? 'Tutor';
        } catch (e) {
          LogService.warning('Could not fetch tutor name for reminders: $e');
        }
        
        try {
          final studentProfile = await _supabase
              .from('profiles')
              .select('full_name')
              .eq('id', learnerId)
              .maybeSingle();
          studentName = studentProfile?['full_name'] as String? ?? 'Student';
        } catch (e) {
          LogService.warning('Could not fetch student name for reminders: $e');
        }

        // Calculate session start datetime
        final timeParts = scheduledTime.split(':');
        final hour = int.tryParse(timeParts[0]) ?? 0;
        final minute = timeParts.length > 1 ? (int.tryParse(timeParts[1]) ?? 0) : 0;
        final sessionStart = DateTime(
          scheduledDate.year,
          scheduledDate.month,
          scheduledDate.day,
          hour,
          minute,
        );

        await NotificationHelperService.scheduleSessionReminders(
          tutorId: tutorId,
          studentId: learnerId,
          sessionId: trialSessionId,
          sessionType: 'trial',
          tutorName: tutorName,
          studentName: studentName,
          sessionStart: sessionStart,
          subject: subject,
        );
        
        LogService.success('Session countdown reminders scheduled after payment: $trialSessionId');
      } catch (e) {
        LogService.warning('Failed to schedule session reminders after payment: $e');
        // Don't fail payment notification if reminder scheduling fails
      }
    } catch (e) {
      LogService.warning('Error sending trial payment success notifications: $e');
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
          .maybeSingle();

      if (trial == null) {
        throw Exception('Trial session not found: $trialSessionId');
      }

      final learnerId = trial['learner_id'] as String;
      final subject = trial['subject'] as String;

      await NotificationHelperService.notifyTrialPaymentFailed(
        trialSessionId: trialSessionId,
        learnerId: learnerId,
        subject: subject,
        reason: reason ?? 'Payment failed',
      );
    } catch (e) {
      LogService.warning('Error sending trial payment failure notification: $e');
    }
  }
}
