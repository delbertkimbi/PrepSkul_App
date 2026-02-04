/**
 * Notification Helper Service
 * 
 * Centralized service for sending notifications for all events
 * 
 * NOTIFICATION STRATEGY:
 * ======================
 * 
 * 1. IN-APP NOTIFICATIONS (Always Sent)
 *    - Created directly in Supabase notifications table
 *    - Always works, even if API is unavailable
 *    - Real-time updates via Supabase Realtime
 *    - Visible in app notification bell and list
 * 
 * 2. PUSH NOTIFICATIONS (Sent via API)
 *    - Sent via Next.js API using Firebase Admin SDK
 *    - Requires API to be deployed and accessible
 *    - Works on Android, iOS, and Web
 *    - Shows system notification with sound
 *    - User taps notification → Opens app → Navigates to content
 * 
 * 3. EMAIL NOTIFICATIONS (Sent via API)
 *    - Sent via Next.js API using Resend
 *    - Requires API to be deployed and accessible
 *    - Branded HTML email templates
 *    - Deep links to app content
 * 
 * FLOW:
 * -----
 * 1. Always create in-app notification first (guaranteed to work)
 * 2. Then call API to send push + email (optional, fails silently if API unavailable)
 * 
 * This ensures users always get notified via in-app, and get push/email
 * when the API is available.
 */

import 'package:prepskul/core/services/notification_service.dart';
import 'package:prepskul/core/services/log_service.dart';
import 'package:prepskul/core/services/pricing_service.dart';
import 'package:prepskul/core/services/supabase_service.dart';
import 'package:prepskul/core/config/app_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;

class NotificationHelperService {
  // Get API base URL from AppConfig (with localhost detection for local development)
  static String get _apiBaseUrl => AppConfig.effectiveApiBaseUrl;

