/**
 * Notification Navigation Service
 * 
 * Handles deep linking and navigation for notifications
 * Parses action_url and routes to appropriate screens
 * 
 * Refactored to use NavigationService for proper stack management
 */

import 'package:flutter/material.dart';
import 'package:prepskul/core/services/log_service.dart';
import 'package:prepskul/core/services/supabase_service.dart';
import 'package:prepskul/core/services/auth_service.dart';
import 'package:prepskul/core/navigation/navigation_service.dart';
import 'package:prepskul/features/booking/services/booking_service.dart';
import 'package:prepskul/features/booking/services/trial_session_service.dart';
import 'package:prepskul/features/booking/models/trial_session_model.dart';
import 'package:prepskul/features/booking/screens/trial_payment_screen.dart';
import 'package:prepskul/features/booking/screens/request_detail_screen.dart';
import 'package:prepskul/features/booking/screens/tutor_booking_detail_screen.dart';
import 'package:prepskul/features/booking/screens/reschedule_request_review_screen.dart';
import 'package:prepskul/features/tutor/screens/tutor_onboarding_screen.dart';
import 'package:prepskul/features/admin/screens/admin_dashboard_screen.dart';
import 'package:prepskul/features/admin/screens/admin_tutor_detail_screen.dart';
import 'package:prepskul/features/admin/screens/admin_user_detail_screen.dart';
import 'package:prepskul/features/admin/screens/admin_tutor_request_detail_screen.dart';
import 'package:prepskul/core/services/tutor_service.dart';
import 'package:prepskul/features/discovery/screens/tutor_detail_screen.dart';

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
      LogService.warning('[NOTIF_NAV] NavigationService not ready, queueing action: $actionUrl');
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
        LogService.warning('[NOTIF_NAV] No user found, cannot navigate');
        return;
      }

      // Get user profile to determine role and admin status
      final profile = await SupabaseService.client
          .from('profiles')
          .select('user_type, is_admin')
          .eq('id', userId)
          .maybeSingle();

      final userTypeRaw = profile?['user_type'] as String?;
      final isAdmin = profile?['is_admin'] as bool? ?? false;
      // Determine effective user type - account for is_admin flag
      final userType = (isAdmin || userTypeRaw == 'admin') ? 'admin' : userTypeRaw;

      // Route based on path
      if (pathSegments[0] == 'admin') {
        // Admin routes
        await _navigateToAdminRoute(pathSegments, userType, metadata);
      } else if (pathSegments[0] == 'bookings') {
        await _navigateToBooking(pathSegments, userType);
      } else if (pathSegments[0] == 'trial-sessions') {
        await _navigateToTrialSession(pathSegments, userType);
      } else if (pathSegments[0] == 'trials') {
        // New trial routes: /trials/{id} or /trials/{id}/payment
        if (pathSegments.length >= 3 && pathSegments[2] == 'payment') {
          final trialId = pathSegments[1];
          await _navigateToTrialPayment(trialId, userType);
        } else {
          await _navigateToTrialSession(
            ['trial-sessions', ...pathSegments.sublist(1)],
            userType,
          );
        }
      } else if (pathSegments[0] == 'profile') {
        await _navigateToProfile(userType: userType);
      } else if (pathSegments[0] == 'tutor') {
        await _navigateToTutorSection(pathSegments, userType);
      } else if (pathSegments[0] == 'student') {
        await _navigateToStudentSection(pathSegments, userType);
      } else if (pathSegments[0] == 'sessions') {
        // Check if it's a reschedule request review
        if (pathSegments.length >= 3 && pathSegments[2] == 'reschedule') {
          await _navigateToRescheduleReview(pathSegments, metadata);
        } else {
          await _navigateToSession(pathSegments, userType);
        }
      } else if (pathSegments[0] == 'payments') {
        await _navigateToPayment(pathSegments, userType);
      } else {
        // Unknown path, try to navigate based on notification type
        await _navigateByNotificationType(notificationType, metadata, userType);
      }
    } catch (e) {
      LogService.error('[NOTIF_NAV] Error navigating to notification action: $e');
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
    final context = navService.context;

    try {
      // Fetch booking request
      final bookingRequest = await BookingService.getBookingRequestById(bookingId);

      if (context == null) {
        LogService.warning('[NOTIF_NAV] No context for booking navigation, queuing link');
        navService.queueDeepLink(Uri(path: '/bookings/$bookingId'));
        return;
      }

      // Check if user is tutor or student/parent
      if (userType == 'tutor') {
        // Navigate to tutor booking detail screen
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => TutorBookingDetailScreen(request: bookingRequest),
          ),
        );
      } else {
        // For students/parents, navigate to request detail screen
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => RequestDetailScreen(request: bookingRequest.toJson()),
          ),
        );
      }
    } catch (e) {
      LogService.error('[NOTIF_NAV] Error navigating to booking: $e');
      // Fallback: navigate to requests tab
      final role = userType == 'parent' ? 'parent' : (userType == 'tutor' ? 'tutor' : 'student');
      final route = role == 'tutor' ? '/tutor-nav' : (role == 'parent' ? '/parent-nav' : '/student-nav');
      final tab = role == 'tutor' ? 1 : 2;
      await navService.navigateToRoute(
        route,
        arguments: {'initialTab': tab},
        replace: true,
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

    final context = navService.context;

    try {
      // Fetch trial session
      final trialSession = await TrialSessionService.getTrialSessionById(trialId);

      if (context == null) {
        LogService.warning('[NOTIF_NAV] No context for trial navigation, queuing link');
        navService.queueDeepLink(Uri(path: '/trials/$trialId'));
        return;
      }

      // FIX: Navigate to appropriate screen based on user type
      if (userType == 'tutor') {
        // For tutors, navigate to tutor sessions screen (tab 1) which shows tutor's view
        // This will display the trial session in the tutor's context with approve/reject options
        await navService.navigateToRoute(
          '/tutor-nav',
          arguments: {'initialTab': 1, 'trialId': trialId},
          replace: true,
        );
      } else {
        // For students/parents, navigate to request detail screen (student view)
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => RequestDetailScreen(trialSession: trialSession),
          ),
        );
      }
    } catch (e) {
      LogService.error('[NOTIF_NAV] Error navigating to trial session: $e');
      // Fallback: navigate to requests tab
      final role = userType == 'parent' ? 'parent' : (userType == 'tutor' ? 'tutor' : 'student');
      final route = role == 'tutor' ? '/tutor-nav' : (role == 'parent' ? '/parent-nav' : '/student-nav');
      final tab = role == 'tutor' ? 1 : 2;
      
      await navService.navigateToRoute(
        route,
        arguments: {'initialTab': tab, 'trialId': trialId},
        replace: true,
      );
    }
  }

  /// Navigate directly to trial payment screen
  static Future<void> _navigateToTrialPayment(
    String trialId,
    String? userType,
  ) async {
    final navService = NavigationService();

    try {
      // Load trial session to pass into payment screen
      final TrialSession trial =
          await TrialSessionService.getTrialSessionById(trialId);

      final context = navService.context;
      if (context == null) {
        LogService.warning('[NOTIF_NAV] No context for trial payment navigation, queuing link');
        navService.queueDeepLink(Uri(path: '/trials/$trialId/payment'));
        return;
      }

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => TrialPaymentScreen(trialSession: trial),
        ),
      );
    } catch (e) {
      LogService.error('[NOTIF_NAV] Error navigating to trial payment: $e');
      // Fallback: navigate to trial sessions / requests tab
      await _navigateToTrialSession(['trial-sessions', trialId], userType);
    }
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
        LogService.error('[NOTIF_NAV] Error fetching user type: $e');
      }
    }

    // Navigate to profile tab in main nav
    final role = userType == 'tutor' ? 'tutor' : (userType == 'parent' ? 'parent' : 'student');
    final route = role == 'tutor' ? '/tutor-nav' : (role == 'parent' ? '/parent-nav' : '/student-nav');
    
    await navService.navigateToRoute(
      route,
      arguments: {'initialTab': 3}, // Profile tab
      replace: true,
    );
  }

  /// Navigate to tutor section
  static Future<void> _navigateToTutorSection(
    List<String> pathSegments,
    String? userType,
  ) async {
    final navService = NavigationService();
    
    if (pathSegments.length < 2) {
      // Navigate to tutor home (replace so back at root never reveals auth)
      if (userType == 'tutor') {
        await navService.navigateToRoute('/tutor-nav', replace: true);
      }
      return;
    }

    final section = pathSegments[1];

    // Handle tutor profile deep link: /tutor/{tutorId}
    // This is for viewing a tutor's profile (e.g., from abandoned booking reminder)
    if (section != 'requests' && section != 'bookings' && section != 'sessions' && section != 'profile' && section != 'dashboard' && section != 'onboarding') {
      // Likely a tutor ID - navigate to tutor detail screen
      final tutorId = section;
      final context = navService.context;
      
      try {
        // Fetch tutor data
        final tutor = await TutorService.fetchTutorById(tutorId);
        
        if (context == null) {
          LogService.warning('[NOTIF_NAV] No context for tutor profile navigation, queuing link');
          navService.queueDeepLink(Uri(path: '/tutor/$tutorId'));
          return;
        }

        if (tutor != null) {
          // Navigate to tutor detail screen
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => TutorDetailScreen(tutor: tutor),
            ),
          );
        } else {
          LogService.warning('[NOTIF_NAV] Tutor not found: $tutorId');
          // Fallback: navigate to find tutors
          await navService.navigateToRoute('/find-tutors', replace: false);
        }
      } catch (e) {
        LogService.error('[NOTIF_NAV] Error navigating to tutor profile: $e');
        // Fallback: navigate to find tutors
        await navService.navigateToRoute('/find-tutors', replace: false);
      }
      return;
    }

    if (section == 'requests' || section == 'bookings') {
      // Navigate to requests tab (replace so back at root never reveals auth)
      if (userType == 'tutor') {
        await navService.navigateToRoute(
          '/tutor-nav',
          arguments: {'initialTab': 1}, // Requests tab
          replace: true,
        );
      }
    } else if (section == 'sessions') {
      // Navigate to sessions tab (replace so back at root never reveals auth)
      if (userType == 'tutor') {
        await navService.navigateToRoute(
          '/tutor-nav',
          arguments: {'initialTab': 2}, // Sessions tab
          replace: true,
        );
      }
    } else if (section == 'bookings' && pathSegments.length >= 3) {
      // Navigate to specific booking detail
      final bookingId = pathSegments[2];
      final context = navService.context;
      
      try {
        // Fetch booking request
        final bookingRequest = await BookingService.getBookingRequestById(bookingId);
        
        if (context == null) {
          LogService.warning('[NOTIF_NAV] No context for booking navigation, queuing link');
          navService.queueDeepLink(Uri(path: '/tutor/bookings/$bookingId'));
          return;
        }

        // Navigate to tutor booking detail screen
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => TutorBookingDetailScreen(request: bookingRequest),
          ),
        );
      } catch (e) {
        LogService.error('[NOTIF_NAV] Error navigating to booking: $e');
        // Fallback: navigate to requests tab
        await navService.navigateToRoute(
          '/tutor-nav',
          arguments: {'initialTab': 1, 'bookingId': bookingId},
          replace: true,
        );
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
      await navService.navigateToRoute(route, replace: true);
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
      // Navigate to sessions tab (learner and tutor)
      final role = userType == 'tutor'
          ? 'tutor'
          : (userType == 'parent' ? 'parent' : 'student');
      final route = role == 'tutor' ? '/tutor-nav' : (role == 'parent' ? '/parent-nav' : '/student-nav');
      await navService.navigateToRoute(
        route,
        arguments: {'initialTab': 2}, // Sessions tab
        replace: false,
      );
      return;
    }

    final sessionId = pathSegments[1];
    final action = pathSegments.length >= 3 ? pathSegments[2] : null;

    if (action == 'feedback' || action == 'review') {
      // Navigate to feedback screen
      try {
        await navService.navigateToRoute(
          '/sessions/$sessionId/feedback',
          replace: false,
        );
      } catch (e) {
        LogService.error('[NOTIF_NAV] Error navigating to feedback screen: $e');
        // Fallback: navigate to sessions tab
        final role = userType == 'tutor'
            ? 'tutor'
            : (userType == 'parent' ? 'parent' : 'student');
        final route = role == 'tutor' ? '/tutor-nav' : (role == 'parent' ? '/parent-nav' : '/student-nav');
        await navService.navigateToRoute(
          route,
          arguments: {'initialTab': 2}, // Sessions tab
          replace: true,
        );
      }
    } else {
      // Navigate to sessions tab (session details can be shown there)
      final role = userType == 'tutor'
          ? 'tutor'
          : (userType == 'parent' ? 'parent' : 'student');
      final route = role == 'tutor' ? '/tutor-nav' : (role == 'parent' ? '/parent-nav' : '/student-nav');
      await navService.navigateToRoute(
        route,
        arguments: {'initialTab': 2}, // Sessions tab
        replace: true,
      );
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
        replace: true,
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
      case 'booking_approved': // New: booking approved notification
      case 'booking_rejected':
        // Check if payment request ID is in metadata - if so, navigate to payment
        final paymentRequestId = metadata?['payment_request_id'] as String?;
        if (paymentRequestId != null && notificationType == 'booking_approved') {
          // Navigate directly to payment screen
          await navService.navigateToRoute(
            '/payments/$paymentRequestId',
            replace: false,
          );
        } else if (notificationType == 'booking_rejected') {
          // For rejected bookings, navigate to Find Tutors tab (tab 1) for students/parents
          // Tutors still go to requests tab
          final role = userType == 'tutor'
              ? 'tutor'
              : (userType == 'parent' ? 'parent' : 'student');
          final route = role == 'tutor' ? '/tutor-nav' : (role == 'parent' ? '/parent-nav' : '/student-nav');
          // Students/parents go to Find Tutors tab (1), tutors go to Requests tab (1)
          final tab = userType == 'tutor' ? 1 : 1; // Find Tutors tab for students/parents
          await navService.navigateToRoute(
            route,
            arguments: {'initialTab': tab},
            replace: true,
          );
        } else {
          // Navigate to requests/bookings tab for other booking notifications
          final role = userType == 'tutor'
              ? 'tutor'
              : (userType == 'parent' ? 'parent' : 'student');
          final route = role == 'tutor' ? '/tutor-nav' : (role == 'parent' ? '/parent-nav' : '/student-nav');
          final tab = userType == 'tutor' ? 1 : 2; // Requests tab
          await navService.navigateToRoute(
            route,
            arguments: {'initialTab': tab},
            replace: true,
          );
        }
        break;

      case 'low_credits_balance':
        // Navigate to payment screen if payment request ID is in metadata
        final paymentRequestId = metadata?['payment_request_id'] as String?;
        if (paymentRequestId != null) {
          await navService.navigateToRoute(
            '/payments/$paymentRequestId',
            replace: false,
          );
        } else {
          // Navigate to payments tab
          final role = userType == 'tutor'
              ? 'tutor'
              : (userType == 'parent' ? 'parent' : 'student');
          final route = role == 'tutor' ? '/tutor-nav' : (role == 'parent' ? '/parent-nav' : '/student-nav');
          await navService.navigateToRoute(
            route,
            arguments: {'initialTab': 2}, // Requests/Payments tab
            replace: false,
          );
        }
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

      case 'user_signup':
      case 'survey_completed':
        // Admin notifications - navigate to admin detail screens
        // Check both user_type and is_admin (handled by userType calculation above)
        if (userType == 'admin') {
          final userId = metadata?['user_id'] as String?;
          final userTypeFromMeta = metadata?['user_type'] as String?;
          if (userId != null) {
            final context = navService.context;
            if (context != null) {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => AdminUserDetailScreen(
                    userId: userId,
                    userType: userTypeFromMeta,
                  ),
                ),
              );
            }
          }
        }
        break;

      case 'tutor_request':
        // Admin notifications - navigate to tutor request detail
        // Check both user_type and is_admin (handled by userType calculation above)
        if (userType == 'admin') {
          final requestId = metadata?['request_id'] as String?;
          if (requestId != null) {
            final context = navService.context;
            if (context != null) {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => AdminTutorRequestDetailScreen(
                    requestId: requestId,
                  ),
                ),
              );
            }
          }
        }
        break;

      case 'onboarding_reminder':
      case 'onboarding_incomplete':
        // Navigate to tutor onboarding screen
        if (userType == 'tutor') {
          final context = navService.context;
          if (context != null) {
            try {
              // Get user's basic info to pass to onboarding
              final userId = SupabaseService.currentUser?.id;
              if (userId != null) {
                final user = await AuthService.getCurrentUser();
                final basicInfo = {
                  'userId': userId,
                  'email': user['email'] as String?,
                  'phone': user['phone'] as String?,
                  'fullName': user['fullName'] as String?,
                };
                
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => TutorOnboardingScreen(basicInfo: basicInfo),
                  ),
                );
              }
            } catch (e) {
              LogService.error('[NOTIF_NAV] Error navigating to onboarding: $e');
              // Fallback to profile tab
              await _navigateToProfile(userType: userType);
            }
          } else {
            // Queue deep link if no context
            navService.queueDeepLink(Uri(path: '/tutor/onboarding'));
          }
        } else {
          // Non-tutors go to profile
          await _navigateToProfile(userType: userType);
        }
        break;

      case 'session_reschedule_request':
        // Navigate to reschedule request review if metadata has request ID
        if (metadata != null && metadata['reschedule_request_id'] != null) {
          final requestId = metadata['reschedule_request_id'] as String;
          await _navigateToRescheduleReview(['sessions', requestId, 'reschedule'], metadata);
        } else {
          // Fallback to sessions tab
          final role = userType == 'tutor'
              ? 'tutor'
              : (userType == 'parent' ? 'parent' : 'student');
          final route = role == 'tutor' ? '/tutor-nav' : (role == 'parent' ? '/parent-nav' : '/student-nav');
          await navService.navigateToRoute(
            route,
            arguments: {'initialTab': 2}, // Sessions tab
            replace: false,
          );
        }
        break;

      default:
        // Unknown notification type, do nothing
        break;
    }
  }

  /// Navigate to reschedule request review screen
  static Future<void> _navigateToRescheduleReview(
    List<String> pathSegments,
    Map<String, dynamic>? metadata,
  ) async {
    final navService = NavigationService();
    final context = navService.context;

    String? requestId;
    
    // Get request ID from metadata or path
    if (metadata != null && metadata['reschedule_request_id'] != null) {
      requestId = metadata['reschedule_request_id'] as String;
    } else if (pathSegments.length >= 2) {
      // Try to extract from path if available
      requestId = pathSegments[1];
    }

    if (requestId == null) {
      LogService.warning('[NOTIF_NAV] No reschedule request ID found');
      return;
    }

    if (context == null) {
      LogService.warning('[NOTIF_NAV] No context for reschedule review navigation, queuing link');
      navService.queueDeepLink(Uri(path: '/sessions/$requestId/reschedule'));
      return;
    }

    try {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => RescheduleRequestReviewScreen(
            rescheduleRequestId: requestId!, // Safe to use ! here since we checked null above
            sessionId: metadata?['session_id'] as String?,
            sessionType: metadata?['session_type'] as String?,
          ),
        ),
      );
    } catch (e) {
      LogService.error('[NOTIF_NAV] Error navigating to reschedule review: $e');
      // Fallback: navigate to sessions tab
      final userId = SupabaseService.currentUser?.id;
      if (userId != null) {
        final profile = await SupabaseService.client
            .from('profiles')
            .select('user_type')
            .eq('id', userId)
            .maybeSingle();
        final userType = profile?['user_type'] as String?;
        final role = userType == 'tutor'
            ? 'tutor'
            : (userType == 'parent' ? 'parent' : 'student');
        final route = role == 'tutor' ? '/tutor-nav' : (role == 'parent' ? '/parent-nav' : '/student-nav');
        await navService.navigateToRoute(
          route,
          arguments: {'initialTab': 2}, // Sessions tab
          replace: true,
        );
      }
    }
  }

  /// Navigate to admin section based on notification action
  static Future<void> _navigateToAdminRoute(
    List<String> pathSegments,
    String? userType,
    Map<String, dynamic>? metadata,
  ) async {
    if (userType != 'admin') {
      LogService.warning('[NOTIF_NAV] User is not admin, cannot navigate to admin section');
      return;
    }

    final navService = NavigationService();
    final context = navService.context;

    if (context == null) {
      LogService.warning('[NOTIF_NAV] No context for admin navigation');
      return;
    }

    try {
      if (pathSegments.length >= 3) {
        final section = pathSegments[1];
        final id = pathSegments[2];

        if (section == 'tutors') {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => AdminTutorDetailScreen(tutorId: id),
            ),
          );
        } else if (section == 'students' || section == 'parents') {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => AdminUserDetailScreen(
                userId: id,
                userType: section == 'students' ? 'student' : 'parent',
              ),
            ),
          );
        } else if (section == 'tutor-requests') {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => AdminTutorRequestDetailScreen(requestId: id),
            ),
          );
        } else {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const AdminDashboardScreen(),
            ),
          );
        }
      } else {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const AdminDashboardScreen(),
          ),
        );
      }
    } catch (e) {
      LogService.error('[NOTIF_NAV] Error navigating to admin section: $e');
      if (context != null) {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const AdminDashboardScreen(),
          ),
        );
      }
    }
  }
}
