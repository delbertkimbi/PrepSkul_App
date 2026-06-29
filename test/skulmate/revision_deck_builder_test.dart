import 'package:flutter_test/flutter_test.dart';
import 'package:prepskul/features/skulmate/models/game_model.dart';
import 'package:prepskul/features/skulmate/services/revision_deck_builder.dart';

void main() {
  test('RevisionDeckBuilder builds quiz cards from game items', () {
    final game = GameModel(
      id: 'g1',
      userId: 'u1',
      title: 'Bio Blitz',
      gameType: GameType.quiz,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      items: [
        GameItem(
          question: 'What absorbs light?',
          options: ['Chlorophyll', 'Oxygen', 'Water', 'CO2'],
          correctAnswer: 'Chlorophyll',
        ),
      ],
      metadata: GameMetadata(
        source: 'text',
        generatedAt: DateTime.now().toIso8601String(),
        difficulty: 'medium',
        totalItems: 1,
        topic: 'Photosynthesis',
      ),
    );

    final deck = RevisionDeckBuilder.fromGame(game);
    expect(deck.cards, hasLength(1));
    expect(deck.cards.first.answer, 'Chlorophyll');
    expect(deck.conceptCheckCardIds, isNotEmpty);
  });
}
