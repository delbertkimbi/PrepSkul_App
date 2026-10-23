import 'package:flutter_test/flutter_test.dart';
import 'package:prepskul/core/utils/tutor_display_name_utils.dart';

void main() {
  test('preserves flattened discovery names', () {
    expect(
      TutorDisplayNameUtils.cardLabel({
        'id': '3f27-test',
        'full_name': 'Marie Josette',
      }, {}),
      'Marie Josette',
    );
  });
  test('accepts accented names and prefers joined profile', () {
    expect(
      TutorDisplayNameUtils.resolve(
        {'full_name': 'Élodie'},
        {'full_name': 'Françoise Ngué'},
      ),
      'Françoise Ngué',
    );
  });
  test('does not use a subject as the tutor name', () {
    expect(
      TutorDisplayNameUtils.resolve({
        'id': 'abcd',
        'full_name': 'Computer Science',
        'subjects': ['Computer Science'],
      }),
      'Tutor ABCD',
    );
  });
}
