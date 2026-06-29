import 'package:flutter_test/flutter_test.dart';
import 'package:prepskul/features/skulmate/models/skulmate_intake_models.dart';

void main() {
  group('SkulMateIntentModeX', () {
    test('selectableInIntake lists shipped modes only', () {
      expect(
        SkulMateIntentModeX.selectableInIntake,
        containsAll([
          SkulMateIntentMode.play,
          SkulMateIntentMode.drill,
          SkulMateIntentMode.scroll,
          SkulMateIntentMode.path,
        ]),
      );
      expect(
        SkulMateIntentModeX.selectableInIntake,
        isNot(contains(SkulMateIntentMode.sheet)),
      );
    });

    test('isComingSoon flags unreleased modes', () {
      expect(SkulMateIntentMode.play.isComingSoon, isFalse);
      expect(SkulMateIntentMode.sheet.isComingSoon, isTrue);
      expect(SkulMateIntentMode.fromClass.isComingSoon, isTrue);
    });
  });
}
