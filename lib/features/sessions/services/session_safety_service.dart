import 'package:prepskul/core/services/log_service.dart';
import 'package:prepskul/core/services/supabase_service.dart';
import 'package:prepskul/core/services/notification_service.dart';
import 'package:prepskul/features/sessions/services/location_sharing_service.dart';

/// Session Safety Service
/// 
/// Handles safety-related features for sessions:
/// - Sharing location with emergency contacts
/// - Triggering panic button alerts
class SessionSafetyService {
  static final _supabase = SupabaseService.client;

  /// Share session location with emergency contact
  /// 
  /// Starts location sharing and notifies emergency contact
  /// 
  /// Parameters:
  /// - [sessionId]: The session ID
  /// - [userId]: The user ID (learner or tutor)
  /// - [userType]: 'learner' or 'tutor'
  /// 
  /// Returns: true if successful
  static Future<bool> shareWithEmergencyContact({
    required String sessionId,
    required String userId,
    required String userType,
  }) async {
    try {
      LogService.info('[SAFETY] Sharing location with emergency contact for session: $sessionId');

      // 1. Start location sharing (this enables real-time tracking)
      final locationSharingStarted = await LocationSharingService.shareWithEmergencyContact(
        sessionId: sessionId,
        userId: userId,
        userType: userType,
      );

      if (!locationSharingStarted) {
        LogService.warning('[SAFETY] Failed to start location sharing');
        return false;
      }

      // 2. Fetch user profile to get emergency contact info
      final profile = await _supabase
          .from('profiles')
          .select('id, full_name, emergency_contact_name, emergency_contact_phone')
          .eq('id', userId)
          .maybeSingle();

      if (profile == null) {
        LogService.warning('[SAFETY] User profile not found: $userId');
        return false;
      }

      final emergencyContactPhone = profile['emergency_contact_phone'] as String?;
      final userName = profile['full_name'] as String? ?? 'User';

      // 3. Create safety record in database (if table exists)
      try {
        await _supabase.from('session_safety_records').insert({
          'session_id': sessionId,
          'user_id': userId,
          'user_type': userType,
          'action': 'location_shared',
          'created_at': DateTime.now().toIso8601String(),
        });
        LogService.success('[SAFETY] Safety record created');
      } catch (e) {
        // Table might not exist yet, log but don't fail
        LogService.warning('[SAFETY] Could not create safety record (table may not exist): $e');
      }

      // 4. Notify emergency contact if phone number is available
      if (emergencyContactPhone != null && emergencyContactPhone.isNotEmpty) {
        // Find emergency contact user by phone
        final emergencyContactProfile = await _supabase
            .from('profiles')
            .select('id, full_name')
            .eq('phone', emergencyContactPhone)
            .maybeSingle();

        if (emergencyContactProfile != null) {
          final emergencyContactId = emergencyContactProfile['id'] as String;
          final emergencyContactName = emergencyContactProfile['full_name'] as String? ?? 'Emergency Contact';

          // Send notification to emergency contact
          await NotificationService.createNotification(
            userId: emergencyContactId,
            type: 'safety_location_shared',
            title: 'Location Sharing Enabled',
            message: '$userName has enabled location sharing for their session. You can now monitor their location.',
            priority: 'high',
            actionUrl: '/sessions/$sessionId',
            actionText: 'View Session',
            metadata: {
              'session_id': sessionId,
              'user_id': userId,
              'user_type': userType,
              'user_name': userName,
            },
          );

          LogService.success('[SAFETY] Notified emergency contact: $emergencyContactName');
        } else {
          LogService.warning('[SAFETY] Emergency contact not found in system: $emergencyContactPhone');
        }
      } else {
        LogService.warning('[SAFETY] No emergency contact phone number found for user: $userId');
      }

      LogService.success('[SAFETY] Location sharing enabled for emergency contact');
      return true;
    } catch (e) {
      LogService.error('[SAFETY] Error sharing location with emergency contact: $e');
      return false;
    }
  }

