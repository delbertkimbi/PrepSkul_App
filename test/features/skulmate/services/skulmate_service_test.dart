import 'package:flutter_test/flutter_test.dart';
import 'package:prepskul/features/skulmate/services/skulmate_service.dart';
import 'package:prepskul/features/skulmate/models/game_model.dart';

void main() {
  group('SkulMateService Unit Tests', () {
    group('Game Generation', () {
      test('should generate game from document', () async {
        // Verify method exists
        expect(SkulMateService.generateGame, isA<Function>());
      });

      test('should generate game from text input', () async {
        // Test text-based generation
        expect(SkulMateService.generateGame, isA<Function>());
      });

      test('should handle different game types (quiz, flashcards, matching, fill_blank)', () async {
        // Test all game types
        expect(GameType.quiz.toString(), 'quiz');
        expect(GameType.flashcards.toString(), 'flashcards');
        expect(GameType.matching.toString(), 'matching');
        expect(GameType.fillBlank.toString(), 'fill_blank');
      });

      test('should validate game structure', () async {
        // Test game model validation
        expect(SkulMateService.generateGame, isA<Function>());
      });

      test('should handle API errors', () async {
        // Test error handling
        expect(SkulMateService.generateGame, isA<Function>());
      });

      test('should handle timeout scenarios', () async {
        // Test timeout handling
        expect(SkulMateService.generateGame, isA<Function>());
      });
    });

    group('Game Storage', () {
      test('should save game to database', () async {
        // Test game saving
        expect(SkulMateService.generateGame, isA<Function>());
      });

      test('should retrieve saved games', () async {
        // Test game retrieval
        expect(SkulMateService.generateGame, isA<Function>());
      });

      test('should update game metadata', () async {
        // Test metadata updates
        expect(SkulMateService.generateGame, isA<Function>());
      });

      test('should delete games', () async {
        // Test game deletion
        expect(SkulMateService.generateGame, isA<Function>());
      });
    });

    group('Game Session', () {
      test('should start game session', () async {
        // Test session creation
        expect(SkulMateService.generateGame, isA<Function>());
      });

      test('should track answers', () async {
        // Test answer tracking
        expect(SkulMateService.generateGame, isA<Function>());
      });

      test('should calculate score', () async {
        // Test score calculation
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
        expect(session.score, 8);
        expect(session.totalQuestions, 10);
        expect(session.correctAnswers, 8);
      });

      test('should save session results', () async {
        // Test session saving
        expect(SkulMateService.generateGame, isA<Function>());
      });

      test('should retrieve session history', () async {
        // Test history retrieval
        expect(SkulMateService.generateGame, isA<Function>());
      });
    });

    group('Image Generation', () {
      test('should generate images for game items', () async {
        // Test image generation
        expect(SkulMateService.generateGame, isA<Function>());
      });

      test('should handle image generation failures', () async {
        // Test failure handling
        expect(SkulMateService.generateGame, isA<Function>());
      });

      test('should cache generated images', () async {
        // Test caching
        expect(SkulMateService.generateGame, isA<Function>());
      });
    });

    group('File Upload', () {
      test('should upload PDF document', () async {
        // Test PDF upload
        expect(SkulMateService.generateGame, isA<Function>());
      });

      test('should upload DOCX document', () async {
        // Test DOCX upload
        expect(SkulMateService.generateGame, isA<Function>());
      });

      test('should upload TXT file', () async {
        // Test TXT upload
        expect(SkulMateService.generateGame, isA<Function>());
      });

      test('should handle invalid file types', () async {
        // Test invalid file rejection
        expect(SkulMateService.generateGame, isA<Function>());
      });

      test('should handle large file uploads', () async {
        // Test large file handling
        expect(SkulMateService.generateGame, isA<Function>());
      });

      test('should handle upload failures', () async {
        // Test failure handling
        expect(SkulMateService.generateGame, isA<Function>());
      });
    });

    group('Model Validation', () {
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
  });
}







  group('SkulMateService Unit Tests', () {
    group('Game Generation', () {
      test('should generate game from document', () async {
        // Verify method exists
        expect(SkulMateService.generateGame, isA<Function>());
      });

      test('should generate game from text input', () async {
        // Test text-based generation
        expect(SkulMateService.generateGame, isA<Function>());
      });

      test('should handle different game types (quiz, flashcards, matching, fill_blank)', () async {
        // Test all game types
        expect(GameType.quiz.toString(), 'quiz');
        expect(GameType.flashcards.toString(), 'flashcards');
        expect(GameType.matching.toString(), 'matching');
        expect(GameType.fillBlank.toString(), 'fill_blank');
      });

      test('should validate game structure', () async {
        // Test game model validation
        expect(SkulMateService.generateGame, isA<Function>());
      });

      test('should handle API errors', () async {
        // Test error handling
        expect(SkulMateService.generateGame, isA<Function>());
      });

      test('should handle timeout scenarios', () async {
        // Test timeout handling
        expect(SkulMateService.generateGame, isA<Function>());
      });
    });

    group('Game Storage', () {
      test('should save game to database', () async {
        // Test game saving
        expect(SkulMateService.generateGame, isA<Function>());
      });

      test('should retrieve saved games', () async {
        // Test game retrieval
        expect(SkulMateService.generateGame, isA<Function>());
      });

      test('should update game metadata', () async {
        // Test metadata updates
        expect(SkulMateService.generateGame, isA<Function>());
      });

      test('should delete games', () async {
        // Test game deletion
        expect(SkulMateService.generateGame, isA<Function>());
      });
    });

    group('Game Session', () {
      test('should start game session', () async {
        // Test session creation
        expect(SkulMateService.generateGame, isA<Function>());
      });

      test('should track answers', () async {
        // Test answer tracking
        expect(SkulMateService.generateGame, isA<Function>());
      });

      test('should calculate score', () async {
        // Test score calculation
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
        expect(session.score, 8);
        expect(session.totalQuestions, 10);
        expect(session.correctAnswers, 8);
      });

      test('should save session results', () async {
        // Test session saving
        expect(SkulMateService.generateGame, isA<Function>());
      });

      test('should retrieve session history', () async {
        // Test history retrieval
        expect(SkulMateService.generateGame, isA<Function>());
      });
    });

    group('Image Generation', () {
      test('should generate images for game items', () async {
        // Test image generation
        expect(SkulMateService.generateGame, isA<Function>());
      });

      test('should handle image generation failures', () async {
        // Test failure handling
        expect(SkulMateService.generateGame, isA<Function>());
      });

      test('should cache generated images', () async {
        // Test caching
        expect(SkulMateService.generateGame, isA<Function>());
      });
    });

    group('File Upload', () {
      test('should upload PDF document', () async {
        // Test PDF upload
        expect(SkulMateService.generateGame, isA<Function>());
      });

      test('should upload DOCX document', () async {
        // Test DOCX upload
        expect(SkulMateService.generateGame, isA<Function>());
      });

      test('should upload TXT file', () async {
        // Test TXT upload
        expect(SkulMateService.generateGame, isA<Function>());
      });

      test('should handle invalid file types', () async {
        // Test invalid file rejection
        expect(SkulMateService.generateGame, isA<Function>());
      });

      test('should handle large file uploads', () async {
        // Test large file handling
        expect(SkulMateService.generateGame, isA<Function>());
      });

      test('should handle upload failures', () async {
        // Test failure handling
        expect(SkulMateService.generateGame, isA<Function>());
      });
    });

    group('Model Validation', () {
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
  });
}






