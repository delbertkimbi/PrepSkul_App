import 'package:flutter_test/flutter_test.dart';
import 'package:prepskul/features/skulmate/services/continue_games_service.dart';

void main() {
  group('ContinueGamesService', () {
    test('returns empty list when no playable games', () async {
      final items = await ContinueGamesService.loadContinueItems(
        const [],
        limit: 3,
      );
      expect(items, isEmpty);
    });

    test('maxItems default is 3', () {
      expect(ContinueGamesService.maxItems, 3);
    });
  });
}
