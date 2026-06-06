import 'package:geocoding/geocoding.dart';
import 'package:prepskul/core/services/log_service.dart';
import 'package:prepskul/core/services/supabase_service.dart';

/// Resolves and persists onsite coordinates for proximity check-in.
class OnsiteGeocodingService {
  static final _supabase = SupabaseService.client;

  /// Max distance (meters) for tutor check-in at session venue.
  static const double checkInRadiusMeters = 100.0;

  /// Returns {latitude, longitude, addressLabel} for a session.
  static Future<Map<String, dynamic>?> resolveSessionCoordinates({
    required String sessionId,
    String? fallbackAddress,
  }) async {
    try {
      final session = await _supabase
          .from('individual_sessions')
          .select('onsite_latitude, onsite_longitude, address, onsite_address, location')
          .eq('id', sessionId)
          .maybeSingle();

      if (session == null) return null;

      final lat = (session['onsite_latitude'] as num?)?.toDouble();
      final lon = (session['onsite_longitude'] as num?)?.toDouble();
      if (lat != null && lon != null) {
        final addr = (session['address'] as String?) ??
            (session['onsite_address'] as String?) ??
            fallbackAddress;
        return {
          'latitude': lat,
          'longitude': lon,
          'address_label': addr ?? 'Session location',
        };
      }

      final address = (session['address'] as String?)?.trim() ??
          (session['onsite_address'] as String?)?.trim() ??
          fallbackAddress?.trim();
      if (address == null || address.isEmpty) return null;

      final coords = await geocodeAddress(address);
      if (coords == null) return null;

      await _persistSessionCoordinates(
        sessionId: sessionId,
        latitude: coords['latitude']!,
        longitude: coords['longitude']!,
      );

      return {
        'latitude': coords['latitude'],
        'longitude': coords['longitude'],
        'address_label': address,
      };
    } catch (e) {
      LogService.warning('resolveSessionCoordinates failed: $e');
      return null;
    }
  }

  static Future<Map<String, double>?> geocodeAddress(String address) async {
    if (address.contains(',') &&
        RegExp(r'^-?\d+\.?\d*,-?\d+\.?\d*$')
            .hasMatch(address.replaceAll(' ', ''))) {
      final parts = address.split(',');
      final lat = double.tryParse(parts[0].trim());
      final lon = double.tryParse(parts[1].trim());
      if (lat != null && lon != null) {
        return {'latitude': lat, 'longitude': lon};
      }
    }

    final candidates = <String>[
      address,
      if (!address.toLowerCase().contains('cameroon') &&
          !address.toLowerCase().contains('cameroun'))
        '$address, Cameroon',
      if (!address.toLowerCase().contains('douala') &&
          !address.toLowerCase().contains('yaound'))
        '$address, Douala, Cameroon',
    ];

    for (final query in candidates) {
      try {
        final locations = await locationFromAddress(query);
        if (locations.isNotEmpty) {
          final loc = locations.first;
          return {'latitude': loc.latitude, 'longitude': loc.longitude};
        }
      } catch (e) {
        LogService.warning('Geocode failed for "$query": $e');
      }
    }
    return null;
  }

  static Future<void> _persistSessionCoordinates({
    required String sessionId,
    required double latitude,
    required double longitude,
  }) async {
    try {
      await _supabase.from('individual_sessions').update({
        'onsite_latitude': latitude,
        'onsite_longitude': longitude,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', sessionId);
    } catch (e) {
      LogService.warning('Could not persist onsite coordinates (migration 088?): $e');
    }
  }

  /// Geocode recurring booking address and store on recurring_sessions row.
  static Future<void> persistRecurringOnsiteCoordinates({
    required String recurringSessionId,
    required String address,
  }) async {
    final coords = await geocodeAddress(address);
    if (coords == null) return;
    try {
      await _supabase.from('recurring_sessions').update({
        'onsite_latitude': coords['latitude'],
        'onsite_longitude': coords['longitude'],
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', recurringSessionId);
    } catch (e) {
      LogService.warning('Could not persist recurring onsite coordinates: $e');
    }
  }
}
