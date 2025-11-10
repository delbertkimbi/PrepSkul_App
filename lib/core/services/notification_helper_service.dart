/**
 * Notification Helper Service
 * 
 * Centralized service for sending notifications for all events
 * Handles both in-app and email notifications
 */

import 'package:prepskul/core/services/notification_service.dart';
import 'dart:convert';
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

  /// Send notification via API (handles both in-app and email)
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
  }) async {
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
        }),
      );

      if (response.statusCode == 200) {
        print('✅ Notification sent via API to user: $userId');
      } else {
        print('⚠️ Failed to send notification via API: ${response.statusCode}');
        // Fallback to in-app only
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
      }
    } catch (e) {
      print('❌ Error sending notification via API: $e');
      // Fallback to in-app only
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
      },
      sendEmail: true,
    );
  }

  /// Notify student/parent when tutor accepts booking request
  static Future<void> notifyBookingRequestAccepted({
    required String studentId,
    required String tutorId,
    required String requestId,
    required String tutorName,
    required String subject,
  }) async {
    await _sendNotificationViaAPI(
      userId: studentId,
      type: 'booking_accepted',
      title: '✅ Booking Accepted!',
      message: '$tutorName has accepted your booking request for $subject. Your sessions are now confirmed!',
      priority: 'high',
      actionUrl: '/bookings/$requestId',
      actionText: 'View Booking',
      icon: '✅',
      metadata: {
        'request_id': requestId,
        'tutor_id': tutorId,
        'tutor_name': tutorName,
        'subject': subject,
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
}

