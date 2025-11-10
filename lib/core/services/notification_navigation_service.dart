/**
 * Notification Navigation Service
 * 
 * Handles deep linking and navigation for notifications
 * Parses action_url and routes to appropriate screens
 */

import 'package:flutter/material.dart';
import 'package:prepskul/core/services/supabase_service.dart';

class NotificationNavigationService {
  /// Navigate to the appropriate screen based on notification action URL
  static Future<void> navigateToAction({
    required BuildContext context,
    required String? actionUrl,
    required String? notificationType,
    Map<String, dynamic>? metadata,
  }) async {
    if (actionUrl == null || actionUrl.isEmpty) {
      return;
    }

    try {
      // Parse the action URL
      final uri = Uri.parse(actionUrl);
      final path = uri.path;
      final pathSegments = path.split('/').where((s) => s.isNotEmpty).toList();

      if (pathSegments.isEmpty) {
        return;
      }

      // Get current user role
      final userId = SupabaseService.currentUser?.id;
      if (userId == null) {
        return;
      }

      // Get user profile to determine role
      final profile = await SupabaseService.client
          .from('profiles')
          .select('user_type')
          .eq('id', userId)
          .maybeSingle();

      final userType = profile?['user_type'] as String?;

      // Route based on path
      if (pathSegments[0] == 'bookings') {
        await _navigateToBooking(context, pathSegments, userType);
      } else if (pathSegments[0] == 'trial-sessions') {
        await _navigateToTrialSession(context, pathSegments, userType);
      } else if (pathSegments[0] == 'profile') {
        await _navigateToProfile(context);
      } else if (pathSegments[0] == 'tutor') {
        await _navigateToTutorSection(context, pathSegments);
      } else if (pathSegments[0] == 'student') {
        await _navigateToStudentSection(context, pathSegments);
      } else if (pathSegments[0] == 'sessions') {
        await _navigateToSession(context, pathSegments);
      } else if (pathSegments[0] == 'payments') {
        await _navigateToPayment(context, pathSegments);
      } else {
        // Unknown path, try to navigate based on notification type
        await _navigateByNotificationType(context, notificationType, metadata);
      }
    } catch (e) {
      print('❌ Error navigating to notification action: $e');
      // Don't throw - navigation failure shouldn't break the app
    }
  }

  /// Navigate to booking details
  static Future<void> _navigateToBooking(
    BuildContext context,
    List<String> pathSegments,
    String? userType,
  ) async {
    if (pathSegments.length < 2) {
      return;
    }

    final bookingId = pathSegments[1];

    // Navigate to booking details screen
    // TODO: Replace with actual booking details screen route
    // Navigator.pushNamed(
    //   context,
    //   '/booking-details',
    //   arguments: {'bookingId': bookingId},
    // );

    // For now, show a snackbar
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Navigate to booking: $bookingId'),
          action: SnackBarAction(label: 'OK', onPressed: () {}),
        ),
      );
    }
  }

  /// Navigate to trial session details
  static Future<void> _navigateToTrialSession(
    BuildContext context,
    List<String> pathSegments,
    String? userType,
  ) async {
    if (pathSegments.length < 2) {
      return;
    }

    final trialId = pathSegments[1];

    // Navigate to trial session details screen
    // TODO: Replace with actual trial session details screen route
    // Navigator.pushNamed(
    //   context,
    //   '/trial-session-details',
    //   arguments: {'trialId': trialId},
    // );

    // For now, show a snackbar
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Navigate to trial session: $trialId'),
          action: SnackBarAction(label: 'OK', onPressed: () {}),
        ),
      );
    }
  }

  /// Navigate to profile
  static Future<void> _navigateToProfile(BuildContext context) async {
    // Navigate to profile screen
    // TODO: Replace with actual profile screen route
    // Navigator.pushNamed(context, '/profile');

    // For now, show a snackbar
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Navigate to profile'),
          action: SnackBarAction(label: 'OK', onPressed: () {}),
        ),
      );
    }
  }

  /// Navigate to tutor section
  static Future<void> _navigateToTutorSection(
    BuildContext context,
    List<String> pathSegments,
  ) async {
    if (pathSegments.length < 2) {
      return;
    }

    final section = pathSegments[1];

    if (section == 'bookings' && pathSegments.length >= 3) {
      final bookingId = pathSegments[2];
      // Navigate to tutor booking details
      // TODO: Replace with actual route
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Navigate to tutor booking: $bookingId')),
        );
      }
    }
  }

  /// Navigate to student section
  static Future<void> _navigateToStudentSection(
    BuildContext context,
    List<String> pathSegments,
  ) async {
    if (pathSegments.length < 2) {
      return;
    }

    final section = pathSegments[1];

    if (section == 'bookings' && pathSegments.length >= 3) {
      final bookingId = pathSegments[2];
      // Navigate to student booking details
      // TODO: Replace with actual route
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Navigate to student booking: $bookingId')),
        );
      }
    }
  }

  /// Navigate to session details
  static Future<void> _navigateToSession(
    BuildContext context,
    List<String> pathSegments,
  ) async {
    if (pathSegments.length < 2) {
      return;
    }

    final sessionId = pathSegments[1];
    final action = pathSegments.length >= 3 ? pathSegments[2] : null;

    if (action == 'review') {
      // Navigate to review screen
      // TODO: Replace with actual review screen route
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Navigate to review for session: $sessionId')),
        );
      }
    } else {
      // Navigate to session details
      // TODO: Replace with actual session details screen route
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Navigate to session: $sessionId')),
        );
      }
    }
  }

  /// Navigate to payment details
  static Future<void> _navigateToPayment(
    BuildContext context,
    List<String> pathSegments,
  ) async {
    if (pathSegments.length < 2) {
      return;
    }

    final paymentId = pathSegments[1];

    // Navigate to payment details screen
    // TODO: Replace with actual payment details screen route
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Navigate to payment: $paymentId')),
      );
    }
  }

  /// Navigate based on notification type (fallback)
  static Future<void> _navigateByNotificationType(
    BuildContext context,
    String? notificationType,
    Map<String, dynamic>? metadata,
  ) async {
    if (notificationType == null) {
      return;
    }

    // Navigate based on notification type
    switch (notificationType) {
      case 'booking_request':
      case 'booking_accepted':
      case 'booking_rejected':
        // Navigate to bookings screen
        // TODO: Replace with actual route
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Navigate to bookings')));
        }
        break;

      case 'trial_request':
      case 'trial_accepted':
      case 'trial_rejected':
        // Navigate to trial sessions screen
        // TODO: Replace with actual route
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Navigate to trial sessions')),
          );
        }
        break;

      case 'payment_received':
      case 'payment_successful':
      case 'payment_failed':
        // Navigate to payments screen
        // TODO: Replace with actual route
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Navigate to payments')));
        }
        break;

      case 'session_completed':
      case 'session_reminder':
        // Navigate to sessions screen
        // TODO: Replace with actual route
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Navigate to sessions')));
        }
        break;

      case 'profile_approved':
      case 'profile_rejected':
      case 'profile_improvement':
        // Navigate to profile screen
        // TODO: Replace with actual route
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Navigate to profile')));
        }
        break;

      default:
        // Unknown notification type, do nothing
        break;
    }
  }
}
