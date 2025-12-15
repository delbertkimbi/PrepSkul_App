import 'package:flutter_test/flutter_test.dart';
import 'package:prepskul/features/sessions/services/location_checkin_service.dart';
import 'package:prepskul/features/sessions/services/location_sharing_service.dart';

/// Integration tests for location features
void main() {
  group('Location Features Integration', () {
    test('both services calculate distance consistently', () {
      const lat1 = 3.8480;
      const lon1 = 11.5021;
      const lat2 = 4.0511;
      const lon2 = 9.7679;

      final distance1 = LocationCheckInService.calculateDistance(
        lat1,
        lon1,
        lat2,
        lon2,
      );

      final distance2 = LocationSharingService.calculateDistance(
        lat1,
        lon1,
        lat2,
        lon2,
      );

      expect(distance1, closeTo(distance2, 100));
    });
  });
}
