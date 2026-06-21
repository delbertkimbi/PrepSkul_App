import 'package:flutter_test/flutter_test.dart';
import 'package:prepskul/features/skulmate/services/scroll_feed_service.dart';

void main() {
  test('ScrollFeedService constants are bounded', () {
    expect(ScrollFeedService.defaultSessionCap, greaterThan(0));
    expect(ScrollFeedService.masteryGateEvery, lessThanOrEqualTo(
      ScrollFeedService.defaultSessionCap,
    ));
  });
}
