import 'package:flutter_test/flutter_test.dart';
import 'package:prepskul/core/config/app_config.dart';

void main() {
  group('AppConfig v1 launch flags', () {
    test('enableGroupClasses is false when GROUP_CLASSES_ENABLED env unset', () {
      // Default fallback in app_config.dart is false; dotenv must not override in unit tests.
      expect(
        AppConfig.enableGroupClasses,
        isFalse,
        reason: 'v1 launch requires GROUP_CLASSES_ENABLED default false',
      );
    });
  });
}