  /// Trigger panic button
  /// 
  /// Sends immediate alerts to emergency contacts and authorities
  /// 
  /// Parameters:
  /// - [sessionId]: The session ID
  /// - [userId]: The user ID (learner or tutor)
  /// - [userType]: 'learner' or 'tutor'
  /// - [reason]: Optional reason for panic button trigger
  /// 
  /// Returns: true if successful
  static Future<bool> triggerPanicButton({
    required String sessionId,
    required String userId,
    required String userType,
    String? reason,
  }) async {
    try {
      LogService.warning('[SAFETY] 🚨 PANIC BUTTON TRIGGERED for session: $sessionId');

      // 1. Fetch user profile and session details
      final profile = await _supabase
          .from('profiles')
          .select('id, full_name, emergency_contact_name, emergency_contact_phone')
          .eq('id', userId)
          .maybeSingle();

      if (profile == null) {
        LogService.error('[SAFETY] User profile not found: $userId');
        return false;
      }

      final userName = profile['full_name'] as String? ?? 'User';
      final emergencyContactPhone = profile['emergency_contact_phone'] as String?;

      // 2. Fetch session details for context
      final session = await _supabase
          .from('individual_sessions')
          .select('id, location, address, tutor_id, learner_id, parent_id, scheduled_start_time')
          .eq('id', sessionId)
          .maybeSingle();

      final sessionLocation = session?['location'] as String?;
      final sessionAddress = session?['address'] as String?;

      // 3. Create safety record
      try {
        await _supabase.from('session_safety_records').insert({
          'session_id': sessionId,
          'user_id': userId,
          'user_type': userType,
          'action': 'panic_button_triggered',
          'reason': reason ?? 'Panic button triggered by user',
          'created_at': DateTime.now().toIso8601String(),
        });
        LogService.success('[SAFETY] Panic button record created');
      } catch (e) {
        LogService.warning('[SAFETY] Could not create panic button record: $e');
      }

      // 4. Notify emergency contact
      if (emergencyContactPhone != null && emergencyContactPhone.isNotEmpty) {
        final emergencyContactProfile = await _supabase
            .from('profiles')
            .select('id, full_name')
            .eq('phone', emergencyContactPhone)
            .maybeSingle();

        if (emergencyContactProfile != null) {
          final emergencyContactId = emergencyContactProfile['id'] as String;

          await NotificationService.createNotification(
            userId: emergencyContactId,
            type: 'safety_panic_button',
            title: '🚨 PANIC BUTTON ACTIVATED',
            message: '$userName has triggered the panic button during their session at ${sessionAddress ?? sessionLocation ?? "Unknown location"}. Immediate attention required!',
            priority: 'urgent',
            actionUrl: '/sessions/$sessionId',
            actionText: 'View Session',
            metadata: {
              'session_id': sessionId,
              'user_id': userId,
              'user_type': userType,
              'user_name': userName,
              'session_location': sessionLocation ?? 'Unknown',
              'session_address': sessionAddress ?? 'Unknown',
            },
          );

          LogService.success('[SAFETY] Notified emergency contact about panic button');
        }
      }

      // 5. Notify all admins
      final adminResponse = await _supabase
          .from('profiles')
          .select('id')
          .eq('user_type', 'admin')
          .eq('is_active', true);

      if (adminResponse.isNotEmpty) {
        for (final admin in adminResponse) {
          final adminId = admin['id'] as String;
          await NotificationService.createNotification(
            userId: adminId,
            type: 'safety_panic_button',
            title: '🚨 PANIC BUTTON ACTIVATED',
            message: '$userName ($userType) triggered panic button during session at ${sessionAddress ?? sessionLocation ?? "Unknown location"}. Immediate action required!',
            priority: 'urgent',
            actionUrl: '/sessions/$sessionId',
            actionText: 'View Session',
            metadata: {
              'session_id': sessionId,
              'user_id': userId,
              'user_type': userType,
              'user_name': userName,
              'session_location': sessionLocation ?? 'Unknown',
              'session_address': sessionAddress ?? 'Unknown',
              'reason': reason,
            },
          );
        }
        LogService.success('[SAFETY] Notified ${adminResponse.length} admin(s) about panic button');
      }

      // 6. Notify tutor/learner/parent involved in session
      if (session != null) {
        final tutorId = session['tutor_id'] as String?;
        final parentId = session['parent_id'] as String?;

        // Notify tutor
        if (tutorId != null && tutorId != userId) {
          await NotificationService.createNotification(
            userId: tutorId,
            type: 'safety_panic_button',
            title: '🚨 Safety Alert',
            message: '$userName has triggered the panic button during your session. Please check on them immediately.',
            priority: 'urgent',
            actionUrl: '/sessions/$sessionId',
            actionText: 'View Session',
            metadata: {
              'session_id': sessionId,
              'user_id': userId,
              'user_type': userType,
              'user_name': userName,
            },
          );
        }

        // Notify parent
        if (parentId != null && parentId != userId) {
          await NotificationService.createNotification(
            userId: parentId,
            type: 'safety_panic_button',
            title: '🚨 Safety Alert',
            message: 'Your child has triggered the panic button during their session. Immediate attention required!',
            priority: 'urgent',
            actionUrl: '/sessions/$sessionId',
            actionText: 'View Session',
            metadata: {
              'session_id': sessionId,
              'user_id': userId,
              'user_type': userType,
              'user_name': userName,
            },
          );
        }
      }

      LogService.success('[SAFETY] Panic button alerts sent successfully');
      return true;
    } catch (e) {
      LogService.error('[SAFETY] Error triggering panic button: $e');
      return false;
    }
  }
}
