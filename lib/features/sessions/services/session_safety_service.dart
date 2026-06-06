import 'package:geolocator/geolocator.dart';
import 'package:prepskul/core/services/log_service.dart';
import 'package:prepskul/core/services/notification_helper_service.dart';
import 'package:prepskul/core/services/notification_service.dart';
import 'package:prepskul/core/services/supabase_service.dart';
import 'package:prepskul/features/sessions/models/session_safety_result.dart';
import 'package:prepskul/features/sessions/services/location_checkin_service.dart';
import 'package:prepskul/features/sessions/services/location_sharing_service.dart';

/// Session Safety Service
///
/// Handles safety-related features for sessions:
/// - Sharing location with emergency contacts
/// - Triggering panic button alerts
class SessionSafetyService {
  static final _supabase = SupabaseService.client;

  static Future<Map<String, dynamic>?> _loadProfile(String userId) async {
    try {
      return await _supabase
          .from('profiles')
          .select('id, full_name, phone_number, emergency_contact_name, emergency_contact_phone')
          .eq('id', userId)
          .maybeSingle();
    } catch (e) {
      LogService.warning('[SAFETY] Full profile select failed, falling back: $e');
      return await _supabase
          .from('profiles')
          .select('id, full_name, phone_number')
          .eq('id', userId)
          .maybeSingle();
    }
  }

  static Future<Map<String, dynamic>?> _loadSession(String sessionId) async {
    try {
      return await _supabase
          .from('individual_sessions')
          .select('id, location, address, tutor_id, learner_id, parent_id, scheduled_date, scheduled_time, status')
          .eq('id', sessionId)
          .maybeSingle();
    } catch (e) {
      LogService.warning('[SAFETY] Session load failed: $e');
      return null;
    }
  }

  static String? _emergencyPhone(Map<String, dynamic>? profile) {
    if (profile == null) return null;
    final emergency = (profile['emergency_contact_phone'] as String?)?.trim();
    if (emergency != null && emergency.isNotEmpty) return emergency;
    return (profile['phone_number'] as String?)?.trim();
  }

  static Future<String?> _findUserIdByPhone(String phone) async {
    final normalized = phone.trim();
    if (normalized.isEmpty) return null;
    try {
      final row = await _supabase
          .from('profiles')
          .select('id')
          .eq('phone_number', normalized)
          .maybeSingle();
      return row?['id'] as String?;
    } catch (e) {
      LogService.warning('[SAFETY] Phone lookup failed: $e');
      return null;
    }
  }

  static Future<Position?> _captureCurrentPosition() async {
    try {
      return await LocationCheckInService.getCurrentLocation();
    } catch (e) {
      LogService.warning('[SAFETY] Could not capture GPS for safety event: $e');
      return null;
    }
  }

