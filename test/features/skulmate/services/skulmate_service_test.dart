import 'package:flutter_test/flutter_test.dart';
import 'package:prepskul/features/skulmate/services/skulmate_service.dart';
import 'package:prepskul/features/skulmate/models/game_model.dart';

void main() {
  group('SkulMateService', () {
    // Note: These are unit tests for the service structure
    // Integration tests would require actual Supabase connection

    test('GameType enum should have correct string values', () {
      expect(GameType.quiz.toString(), 'quiz');
      expect(GameType.flashcards.toString(), 'flashcards');
      expect(GameType.matching.toString(), 'matching');
      expect(GameType.fillBlank.toString(), 'fill_blank');
    });

    test('GameType.fromString should handle all types', () {
      expect(GameType.fromString('quiz'), GameType.quiz);
      expect(GameType.fromString('flashcards'), GameType.flashcards);
      expect(GameType.fromString('matching'), GameType.matching);
      expect(GameType.fromString('fill_blank'), GameType.fillBlank);
      expect(GameType.fromString('fillblank'), GameType.fillBlank);
    });

    test('GameMetadata should create from JSON correctly', () {
      final json = {
        'source': 'document',
        'generatedAt': '2024-01-01T00:00:00Z',
        'difficulty': 'medium',
        'totalItems': 10
      };

      final metadata = GameMetadata.fromJson(json);

      expect(metadata.source, 'document');
      expect(metadata.difficulty, 'medium');
      expect(metadata.totalItems, 10);
    });

    test('GameSession should create from JSON correctly', () {
      final json = {
        'id': 'session-id',
        'game_id': 'game-id',
        'user_id': 'user-id',
        'score': 8,
        'total_questions': 10,
        'correct_answers': 8,
        'time_taken_seconds': 120,
        'answers': {'0': 1, '1': 0},
        'completed_at': '2024-01-01T00:00:00Z',
        'created_at': '2024-01-01T00:00:00Z'
      };

      final session = GameSession.fromJson(json);

      expect(session.id, 'session-id');
      expect(session.gameId, 'game-id');
      expect(session.score, 8);
      expect(session.totalQuestions, 10);
      expect(session.correctAnswers, 8);
      expect(session.timeTakenSeconds, 120);
    });
  });
}





import 'package:prepskul/features/skulmate/services/skulmate_service.dart';
import 'package:prepskul/features/skulmate/models/game_model.dart';

void main() {
  group('SkulMateService', () {
    // Note: These are unit tests for the service structure
    // Integration tests would require actual Supabase connection

    test('GameType enum should have correct string values', () {
      expect(GameType.quiz.toString(), 'quiz');
      expect(GameType.flashcards.toString(), 'flashcards');
      expect(GameType.matching.toString(), 'matching');
      expect(GameType.fillBlank.toString(), 'fill_blank');
    });

    test('GameType.fromString should handle all types', () {
      expect(GameType.fromString('quiz'), GameType.quiz);
      expect(GameType.fromString('flashcards'), GameType.flashcards);
      expect(GameType.fromString('matching'), GameType.matching);
      expect(GameType.fromString('fill_blank'), GameType.fillBlank);
      expect(GameType.fromString('fillblank'), GameType.fillBlank);
    });

    test('GameMetadata should create from JSON correctly', () {
      final json = {
        'source': 'document',
        'generatedAt': '2024-01-01T00:00:00Z',
        'difficulty': 'medium',
        'totalItems': 10
      };

      final metadata = GameMetadata.fromJson(json);

      expect(metadata.source, 'document');
      expect(metadata.difficulty, 'medium');
      expect(metadata.totalItems, 10);
    });

    test('GameSession should create from JSON correctly', () {
      final json = {
        'id': 'session-id',
        'game_id': 'game-id',
        'user_id': 'user-id',
        'score': 8,
        'total_questions': 10,
        'correct_answers': 8,
        'time_taken_seconds': 120,
        'answers': {'0': 1, '1': 0},
        'completed_at': '2024-01-01T00:00:00Z',
        'created_at': '2024-01-01T00:00:00Z'
      };

      final session = GameSession.fromJson(json);

      expect(session.id, 'session-id');
      expect(session.gameId, 'game-id');
      expect(session.score, 8);
      expect(session.totalQuestions, 10);
      expect(session.correctAnswers, 8);
      expect(session.timeTakenSeconds, 120);
    });
  });
}




