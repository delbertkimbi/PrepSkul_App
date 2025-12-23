import 'dart:convert';

/// Model for skulMate game data
class GameModel {
  final String id;
  final String userId;
  final String? childId;
  final String title;
  final GameType gameType;
  final String? documentUrl;
  final String? sourceType;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDeleted;
  final List<GameItem> items;
  final GameMetadata metadata;

  GameModel({
    required this.id,
    required this.userId,
    this.childId,
    required this.title,
    required this.gameType,
    this.documentUrl,
    this.sourceType,
    required this.createdAt,
    required this.updatedAt,
    this.isDeleted = false,
    required this.items,
    required this.metadata,
  });

  factory GameModel.fromJson(Map<String, dynamic> json) {
    return GameModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      childId: json['child_id'] as String?,
      title: json['title'] as String,
      gameType: GameType.fromString(json['game_type'] as String),
      documentUrl: json['document_url'] as String?,
      sourceType: json['source_type'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      isDeleted: json['is_deleted'] as bool? ?? false,
      items: (json['items'] as List<dynamic>?)
              ?.map((item) => GameItem.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [],
      metadata: GameMetadata.fromJson(
        json['metadata'] as Map<String, dynamic>? ?? {},
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'child_id': childId,
      'title': title,
      'game_type': gameType.toString(),
      'document_url': documentUrl,
      'source_type': sourceType,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'is_deleted': isDeleted,
      'items': items.map((item) => item.toJson()).toList(),
      'metadata': metadata.toJson(),
    };
  }
}

/// Game types supported by skulMate
enum GameType {
  quiz,
  flashcards,
  matching,
  fillBlank;

  static GameType fromString(String value) {
    switch (value.toLowerCase()) {
      case 'quiz':
        return GameType.quiz;
      case 'flashcards':
        return GameType.flashcards;
      case 'matching':
        return GameType.matching;
      case 'fill_blank':
      case 'fillblank':
        return GameType.fillBlank;
      default:
        return GameType.quiz;
    }
  }

  @override
  String toString() {
    switch (this) {
      case GameType.quiz:
        return 'quiz';
      case GameType.flashcards:
        return 'flashcards';
      case GameType.matching:
        return 'matching';
      case GameType.fillBlank:
        return 'fill_blank';
    }
  }
}

/// Individual game item (question, flashcard, matching pair, etc.)
class GameItem {
  final String? question;
  final String? term; // For flashcards
  final String? definition; // For flashcards
  final List<String>? options; // For quiz
  final dynamic correctAnswer; // Can be int (for quiz) or String (for fill_blank)
  final String? explanation;
  final String? leftItem; // For matching
  final String? rightItem; // For matching
  final String? blankText; // For fill_blank

  GameItem({
    this.question,
    this.term,
    this.definition,
    this.options,
    this.correctAnswer,
    this.explanation,
    this.leftItem,
    this.rightItem,
    this.blankText,
  });

  factory GameItem.fromJson(Map<String, dynamic> json) {
    return GameItem(
      question: json['question'] as String?,
      term: json['term'] as String?,
      definition: json['definition'] as String?,
      options: json['options'] != null
          ? List<String>.from(json['options'] as List)
          : null,
      correctAnswer: json['correctAnswer'] ?? json['correct_answer'],
      explanation: json['explanation'] as String?,
      leftItem: json['leftItem'] ?? json['left_item'] as String?,
      rightItem: json['rightItem'] ?? json['right_item'] as String?,
      blankText: json['blankText'] ?? json['blank_text'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (question != null) 'question': question,
      if (term != null) 'term': term,
      if (definition != null) 'definition': definition,
      if (options != null) 'options': options,
      if (correctAnswer != null) 'correctAnswer': correctAnswer,
      if (explanation != null) 'explanation': explanation,
      if (leftItem != null) 'leftItem': leftItem,
      if (rightItem != null) 'rightItem': rightItem,
      if (blankText != null) 'blankText': blankText,
    };
  }
}

/// Game metadata
class GameMetadata {
  final String source;
  final String generatedAt;
  final String difficulty;
  final int totalItems;

  GameMetadata({
    required this.source,
    required this.generatedAt,
    required this.difficulty,
    required this.totalItems,
  });

  factory GameMetadata.fromJson(Map<String, dynamic> json) {
    return GameMetadata(
      source: json['source'] as String? ?? 'document',
      generatedAt: json['generatedAt'] ?? json['generated_at'] as String? ?? '',
      difficulty: json['difficulty'] as String? ?? 'medium',
      totalItems: json['totalItems'] ?? json['total_items'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'source': source,
      'generatedAt': generatedAt,
      'difficulty': difficulty,
      'totalItems': totalItems,
    };
  }
}

/// Game session result
class GameSession {
  final String id;
  final String gameId;
  final String userId;
  final int score;
  final int totalQuestions;
  final int correctAnswers;
  final int? timeTakenSeconds;
  final Map<String, dynamic>? answers;
  final DateTime? completedAt;
  final DateTime createdAt;

  GameSession({
    required this.id,
    required this.gameId,
    required this.userId,
    this.score = 0,
    this.totalQuestions = 0,
    this.correctAnswers = 0,
    this.timeTakenSeconds,
    this.answers,
    this.completedAt,
    required this.createdAt,
  });

  factory GameSession.fromJson(Map<String, dynamic> json) {
    return GameSession(
      id: json['id'] as String,
      gameId: json['game_id'] as String,
      userId: json['user_id'] as String,
      score: json['score'] as int? ?? 0,
      totalQuestions: json['total_questions'] as int? ?? 0,
      correctAnswers: json['correct_answers'] as int? ?? 0,
      timeTakenSeconds: json['time_taken_seconds'] as int?,
      answers: json['answers'] as Map<String, dynamic>?,
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'game_id': gameId,
      'user_id': userId,
      'score': score,
      'total_questions': totalQuestions,
      'correct_answers': correctAnswers,
      'time_taken_seconds': timeTakenSeconds,
      'answers': answers,
      'completed_at': completedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }
}

