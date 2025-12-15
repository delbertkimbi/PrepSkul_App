import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:prepskul/core/services/supabase_service.dart';
import 'package:prepskul/core/services/log_service.dart';
import 'package:prepskul/core/services/notification_service.dart';

/// Quality Assurance Service
///
/// Handles quality assurance checks for completed sessions:
/// - Auto-move pending earnings to active after 24-48h QA period
/// - Issue detection (late arrival, poor ratings, complaints)
/// - Fine calculation and deduction
/// - Refund processing
class QualityAssuranceService {
  static SupabaseClient get _supabase => SupabaseService.client;

  /// Process pending earnings and move to active after QA period
  ///
  /// Checks all pending earnings that have passed the quality assurance period
  /// (24-48 hours) and moves them to active balance if no issues are detected
  ///
  /// This should be called:
  /// - When tutor checks wallet (getTutorWalletBalances)
  /// - Via scheduled cron job (daily)
  /// - On app startup (optional)
  static Future<void> processPendingEarningsToActive({
    int qualityAssuranceHours = 24,
  }) async {
    try {
      LogService.debug('Processing pending earnings for quality assurance...');

      // Get all pending earnings that have passed QA period
      final cutoffTime = DateTime.now()
          .subtract(Duration(hours: qualityAssuranceHours))
          .toIso8601String();

      final pendingEarnings = await _supabase
          .from('tutor_earnings')
          .select('''
            id,
            tutor_id,
            session_id,
            session_payment_id,
            tutor_earnings,
            earnings_status,
            pending_balance_added_at,
            created_at,
            session_payments!inner(
              payment_status,
              payment_confirmed_at,
              individual_sessions!inner(
                session_ended_at,
                status
              )
            )
          ''')
          .eq('earnings_status', 'pending')
          .not('pending_balance_added_at', 'is', null)
          .lt('pending_balance_added_at', cutoffTime);

      if (pendingEarnings.isEmpty) {
        LogService.success('No pending earnings ready for QA processing');
        return;
      }

      LogService.info('Found ${pendingEarnings.length} pending earnings to process');

      int processed = 0;
      int skipped = 0;

      for (final earning in pendingEarnings) {
        try {
          final sessionPayment = earning['session_payments'] as Map<String, dynamic>?;
          final session = sessionPayment?['individual_sessions'] as Map<String, dynamic>?;
          
          // Skip if payment not confirmed
          if (sessionPayment?['payment_status'] != 'paid') {
            LogService.warning('Skipping earning ${earning['id']}: Payment not confirmed');
            skipped++;
            continue;
          }

          // Skip if session not completed
          if (session?['status'] != 'completed') {
            LogService.warning('Skipping earning ${earning['id']}: Session not completed');
            skipped++;
            continue;
          }

          final sessionId = earning['session_id'] as String;
          final paymentId = earning['session_payment_id'] as String;
          final tutorId = earning['tutor_id'] as String;
          final earningsAmount = (earning['tutor_earnings'] as num).toDouble();

          // Check for issues before moving to active
          final issues = await _detectIssues(sessionId);
          
          if (issues.hasIssues) {
            // Process fines or refunds based on issue severity
            await _processIssues(
              sessionId: sessionId,
              paymentId: paymentId,
              tutorId: tutorId,
              earningsAmount: earningsAmount,
              issues: issues,
            );
          } else {
            // No issues - move to active balance
            await _moveToActiveBalance(
              tutorId: tutorId,
              paymentId: paymentId,
              earningsAmount: earningsAmount,
            );
            processed++;
          }
        } catch (e) {
          LogService.error('Error processing earning ${earning['id']}: $e');
          skipped++;
        }
      }

      LogService.success('QA Processing complete: $processed moved to active, $skipped skipped');
    } catch (e) {
      LogService.error('Error processing pending earnings: $e');
      rethrow;
    }
  }

