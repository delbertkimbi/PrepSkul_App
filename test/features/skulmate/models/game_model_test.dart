import 'package:flutter_test/flutter_test.dart';
import 'package:prepskul/features/skulmate/models/game_model.dart';

void main() {
  group('GameModel', () {
    test('should create GameModel from JSON', () {
      final json = {
        'id': 'test-id',
        'user_id': 'user-id',
        'child_id': null,
        'title': 'Test Game',
        'game_type': 'quiz',
        'document_url': 'https://example.com/doc.pdf',
        'source_type': 'pdf',
        'created_at': '2024-01-01T00:00:00Z',
        'updated_at': '2024-01-01T00:00:00Z',
        'is_deleted': false,
        'items': [
          {
            'question': 'What is 2+2?',
            'options': ['3', '4', '5', '6'],
            'correctAnswer': 1,
            'explanation': '2+2 equals 4'
          }
        ],
        'metadata': {
          'source': 'document',
          'generatedAt': '2024-01-01T00:00:00Z',
          'difficulty': 'easy',
          'totalItems': 1
        }
      };

      final game = GameModel.fromJson(json);

      expect(game.id, 'test-id');
      expect(game.userId, 'user-id');
      expect(game.title, 'Test Game');
      expect(game.gameType, GameType.quiz);
      expect(game.items.length, 1);
      expect(game.items[0].question, 'What is 2+2?');
    });

    test('should convert GameModel to JSON', () {
      final game = GameModel(
        id: 'test-id',
        userId: 'user-id',
        title: 'Test Game',
        gameType: GameType.quiz,
        createdAt: DateTime.parse('2024-01-01T00:00:00Z'),
        updatedAt: DateTime.parse('2024-01-01T00:00:00Z'),
        items: [
          GameItem(
            question: 'What is 2+2?',
            options: ['3', '4', '5', '6'],
            correctAnswer: 1,
            explanation: '2+2 equals 4',
          )
        ],
        metadata: GameMetadata(
          source: 'document',
          generatedAt: '2024-01-01T00:00:00Z',
          difficulty: 'easy',
          totalItems: 1,
        ),
      );

      final json = game.toJson();

      expect(json['id'], 'test-id');
      expect(json['title'], 'Test Game');
      expect(json['game_type'], 'quiz');
    });
  });

  group('GameType', () {
    test('should parse quiz type', () {
      expect(GameType.fromString('quiz'), GameType.quiz);
    });

    test('should parse flashcards type', () {
      expect(GameType.fromString('flashcards'), GameType.flashcards);
    });

    test('should parse matching type', () {
      expect(GameType.fromString('matching'), GameType.matching);
    });

    test('should parse fill_blank type', () {
      expect(GameType.fromString('fill_blank'), GameType.fillBlank);
    });

    test('should default to quiz for unknown type', () {
      expect(GameType.fromString('unknown'), GameType.quiz);
    });
  });

  group('GameItem', () {
    test('should create quiz item from JSON', () {
      final json = {
        'question': 'What is 2+2?',
        'options': ['3', '4', '5', '6'],
        'correctAnswer': 1,
        'explanation': '2+2 equals 4'
      };

      final item = GameItem.fromJson(json);

      expect(item.question, 'What is 2+2?');
      expect(item.options, ['3', '4', '5', '6']);
      expect(item.correctAnswer, 1);
      expect(item.explanation, '2+2 equals 4');
    });

    test('should create flashcard item from JSON', () {
      final json = {
        'term': 'Photosynthesis',
        'definition': 'Process by which plants make food'
      };

      final item = GameItem.fromJson(json);

      expect(item.term, 'Photosynthesis');
      expect(item.definition, 'Process by which plants make food');
    });

    test('should create matching item from JSON', () {
      final json = {
        'leftItem': 'Capital',
        'rightItem': 'Yaoundé'
      };

      final item = GameItem.fromJson(json);

      expect(item.leftItem, 'Capital');
      expect(item.rightItem, 'Yaoundé');
    });
  });
}





