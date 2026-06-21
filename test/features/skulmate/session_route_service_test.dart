import 'package:flutter_test/flutter_test.dart';
import 'package:prepskul/features/skulmate/services/session_route_service.dart';

void main() {
  group('SessionRouteService.extractFocusPhrase', () {
    test('prefers first bullet line', () {
      const summary = '''
We reviewed photosynthesis today.
- Light-dependent reactions and chlorophyll
- Calvin cycle overview
''';
      expect(
        SessionRouteService.extractFocusPhrase(summary),
        'Light-dependent reactions and chlorophyll',
      );
    });

    test('falls back to first sentence', () {
      const summary =
          'Focused on quadratic equations and factoring. Homework on page 12.';
      expect(
        SessionRouteService.extractFocusPhrase(summary),
        'Focused on quadratic equations and factoring.',
      );
    });

    test('clips very long single-line summaries', () {
      final long = 'A' * 120;
      final result = SessionRouteService.extractFocusPhrase(long);
      expect(result.length, lessThanOrEqualTo(96));
      expect(result.endsWith('…'), isTrue);
    });
  });
}