  /// Detect issues for a session
  ///
  /// Checks for:
  /// - Late arrival (tutor joined late)
  /// - Poor ratings (rating < 3)
  /// - Complaints in feedback
  /// - No-show (tutor didn't join)
  static Future<SessionIssues> _detectIssues(String sessionId) async {
    try {
      final issues = SessionIssues();

      // Get session details
      final session = await _supabase
          .from('individual_sessions')
          .select('''
            id,
            tutor_id,
            scheduled_time,
            session_started_at,
            tutor_joined_at,
            status,
            session_attendance!inner(
              user_id,
              joined_at,
              left_at
            )
          ''')
          .eq('id', sessionId)
          .maybeSingle();

      if (session == null) {
        return issues;
      }

      // Check for late arrival (tutor joined more than 5 minutes late)
      final scheduledTime = session['scheduled_time'] as String?;
      final tutorJoinedAt = session['tutor_joined_at'] as String?;
      
      if (scheduledTime != null && tutorJoinedAt != null) {
        try {
          // Parse scheduled time (format: "HH:mm")
          final timeParts = scheduledTime.split(':');
          final scheduledHour = int.parse(timeParts[0]);
          final scheduledMinute = int.parse(timeParts[1]);
          
          // Get session date
          final sessionDate = session['session_date'] as String?;
          if (sessionDate != null) {
            final sessionDateTime = DateTime.parse(sessionDate);
            final scheduledDateTime = DateTime(
              sessionDateTime.year,
              sessionDateTime.month,
              sessionDateTime.day,
              scheduledHour,
              scheduledMinute,
            );
            
            final joinedDateTime = DateTime.parse(tutorJoinedAt);
            final lateMinutes = joinedDateTime.difference(scheduledDateTime).inMinutes;
            
            if (lateMinutes > 5) {
              issues.isLate = true;
              issues.lateMinutes = lateMinutes;
              LogService.warning('Late arrival detected: $lateMinutes minutes late');
            }
          }
        } catch (e) {
          LogService.warning('Error checking late arrival: $e');
        }
      }

      // Check for no-show (tutor never joined)
      if (tutorJoinedAt == null && session['status'] == 'completed') {
        issues.isNoShow = true;
        LogService.warning('No-show detected: Tutor never joined');
      }

      // Check feedback for poor ratings and complaints
      final feedback = await _supabase
          .from('session_feedback')
          .select('student_rating, student_review, student_what_could_improve')
          .eq('session_id', sessionId)
          .maybeSingle();

      if (feedback != null) {
        final rating = feedback['student_rating'] as int?;
        if (rating != null && rating < 3) {
          issues.hasPoorRating = true;
          issues.rating = rating;
          LogService.warning('Poor rating detected: $rating stars');
        }

        // Check for complaint keywords in review or improvement feedback
        final review = feedback['student_review'] as String? ?? '';
        final improvement = feedback['student_what_could_improve'] as String? ?? '';
        final combinedText = (review + ' ' + improvement).toLowerCase();

        final complaintKeywords = [
          'terrible',
          'awful',
          'horrible',
          'waste',
          'disappointed',
          'complaint',
          'refund',
          'unsatisfied',
          'poor quality',
          'not worth',
        ];

        for (final keyword in complaintKeywords) {
          if (combinedText.contains(keyword)) {
            issues.hasComplaint = true;
            LogService.warning('Complaint detected in feedback');
            break;
          }
        }
      }

      return issues;
    } catch (e) {
      LogService.error('Error detecting issues: $e');
      return SessionIssues(); // Return empty issues on error
    }
  }

