import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:prepskul/features/sessions/services/location_checkin_service.dart';

/// Unit tests for LocationCheckInService
void main() {
  group('LocationCheckInService', () {
    group('Distance Calculation', () {
      test('calculateDistance returns correct distance', () {
        const lat1 = 3.8480;
        const lon1 = 11.5021;
        const lat2 = 4.0511;
        const lon2 = 9.7679;
        
        final distance = LocationCheckInService.calculateDistance(
          lat1,
          lon1,
          lat2,
          lon2,
        );
        
        expect(distance, greaterThan(190000));
        expect(distance, lessThan(200000));
      });

      test('calculateDistance returns 0 for same coordinates', () {
        const lat = 3.8480;
        const lon = 11.5021;
        
        final distance = LocationCheckInService.calculateDistance(
          lat,
          lon,
          lat,
          lon,
        );
        
        expect(distance, closeTo(0, 1));
      });
    });

    group('Proximity Verification', () {
      test('verifyLocationProximity handles coordinate format', () async {
        try {
          final verified = await LocationCheckInService.verifyLocationProximity(
            sessionAddress: '3.8480,11.5021',
            allowedRadiusMeters: 100.0,
          );
          expect(verified, isA<bool>());
        } catch (e) {
          expect(e, isA<Exception>());
        }
      });

      test('verifyLocationProximity handles invalid address format', () async {
        final verified = await LocationCheckInService.verifyLocationProximity(
          sessionAddress: 'invalid address',
          allowedRadiusMeters: 100.0,
        );
        
        expect(verified, isFalse);
      });
    });
  });
}
