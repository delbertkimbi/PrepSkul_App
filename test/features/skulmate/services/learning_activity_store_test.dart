import 'package:flutter_test/flutter_test.dart';
import 'package:prepskul/features/skulmate/services/learning_activity_store.dart';

void main() {
  test('streak counts days, not answers, and allows yesterday', () {
    final rows = [
      {'at': '2026-10-17T10:00:00'},
      {'at': '2026-10-17T11:00:00'},
      {'at': '2026-10-16T11:00:00'},
      {'at': '2026-10-14T11:00:00'},
    ];
    expect(LearningActivityStore.streak(rows, DateTime(2026, 10, 18)), 2);
    expect(LearningActivityStore.streak(rows, DateTime(2026, 10, 19)), 0);
    expect(LearningActivityStore.streak([], DateTime(2026, 10, 18)), 0);
  });
}
