/**
 * Notification Navigation Service
 * 
 * Handles deep linking and navigation for notifications
 * Parses action_url and routes to appropriate screens
 * 
 * Refactored to use NavigationService for proper stack management
 */

import 'package:flutter/material.dart';
import 'package:prepskul/core/services/supabase_service.dart';
import 'package:prepskul/core/navigation/navigation_service.dart';
import 'package:prepskul/features/booking/services/booking_service.dart';

class NotificationNavigationService {
  /// Navigate to the appropriate screen based on notification action URL
  static Future<void> navigateToAction({
    required BuildContext? context,
    required String? actionUrl,
    required String? notificationType,
    Map<String, dynamic>? metadata,
  }) async {
    if (actionUrl == null || actionUrl.isEmpty) {
      return;
    }

    final navService = NavigationService();
    if (!navService.isReady) {
      print('⚠️ [NOTIF_NAV] NavigationService not ready, queueing action: $actionUrl');
      navService.queueDeepLink(Uri.parse(actionUrl));
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
        print('⚠️ [NOTIF_NAV] No user found, cannot navigate');
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
        await _navigateToBooking(pathSegments, userType);
      } else if (pathSegments[0] == 'trial-sessions') {
        await _navigateToTrialSession(pathSegments, userType);
      } else if (pathSegments[0] == 'profile') {
        await _navigateToProfile(userType: userType);
      } else if (pathSegments[0] == 'tutor') {
        await _navigateToTutorSection(pathSegments, userType);
      } else if (pathSegments[0] == 'student') {
        await _navigateToStudentSection(pathSegments, userType);
      } else if (pathSegments[0] == 'sessions') {
        await _navigateToSession(pathSegments, userType);
      } else if (pathSegments[0] == 'payments') {
        await _navigateToPayment(pathSegments, userType);
      } else {
        // Unknown path, try to navigate based on notification type
        await _navigateByNotificationType(notificationType, metadata, userType);
      }
    } catch (e) {
      print('❌ [NOTIF_NAV] Error navigating to notification action: $e');
      // Don't throw - navigation failure shouldn't break the app
    }
  }

  /// Navigate to booking details
  static Future<void> _navigateToBooking(
    List<String> pathSegments,
    String? userType,
  ) async {
    if (pathSegments.length < 2) {
      return;
    }

    final bookingId = pathSegments[1];
    final navService = NavigationService();

    try {
      // Fetch booking request to validate it exists
      await BookingService.getBookingRequestById(bookingId);

      // Check if user is tutor or student
      if (userType == 'tutor') {
        // Navigate to tutor booking detail screen (push, not replace)
        // TODO: Create proper route for booking detail
        // For now, navigate to requests tab which will show the booking
        await navService.navigateToRoute(
          '/tutor-nav',
          arguments: {'initialTab': 1}, // Requests tab
          replace: false, // Push to allow back navigation
        );
      } else {
        // For students/parents, navigate to requests tab
        final role = userType == 'parent' ? 'parent' : 'student';
        await navService.navigateToRoute(
          role == 'parent' ? '/parent-nav' : '/student-nav',
          arguments: {'initialTab': 2}, // Requests tab
          replace: false,
        );
      }
    } catch (e) {
      print('❌ [NOTIF_NAV] Error navigating to booking: $e');
      // Fallback: navigate to requests tab
      final role = userType == 'parent' ? 'parent' : (userType == 'tutor' ? 'tutor' : 'student');
      final route = role == 'tutor' ? '/tutor-nav' : (role == 'parent' ? '/parent-nav' : '/student-nav');
      final tab = role == 'tutor' ? 1 : 2;
      await navService.navigateToRoute(
        route,
        arguments: {'initialTab': tab},
        replace: false,
      );
    }
  }

  /// Navigate to trial session details
  static Future<void> _navigateToTrialSession(
    List<String> pathSegments,
    String? userType,
  ) async {
    if (pathSegments.length < 2) {
      return;
    }

    final trialId = pathSegments[1];
    final navService = NavigationService();

    // Navigate to requests tab where trial sessions are shown
    // TODO: Create proper route for trial session details
    final role = userType == 'parent' ? 'parent' : (userType == 'tutor' ? 'tutor' : 'student');
    final route = role == 'tutor' ? '/tutor-nav' : (role == 'parent' ? '/parent-nav' : '/student-nav');
    final tab = role == 'tutor' ? 1 : 2;
    
    await navService.navigateToRoute(
      route,
      arguments: {'initialTab': tab, 'trialId': trialId},
      replace: false,
    );
  }

  /// Navigate to profile
  static Future<void> _navigateToProfile({
    String? userType,
  }) async {
    final navService = NavigationService();
    
    // Get user type if not provided
    if (userType == null) {
      try {
        final userId = SupabaseService.currentUser?.id;
        if (userId != null) {
          final profile = await SupabaseService.client
              .from('profiles')
              .select('user_type')
              .eq('id', userId)
              .maybeSingle();
          userType = profile?['user_type'] as String?;
        }
      } catch (e) {
        print('❌ [NOTIF_NAV] Error fetching user type: $e');
      }
    }

    // Navigate to profile tab in main nav
    final role = userType == 'tutor' ? 'tutor' : (userType == 'parent' ? 'parent' : 'student');
    final route = role == 'tutor' ? '/tutor-nav' : (role == 'parent' ? '/parent-nav' : '/student-nav');
    
    await navService.navigateToRoute(
      route,
      arguments: {'initialTab': 3}, // Profile tab
      replace: false,
    );
  }

  /// Navigate to tutor section
  static Future<void> _navigateToTutorSection(
    List<String> pathSegments,
    String? userType,
  ) async {
    final navService = NavigationService();
    
    if (pathSegments.length < 2) {
      // Navigate to tutor home
      if (userType == 'tutor') {
        await navService.navigateToRoute('/tutor-nav', replace: false);
      }
      return;
    }

    final section = pathSegments[1];

    if (section == 'requests' || section == 'bookings') {
      // Navigate to requests tab
      if (userType == 'tutor') {
        await navService.navigateToRoute(
          '/tutor-nav',
          arguments: {'initialTab': 1}, // Requests tab
          replace: false,
        );
      }
    } else if (section == 'sessions') {
      // Navigate to sessions tab
      if (userType == 'tutor') {
        await navService.navigateToRoute(
          '/tutor-nav',
          arguments: {'initialTab': 2}, // Sessions tab
          replace: false,
        );
      }
    } else if (section == 'bookings' && pathSegments.length >= 3) {
      // Navigate to specific booking detail
      final bookingId = pathSegments[2];
      try {
        // TODO: Create proper route for booking detail
        // For now, navigate to requests tab
        await navService.navigateToRoute(
          '/tutor-nav',
          arguments: {'initialTab': 1, 'bookingId': bookingId},
          replace: false,
        );
      } catch (e) {
        print('❌ [NOTIF_NAV] Error navigating to booking: $e');
      }
    }
  }

  /// Navigate to student section
  static Future<void> _navigateToStudentSection(
    List<String> pathSegments,
    String? userType,
  ) async {
    final navService = NavigationService();
    
    if (pathSegments.length < 2) {
      // Navigate to student home
      final role = userType == 'parent' ? 'parent' : 'student';
      final route = role == 'parent' ? '/parent-nav' : '/student-nav';
      await navService.navigateToRoute(route, replace: false);
      return;
    }

    final section = pathSegments[1];

    if (section == 'requests' || section == 'bookings') {
      // Navigate to requests tab
      final role = userType == 'parent' ? 'parent' : 'student';
      final route = role == 'parent' ? '/parent-nav' : '/student-nav';
      await navService.navigateToRoute(
        route,
        arguments: {'initialTab': 2}, // Requests tab
        replace: false,
      );
    }
  }

  /// Navigate to session details
  static Future<void> _navigateToSession(
    List<String> pathSegments,
    String? userType,
  ) async {
    final navService = NavigationService();
    
    if (pathSegments.length < 2) {
      // Navigate to sessions tab
      if (userType == 'tutor') {
        await navService.navigateToRoute(
          '/tutor-nav',
          arguments: {'initialTab': 2}, // Sessions tab
          replace: false,
        );
      }
      return;
    }

    final action = pathSegments.length >= 3 ? pathSegments[2] : null;

    if (action == 'review') {
      // TODO: Navigate to review screen when implemented
      // For now, navigate to sessions tab
      if (userType == 'tutor') {
        await navService.navigateToRoute(
          '/tutor-nav',
          arguments: {'initialTab': 2}, // Sessions tab
          replace: false,
        );
      }
    } else {
      // Navigate to sessions tab (session details can be shown there)
      if (userType == 'tutor') {
        await navService.navigateToRoute(
          '/tutor-nav',
          arguments: {'initialTab': 2}, // Sessions tab
          replace: false,
        );
      }
    }
  }

  /// Navigate to payment details
  static Future<void> _navigateToPayment(
    List<String> pathSegments,
    String? userType,
  ) async {
    final navService = NavigationService();
    
    if (pathSegments.length < 2) {
      // No payment ID, navigate to requests tab
      final role = userType == 'tutor'
          ? 'tutor'
          : (userType == 'parent' ? 'parent' : 'student');
      final route = role == 'tutor' ? '/tutor-nav' : (role == 'parent' ? '/parent-nav' : '/student-nav');
      await navService.navigateToRoute(
        route,
        arguments: {'initialTab': 2}, // Requests tab
        replace: false,
      );
      return;
    }

    final paymentRequestId = pathSegments[1];
    
    // Navigate to booking payment screen via route
    await navService.navigateToRoute(
      '/payments/$paymentRequestId',
      replace: false,
    );
  }

  /// Navigate based on notification type (fallback)
  static Future<void> _navigateByNotificationType(
    String? notificationType,
    Map<String, dynamic>? metadata,
    String? userType,
  ) async {
    if (notificationType == null) {
      return;
    }

    final navService = NavigationService();

    // Navigate based on notification type
    switch (notificationType) {
      case 'booking_request':
      case 'booking_accepted':
      case 'booking_rejected':
        // Navigate to requests/bookings tab
        final role = userType == 'tutor'
            ? 'tutor'
            : (userType == 'parent' ? 'parent' : 'student');
        final route = role == 'tutor' ? '/tutor-nav' : (role == 'parent' ? '/parent-nav' : '/student-nav');
        final tab = userType == 'tutor' ? 1 : 2; // Requests tab
        await navService.navigateToRoute(
          route,
          arguments: {'initialTab': tab},
          replace: false,
        );
        break;

      case 'trial_request':
      case 'trial_accepted':
      case 'trial_rejected':
        // Navigate to requests tab (trial sessions shown there)
        final role2 = userType == 'tutor'
            ? 'tutor'
            : (userType == 'parent' ? 'parent' : 'student');
        final route2 = role2 == 'tutor' ? '/tutor-nav' : (role2 == 'parent' ? '/parent-nav' : '/student-nav');
        final tab2 = userType == 'tutor' ? 1 : 2; // Requests tab
        await navService.navigateToRoute(
          route2,
          arguments: {'initialTab': tab2},
          replace: false,
        );
        break;

      case 'payment_received':
      case 'payment_successful':
      case 'payment_failed':
        // Navigate to profile tab (wallet shown there for tutors)
        final role3 = userType == 'tutor'
            ? 'tutor'
            : (userType == 'parent' ? 'parent' : 'student');
        final route3 = role3 == 'tutor' ? '/tutor-nav' : (role3 == 'parent' ? '/parent-nav' : '/student-nav');
        await navService.navigateToRoute(
          route3,
          arguments: {'initialTab': 3}, // Profile tab
          replace: false,
        );
        break;

      case 'session_completed':
      case 'session_reminder':
      case 'session_starting_soon':
        // Navigate to sessions tab (tutors only)
        if (userType == 'tutor') {
          await navService.navigateToRoute(
            '/tutor-nav',
            arguments: {'initialTab': 2}, // Sessions tab
            replace: false,
          );
        }
        break;

      case 'profile_approved':
      case 'profile_rejected':
      case 'profile_improvement':
        // Navigate to profile screen
        await _navigateToProfile(userType: userType);
        break;

      default:
        // Unknown notification type, do nothing
        break;
    }
  }
}
