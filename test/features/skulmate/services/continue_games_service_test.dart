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

    test('defaultLimit is 6 and lookback is 7 days', () {
      expect(ContinueGamesService.defaultLimit, 6);
      expect(ContinueGamesService.lookbackDays, 7);
    });
  });
}