  /// Send notification via API (handles in-app, push, and email)
  /// 
  /// NOTIFICATION TYPES SENT:
  /// - In-App: ALWAYS sent (created directly in Supabase)
  /// - Push: Sent via API (Firebase Admin SDK on Next.js server)
  /// - Email: Sent via API (Resend, controlled by sendEmail parameter)
  /// 
  /// If API is unavailable, only in-app notification is sent (silent fail).
  static Future<void> _sendNotificationViaAPI({
    required String userId,
    required String type,
    required String title,
    required String message,
    String priority = 'normal',
    String? actionUrl,
    String? actionText,
    String? icon,
    Map<String, dynamic>? metadata,
    bool sendEmail = true,
    bool sendPush = true, // Push notifications are always sent when API is available
  }) async {
    // STEP 1: Always create in-app notification first (this always works)
    // This ensures users are notified even if API is unavailable
    await NotificationService.createNotification(
      userId: userId,
      type: type,
      title: title,
      message: message,
      priority: priority,
      actionUrl: actionUrl,
      actionText: actionText,
      icon: icon,
      metadata: metadata
          );

    // STEP 2: Try to send push + email via API (optional - API might not be deployed)
    // The API endpoint handles:
    // - Push notifications (Firebase Admin SDK)
    // - Email notifications (Resend, if sendEmail is true)
    try {
      final response = await http.post(
        Uri.parse('$_apiBaseUrl/notifications/send'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'userId': userId,
          'type': type,
          'title': title,
          'message': message,
          'priority': priority,
          'actionUrl': actionUrl,
          'actionText': actionText,
          'icon': icon,
          'metadata': metadata,
          'sendEmail': sendEmail,
          'sendPush': sendPush, // Explicitly include push notification flag
        }),
      ).timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          throw TimeoutException('Notification API request timed out');
        }
          );

      if (response.statusCode == 200) {
        // Success - push + email notifications sent via API
        // In-app notification already created above
        // All three notification types delivered:
        // ✅ In-app (Supabase)
        // ✅ Push (Firebase via API)
        // ✅ Email (Resend via API, if sendEmail=true)
        LogService.success('Notification sent via API: $type to user $userId');
      } else {
        // API returned error status code
        LogService.warning('Notification API returned status ${response.statusCode}: ${response.body}');
        // Log error but don't throw - in-app notification already created
        if (response.statusCode == 429) {
          LogService.warning('Rate limit detected for notification API. Email may not have been sent.');
        } else if (response.statusCode >= 500) {
          LogService.warning('Server error in notification API. Email may not have been sent.');
        }
      }
      // If API returns error, in-app notification is still created (silent fail)
    } catch (e) {
      // API call failed (network error, timeout, or API not deployed)
      // This is expected if API is not deployed - in-app notification already created above
      // Log error for debugging but don't throw
      if (e is TimeoutException) {
        LogService.warning('Notification API request timed out. In-app notification still created.');
      } else {
        LogService.warning('Notification API call failed: $e. In-app notification still created.');
      }
      // Silent fail - notification still works via in-app
      // User will see notification when they open the app
    }
  }

  /// Send tutor onboarding reminder (in-app + email + push via API).
  /// Use when tutor skips onboarding or when tutor home detects incomplete onboarding.
  /// [metadata] may include onboarding_skipped, onboarding_complete, and reminder_stage
  /// (e.g. missing_video, missing_id, missing_docs) for stage-specific email/push content.
  static Future<void> sendOnboardingReminder({
    required String userId,
    required String title,
    required String message,
    String? actionUrl,
    Map<String, dynamic>? metadata,
  }) async {
    await _sendNotificationViaAPI(
      userId: userId,
      type: 'onboarding_reminder',
      title: title,
      message: message,
      priority: 'high',
      actionUrl: actionUrl ?? '/tutor-onboarding',
      actionText: 'Complete Profile',
      icon: '🎓',
      metadata: metadata,
      sendEmail: true,
      sendPush: true,
    );
  }

  // ============================================
  // BOOKING REQUEST NOTIFICATIONS
  // ============================================

  /// Notify tutor about new booking request
  static Future<void> notifyBookingRequestCreated({
    required String tutorId,
    required String studentId,
    required String requestId,
    required String studentName,
    required String subject,
    String? senderAvatarUrl,
  }) async {
    await _sendNotificationViaAPI(
      userId: tutorId,
      type: 'booking_request',
      title: '🎓 New Booking Request',
      message: '$studentName wants to book sessions for $subject. Review and respond to the request.',
      priority: 'high',
      actionUrl: '/bookings/requests/$requestId',
      actionText: 'View Request',
      icon: '🎓',
      metadata: {
        'request_id': requestId,
        'student_id': studentId,
        'student_name': studentName,
        'subject': subject,
        if (senderAvatarUrl != null) 'sender_avatar_url': senderAvatarUrl,
        'sender_initials': studentName.isNotEmpty ? studentName[0].toUpperCase() : null,
      },
      sendEmail: true
          );
  }

  /// Notify student/parent when tutor accepts booking request
  /// 
  /// Includes payment request ID for auto-launching payment screen
  static Future<void> notifyBookingRequestAccepted({
    required String studentId,
    required String tutorId,
    required String requestId,
    required String tutorName,
    required String subject,
    String? paymentRequestId, // Payment request ID (created on approval)
    String? senderAvatarUrl,
  }) async {
    // Action URL: Navigate to payment if payment request exists, otherwise to booking details
    final actionUrl = paymentRequestId != null
        ? '/payments/$paymentRequestId'
        : '/bookings/$requestId';
    
    final actionText = paymentRequestId != null
        ? 'Pay Now'
        : 'View Booking';

    final message = paymentRequestId != null
        ? '$tutorName has accepted your booking request for $subject. Please proceed to payment.'
        : '$tutorName has accepted your booking request for $subject. Your sessions are now confirmed!';

    await _sendNotificationViaAPI(
      userId: studentId,
      type: 'booking_approved', // Changed from 'booking_accepted' to match plan
      title: 'Booking Approved',
      message: message,
      priority: 'high',
      actionUrl: actionUrl,
      actionText: actionText,
      icon: '',
      metadata: {
        'request_id': requestId,
        'tutor_id': tutorId,
        'tutor_name': tutorName,
        'subject': subject,
        if (paymentRequestId != null) 'payment_request_id': paymentRequestId,
        if (senderAvatarUrl != null) 'sender_avatar_url': senderAvatarUrl,
        'sender_initials': tutorName.isNotEmpty ? tutorName[0].toUpperCase() : null,
      },
      sendEmail: true
          );
  }

  /// Notify student/parent when tutor rejects booking request
  static Future<void> notifyBookingRequestRejected({
    required String studentId,
    required String tutorId,
    required String requestId,
    required String tutorName,
    String? rejectionReason,
    String? senderAvatarUrl,
  }) async {
    final message = rejectionReason != null
        ? '$tutorName has declined your booking request. Reason: $rejectionReason'
        : '$tutorName has declined your booking request.';

    await _sendNotificationViaAPI(
      userId: studentId,
      type: 'booking_rejected',
      title: '⚠️ Booking Declined',
      message: message,
      priority: 'normal',
      actionUrl: '/bookings/requests',
      actionText: 'Find Another Tutor',
      icon: '⚠️',
      metadata: {
        'request_id': requestId,
        'tutor_id': tutorId,
        'tutor_name': tutorName,
        'rejection_reason': rejectionReason,
        if (senderAvatarUrl != null) 'sender_avatar_url': senderAvatarUrl,
        'sender_initials': tutorName.isNotEmpty ? tutorName[0].toUpperCase() : null,
      },
      sendEmail: true
          );
  }

  /// Notify parent/student about multi-learner booking acceptance (partial or full)
  /// 
  /// When tutor accepts some learners in a multi-learner booking:
  /// - Lists accepted learners
  /// - Mentions declined learners if any
  /// - Provides payment link if payment request created
  static Future<void> notifyMultiLearnerBookingAccepted({
    required String studentId,
    required String tutorId,
    required String requestId,
    required String tutorName,
    required List<String> acceptedLearners,
    List<String>? declinedLearners,
    String? paymentRequestId,
    String? senderAvatarUrl,
  }) async {
    final actionUrl = paymentRequestId != null
        ? '/payments/$paymentRequestId'
        : '/bookings/$requestId';
    
    final actionText = paymentRequestId != null
        ? 'Pay Now'
        : 'View Booking';

    // Build message based on acceptance status
    String message;
    if (declinedLearners != null && declinedLearners.isNotEmpty) {
      // Partial acceptance
      final acceptedList = acceptedLearners.join(', ');
      final declinedList = declinedLearners.join(', ');
      message = '$tutorName has accepted your booking for: $acceptedList. '
          'The following learners were declined: $declinedList. '
          '${paymentRequestId != null ? 'Please proceed to payment for accepted learners.' : 'Your sessions are now confirmed for accepted learners!'}';
    } else {
      // Full acceptance
      final acceptedList = acceptedLearners.join(', ');
      message = '$tutorName has accepted your booking request for: $acceptedList. '
          '${paymentRequestId != null ? 'Please proceed to payment.' : 'Your sessions are now confirmed!'}';
    }

    await _sendNotificationViaAPI(
      userId: studentId,
      type: 'booking_approved',
      title: 'Booking Approved',
      message: message,
      priority: 'high',
      actionUrl: actionUrl,
      actionText: actionText,
      icon: '✅',
      metadata: {
        'request_id': requestId,
        'tutor_id': tutorId,
        'tutor_name': tutorName,
        'accepted_learners': acceptedLearners,
        if (declinedLearners != null && declinedLearners.isNotEmpty) 'declined_learners': declinedLearners,
        if (paymentRequestId != null) 'payment_request_id': paymentRequestId,
        if (senderAvatarUrl != null) 'sender_avatar_url': senderAvatarUrl,
        'sender_initials': tutorName.isNotEmpty ? tutorName[0].toUpperCase() : null,
        'is_multi_learner': true,
      },
      sendEmail: true,
    );
  }

  /// Notify parent/student about multi-learner booking rejection
  /// 
  /// When tutor declines all learners in a multi-learner booking:
  /// - Lists declined learners
  /// - Includes rejection reason if provided
  static Future<void> notifyMultiLearnerBookingRejected({
    required String studentId,
    required String tutorId,
    required String requestId,
    required String tutorName,
    required List<String> declinedLearners,
    String? reason,
    String? senderAvatarUrl,
  }) async {
    final declinedList = declinedLearners.join(', ');
    final message = reason != null
        ? '$tutorName has declined your booking request for: $declinedList. Reason: $reason'
        : '$tutorName has declined your booking request for: $declinedList.';

    await _sendNotificationViaAPI(
      userId: studentId,
      type: 'booking_rejected',
      title: '⚠️ Booking Declined',
      message: message,
      priority: 'normal',
      actionUrl: '/bookings/requests',
      actionText: 'Find Another Tutor',
      icon: '⚠️',
      metadata: {
        'request_id': requestId,
        'tutor_id': tutorId,
        'tutor_name': tutorName,
        'declined_learners': declinedLearners,
        'rejection_reason': reason,
        if (senderAvatarUrl != null) 'sender_avatar_url': senderAvatarUrl,
        'sender_initials': tutorName.isNotEmpty ? tutorName[0].toUpperCase() : null,
        'is_multi_learner': true,
      },
      sendEmail: true,
    );
  }

  // ============================================
  // TRIAL SESSION NOTIFICATIONS
  // ============================================

  /// Notify tutor about new trial session request
  static Future<void> notifyTrialRequestCreated({
    required String tutorId,
    required String studentId,
    required String trialId,
    required String studentName,
    required String subject,
    required DateTime scheduledDate,
    required String scheduledTime,
    String? senderAvatarUrl,
    bool isReschedule = false,
    String? originalSessionId,
    bool isGroupRequest = false,
    int? learnerCount,
  }) async {
    final title = isReschedule 
        ? '🔄 Reschedule Request for Missed Trial Session'
        : isGroupRequest && (learnerCount ?? 0) > 1
            ? '🎯 New Trial Request (${learnerCount ?? 0} learners)'
            : '🎯 New Trial Session Request';
    
    final message = isReschedule
        ? '$studentName wants to reschedule a missed trial session for $subject. They are requesting a new time: ${scheduledDate.toLocal().toString().split(' ')[0]} at $scheduledTime. Please review and approve or suggest an alternative time.'
        : isGroupRequest && (learnerCount ?? 0) > 1
            ? '$studentName wants to book a trial session for $learnerCount learners for $subject on ${scheduledDate.toLocal().toString().split(' ')[0]} at $scheduledTime. This is ONE trial session (same price). Review and accept or decline.'
            : '$studentName wants to book a trial session for $subject on ${scheduledDate.toLocal().toString().split(' ')[0]} at $scheduledTime.';
    
    await _sendNotificationViaAPI(
      userId: tutorId,
      type: 'trial_request',
      title: title,
      message: message,
      priority: 'high',
      actionUrl: '/trials/$trialId',
      actionText: isReschedule ? 'Review Reschedule Request' : 'Review Request',
      icon: isReschedule ? '🔄' : '🎯',
      metadata: {
        'trial_id': trialId,
        'student_id': studentId,
        'student_name': studentName,
        'subject': subject,
        'scheduled_date': scheduledDate.toIso8601String(),
        'scheduled_time': scheduledTime,
        if (senderAvatarUrl != null) 'sender_avatar_url': senderAvatarUrl,
        'sender_initials': studentName.isNotEmpty ? studentName[0].toUpperCase() : null,
        if (isReschedule) 'is_reschedule': true,
        if (originalSessionId != null) 'original_session_id': originalSessionId,
        if (isGroupRequest) 'is_group_request': true,
        if (learnerCount != null) 'learner_count': learnerCount,
      },
      sendEmail: true
          );
  }

  /// Notify student/parent when tutor accepts trial request
  static Future<void> notifyTrialRequestAccepted({
    required String studentId,
    required String tutorId,
    required String trialId,
    required String tutorName,
    required String subject,
    required DateTime scheduledDate,
    required String scheduledTime,
    String? senderAvatarUrl,
  }) async {
    await _sendNotificationViaAPI(
      userId: studentId,
      type: 'trial_accepted',
      title: 'Trial Session Confirmed',
      message: 'Your trial request with $tutorName has been approved. Tap to view details and pay.',
      priority: 'high',
      actionUrl: '/trials/$trialId/payment',
      actionText: 'Pay Now',
      icon: '',
      metadata: {
        'trial_id': trialId,
        'tutor_id': tutorId,
        'tutor_name': tutorName,
        'subject': subject,
        'scheduled_date': scheduledDate.toIso8601String(),
        'scheduled_time': scheduledTime,
        if (senderAvatarUrl != null) 'sender_avatar_url': senderAvatarUrl,
        'sender_initials': tutorName.isNotEmpty ? tutorName[0].toUpperCase() : null,
      },
      sendEmail: true
          );
  }

  /// Notify student/parent when tutor rejects trial request
  static Future<void> notifyTrialRequestRejected({
    required String studentId,
    required String tutorId,
    required String trialId,
    required String tutorName,
    String? rejectionReason,
    String? senderAvatarUrl,
  }) async {
    final message = rejectionReason != null
        ? '$tutorName has declined your trial session request. Reason: $rejectionReason'
        : '$tutorName has declined your trial session request.';

    await _sendNotificationViaAPI(
      userId: studentId,
      type: 'trial_rejected',
      title: '⚠️ Trial Session Declined',
      message: message,
      priority: 'normal',
      actionUrl: '/trials',
      actionText: 'Find Another Tutor',
      icon: '⚠️',
      metadata: {
        'trial_id': trialId,
        'tutor_id': tutorId,
        'tutor_name': tutorName,
        'rejection_reason': rejectionReason,
        if (senderAvatarUrl != null) 'sender_avatar_url': senderAvatarUrl,
        'sender_initials': tutorName.isNotEmpty ? tutorName[0].toUpperCase() : null,
      },
      sendEmail: true
          );
  }

  /// Notify tutor when student/parent cancels an approved trial session
  static Future<void> notifyTrialSessionCancelled({
    required String tutorId,
    required String studentId,
    required String trialId,
    required String studentName,
    required String subject,
    required DateTime scheduledDate,
    required String scheduledTime,
    required String cancellationReason,
    required String cancelledBy, // 'student' or 'parent'
  }) async {
    final cancelledByText = cancelledBy == 'parent' ? 'parent' : 'student';
    final message = cancellationReason.isNotEmpty
        ? '$studentName has cancelled the trial session for $subject scheduled for ${scheduledDate.toLocal().toString().split(' ')[0]} at $scheduledTime. Reason: $cancellationReason'
        : '$studentName has cancelled the trial session for $subject scheduled for ${scheduledDate.toLocal().toString().split(' ')[0]} at $scheduledTime.';

    await _sendNotificationViaAPI(
      userId: tutorId,
      type: 'trial_cancelled',
      title: '⚠️ Trial Session Cancelled',
      message: message,
      priority: 'normal',
      actionUrl: '/trials/$trialId',
      actionText: 'View Details',
      icon: '⚠️',
      metadata: {
        'trial_id': trialId,
        'student_id': studentId,
        'student_name': studentName,
        'subject': subject,
        'scheduled_date': scheduledDate.toIso8601String(),
        'scheduled_time': scheduledTime,
        'cancellation_reason': cancellationReason,
        'cancelled_by': cancelledByText,
      },
      sendEmail: true
          );
  }

  // ============================================
  // PAYMENT NOTIFICATIONS
  // ============================================

  /// Notify tutor when payment is received
  static Future<void> notifyPaymentReceived({
    required String tutorId,
    required String studentId,
    required String paymentId,
    required String studentName,
    required double amount,
    required String currency,
    String? sessionType, // 'trial' or 'recurring'
  }) async {
    await _sendNotificationViaAPI(
      userId: tutorId,
      type: 'payment_received',
      title: 'Payment Received',
      message: 'Payment received from $studentName. Tap to view details.',
      priority: 'normal',
      actionUrl: '/payments/$paymentId',
      actionText: 'View Payment',
      icon: '💰',
      metadata: {
        'payment_id': paymentId,
        'student_id': studentId,
        'student_name': studentName,
        'amount': amount,
        'currency': currency,
        'session_type': sessionType,
      },
      sendEmail: true
          );
  }

  /// Notify student/parent when payment fails
  static Future<void> notifyPaymentFailed({
    required String studentId,
    required String paymentId,
    required double amount,
    required String currency,
    String? errorMessage,
  }) async {
    await _sendNotificationViaAPI(
      userId: studentId,
      type: 'payment_failed',
      title: '❌ Payment Failed',
      message: 'Your payment of $amount $currency failed.${errorMessage != null ? ' Reason: $errorMessage' : ''} Please try again.',
      priority: 'high',
      actionUrl: '/payments/$paymentId/retry',
      actionText: 'Retry Payment',
      icon: '❌',
      metadata: {
        'payment_id': paymentId,
        'amount': amount,
        'currency': currency,
        'error_message': errorMessage,
      },
      sendEmail: true
          );
  }

  /// Notify student/parent when payment is successful
  static Future<void> notifyPaymentSuccessful({
    required String studentId,
    required String paymentId,
    required double amount,
    required String currency,
    String? sessionType,
  }) async {
    await _sendNotificationViaAPI(
      userId: studentId,
      type: 'payment_successful',
      title: 'Payment Successful',
      message: 'Your payment of $amount $currency was successful.${sessionType != null ? ' Your ${sessionType} session is confirmed!' : ''}',
      priority: 'normal',
      actionUrl: '/payments/$paymentId',
      actionText: 'View Receipt',
      icon: '',
      metadata: {
        'payment_id': paymentId,
        'amount': amount,
        'currency': currency,
        'session_type': sessionType,
      },
      sendEmail: true
          );
  }


  // ============================================
  // PAYMENT REMINDER NOTIFICATIONS
  // ============================================

  /// Schedule payment reminder notifications for unpaid sessions
  /// 
  /// Schedules reminders at 2 days, 1 day, and 2 hours before payment deadline
  static Future<void> schedulePaymentReminders({
    required String studentId,
    required String sessionId,
    required String sessionType, // 'trial' or 'recurring'
    required DateTime paymentDeadline,
    required String subject,
    required double amount,
    required String currency,
  }) async {
    try {
      // Schedule via API (backend will handle scheduling)
      final response = await http.post(
        Uri.parse('$_apiBaseUrl/notifications/schedule-payment-reminders'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'studentId': studentId,
          'sessionId': sessionId,
          'sessionType': sessionType,
          'paymentDeadline': paymentDeadline.toIso8601String(),
          'subject': subject,
          'amount': amount,
          'currency': currency,
        })
          );

      if (response.statusCode == 200) {
        LogService.success('Payment reminders scheduled for session: $sessionId');
      } else {
        LogService.warning('Failed to schedule payment reminders: ${response.statusCode}');
      }
    } catch (e) {
      LogService.error('Error scheduling payment reminders: $e');
      // Don't throw - scheduling reminders shouldn't fail session creation
      // Fallback: create in-app notifications directly
      try {
        // 2 days before
        final twoDaysBefore = paymentDeadline.subtract(const Duration(days: 2));
        if (twoDaysBefore.isAfter(DateTime.now())) {
          await _sendNotificationViaAPI(
            userId: studentId,
            type: 'payment_reminder',
            title: '⏰ Payment Reminder',
            message: 'Your $sessionType session for $subject (${amount.toStringAsFixed(0)} $currency) payment is due in 2 days.',
            priority: 'normal',
            actionUrl: '/payments/$sessionId',
            actionText: 'Pay Now',
            icon: '⏰',
            metadata: {
              'session_id': sessionId,
              'session_type': sessionType,
              'reminder_type': '2_days',
              'deadline': paymentDeadline.toIso8601String(),
            },
            sendEmail: true
          );
        }

        // 1 day before
        final oneDayBefore = paymentDeadline.subtract(const Duration(days: 1));
        if (oneDayBefore.isAfter(DateTime.now())) {
          await _sendNotificationViaAPI(
            userId: studentId,
            type: 'payment_reminder',
            title: '⏰ Payment Due Tomorrow',
            message: 'Your $sessionType session for $subject (${amount.toStringAsFixed(0)} $currency) payment is due tomorrow!',
            priority: 'high',
            actionUrl: '/payments/$sessionId',
            actionText: 'Pay Now',
            icon: '⏰',
            metadata: {
              'session_id': sessionId,
              'session_type': sessionType,
              'reminder_type': '1_day',
              'deadline': paymentDeadline.toIso8601String(),
            },
            sendEmail: true
          );
        }

        // 2 hours before
        final twoHoursBefore = paymentDeadline.subtract(const Duration(hours: 2));
        if (twoHoursBefore.isAfter(DateTime.now())) {
          await _sendNotificationViaAPI(
            userId: studentId,
            type: 'payment_reminder',
            title: '🚨 Payment Due Soon!',
            message: 'Your $sessionType session for $subject (${amount.toStringAsFixed(0)} $currency) payment is due in 2 hours!',
            priority: 'urgent',
            actionUrl: '/payments/$sessionId',
            actionText: 'Pay Now',
            icon: '🚨',
            metadata: {
              'session_id': sessionId,
              'session_type': sessionType,
              'reminder_type': '2_hours',
              'deadline': paymentDeadline.toIso8601String(),
            },
            sendEmail: true,
            sendPush: true
          );
        }
      } catch (e2) {
        LogService.warning('Could not create fallback payment reminder notifications: $e2');
      }
    }
  }

  /// Notify when payment is due soon
  static Future<void> notifyPaymentDue({
    required String studentId,
    required String sessionId,
    required String sessionType,
    required String subject,
    required double amount,
    required String currency,
    required DateTime deadline,
    String reminderType = 'general', // '2_days', '1_day', '2_hours'
  }) async {
    String title;
    String message;
    String priority;

    switch (reminderType) {
      case '2_days':
        title = '⏰ Payment Reminder';
        message = 'Your $sessionType session for $subject (${amount.toStringAsFixed(0)} $currency) payment is due in 2 days.';
        priority = 'normal';
        break;
      case '1_day':
        title = '⏰ Payment Due Tomorrow';
        message = 'Your $sessionType session for $subject (${amount.toStringAsFixed(0)} $currency) payment is due tomorrow!';
        priority = 'high';
        break;
      case '2_hours':
        title = '🚨 Payment Due Soon!';
        message = 'Your $sessionType session for $subject (${amount.toStringAsFixed(0)} $currency) payment is due in 2 hours!';
        priority = 'urgent';
        break;
      default:
        title = '⏰ Payment Reminder';
        message = 'Your $sessionType session for $subject (${amount.toStringAsFixed(0)} $currency) payment is due soon.';
        priority = 'normal';
    }

    await _sendNotificationViaAPI(
      userId: studentId,
      type: 'payment_reminder',
      title: title,
      message: message,
      priority: priority,
      actionUrl: '/payments/$sessionId',
      actionText: 'Pay Now',
      icon: '⏰',
      metadata: {
        'session_id': sessionId,
        'session_type': sessionType,
        'reminder_type': reminderType,
        'deadline': deadline.toIso8601String(),
        'amount': amount,
        'currency': currency,
      },
      sendEmail: true,
      sendPush: reminderType == '2_hours', // Push only for urgent reminders
    );
  }

  /// Notify when session is expiring without payment
  static Future<void> notifySessionExpiring({
    required String studentId,
    required String sessionId,
    required String sessionType,
    required String subject,
    required DateTime sessionStart,
  }) async {
    await _sendNotificationViaAPI(
      userId: studentId,
      type: 'session_expiring',
      title: '⚠️ Session Expiring Soon',
      message: 'Your $sessionType session for $subject is scheduled for ${sessionStart.toString().split('.')[0]}. Payment is required to confirm your session.',
      priority: 'high',
      actionUrl: '/payments/$sessionId',
      actionText: 'Pay Now',
      icon: '⚠️',
      metadata: {
        'session_id': sessionId,
        'session_type': sessionType,
        'session_start': sessionStart.toIso8601String(),
      },
      sendEmail: true,
      sendPush: true
          );
  }


  /// Notify tutor when session is ready (payment received and session scheduled)
  static Future<void> notifyTutorSessionReady({
    required String tutorId,
    required String sessionId,
    required String sessionType, // 'trial' or 'recurring'
    required String learnerName,
    required String subject,
    required DateTime scheduledDate,
    required String scheduledTime,
    String? meetLink,
  }) async {
    final formattedDate = '${scheduledDate.day}/${scheduledDate.month}/${scheduledDate.year}';
    final message = meetLink != null
        ? 'Payment received! Your $sessionType session with $learnerName for $subject is scheduled for $formattedDate at $scheduledTime. The meeting link is ready - you can start preparing!'
        : 'Payment received! Your $sessionType session with $learnerName for $subject is scheduled for $formattedDate at $scheduledTime. The meeting link will be available soon.';
    
    await _sendNotificationViaAPI(
      userId: tutorId,
      type: 'session_ready',
      title: 'Session Confirmed - Payment Received',
      message: message,
      priority: 'high',
      actionUrl: '/sessions/$sessionId',
      actionText: 'View Session',
      icon: '',
      metadata: {
        'session_id': sessionId,
        'session_type': sessionType,
        'learner_name': learnerName,
        'subject': subject,
        'scheduled_date': scheduledDate.toIso8601String(),
        'scheduled_time': scheduledTime,
        'meet_link': meetLink,
      },
      sendEmail: true,
      sendPush: true,
    );
  }


  // ============================================
  // SESSION NOTIFICATIONS
  // ============================================

  /// Schedule session reminders (24 hours, 1 hour, and 15 minutes before)
  /// 
  /// Schedules multiple reminders for both tutor and student
  /// - 24 hours before: "Session reminder"
  /// - 1 hour before: "Session starting soon"
  /// - 15 minutes before: "Join now"
  static Future<void> scheduleSessionReminders({
    required String tutorId,
    required String studentId,
    required String sessionId,
    required String sessionType, // 'trial' or 'recurring'
    required String tutorName,
    required String studentName,
    required DateTime sessionStart,
    required String subject,
  }) async {
    // Schedule reminders via API (backend will handle scheduling for both users)
    try {
      final response = await http.post(
        Uri.parse('$_apiBaseUrl/notifications/schedule-session-reminders'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'sessionId': sessionId,
          'tutorId': tutorId,
          'studentId': studentId,
          'sessionStart': sessionStart.toIso8601String(),
          'sessionType': sessionType,
          'tutorName': tutorName,
          'studentName': studentName,
          'subject': subject,
        })
          );

      if (response.statusCode == 200) {
        LogService.success('Session reminders scheduled for session: $sessionId (24h, 1h, 15min)');
      } else {
        LogService.warning('Failed to schedule session reminders: ${response.statusCode}');
        // Fallback: Create in-app notifications directly
        await _createFallbackSessionReminders(
          tutorId: tutorId,
          studentId: studentId,
          sessionId: sessionId,
          sessionType: sessionType,
          tutorName: tutorName,
          studentName: studentName,
          sessionStart: sessionStart,
          subject: subject,
        );
      }
    } catch (e) {
      LogService.error('Error scheduling session reminders: $e');
      // Fallback: Create in-app notifications directly
      await _createFallbackSessionReminders(
        tutorId: tutorId,
        studentId: studentId,
        sessionId: sessionId,
        sessionType: sessionType,
        tutorName: tutorName,
        studentName: studentName,
        sessionStart: sessionStart,
        subject: subject,
      );
    }
  }

  /// Create fallback session reminders (in-app notifications)
  /// Used when API scheduling fails
  /// 
  /// IMPORTANT: This fallback should NOT create future reminders immediately.
  /// Future reminders (24h, 1h, 15min before) should be scheduled by the backend API.
  /// This fallback only logs a warning - actual scheduling must be done server-side.
  static Future<void> _createFallbackSessionReminders({
    required String tutorId,
    required String studentId,
    required String sessionId,
    required String sessionType,
    required String tutorName,
    required String studentName,
    required DateTime sessionStart,
    required String subject,
  }) async {
    try {
      final now = DateTime.now();
      
      // CRITICAL FIX: Do NOT create future reminders immediately
      // The fallback should not create notifications that should be sent in the future.
      // These must be scheduled by the backend API or a proper scheduler.
      // Creating them now would cause all three notifications to appear at once.
      
      // Only log that scheduling failed - don't create future notifications
      LogService.warning(
        'Session reminder scheduling failed for session: $sessionId. '
        'Reminders should be scheduled server-side at: '
        '24h before (${sessionStart.subtract(const Duration(hours: 24)).toIso8601String()}), '
        '1h before (${sessionStart.subtract(const Duration(hours: 1)).toIso8601String()}), '
        'and 15min before (${sessionStart.subtract(const Duration(minutes: 15)).toIso8601String()}).'
      );
      
      // NOTE: The backend API should handle scheduling these reminders.
      // If the API call fails, we should retry or use a proper scheduling service.
      // Creating notifications immediately defeats the purpose of timed reminders.
      
    } catch (e) {
      LogService.warning('Could not create fallback session reminders: $e');
    }
  }

  /// Notify when session is started
  /// 
  /// Sends notification with Meet link for online sessions
  static Future<void> notifySessionStarted({
    required String userId,
    required String sessionId,
    required String meetLink,
  }) async {
    await _sendNotificationViaAPI(
      userId: userId,
      type: 'session_started',
      title: '🎓 Session Started',
      message: 'Your session has started! Join the meeting now: $meetLink',
      priority: 'high',
      actionUrl: '/sessions/$sessionId',
      actionText: 'Join Meeting',
      icon: '🎓',
      metadata: {
        'session_id': sessionId,
        'is_online': true,
        'meet_link': meetLink,
      },
      sendEmail: true,
      sendPush: true
          );
  }

  /// Notify tutor when earnings are added to pending balance
  /// 
  /// Sends notification after session payment record is created
  static Future<void> notifyTutorEarningsAdded({
    required String tutorId,
    required String sessionId,
    required double earnings,
  }) async {
    await _sendNotificationViaAPI(
      userId: tutorId,
      type: 'earnings_added',
      title: 'Earnings Added',
      message: '${earnings.toStringAsFixed(2)} XAF has been added to your pending balance. It will become active after payment confirmation.',
      priority: 'normal',
      actionUrl: '/earnings',
      actionText: 'View Earnings',
      icon: '💰',
      metadata: {
        'session_id': sessionId,
        'earnings': earnings,
        'status': 'pending',
      },
      sendEmail: true,
      sendPush: true
          );
  }

  /// Schedule feedback reminder for 24 hours after session end
  /// 
  /// Schedules a notification to remind students to provide feedback
  static Future<void> scheduleFeedbackReminder({
    required String userId,
    required String sessionId,
    required DateTime reminderTime,
  }) async {
    // Schedule reminder via API (backend will handle scheduling)
    try {
      final response = await http.post(
        Uri.parse('$_apiBaseUrl/notifications/schedule-feedback-reminder'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'userId': userId,
          'sessionId': sessionId,
          'reminderTime': reminderTime.toIso8601String(),
        })
          );

      if (response.statusCode == 200) {
        LogService.success('Feedback reminder scheduled for session: $sessionId');
      } else {
        LogService.warning('Failed to schedule feedback reminder: ${response.statusCode}');
        // Fallback: Create in-app notification immediately (will be shown when user opens app)
        // The app can check if 24h has passed when displaying notifications
        await NotificationService.createNotification(
          userId: userId,
          type: 'feedback_reminder',
          title: 'Feedback Reminder',
          message: 'Please provide feedback for your completed session. It helps your tutor improve!',
          priority: 'normal',
          actionUrl: '/sessions/$sessionId/feedback',
          actionText: 'Provide Feedback',
          icon: '💬',
          metadata: {
            'session_id': sessionId,
            'reminder_time': reminderTime.toIso8601String(),
          }
          );
      }
    } catch (e) {
      LogService.error('Error scheduling feedback reminder: $e');
      // Fallback: Create in-app notification
      try {
        await NotificationService.createNotification(
          userId: userId,
          type: 'feedback_reminder',
          title: 'Feedback Reminder',
          message: 'Please provide feedback for your completed session. It helps your tutor improve!',
          priority: 'normal',
          actionUrl: '/sessions/$sessionId/feedback',
          actionText: 'Provide Feedback',
          icon: '💬',
          metadata: {
            'session_id': sessionId,
            'reminder_time': reminderTime.toIso8601String(),
          }
          );
      } catch (e2) {
        LogService.warning('Could not create fallback feedback reminder notification: $e2');
      }
    }
  }

  /// Notify when session is completed
  /// 
  /// Sends notification and schedules review reminder (24 hours after)
  static Future<void> notifySessionCompleted({
    required String userId,
    required String sessionId,
    required String sessionType,
    required String otherPartyName,
    required String subject,
    required DateTime sessionEndTime,
  }) async {
    await _sendNotificationViaAPI(
      userId: userId,
      type: 'session_completed',
      title: 'Session Completed',
      message: 'Your $sessionType session with $otherPartyName for $subject has been completed. Please leave a review!',
      priority: 'normal',
      actionUrl: '/sessions/$sessionId/review',
      actionText: 'Leave Review',
      icon: '',
      metadata: {
        'session_id': sessionId,
        'session_type': sessionType,
        'other_party_name': otherPartyName,
        'subject': subject,
      },
      sendEmail: true
          );

    // Schedule review reminder (24 hours after session) via API
    try {
      final response = await http.post(
        Uri.parse('$_apiBaseUrl/notifications/schedule-review-reminder'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'sessionId': sessionId,
          'userId': userId,
          'otherPartyName': otherPartyName,
          'subject': subject,
          'sessionType': sessionType,
          'sessionEndTime': sessionEndTime.toIso8601String(),
        })
          );

      if (response.statusCode == 200) {
        LogService.success('Review reminder scheduled for user: $userId');
      }
    } catch (e) {
      LogService.error('Error scheduling review reminder: $e');
      // Don't throw - review reminder scheduling shouldn't fail session completion
    }
  }

  // ============================================
  // TUTOR PROFILE NOTIFICATIONS
  // ============================================

  /// Notify tutor when profile is approved (already handled in admin dashboard, but adding for completeness)
  static Future<void> notifyProfileApproved({
    required String tutorId,
    required String tutorName,
    double? rating,
    double? sessionPrice,
    String? pricingTier,
  }) async {
    // Verify user is actually a tutor before sending notification
    try {
      final profile = await SupabaseService.client
          .from('profiles')
          .select('user_type')
          .eq('id', tutorId)
          .maybeSingle();
      
      if (profile == null || profile['user_type'] != 'tutor') {
        LogService.warning('Skipping tutor profile approval notification for non-tutor user: $tutorId (role: ${profile?['user_type']})');
        return;
      }
    } catch (e) {
      LogService.warning('Could not verify user role for profile approval notification: $e');
      // Continue anyway - better to send notification than miss it
    }

    // This is already handled in the admin dashboard email sending
    // But we can add in-app notification here
    await NotificationService.createNotification(
      userId: tutorId,
      type: 'profile_approved',
      title: 'Profile Approved 🎉 ',
      message: 'Congratulations! Your tutor profile has been approved and is now live. Students can now book sessions with you!',
      priority: 'high',
      actionUrl: '/tutor/profile',
      actionText: 'View Profile',
      icon: '🎉',
      metadata: {
        'rating': rating,
        'session_price': sessionPrice,
        'pricing_tier': pricingTier,
      }
          );
  }

  /// Notify tutor when profile needs improvement
  static Future<void> notifyProfileNeedsImprovement({
    required String tutorId,
    required String tutorName,
    required List<String> improvementRequests,
  }) async {
    await _sendNotificationViaAPI(
      userId: tutorId,
      type: 'profile_improvement',
      title: '📝 Profile Needs Improvement',
      message: 'Your tutor profile needs some updates. Please review the feedback and update your profile.',
      priority: 'high',
      actionUrl: '/tutor/profile/edit',
      actionText: 'Update Profile',
      icon: '📝',
      metadata: {
        'improvement_requests': improvementRequests,
      },
      sendEmail: true
          );
  }

  /// Notify tutor when profile is rejected
  static Future<void> notifyProfileRejected({
    required String tutorId,
    required String tutorName,
    required String rejectionReason,
  }) async {
    await _sendNotificationViaAPI(
      userId: tutorId,
      type: 'profile_rejected',
      title: '⚠️ Profile Rejected',
      message: 'Your tutor profile application was not approved. Reason: $rejectionReason. You can update your profile and re-apply.',
      priority: 'high',
      actionUrl: '/tutor/profile/edit',
      actionText: 'Update Profile',
      icon: '⚠️',
      metadata: {
        'rejection_reason': rejectionReason,
      },
      sendEmail: true
          );
  }

  // ============================================
  // PAYMENT NOTIFICATIONS
  // ============================================

  /// Notify when payment request is paid
  static Future<void> notifyPaymentRequestPaid({
    required String paymentRequestId,
    String? bookingRequestId,
    required String studentId,
    required String tutorId,
    required double amount,
  }) async {
    await _sendNotificationViaAPI(
      userId: studentId,
      type: 'payment_request_paid',
      title: 'Payment Confirmed',
      message: 'Your payment has been confirmed. Your sessions are now active! Tap to view booking.',
      priority: 'high',
      actionUrl: bookingRequestId != null ? '/bookings/$bookingRequestId' : '/payments',
      actionText: 'View Booking',
      icon: '',
      metadata: {
        'payment_request_id': paymentRequestId,
        'booking_request_id': bookingRequestId,
        'amount': amount,
      },
      sendEmail: true
          );

    // Notify tutor
    await _sendNotificationViaAPI(
      userId: tutorId,
      type: 'payment_received',
      title: 'Payment Received',
      message: 'A student has paid for their booking. Sessions are now active!',
      priority: 'normal',
      actionUrl: bookingRequestId != null ? '/tutor/bookings/$bookingRequestId' : '/tutor/bookings',
      actionText: 'View Booking',
      icon: '💰',
      metadata: {
        'payment_request_id': paymentRequestId,
        'booking_request_id': bookingRequestId,
        'amount': amount,
      },
      sendEmail: false
          );
  }

  /// Notify when payment request fails
  static Future<void> notifyPaymentRequestFailed({
    required String paymentRequestId,
    required String studentId,
    required String reason,
  }) async {
    await _sendNotificationViaAPI(
      userId: studentId,
      type: 'payment_request_failed',
      title: '⚠️ Payment Failed',
      message: 'Your payment could not be processed. Reason: $reason. Please try again.',
      priority: 'high',
      actionUrl: '/payments/$paymentRequestId',
      actionText: 'Retry Payment',
      icon: '⚠️',
      metadata: {
        'payment_request_id': paymentRequestId,
        'reason': reason,
      },
      sendEmail: true
          );
  }

  /// Notify when trial payment is completed
  static Future<void> notifyTrialPaymentCompleted({
    required String trialSessionId,
    required String learnerId,
    required String tutorId,
    required String subject,
    String? meetLink,
  }) async {
    await _sendNotificationViaAPI(
      userId: learnerId,
      type: 'trial_payment_completed',
      title: 'Trial Payment Confirmed',
      message: 'Your trial session payment has been confirmed. ${meetLink != null ? "Meet link is now available." : "Your session is scheduled."}',
      priority: 'high',
      actionUrl: '/trials/$trialSessionId',
      actionText: 'View Session',
      icon: '',
      metadata: {
        'trial_session_id': trialSessionId,
        'subject': subject,
        'meet_link': meetLink,
      },
      sendEmail: true
          );
  }

  /// Notify tutor when trial payment is received
  static Future<void> notifyTrialPaymentReceived({
    required String trialSessionId,
    required String tutorId,
    required String learnerId,
    required String subject,
  }) async {
    await _sendNotificationViaAPI(
      userId: tutorId,
      type: 'trial_payment_received',
      title: 'Trial Payment Received',
      message: 'A student has paid for their trial session in $subject. The session is now scheduled.',
      priority: 'normal',
      actionUrl: '/tutor/trials/$trialSessionId',
      actionText: 'View Session',
      icon: '💰',
      metadata: {
        'trial_session_id': trialSessionId,
        'subject': subject,
      },
      sendEmail: false
          );
  }

  /// Notify when trial payment fails
  static Future<void> notifyTrialPaymentFailed({
    required String trialSessionId,
    required String learnerId,
    required String subject,
    required String reason,
  }) async {
    await _sendNotificationViaAPI(
      userId: learnerId,
      type: 'trial_payment_failed',
      title: '⚠️ Trial Payment Failed',
      message: 'Your trial session payment could not be processed. Reason: $reason. Please try again.',
      priority: 'high',
      actionUrl: '/trials/$trialSessionId',
      actionText: 'Retry Payment',
      icon: '⚠️',
      metadata: {
        'trial_session_id': trialSessionId,
        'subject': subject,
        'reason': reason,
      },
      sendEmail: true
          );
  }

  /// Notify student/parent when sessions are created after payment
  static Future<void> notifySessionsCreated({
    required String studentId,
    required String tutorId,
    required String recurringSessionId,
    required String tutorName,
    required String studentName,
    required int sessionCount,
    required int frequency,
    required List<String> days,
  }) async {
    final daysText = days.join(', ');
    await _sendNotificationViaAPI(
      userId: studentId,
      type: 'sessions_created',
      title: 'Sessions Created',
      message: '$sessionCount session${sessionCount > 1 ? 's' : ''} have been created for your booking with $tutorName. Sessions are now visible in your Sessions tab!',
      priority: 'high',
      actionUrl: '/sessions',
      actionText: 'View Sessions',
      icon: '📅',
      metadata: {
        'recurring_session_id': recurringSessionId,
        'tutor_id': tutorId,
        'tutor_name': tutorName,
        'session_count': sessionCount,
        'frequency': frequency,
        'days': days,
      },
      sendEmail: true
          );
  }

  /// Notify tutor when sessions are created after payment
  static Future<void> notifyTutorSessionsCreated({
    required String tutorId,
    required String studentId,
    required String recurringSessionId,
    required String studentName,
    required String tutorName,
    required int sessionCount,
    required int frequency,
    required List<String> days,
  }) async {
    final daysText = days.join(', ');
    await _sendNotificationViaAPI(
      userId: tutorId,
      type: 'sessions_created',
      title: 'Sessions Created',
      message: '$sessionCount session${sessionCount > 1 ? 's' : ''} have been created for your booking with $studentName. Sessions are now visible in your Sessions tab!',
      priority: 'normal',
      actionUrl: '/tutor/sessions',
      actionText: 'View Sessions',
      icon: '📅',
      metadata: {
        'recurring_session_id': recurringSessionId,
        'student_id': studentId,
        'student_name': studentName,
        'session_count': sessionCount,
        'frequency': frequency,
        'days': days,
      },
      sendEmail: false
          );
  }

  // ============================================
  // TUTOR REQUEST NOTIFICATIONS (ADMIN)
  // ============================================

  /// Notify admin about new tutor request
  static Future<void> notifyTutorRequestCreated({
    required String adminId,
    required String requestId,
    required String requesterName,
  }) async {
    await _sendNotificationViaAPI(
      userId: adminId,
      type: 'tutor_request',
      title: '🎓 New Tutor Request',
      message: '$requesterName has submitted a new tutor request. Please review and find a suitable tutor.',
      priority: 'high',
      actionUrl: '/admin/tutor-requests/$requestId',
      actionText: 'Review Request',
      icon: '🎓',
      metadata: {
        'request_id': requestId,
        'requester_name': requesterName,
      },
      sendEmail: true
          );
  }

  /// Notify user when their tutor request is matched with a tutor
  static Future<void> notifyTutorRequestMatched({
    required String userId,
    required String requestId,
    required String tutorName,
    String? tutorId,
  }) async {
    await _sendNotificationViaAPI(
      userId: userId,
      type: 'tutor_request_matched',
      title: 'Tutor Matched',
      message: 'We found a tutor for your request: $tutorName',
      priority: 'high',
      actionUrl: '/requests/$requestId',
      actionText: 'View Details',
      icon: '🎉',
      metadata: {
        'request_id': requestId,
        'tutor_id': tutorId,
        'tutor_name': tutorName,
      },
      sendEmail: true,
    );
  }

  /// Notify all admins about new user signup
  /// 
  /// Creates a notification for each admin user when a new user signs up
  static Future<void> notifyAdminsAboutNewUserSignup({
    required String userId,
    required String userType, // 'student', 'parent', or 'tutor'
    required String userName,
    required String userEmail,
  }) async {
    try {
      // Import SupabaseService dynamically to avoid circular dependency
      final supabase = Supabase.instance.client;
      
      // Get all admin users
      final adminResponse = await supabase
          .from('profiles')
          .select('id')
          .eq('is_admin', true);

      if (adminResponse.isEmpty) {
        LogService.warning('No admin users found to notify about new user signup');
        return;
      }

      // Build message
      final userTypeDisplay = userType == 'student' 
          ? 'Student' 
          : userType == 'parent' 
              ? 'Parent' 
              : 'Tutor';
      final message = '$userName ($userTypeDisplay) has just signed up.\n\nEmail: $userEmail';

      // Send notification to each admin
      for (final admin in adminResponse as List) {
        final adminId = admin['id'] as String;
        
        await _sendNotificationViaAPI(
          userId: adminId,
          type: 'user_signup',
          title: '👤 New User Signup',
          message: message,
          priority: 'normal',
          actionUrl: '/admin/${userType == 'student' ? 'students' : userType == 'parent' ? 'parents' : 'tutors'}/$userId',
          actionText: 'View Profile',
          icon: '👤',
          metadata: {
            'user_id': userId,
            'user_type': userType,
            'user_name': userName,
            'user_email': userEmail,
          },
          sendEmail: true
          );
      }

      LogService.success('Notified ${adminResponse.length} admin(s) about new user signup: $userName');
    } catch (e) {
      LogService.warning('Error notifying admins about new user signup: $e');
      // Don't throw - notification failure shouldn't block user signup
    }
  }

  /// Notify all admins about new survey completion
  /// 
  /// Creates a notification for each admin user when a student or parent completes their survey
  static Future<void> notifyAdminsAboutSurveyCompletion({
    required String userId,
    required String userType, // 'student' or 'parent'
    required String userName,
    required String learningPath,
    Map<String, dynamic>? surveyDetails, // Additional survey details
  }) async {
    try {
      // Import SupabaseService dynamically to avoid circular dependency
      final supabase = Supabase.instance.client;
      
      // Get all admin users
      final adminResponse = await supabase
          .from('profiles')
          .select('id')
          .eq('is_admin', true);

      if (adminResponse.isEmpty) {
        LogService.warning('No admin users found to notify about survey completion');
        return;
      }

      // Build message with survey details
      String message = '$userName (${userType == 'student' ? 'Student' : 'Parent'}) has completed their survey.';
      
      // Add learning path
      if (learningPath.isNotEmpty) {
        message += '\n\nLearning Path: $learningPath';
      }

      // Add additional details if provided
      if (surveyDetails != null) {
        final details = <String>[];
        
        if (surveyDetails['subjects'] != null) {
          final subjects = surveyDetails['subjects'] is List
              ? (surveyDetails['subjects'] as List).join(', ')
              : surveyDetails['subjects'].toString();
          if (subjects.isNotEmpty) {
            details.add('Subjects: $subjects');
          }
        }
        
        if (surveyDetails['skills'] != null) {
          final skills = surveyDetails['skills'] is List
              ? (surveyDetails['skills'] as List).join(', ')
              : surveyDetails['skills'].toString();
          if (skills.isNotEmpty) {
            details.add('Skills: $skills');
          }
        }
        
        if (surveyDetails['exam_type'] != null) {
          details.add('Exam Type: ${surveyDetails['exam_type']}');
        }
        
        if (surveyDetails['city'] != null) {
          details.add('Location: ${surveyDetails['city']}');
        }
        
        if (surveyDetails['budget_min'] != null && surveyDetails['budget_max'] != null) {
          details.add('Budget: ${surveyDetails['budget_min']}-${surveyDetails['budget_max']} XAF');
        }

        if (details.isNotEmpty) {
          message += '\n\n${details.join('\n')}';
        }
      }

      // Send notification to each admin
      for (final admin in adminResponse as List) {
        final adminId = admin['id'] as String;
        
        await _sendNotificationViaAPI(
          userId: adminId,
          type: 'survey_completed',
          title: '📝 New Survey Completed',
          message: message,
          priority: 'normal',
          actionUrl: '/admin/${userType == 'student' ? 'students' : 'parents'}/$userId',
          actionText: 'View Profile',
          icon: '📝',
          metadata: {
            'user_id': userId,
            'user_type': userType,
            'user_name': userName,
            'learning_path': learningPath,
            'survey_details': surveyDetails,
          },
          sendEmail: true
          );
      }

      LogService.success('Notified ${adminResponse.length} admin(s) about survey completion for $userName');
    } catch (e) {
      LogService.warning('Error notifying admins about survey completion: $e');
      // Don't throw - notification failure shouldn't block survey completion
    }
  }

  /// Notify tutor when pending trial request is updated/modified
  static Future<void> notifyTrialRequestUpdated({
    required String tutorId,
    required String studentId,
    required String trialId,
    required String studentName,
    required String subject,
  }) async {
    await _sendNotificationViaAPI(
      userId: tutorId,
      type: 'trial_request_updated',
      title: '🔄 Trial Request Updated',
      message: '$studentName has updated their trial request for $subject. Please review the changes.',
      priority: 'normal',
      actionUrl: '/trials/$trialId',
      actionText: 'Review Request',
      icon: '🔄',
      metadata: {
        'trial_id': trialId,
        'student_id': studentId,
        'student_name': studentName,
        'subject': subject,
      },
      sendEmail: true,
    );
  }

  /// Notify tutor when approved trial session is modified (requires re-approval)
  static Future<void> notifyTrialSessionModified({
    required String tutorId,
    required String studentId,
    required String trialId,
    required String studentName,
    required String subject,
    required String modificationReason,
  }) async {
    await _sendNotificationViaAPI(
      userId: tutorId,
      type: 'trial_session_modified',
      title: '🔄 Trial Session Modified',
      message: '$studentName has modified the approved trial session for $subject. Reason: $modificationReason. Please review and approve again.',
      priority: 'high',
      actionUrl: '/trials/$trialId',
      actionText: 'Review Changes',
      icon: '🔄',
      metadata: {
        'trial_id': trialId,
        'student_id': studentId,
        'student_name': studentName,
        'subject': subject,
        'modification_reason': modificationReason,
      },
      sendEmail: true,
    );
  }

  /// Notify tutor when pending trial request is deleted
  static Future<void> notifyTrialRequestDeleted({
    required String tutorId,
    required String studentId,
    required String trialId,
    required String studentName,
    required String subject,
    String? deletionReason,
  }) async {
    final message = deletionReason != null && deletionReason.isNotEmpty
        ? '$studentName has deleted their trial request for $subject. Reason: $deletionReason'
        : '$studentName has deleted their trial request for $subject.';
    
    await _sendNotificationViaAPI(
      userId: tutorId,
      type: 'trial_request_deleted',
      title: '🗑️ Trial Request Deleted',
      message: message,
      priority: 'normal',
      actionUrl: '/trials',
      actionText: 'View Other Requests',
      icon: '🗑️',
      metadata: {
        'trial_id': trialId,
        'student_id': studentId,
        'student_name': studentName,
        'subject': subject,
        if (deletionReason != null) 'deletion_reason': deletionReason,
      },
      sendEmail: true,
    );
  }

  /// Notify learner when tutor requests modification
  static Future<void> notifyTutorModificationRequest({
    required String tutorId,
    required String studentId,
    required String trialId,
    required String tutorName,
    required String subject,
    required String reason,
  }) async {
    await _sendNotificationViaAPI(
      userId: studentId,
      type: 'tutor_modification_request',
      title: '🔄 Modification Request from $tutorName',
      message: '$tutorName has requested to modify the trial session for $subject. Reason: $reason. Please review and accept or decline.',
      priority: 'high',
      actionUrl: '/trials/$trialId',
      actionText: 'Review Request',
      icon: '🔄',
      metadata: {
        'trial_id': trialId,
        'tutor_id': tutorId,
        'tutor_name': tutorName,
        'subject': subject,
        'reason': reason,
      },
      sendEmail: true,
    );
  }

  /// Notify tutor when learner accepts modification request
  static Future<void> notifyModificationAccepted({
    required String tutorId,
    required String studentId,
    required String trialId,
    required String studentName,
  }) async {
    await _sendNotificationViaAPI(
      userId: tutorId,
      type: 'modification_accepted',
      title: 'Modification Accepted',
      message: '$studentName has accepted your modification request. The session has been updated.',
      priority: 'normal',
      actionUrl: '/trials/$trialId',
      actionText: 'View Session',
      icon: '',
      metadata: {
        'trial_id': trialId,
        'student_id': studentId,
        'student_name': studentName,
      },
      sendEmail: true,
    );
  }

  /// Notify user when their credits balance is low
  static Future<void> notifyLowCreditsBalance({
    required String userId,
    required double balance,
    required double threshold,
    String? paymentRequestId,
  }) async {
    await _sendNotificationViaAPI(
      userId: userId,
      type: 'low_credits_balance',
      title: 'Low Credits Balance',
      message: 'Your credits balance (${balance.toStringAsFixed(0)}) is below the threshold (${threshold.toStringAsFixed(0)}). Please top up to continue using services.',
      priority: 'normal',
      actionUrl: paymentRequestId != null ? '/payments/$paymentRequestId' : '/credits',
      actionText: 'Top Up Credits',
      icon: '💰',
      metadata: {
        'balance': balance,
        'threshold': threshold,
        if (paymentRequestId != null) 'payment_request_id': paymentRequestId,
      },
      sendEmail: true,
      sendPush: false,
    );
  }

  /// Notify admin when a tutor request is updated by user
  static Future<void> notifyTutorRequestUpdated({
    required String adminId,
    required String requestId,
    required String requesterName,
  }) async {
    await _sendNotificationViaAPI(
      userId: adminId,
      type: 'tutor_request_updated',
      title: '🔄 Tutor Request Updated',
      message: '$requesterName has updated their tutor request. Please review the changes.',
      priority: 'normal',
      actionUrl: '/admin/tutor-requests/$requestId',
      actionText: 'Review Request',
      icon: '🔄',
      metadata: {
        'request_id': requestId,
        'requester_name': requesterName,
      },
      sendEmail: true,
    );
  }

  /// Notify admin when a tutor request is deleted by user
  static Future<void> notifyTutorRequestDeleted({
    required String adminId,
    required String requestId,
    required String requesterName,
  }) async {
    await _sendNotificationViaAPI(
      userId: adminId,
      type: 'tutor_request_deleted',
      title: '🗑️ Tutor Request Deleted',
      message: '$requesterName has deleted their tutor request.',
      priority: 'normal',
      actionUrl: '/admin/tutor-requests',
      actionText: 'View Requests',
      icon: '🗑️',
      metadata: {
        'request_id': requestId,
        'requester_name': requesterName,
      },
      sendEmail: true,
    );
  }

  /// Notify user when their tutor request status changes
  static Future<void> notifyTutorRequestStatusChanged({
    required String userId,
    required String requestId,
    required String oldStatus,
    required String newStatus,
    String? adminNotes,
  }) async {
    String title;
    String message;
    String priority = 'normal';
    String icon = '📋';

    switch (newStatus.toLowerCase()) {
      case 'in_progress':
        title = '🔄 Request In Progress';
        message = 'Your tutor request is now being processed by our team. We\'ll keep you updated!';
        priority = 'normal';
        icon = '🔄';
        break;
      case 'matched':
        title = '🎉 Tutor Matched!';
        message = 'Great news! We found a tutor for your request. Check the details now!';
        priority = 'high';
        icon = '🎉';
        break;
      case 'closed':
        title = 'Request Closed';
        message = 'Your tutor request has been closed.${adminNotes != null ? " Note: $adminNotes" : ""}';
        priority = 'normal';
        icon = '✅';
        break;
      default:
        title = '📋 Request Status Updated';
        message = 'Your tutor request status has been updated to: ${newStatus.replaceAll('_', ' ')}.';
        priority = 'normal';
        icon = '📋';
    }

    await _sendNotificationViaAPI(
      userId: userId,
      type: 'tutor_request_status_changed',
      title: title,
      message: message,
      priority: priority,
      actionUrl: '/requests/$requestId',
      actionText: 'View Details',
      icon: icon,
      metadata: {
        'request_id': requestId,
        'old_status': oldStatus,
        'new_status': newStatus,
        if (adminNotes != null) 'admin_notes': adminNotes,
      },
      sendEmail: true,
      sendPush: newStatus == 'matched' || newStatus == 'in_progress',
    );
  }

  // ============================================
  // ABANDONED BOOKING REMINDER NOTIFICATIONS
  // ============================================

  /// Notify user to complete their abandoned booking
  /// Called when user reached review screen but didn't complete booking
  static Future<void> notifyAbandonedBookingReminder({
    required String userId,
    required String tutorId,
    required String tutorName,
    required String bookingType, // 'trial' or 'normal'
    required String tutorProfileDeepLink, // Format: /tutor/{tutorId}
    String? subject,
  }) async {
    final title = bookingType == 'trial'
        ? '⏰ Complete Your Trial Booking'
        : '⏰ Complete Your Booking Request';
    
    final message = bookingType == 'trial'
        ? 'You started booking a trial session with $tutorName${subject != null ? " for $subject" : ""}. Complete your booking to secure your spot!'
        : 'You started booking sessions with $tutorName${subject != null ? " for $subject" : ""}. Complete your booking request to get started!';

    await _sendNotificationViaAPI(
      userId: userId,
      type: 'abandoned_booking_reminder',
      title: title,
      message: message,
      priority: 'normal',
      actionUrl: tutorProfileDeepLink, // Deep link to tutor profile
      actionText: 'View Tutor Profile',
      icon: '⏰',
      metadata: {
        'tutor_id': tutorId,
        'tutor_name': tutorName,
        'booking_type': bookingType,
        'tutor_profile_deep_link': tutorProfileDeepLink,
        if (subject != null) 'subject': subject,
      },
      sendEmail: true,
      sendPush: true,
    );
  }
}
