import 'package:flutter_test/flutter_test.dart';
import 'package:prepskul/features/sessions/services/location_sharing_service.dart';

/// Unit tests for LocationSharingService
void main() {
  group('LocationSharingService', () {
    group('Distance Calculation', () {
      test('calculateDistance returns correct distance', () {
        const lat1 = 3.8480;
        const lon1 = 11.5021;
        const lat2 = 4.0511;
        const lon2 = 9.7679;
        
        final distance = LocationSharingService.calculateDistance(
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
        
        final distance = LocationSharingService.calculateDistance(
          lat,
          lon,
          lat,
          lon,
        );
        
        expect(distance, closeTo(0, 1));
      });
    });
  });
}
