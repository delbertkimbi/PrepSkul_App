import 'package:flutter_test/flutter_test.dart';
import 'package:prepskul/core/navigation/navigation_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NavigationService pending tutor deep link', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
    });

    test('stores and retrieves pending tutor link correctly', () async {
      const tutorId = 'tutor-123';

      // Initially no pending link
      expect(await NavigationService.hasPendingTutorLink(), isFalse);

      // Store pending tutor link
      await NavigationService.storePendingTutorLink(tutorId);

      // Now pending link should exist
      expect(await NavigationService.hasPendingTutorLink(), isTrue);

      // Retrieve and clear pending tutor link
      final retrievedId = await NavigationService.getAndClearPendingTutorLink();
      expect(retrievedId, tutorId);

      // After retrieval, key should be cleared
      expect(await NavigationService.hasPendingTutorLink(), isFalse);
    });
  });
}

