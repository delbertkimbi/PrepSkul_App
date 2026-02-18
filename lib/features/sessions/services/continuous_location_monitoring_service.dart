import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:prepskul/core/services/log_service.dart';
import 'package:prepskul/core/services/supabase_service.dart';
import 'package:prepskul/features/sessions/services/location_checkin_service.dart';

/// Continuous location monitoring for onsite sessions (Uber-style).
///
/// - Runs in the background every [interval] (default 5 min). No popups.
/// - Logs each position to session_attendance.location_history.
/// - If tutor is > [deviationThresholdMeters] from venue, logs to location_deviations.
/// - Does not block session completion; if app is killed, only check-in/check-out count.
class ContinuousLocationMonitoringService {
  static final _supabase = SupabaseService.client;

  static Timer? _timer;
  static String? _sessionId;
  static String? _userId;
  static double? _venueLat;
  static double? _venueLon;

  /// Interval between location checks. Battery-friendly; no in-app prompts.
  static const Duration interval = Duration(minutes: 5);

  /// If tutor moves beyond this distance (meters) from session venue, log a deviation.
  static const double deviationThresholdMeters = 50.0;

  /// Start monitoring for an onsite session. Call when tutor starts session.
  /// [sessionAddress] can be "lat,lon" or a text address (geocoded once).
  static Future<void> startMonitoring({
    required String sessionId,
    required String userId,
    required String sessionAddress,
  }) async {
    if (_sessionId != null && _sessionId != sessionId) {
      stopMonitoring(_sessionId!);
    }
    if (_sessionId == sessionId) {
      LogService.debug('[CONTINUOUS_MONITOR] Already monitoring session $sessionId');
      return;
    }

    double? venueLat;
    double? venueLon;

    if (sessionAddress.contains(',') &&
        RegExp(r'^-?\d+\.?\d*,-?\d+\.?\d*$').hasMatch(sessionAddress.replaceAll(' ', ''))) {
      final parts = sessionAddress.split(',');
      venueLat = double.tryParse(parts[0].trim());
      venueLon = double.tryParse(parts[1].trim());
    }
    if (venueLat == null || venueLon == null) {
      try {
        final locations = await locationFromAddress(sessionAddress);
        if (locations.isNotEmpty) {
          venueLat = locations.first.latitude;
          venueLon = locations.first.longitude;
        }
      } catch (e) {
        LogService.warning('[CONTINUOUS_MONITOR] Geocode failed for session venue: $e');
      }
    }

    if (venueLat == null || venueLon == null) {
      LogService.warning('[CONTINUOUS_MONITOR] Could not resolve venue; monitoring disabled for $sessionId');
      return;
    }

    _sessionId = sessionId;
    _userId = userId;
    _venueLat = venueLat;
    _venueLon = venueLon;

    _timer?.cancel();
    _timer = Timer.periodic(interval, (_) => _performCheck());
    // First check after a short delay so we don't double-hit right after start
    Future.delayed(const Duration(seconds: 30), () => _performCheck());
    LogService.success('[CONTINUOUS_MONITOR] Started for session $sessionId (every ${interval.inMinutes} min, ${deviationThresholdMeters}m threshold)');
  }

  static Future<void> _performCheck() async {
    final sessionId = _sessionId;
    final userId = _userId;
    final venueLat = _venueLat;
    final venueLon = _venueLon;
    if (sessionId == null || userId == null || venueLat == null || venueLon == null) return;

    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 10),
      );
      final distanceMeters = LocationCheckInService.calculateDistance(
        position.latitude,
        position.longitude,
        venueLat,
        venueLon,
      );

      final attendance = await _supabase
          .from('session_attendance')
          .select('id, location_history, location_deviations, last_location_check, location_check_count')
          .eq('session_id', sessionId)
          .eq('user_id', userId)
          .eq('user_type', 'tutor')
          .maybeSingle();

      if (attendance == null) return;

      final now = DateTime.now().toIso8601String();
      final historyEntry = {
        'timestamp': now,
        'lat': position.latitude,
        'lon': position.longitude,
        'distance_meters': distanceMeters.round(),
      };

      List<dynamic> history = [];
      try {
        final existing = attendance['location_history'];
        history = existing is List ? List.from(existing) : [];
      } catch (_) {}
      history.add(historyEntry);

      List<dynamic> deviations = [];
      try {
        final existing = attendance['location_deviations'];
        deviations = existing is List ? List.from(existing) : [];
      } catch (_) {}
      if (distanceMeters > deviationThresholdMeters) {
        deviations.add({
          'timestamp': now,
          'distance_meters': distanceMeters.round(),
          'resolved': false,
        });
        LogService.debug('[CONTINUOUS_MONITOR] Deviation logged: ${distanceMeters.round()}m from venue');
      }

      final count = (attendance['location_check_count'] as int? ?? 0) + 1;
      await _supabase.from('session_attendance').update({
        'location_history': history,
        'location_deviations': deviations,
        'last_location_check': now,
        'location_check_count': count,
        'updated_at': now,
      }).eq('id', attendance['id']);
    } catch (e) {
      LogService.warning('[CONTINUOUS_MONITOR] Check failed (non-blocking): $e');
    }
  }

  /// Stop monitoring. Call when session ends or tutor checks out.
  static void stopMonitoring(String sessionId) {
    if (_sessionId != sessionId) return;
    _timer?.cancel();
    _timer = null;
    _sessionId = null;
    _userId = null;
    _venueLat = null;
    _venueLon = null;
    LogService.success('[CONTINUOUS_MONITOR] Stopped for session $sessionId');
  }

  /// Whether we are currently monitoring any session.
  static bool get isMonitoring => _sessionId != null;
}