  /// Process detected issues
  ///
  /// Applies fines or refunds based on issue severity
  static Future<void> _processIssues({
    required String sessionId,
    required String paymentId,
    required String tutorId,
    required double earningsAmount,
    required SessionIssues issues,
  }) async {
    try {
      double fineAmount = 0.0;
      bool shouldRefund = false;
      String issueReason = '';

      // Calculate fines based on issues
      if (issues.isNoShow) {
        // No-show: Full refund to student
        shouldRefund = true;
        issueReason = 'Tutor did not attend the session (no-show)';
      } else if (issues.hasComplaint && issues.hasPoorRating) {
        // Severe complaint + poor rating: 50% fine
        fineAmount = earningsAmount * 0.5;
        issueReason = 'Poor rating (${issues.rating} stars) and complaint in feedback';
      } else if (issues.hasPoorRating) {
        // Poor rating only: 20% fine
        fineAmount = earningsAmount * 0.2;
        issueReason = 'Poor rating (${issues.rating} stars)';
      } else if (issues.isLate) {
        // Late arrival: 10% fine (min 500 XAF, max 2000 XAF)
        fineAmount = earningsAmount * 0.1;
        if (fineAmount < 500) fineAmount = 500;
        if (fineAmount > 2000) fineAmount = 2000;
        issueReason = 'Late arrival (${issues.lateMinutes} minutes late)';
      } else if (issues.hasComplaint) {
        // Complaint only: 15% fine
        fineAmount = earningsAmount * 0.15;
        issueReason = 'Complaint in feedback';
      }

      if (shouldRefund) {
        // Process full refund
        await _processRefund(
          sessionId: sessionId,
          paymentId: paymentId,
          tutorId: tutorId,
          refundAmount: earningsAmount,
          reason: issueReason,
        );
      } else if (fineAmount > 0) {
        // Apply fine and move remaining to active
        final remainingAmount = earningsAmount - fineAmount;
        
        // Update earnings with fine
        await _supabase
            .from('tutor_earnings')
            .update({
              'earnings_status': 'active',
              'tutor_earnings': remainingAmount,
              'fine_amount': fineAmount,
              'fine_reason': issueReason,
              'added_to_active_balance': true,
              'active_balance_added_at': DateTime.now().toIso8601String(),
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('session_payment_id', paymentId);

        // Record fine in session_payments
        await _supabase
            .from('session_payments')
            .update({
              'fine_applied': true,
              'fine_amount': fineAmount,
              'fine_reason': issueReason,
              'earnings_added_to_wallet': true,
              'wallet_updated_at': DateTime.now().toIso8601String(),
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', paymentId);

        // Notify tutor of fine
        await NotificationService.createNotification(
          userId: tutorId,
          type: 'fine_applied',
          title: '⚠️ Fine Applied',
          message: 'A fine of ${fineAmount.toStringAsFixed(0)} XAF was applied due to: $issueReason. Remaining earnings: ${remainingAmount.toStringAsFixed(0)} XAF.',
          priority: 'normal',
          actionUrl: '/earnings',
          actionText: 'View Earnings',
          icon: '⚠️',
          metadata: {
            'session_id': sessionId,
            'payment_id': paymentId,
            'fine_amount': fineAmount,
            'reason': issueReason,
          },
        );

        LogService.success('Fine applied: ${fineAmount.toStringAsFixed(0)} XAF, remaining: ${remainingAmount.toStringAsFixed(0)} XAF');
      } else {
        // No action needed, move to active
        await _moveToActiveBalance(
          tutorId: tutorId,
          paymentId: paymentId,
          earningsAmount: earningsAmount,
        );
      }
    } catch (e) {
      LogService.error('Error processing issues: $e');
      rethrow;
    }
  }

  /// Move earnings to active balance
  static Future<void> _moveToActiveBalance({
    required String tutorId,
    required String paymentId,
    required double earningsAmount,
  }) async {
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

      await _supabase
          .from('session_payments')
          .update({
            'earnings_added_to_wallet': true,
            'wallet_updated_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', paymentId);

      LogService.success('Moved ${earningsAmount.toStringAsFixed(0)} XAF to active balance for tutor: $tutorId');
    } catch (e) {
      LogService.error('Error moving to active balance: $e');
      rethrow;
    }
  }

  /// Process refund for a session
  ///
  /// Refunds the full session fee to the student/parent
  static Future<void> _processRefund({
    required String sessionId,
    required String paymentId,
    required String tutorId,
    required double refundAmount,
    required String reason,
  }) async {
    try {
      // Get session to find student/parent
      final session = await _supabase
          .from('individual_sessions')
          .select('learner_id, parent_id, session_payments!inner(session_fee)')
          .eq('id', sessionId)
          .single();

      final studentId = session['learner_id'] as String?;
      final parentId = session['parent_id'] as String?;
      final sessionFee = session['session_payments']['session_fee'] as num?;

      // Update earnings status to cancelled
      await _supabase
          .from('tutor_earnings')
          .update({
            'earnings_status': 'cancelled',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('session_payment_id', paymentId);

      // Update payment status to refunded
      await _supabase
          .from('session_payments')
          .update({
            'payment_status': 'refunded',
            'refunded_at': DateTime.now().toIso8601String(),
            'refund_reason': reason,
            'refund_amount': sessionFee?.toDouble(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', paymentId);

      // TODO: Process actual refund via Fapshi or points system
      // For now, just mark as refunded

      // Notify student/parent
      final userId = studentId ?? parentId;
      if (userId != null) {
        await NotificationService.createNotification(
          userId: userId,
          type: 'refund_processed',
          title: '💰 Refund Processed',
          message: 'A refund of ${sessionFee?.toStringAsFixed(0) ?? 'N/A'} XAF has been processed for your session. Reason: $reason',
          priority: 'normal',
          actionUrl: '/payments',
          actionText: 'View Payments',
          icon: '💰',
          metadata: {
            'session_id': sessionId,
            'payment_id': paymentId,
            'refund_amount': sessionFee,
            'reason': reason,
          },
        );
      }

      // Notify tutor
      await NotificationService.createNotification(
        userId: tutorId,
        type: 'earnings_cancelled',
        title: '⚠️ Earnings Cancelled',
        message: 'Your earnings for this session were cancelled due to: $reason. A refund has been processed.',
        priority: 'normal',
        actionUrl: '/earnings',
        actionText: 'View Earnings',
        icon: '⚠️',
        metadata: {
          'session_id': sessionId,
          'payment_id': paymentId,
          'reason': reason,
        },
      );

      LogService.success('Refund processed: ${sessionFee?.toStringAsFixed(0) ?? 'N/A'} XAF for session: $sessionId');
    } catch (e) {
      LogService.error('Error processing refund: $e');
      rethrow;
    }
  }
}

/// Session Issues Model
///
/// Tracks detected issues for a session
class SessionIssues {
  bool isLate = false;
  int lateMinutes = 0;
  bool isNoShow = false;
  bool hasPoorRating = false;
  int? rating;
  bool hasComplaint = false;

  bool get hasIssues => isLate || isNoShow || hasPoorRating || hasComplaint;
}


