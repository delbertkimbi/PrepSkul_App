import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:geocoding/geocoding.dart';
import 'package:prepskul/core/services/log_service.dart';
import 'package:prepskul/core/services/supabase_service.dart';

/// Transportation Cost Service
///
/// Calculates transportation costs for onsite sessions using OSRM routing
/// Cost range: 200-1000 XAF (round trip)
/// Platform fee: 0% (transportation is parent compensation, not part of platform revenue)
class TransportationCostService {
  static const String _osrmBaseUrl = 'http://router.project-osrm.org';
  
  /// Calculate transportation cost between two addresses
  ///
  /// [tutorHomeAddress] - Tutor's home address (can be null, will use city center as fallback)
  /// [onsiteAddress] - Onsite session address (required)
  /// [tutorCity] - Tutor's city (fallback if address not available)
  ///
  /// Returns transportation cost (200-1000 XAF) or null if calculation fails
  static Future<double?> calculateTransportationCost({
    String? tutorHomeAddress,
    required String onsiteAddress,
    String? tutorCity,
  }) async {
    try {
      // Step 1: Convert addresses to coordinates
      Location? tutorLocation;
      Location? onsiteLocation;

      // Get tutor coordinates
      if (tutorHomeAddress != null && tutorHomeAddress.isNotEmpty) {
        try {
          final tutorLocations = await locationFromAddress(tutorHomeAddress);
          if (tutorLocations.isNotEmpty) {
            tutorLocation = tutorLocations.first;
          }
        } catch (e) {
          LogService.warning('Could not geocode tutor address: $e');
        }
      }

      // Fallback: Use city center if tutor address not available
      if (tutorLocation == null && tutorCity != null && tutorCity.isNotEmpty) {
        try {
          final cityLocations = await locationFromAddress(tutorCity);
          if (cityLocations.isNotEmpty) {
            tutorLocation = cityLocations.first;
            LogService.info('Using city center as tutor location: $tutorCity');
          }
        } catch (e) {
          LogService.warning('Could not geocode tutor city: $e');
        }
      }

      // Get onsite coordinates
      try {
        final onsiteLocations = await locationFromAddress(onsiteAddress);
        if (onsiteLocations.isEmpty) {
          LogService.error('Could not geocode onsite address: $onsiteAddress');
          return _getDefaultCost(); // Return mid-range default
        }
        onsiteLocation = onsiteLocations.first;
      } catch (e) {
        LogService.error('Error geocoding onsite address: $e');
        return _getDefaultCost(); // Return mid-range default
      }

      // If we still don't have tutor location, use default cost
      if (tutorLocation == null) {
        LogService.warning('Tutor location not available, using default transportation cost');
        return _getDefaultCost();
      }

      // Step 2: Call OSRM routing API
      final distanceKm = await _getRouteDistance(
        tutorLocation.longitude,
        tutorLocation.latitude,
        onsiteLocation.longitude,
        onsiteLocation.latitude,
      );

      if (distanceKm == null) {
        LogService.warning('OSRM routing failed, using default transportation cost');
        return _getDefaultCost();
      }

      // Step 3: Calculate cost based on distance
      final cost = _calculateCostFromDistance(distanceKm);
      
      LogService.success('Transportation cost calculated: $cost XAF (distance: ${distanceKm.toStringAsFixed(2)} km)');
      
      return cost;
    } catch (e) {
      LogService.error('Error calculating transportation cost: $e');
      return _getDefaultCost(); // Return mid-range default on error
    }
  }

  /// Get route distance using OSRM API
  ///
  /// Returns distance in kilometers or null if API call fails
  static Future<double?> _getRouteDistance(
    double fromLon,
    double fromLat,
    double toLon,
    double toLat,
  ) async {
    try {
      // OSRM route API: /route/v1/{profile}/{coordinates}
      // Profile: driving (for car/taxi transportation)
      final url = '$_osrmBaseUrl/route/v1/driving/$fromLon,$fromLat;$toLon,$toLat?overview=false';
      
      final response = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('OSRM API timeout');
        },
      );

      if (response.statusCode != 200) {
        LogService.error('OSRM API error: ${response.statusCode}');
        return null;
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      
      // Check if route found
      if (data['code'] != 'Ok') {
        LogService.warning('OSRM route not found: ${data['code']}');
        return null;
      }

      final routes = data['routes'] as List?;
      if (routes == null || routes.isEmpty) {
        LogService.warning('No routes found in OSRM response');
        return null;
      }

      final route = routes[0] as Map<String, dynamic>;
      final distanceMeters = route['distance'] as num?;
      
      if (distanceMeters == null) {
        return null;
      }

      // Convert meters to kilometers
      final distanceKm = distanceMeters.toDouble() / 1000.0;
      
      return distanceKm;
    } catch (e) {
      LogService.error('Error calling OSRM API: $e');
      return null;
    }
  }

  /// Calculate transportation cost from distance
  ///
  /// Formula:
  /// - Base: 200 XAF (0-2 km)
  /// - Max: 1000 XAF (10+ km)
  /// - Linear scaling: 200 + ((distance - 2) / 8) * 800 (for 2-10 km)
  static double _calculateCostFromDistance(double distanceKm) {
    // Round trip: multiply distance by 2
    final roundTripDistance = distanceKm * 2;

    // Base cost for short distances
    if (roundTripDistance <= 2) {
      return 200.0;
    }

    // Maximum cost for very long distances
    if (roundTripDistance >= 10) {
      return 1000.0;
    }

    // Linear scaling between 2-10 km
    // Formula: 200 + ((distance - 2) / 8) * 800
    final cost = 200 + ((roundTripDistance - 2) / 8) * 800;
    
    // Round to nearest 50 XAF for cleaner amounts
    return (cost / 50).round() * 50.0;
  }

  /// Get default transportation cost (mid-range)
  ///
  /// Used when calculation fails or tutor address not available
  static double _getDefaultCost() {
    return 500.0; // Mid-range default (500 XAF)
  }

  /// Save transportation calculation to database
  ///
  /// Stores calculation details for audit and future reference
  static Future<void> saveTransportationCalculation({
    required String sessionId,
    required String tutorId,
    String? tutorHomeAddress,
    required String onsiteAddress,
    double? distanceKm,
    int? durationMinutes,
    required double calculatedCost,
    Map<String, dynamic>? osrmRouteData,
  }) async {
    try {
      await SupabaseService.client
          .from('tutor_transportation_calculations')
          .insert({
            'session_id': sessionId,
            'tutor_id': tutorId,
            'tutor_home_address': tutorHomeAddress,
            'onsite_address': onsiteAddress,
            'distance_km': distanceKm,
            'duration_minutes': durationMinutes,
            'calculated_cost': calculatedCost,
            'osrm_route_data': osrmRouteData != null ? jsonEncode(osrmRouteData) : null,
          });
      
      LogService.success('Transportation calculation saved for session: $sessionId');
    } catch (e) {
      LogService.error('Error saving transportation calculation: $e');
      // Don't throw - calculation is saved but audit record failed
    }
  }

  /// Get transportation cost for a session (from database)
  ///
  /// Returns stored transportation cost or null if not found
  static Future<double?> getTransportationCostForSession(String sessionId) async {
    try {
      final response = await SupabaseService.client
          .from('individual_sessions')
          .select('transportation_cost')
          .eq('id', sessionId)
          .maybeSingle();

      if (response == null) {
        return null;
      }

      final cost = response['transportation_cost'] as num?;
      return cost?.toDouble();
    } catch (e) {
      LogService.error('Error fetching transportation cost: $e');
      return null;
    }
  }
}
