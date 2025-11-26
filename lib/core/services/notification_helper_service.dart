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
import 'package:prepskul/core/services/pricing_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;

class NotificationHelperService {
  // Get API base URL from environment or use default
  static String get _apiBaseUrl {
    // In Flutter, we'll use the web API URL
    // You can also use flutter_dotenv to load from .env
    return const String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'https://app.prepskul.com/api',
    );
  }

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
      metadata: metadata,
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
        },
      );

      if (response.statusCode == 200) {
        // Success - push + email notifications sent via API
        // In-app notification already created above
        // All three notification types delivered:
        // ✅ In-app (Supabase)
        // ✅ Push (Firebase via API)
        // ✅ Email (Resend via API, if sendEmail=true)
        print('✅ Notification sent via API: $type to user $userId');
      } else {
        // API returned error status code
        print('⚠️ Notification API returned status ${response.statusCode}: ${response.body}');
        // Log error but don't throw - in-app notification already created
        if (response.statusCode == 429) {
          print('⚠️ Rate limit detected for notification API. Email may not have been sent.');
        } else if (response.statusCode >= 500) {
          print('⚠️ Server error in notification API. Email may not have been sent.');
        }
      }
      // If API returns error, in-app notification is still created (silent fail)
    } catch (e) {
      // API call failed (network error, timeout, or API not deployed)
      // This is expected if API is not deployed - in-app notification already created above
      // Log error for debugging but don't throw
      if (e is TimeoutException) {
        print('⚠️ Notification API request timed out. In-app notification still created.');
      } else {
        print('⚠️ Notification API call failed: $e. In-app notification still created.');
      }
      // Silent fail - notification still works via in-app
      // User will see notification when they open the app
    }
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
      sendEmail: true,
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
      type: 'booking_accepted',
      title: '✅ Booking Accepted!',
      message: message,
      priority: 'high',
      actionUrl: actionUrl,
      actionText: actionText,
      icon: '✅',
      metadata: {
        'request_id': requestId,
        'tutor_id': tutorId,
        'tutor_name': tutorName,
        'subject': subject,
        if (paymentRequestId != null) 'payment_request_id': paymentRequestId,
        if (senderAvatarUrl != null) 'sender_avatar_url': senderAvatarUrl,
        'sender_initials': tutorName.isNotEmpty ? tutorName[0].toUpperCase() : null,
      },
      sendEmail: true,
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
  }) async {
    await _sendNotificationViaAPI(
      userId: tutorId,
      type: 'trial_request',
      title: '🎯 New Trial Session Request',
      message: '$studentName wants to book a trial session for $subject on ${scheduledDate.toLocal().toString().split(' ')[0]} at $scheduledTime.',
      priority: 'high',
      actionUrl: '/trials/$trialId',
      actionText: 'Review Request',
      icon: '🎯',
      metadata: {
        'trial_id': trialId,
        'student_id': studentId,
        'student_name': studentName,
        'subject': subject,
        'scheduled_date': scheduledDate.toIso8601String(),
        'scheduled_time': scheduledTime,
        if (senderAvatarUrl != null) 'sender_avatar_url': senderAvatarUrl,
        'sender_initials': studentName.isNotEmpty ? studentName[0].toUpperCase() : null,
      },
      sendEmail: true,
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
      title: '✅ Trial Session Confirmed!',
      message: '$tutorName has accepted your trial session for $subject on ${scheduledDate.toLocal().toString().split(' ')[0]} at $scheduledTime. Please proceed to payment.',
      priority: 'high',
      actionUrl: '/trials/$trialId/payment',
      actionText: 'Pay Now',
      icon: '✅',
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
      sendEmail: true,
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
      sendEmail: true,
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
      sendEmail: true,
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
      title: '💰 Payment Received',
      message: 'You received $amount $currency from $studentName for ${sessionType ?? 'session'}.',
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
      sendEmail: true,
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
      sendEmail: true,
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
      title: '✅ Payment Successful',
      message: 'Your payment of $amount $currency was successful.${sessionType != null ? ' Your ${sessionType} session is confirmed!' : ''}',
      priority: 'normal',
      actionUrl: '/payments/$paymentId',
      actionText: 'View Receipt',
      icon: '✅',
      metadata: {
        'payment_id': paymentId,
        'amount': amount,
        'currency': currency,
        'session_type': sessionType,
      },
      sendEmail: true,
    );
  }

  // ============================================
  // SESSION NOTIFICATIONS
  // ============================================

  /// Schedule session reminder (30 minutes before and 24 hours before)
  /// 
  /// Schedules reminders for both tutor and student
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
        }),
      );

      if (response.statusCode == 200) {
        print('✅ Session reminders scheduled for session: $sessionId');
      } else {
        print('⚠️ Failed to schedule session reminders: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error scheduling session reminders: $e');
      // Don't throw - scheduling reminders shouldn't fail session creation
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
      sendPush: true,
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
      title: '💰 Earnings Added',
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
      sendPush: true,
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
        }),
      );

      if (response.statusCode == 200) {
        print('✅ Feedback reminder scheduled for session: $sessionId');
      } else {
        print('⚠️ Failed to schedule feedback reminder: ${response.statusCode}');
        // Fallback: Create in-app notification immediately (will be shown when user opens app)
        // The app can check if 24h has passed when displaying notifications
        await NotificationService.createNotification(
          userId: userId,
          type: 'feedback_reminder',
          title: '💬 Feedback Reminder',
          message: 'Please provide feedback for your completed session. It helps your tutor improve!',
          priority: 'normal',
          actionUrl: '/sessions/$sessionId/feedback',
          actionText: 'Provide Feedback',
          icon: '💬',
          metadata: {
            'session_id': sessionId,
            'reminder_time': reminderTime.toIso8601String(),
          },
        );
      }
    } catch (e) {
      print('❌ Error scheduling feedback reminder: $e');
      // Fallback: Create in-app notification
      try {
        await NotificationService.createNotification(
          userId: userId,
          type: 'feedback_reminder',
          title: '💬 Feedback Reminder',
          message: 'Please provide feedback for your completed session. It helps your tutor improve!',
          priority: 'normal',
          actionUrl: '/sessions/$sessionId/feedback',
          actionText: 'Provide Feedback',
          icon: '💬',
          metadata: {
            'session_id': sessionId,
            'reminder_time': reminderTime.toIso8601String(),
          },
        );
      } catch (e2) {
        print('⚠️ Could not create fallback feedback reminder notification: $e2');
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
      title: '✅ Session Completed',
      message: 'Your $sessionType session with $otherPartyName for $subject has been completed. Please leave a review!',
      priority: 'normal',
      actionUrl: '/sessions/$sessionId/review',
      actionText: 'Leave Review',
      icon: '✅',
      metadata: {
        'session_id': sessionId,
        'session_type': sessionType,
        'other_party_name': otherPartyName,
        'subject': subject,
      },
      sendEmail: true,
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
        }),
      );

      if (response.statusCode == 200) {
        print('✅ Review reminder scheduled for user: $userId');
      }
    } catch (e) {
      print('❌ Error scheduling review reminder: $e');
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
    // This is already handled in the admin dashboard email sending
    // But we can add in-app notification here
    await NotificationService.createNotification(
      userId: tutorId,
      type: 'profile_approved',
      title: '🎉 Profile Approved!',
      message: 'Congratulations! Your tutor profile has been approved and is now live. Students can now book sessions with you!',
      priority: 'high',
      actionUrl: '/tutor/profile',
      actionText: 'View Profile',
      icon: '🎉',
      metadata: {
        'rating': rating,
        'session_price': sessionPrice,
        'pricing_tier': pricingTier,
      },
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
      sendEmail: true,
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
      sendEmail: true,
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
      title: '✅ Payment Confirmed',
      message: 'Your payment of ${PricingService.formatPrice(amount)} has been confirmed. Your sessions are now active!',
      priority: 'high',
      actionUrl: bookingRequestId != null ? '/bookings/$bookingRequestId' : '/payments',
      actionText: 'View Booking',
      icon: '✅',
      metadata: {
        'payment_request_id': paymentRequestId,
        'booking_request_id': bookingRequestId,
        'amount': amount,
      },
      sendEmail: true,
    );

    // Notify tutor
    await _sendNotificationViaAPI(
      userId: tutorId,
      type: 'payment_received',
      title: '💰 Payment Received',
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
      sendEmail: false,
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
      sendEmail: true,
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
      title: '✅ Trial Payment Confirmed',
      message: 'Your trial session payment has been confirmed. ${meetLink != null ? "Meet link is now available." : "Your session is scheduled."}',
      priority: 'high',
      actionUrl: '/trials/$trialSessionId',
      actionText: 'View Session',
      icon: '✅',
      metadata: {
        'trial_session_id': trialSessionId,
        'subject': subject,
        'meet_link': meetLink,
      },
      sendEmail: true,
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
      title: '💰 Trial Payment Received',
      message: 'A student has paid for their trial session in $subject. The session is now scheduled.',
      priority: 'normal',
      actionUrl: '/tutor/trials/$trialSessionId',
      actionText: 'View Session',
      icon: '💰',
      metadata: {
        'trial_session_id': trialSessionId,
        'subject': subject,
      },
      sendEmail: false,
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
      sendEmail: true,
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
        print('⚠️ No admin users found to notify about new user signup');
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
          sendEmail: true,
        );
      }

      print('✅ Notified ${adminResponse.length} admin(s) about new user signup: $userName');
    } catch (e) {
      print('⚠️ Error notifying admins about new user signup: $e');
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
        print('⚠️ No admin users found to notify about survey completion');
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
          sendEmail: true,
        );
      }

      print('✅ Notified ${adminResponse.length} admin(s) about survey completion for $userName');
    } catch (e) {
      print('⚠️ Error notifying admins about survey completion: $e');
      // Don't throw - notification failure shouldn't block survey completion
    }
  }
}

