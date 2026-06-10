import 'dart:convert';

import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'package:prepskul/core/services/log_service.dart';

/// Resolves addresses to lat/lng with platform geocoder + OpenStreetMap Nominatim fallback.
class GeocodingHelper {
  GeocodingHelper._();

  static final _coordPattern = RegExp(r'^-?\d+\.?\d*\s*,\s*-?\d+\.?\d*$');

  static List<String> _queriesFor(String address) {
    final trimmed = address.trim();
    if (trimmed.isEmpty) return const [];
    final lower = trimmed.toLowerCase();
    final hasCountry = lower.contains('cameroon') || lower.contains('cameroun');
    final hasComma = trimmed.contains(',');
    return [
      trimmed,
      if (!hasCountry && !hasComma) '$trimmed, Cameroon',
      if (!hasCountry && hasComma) '$trimmed, Cameroon',
      if (!lower.contains('douala')) '$trimmed, Douala, Cameroon',
      if (!lower.contains('yaoundé') && !lower.contains('yaounde'))
        '$trimmed, Yaoundé, Cameroon',
    ];
  }

  static ({double lat, double lng})? _parseCoordString(String value) {
    if (!_coordPattern.hasMatch(value.replaceAll(' ', ''))) return null;
    final parts = value.split(',');
    if (parts.length != 2) return null;
    final lat = double.tryParse(parts[0].trim());
    final lng = double.tryParse(parts[1].trim());
    if (lat == null || lng == null) return null;
    return (lat: lat, lng: lng);
  }

  /// Strip hidden `@coords:lat,lng` tag from user-facing copy.
  static String stripEmbeddedCoords(String text) {
    return text
        .replaceAll(RegExp(r'\s*@coords:\s*-?\d+\.?\d*\s*,\s*-?\d+\.?\d*\s*'), '')
        .trim();
  }

  static String _normalizeLandmarkKey(String address) {
    return address.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  /// Approximate coords for common Cameroon tutoring landmarks when geocoders fail.
  static ({double lat, double lng})? _knownLandmark(String address) {
    final key = _normalizeLandmarkKey(address);
    const landmarks = <String, ({double lat, double lng})>{
      'stlukejunction': (lat: 4.1590, lng: 9.2758),
      'stlukjunction': (lat: 4.1590, lng: 9.2758),
      'stluke': (lat: 4.1657, lng: 9.2734),
      'biakajunction': (lat: 4.1545, lng: 9.2876),
      'molyko': (lat: 4.1555, lng: 9.2870),
    };
    for (final entry in landmarks.entries) {
      if (key.contains(entry.key)) return entry.value;
    }
    return null;
  }

  /// Build a display address from learner/parent survey fields.
  static String? formatSurveyAddress(Map<String, dynamic>? survey) {
    if (survey == null) return null;
    final city = survey['city']?.toString().trim();
    final quarter = survey['quarter']?.toString().trim();
    if (city == null || city.isEmpty || quarter == null || quarter.isEmpty) {
      return null;
    }
    final street = survey['street']?.toString().trim();
    final streetPart =
        street != null && street.isNotEmpty ? ', $street' : '';
    return '$city, $quarter$streetPart';
  }

  static String _normalizeLocationKey(String value) {
    return stripEmbeddedCoords(value)
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  /// Hide map preview when the session is at the learner's own address.
  static bool shouldShowMapForSession({
    required String sessionAddress,
    String? userAddress,
  }) {
    final sessionKey = _normalizeLocationKey(sessionAddress);
    if (sessionKey.isEmpty) return false;
    final userKey = userAddress == null ? '' : _normalizeLocationKey(userAddress);
    if (userKey.isEmpty) return true;
    if (userKey == sessionKey) return false;
    if (sessionKey.contains(userKey) || userKey.contains(sessionKey)) {
      return false;
    }
    return true;
  }

  static String? extractEmbeddedCoordinates(String? text) {
    if (text == null || text.isEmpty) return null;
    final match = RegExp(r'@coords:\s*(-?\d+\.?\d*)\s*,\s*(-?\d+\.?\d*)').firstMatch(text);
    if (match == null) return null;
    return '${match.group(1)},${match.group(2)}';
  }

  static Future<({double lat, double lng})?> resolve(String address) async {
    final trimmed = address.trim();
    if (trimmed.isEmpty) return null;

    final direct = _parseCoordString(trimmed);
    if (direct != null) return direct;

    for (final query in _queriesFor(trimmed)) {
      try {
        final locations = await locationFromAddress(query);
        if (locations.isNotEmpty) {
          return (lat: locations.first.latitude, lng: locations.first.longitude);
        }
      } catch (e) {
        LogService.warning('Geocoding failed for "$query": $e');
      }
    }

    final nominatim = await _nominatimSearch(trimmed);
    if (nominatim != null) return nominatim;

    final landmark = _knownLandmark(trimmed);
    if (landmark != null) {
      LogService.info('Landmark fallback for "$trimmed" → ${landmark.lat},${landmark.lng}');
      return landmark;
    }

    return null;
  }

  static Future<({double lat, double lng})?> _nominatimSearch(String address) async {
    for (final query in _queriesFor(address)) {
      try {
        final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
          'q': query,
          'format': 'json',
          'limit': '1',
          'countrycodes': 'cm',
        });
        final response = await http.get(
          uri,
          headers: {'User-Agent': 'PrepSkul/1.0 (onsite-sessions)'},
        );
        if (response.statusCode != 200) continue;
        final list = jsonDecode(response.body) as List<dynamic>;
        if (list.isEmpty) continue;
        final item = list.first as Map<String, dynamic>;
        final lat = double.tryParse(item['lat']?.toString() ?? '');
        final lng = double.tryParse(item['lon']?.toString() ?? '');
        if (lat != null && lng != null) {
          LogService.info('Nominatim resolved "$query" → $lat,$lng');
          return (lat: lat, lng: lng);
        }
      } catch (e) {
        LogService.warning('Nominatim failed for "$query": $e');
      }
    }
    return null;
  }
}
