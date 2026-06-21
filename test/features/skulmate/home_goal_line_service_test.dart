import 'package:flutter_test/flutter_test.dart';
import 'package:prepskul/features/skulmate/services/home_goal_line_service.dart';

void main() {
  group('HomeGoalLineService', () {
    test('notificationBody returns streak copy', () async {
      final body = await HomeGoalLineService.notificationBody(
        french: false,
        streakCount: 3,
      );
      expect(body, contains('3-day streak'));
    });

    test('notificationBody returns French fallback', () async {
      final body = await HomeGoalLineService.notificationBody(
        french: true,
        streakCount: 0,
      );
      expect(body, contains('minutes'));
    });
  });
}