import 'package:prepskul/features/skulmate/models/game_model.dart';

void main() {
  group('GameModel', () {
    test('should create GameModel from JSON', () {
      final json = {
        'id': 'test-id',
        'user_id': 'user-id',
        'child_id': null,
        'title': 'Test Game',
        'game_type': 'quiz',
        'document_url': 'https://example.com/doc.pdf',
        'source_type': 'pdf',
        'created_at': '2024-01-01T00:00:00Z',
        'updated_at': '2024-01-01T00:00:00Z',
        'is_deleted': false,
        'items': [
          {
            'question': 'What is 2+2?',
            'options': ['3', '4', '5', '6'],
            'correctAnswer': 1,
            'explanation': '2+2 equals 4'
          }
        ],
        'metadata': {
          'source': 'document',
          'generatedAt': '2024-01-01T00:00:00Z',
          'difficulty': 'easy',
          'totalItems': 1
        }
      };

      final game = GameModel.fromJson(json);

      expect(game.id, 'test-id');
      expect(game.userId, 'user-id');
      expect(game.title, 'Test Game');
      expect(game.gameType, GameType.quiz);
      expect(game.items.length, 1);
      expect(game.items[0].question, 'What is 2+2?');
    });

    test('should convert GameModel to JSON', () {
      final game = GameModel(
        id: 'test-id',
        userId: 'user-id',
        title: 'Test Game',
        gameType: GameType.quiz,
        createdAt: DateTime.parse('2024-01-01T00:00:00Z'),
        updatedAt: DateTime.parse('2024-01-01T00:00:00Z'),
        items: [
          GameItem(
            question: 'What is 2+2?',
            options: ['3', '4', '5', '6'],
            correctAnswer: 1,
            explanation: '2+2 equals 4',
          )
        ],
        metadata: GameMetadata(
          source: 'document',
          generatedAt: '2024-01-01T00:00:00Z',
          difficulty: 'easy',
          totalItems: 1,
        ),
      );

      final json = game.toJson();

      expect(json['id'], 'test-id');
      expect(json['title'], 'Test Game');
      expect(json['game_type'], 'quiz');
    });
  });

  group('GameType', () {
    test('should parse quiz type', () {
      expect(GameType.fromString('quiz'), GameType.quiz);
    });

    test('should parse flashcards type', () {
      expect(GameType.fromString('flashcards'), GameType.flashcards);
    });

    test('should parse matching type', () {
      expect(GameType.fromString('matching'), GameType.matching);
    });

    test('should parse fill_blank type', () {
      expect(GameType.fromString('fill_blank'), GameType.fillBlank);
    });

    test('should default to quiz for unknown type', () {
      expect(GameType.fromString('unknown'), GameType.quiz);
    });
  });

  group('GameItem', () {
    test('should create quiz item from JSON', () {
      final json = {
        'question': 'What is 2+2?',
        'options': ['3', '4', '5', '6'],
        'correctAnswer': 1,
        'explanation': '2+2 equals 4'
      };

      final item = GameItem.fromJson(json);

      expect(item.question, 'What is 2+2?');
      expect(item.options, ['3', '4', '5', '6']);
      expect(item.correctAnswer, 1);
      expect(item.explanation, '2+2 equals 4');
    });

    test('should create flashcard item from JSON', () {
      final json = {
        'term': 'Photosynthesis',
        'definition': 'Process by which plants make food'
      };

      final item = GameItem.fromJson(json);

      expect(item.term, 'Photosynthesis');
      expect(item.definition, 'Process by which plants make food');
    });

    test('should create matching item from JSON', () {
      final json = {
        'leftItem': 'Capital',
        'rightItem': 'Yaoundé'
      };

      final item = GameItem.fromJson(json);

      expect(item.leftItem, 'Capital');
      expect(item.rightItem, 'Yaoundé');
    });
  });
}