  static Future<void> _recordSafetyEvent({
    required String sessionId,
    required String userId,
    required String userType,
    required String action,
    String? reason,
    Position? position,
    Map<String, dynamic>? extraMetadata,
  }) async {
    try {
      await _supabase.from('session_safety_records').insert({
        'session_id': sessionId,
        'user_id': userId,
        'user_type': userType,
        'action': action,
        if (reason != null) 'reason': reason,
        if (position != null) ...{
          'latitude': position.latitude,
          'longitude': position.longitude,
          'location_accuracy': position.accuracy,
        },
        'metadata': {
          if (position != null)
            'gps_captured_at': DateTime.now().toIso8601String(),
          ...?extraMetadata,
        },
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      LogService.warning('[SAFETY] Could not persist safety record: $e');
    }
  }

  /// Share session location with emergency contact
  static Future<SessionSafetyResult> shareWithEmergencyContact({
    required String sessionId,
    required String userId,
    required String userType,
  }) async {
    try {
      LogService.info('[SAFETY] Sharing location for session: $sessionId');

      final shareResult = await LocationSharingService.startLocationSharing(
        sessionId: sessionId,
        userId: userId,
        userType: userType,
      );

      if (!shareResult.success) {
        return SessionSafetyResult(
          success: false,
          message: shareResult.message,
        );
      }

      final profile = await _loadProfile(userId);
      if (profile == null) {
        return const SessionSafetyResult(
          success: false,
          message: 'Could not load your profile. Please try again.',
        );
      }

      final position = await _captureCurrentPosition();

      await _recordSafetyEvent(
        sessionId: sessionId,
        userId: userId,
        userType: userType,
        action: 'location_shared',
        position: position,
      );

      final userName = profile['full_name'] as String? ?? 'User';
      final emergencyPhone = _emergencyPhone(profile);

      if (emergencyPhone != null) {
        final emergencyContactId = await _findUserIdByPhone(emergencyPhone);
        if (emergencyContactId != null) {
          await NotificationService.createNotification(
            userId: emergencyContactId,
            type: 'safety_location_shared',
            title: 'Location Sharing Enabled',
            message:
                '$userName has enabled location sharing for their on-site session. You can monitor their location in PrepSkul.',
            priority: 'high',
            actionUrl: '/sessions/$sessionId',
            actionText: 'View Session',
            metadata: {
              'session_id': sessionId,
              'user_id': userId,
              'user_type': userType,
            },
          );
        }
      }

      return SessionSafetyResult(
        success: true,
        message: emergencyPhone == null
            ? 'Live location sharing started. Add an emergency contact in your profile to notify someone.'
            : 'Location sharing started. Your emergency contact has been notified if they use PrepSkul.',
      );
    } catch (e) {
      LogService.error('[SAFETY] Error sharing location: $e');
      return SessionSafetyResult(
        success: false,
        message: 'Failed to share location. Please try again.',
      );
    }
  }

  /// Trigger panic button
  static Future<SessionSafetyResult> triggerPanicButton({
    required String sessionId,
    required String userId,
    required String userType,
    String? reason,
  }) async {
    try {
      LogService.warning('[SAFETY] Panic button for session: $sessionId');

      final profile = await _loadProfile(userId);
      if (profile == null) {
        return const SessionSafetyResult(
          success: false,
          message: 'Could not load your profile. Please contact emergency services directly.',
        );
      }

      final session = await _loadSession(sessionId);
      final userName = profile['full_name'] as String? ?? 'User';
      final userPhone = (profile['phone_number'] as String?)?.trim();
      final sessionAddress = session?['address'] as String?;
      final sessionLocation = session?['location'] as String?;
      final locationLabel = sessionAddress ?? sessionLocation ?? 'Unknown location';

      final position = await _captureCurrentPosition();

      await _recordSafetyEvent(
        sessionId: sessionId,
        userId: userId,
        userType: userType,
        action: 'panic_button_triggered',
        reason: reason ?? 'Panic button triggered by user',
        position: position,
        extraMetadata: {
          'session_address': locationLabel,
          if (reason != null) 'user_reason': reason,
        },
      );

      try {
        await LocationSharingService.startLocationSharing(
          sessionId: sessionId,
          userId: userId,
          userType: userType,
          updateInterval: const Duration(seconds: 15),
        );
      } catch (e) {
        LogService.warning('[SAFETY] Panic: location sharing optional step failed: $e');
      }

      final emergencyPhone = _emergencyPhone(profile);
      if (emergencyPhone != null) {
        final emergencyContactId = await _findUserIdByPhone(emergencyPhone);
        if (emergencyContactId != null) {
          await NotificationService.createNotification(
            userId: emergencyContactId,
            type: 'safety_panic_button',
            title: 'PANIC BUTTON ACTIVATED',
            message:
                '$userName triggered the panic button during a session at $locationLabel. Immediate attention required.',
            priority: 'urgent',
            actionUrl: '/sessions/$sessionId',
            actionText: 'View Session',
            metadata: {
              'session_id': sessionId,
              'user_id': userId,
              'user_type': userType,
              if (position != null) ...{
                'latitude': position.latitude,
                'longitude': position.longitude,
              },
            },
          );
        }
      }

      final coordsSuffix = position != null
          ? ' GPS: ${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}.'
          : '';

      await NotificationHelperService.notifyAdminsAboutSessionSafetyAlert(
        sessionId: sessionId,
        title: 'PANIC BUTTON ACTIVATED',
        message:
            '$userName ($userType) triggered the panic button during session at $locationLabel.$coordsSuffix',
        severity: 'critical',
        type: 'safety_panic_button',
        metadata: {
          'user_id': userId,
          'user_type': userType,
          'reason': reason,
          if (position != null) ...{
            'latitude': position.latitude,
            'longitude': position.longitude,
            'location_accuracy': position.accuracy,
          },
        },
        sendPush: true,
      );

      await NotificationHelperService.notifySecurityOpsPanicAlert(
        sessionId: sessionId,
        userId: userId,
        userType: userType,
        userName: userName,
        userPhone: userPhone,
        sessionAddress: locationLabel,
        latitude: position?.latitude,
        longitude: position?.longitude,
        locationAccuracy: position?.accuracy,
        reason: reason,
      );

      if (session != null) {
        final tutorId = session['tutor_id'] as String?;
        final parentId = session['parent_id'] as String?;

        if (tutorId != null && tutorId != userId) {
          await NotificationService.createNotification(
            userId: tutorId,
            type: 'safety_panic_button',
            title: 'Safety Alert',
            message:
                '$userName triggered the panic button during your session. Please check on them immediately.',
            priority: 'urgent',
            actionUrl: '/sessions/$sessionId',
            actionText: 'View Session',
            metadata: {'session_id': sessionId, 'user_id': userId},
          );
        }

        if (parentId != null && parentId != userId) {
          await NotificationService.createNotification(
            userId: parentId,
            type: 'safety_panic_button',
            title: 'Safety Alert',
            message:
                'A panic button was triggered during your child\'s session. Immediate attention required.',
            priority: 'urgent',
            actionUrl: '/sessions/$sessionId',
            actionText: 'View Session',
            metadata: {'session_id': sessionId, 'user_id': userId},
          );
        }
      }

      return SessionSafetyResult(
        success: true,
        message: position == null
            ? 'Panic alert sent. Admins were notified (GPS was unavailable — enable location if possible). If you are in immediate danger, contact local emergency services.'
            : 'Panic alert sent with your live location. Admins and PrepSkul security were notified. If you are in immediate danger, contact local emergency services.',
      );
    } catch (e) {
      LogService.error('[SAFETY] Error triggering panic button: $e');
      return const SessionSafetyResult(
        success: false,
        message:
            'Failed to trigger panic button. Please contact emergency services directly.',
      );
    }
  }
}
