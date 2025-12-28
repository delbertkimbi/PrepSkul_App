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
  fillBlank,
  match3,
  bubblePop,
  wordSearch,
  crossword,
  diagramLabel,
  dragDrop,
  puzzlePieces;

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
      case 'match3':
      case 'match_3':
        return GameType.match3;
      case 'bubble_pop':
      case 'bubblepop':
        return GameType.bubblePop;
      case 'word_search':
      case 'wordsearch':
        return GameType.wordSearch;
      case 'crossword':
        return GameType.crossword;
      case 'diagram_label':
      case 'diagramlabel':
        return GameType.diagramLabel;
      case 'drag_drop':
      case 'dragdrop':
        return GameType.dragDrop;
      case 'puzzle_pieces':
      case 'puzzlepieces':
        return GameType.puzzlePieces;
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
      case GameType.match3:
        return 'match3';
      case GameType.bubblePop:
        return 'bubble_pop';
      case GameType.wordSearch:
        return 'word_search';
      case GameType.crossword:
        return 'crossword';
      case GameType.diagramLabel:
        return 'diagram_label';
      case GameType.dragDrop:
        return 'drag_drop';
      case GameType.puzzlePieces:
        return 'puzzle_pieces';
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
  // New fields for interactive game types
  final String? imageUrl; // For diagram/image-based games
  final List<List<String>>? gridData; // For match-3, word search, crossword (2D grid)
  final List<Map<String, dynamic>>? dragItems; // For drag-drop games
  final List<Map<String, dynamic>>? dropZones; // For drag-drop target areas
  final List<Map<String, dynamic>>? puzzlePieces; // For puzzle assembly games
  final List<Map<String, dynamic>>? diagramLabels; // For diagram labeling (list of label positions)
  final List<String>? words; // For word search
  final List<Map<String, dynamic>>? clues; // For crossword
  final List<Map<String, dynamic>>? bubbles; // For bubble pop

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
    this.imageUrl,
    this.gridData,
    this.dragItems,
    this.dropZones,
    this.puzzlePieces,
    this.diagramLabels,
    this.words,
    this.clues,
    this.bubbles,
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
      imageUrl: json['imageUrl'] ?? json['image_url'] as String?,
      gridData: json['gridData'] != null
          ? (json['gridData'] as List).map((row) => List<String>.from(row as List)).toList()
          : json['grid_data'] != null
              ? (json['grid_data'] as List).map((row) => List<String>.from(row as List)).toList()
              : null,
      dragItems: json['dragItems'] != null
          ? List<Map<String, dynamic>>.from(json['dragItems'] as List)
          : json['drag_items'] != null
              ? List<Map<String, dynamic>>.from(json['drag_items'] as List)
              : null,
      dropZones: json['dropZones'] != null
          ? List<Map<String, dynamic>>.from(json['dropZones'] as List)
          : json['drop_zones'] != null
              ? List<Map<String, dynamic>>.from(json['drop_zones'] as List)
              : null,
      puzzlePieces: json['puzzlePieces'] != null
          ? List<Map<String, dynamic>>.from(json['puzzlePieces'] as List)
          : json['puzzle_pieces'] != null
              ? List<Map<String, dynamic>>.from(json['puzzle_pieces'] as List)
              : null,
      diagramLabels: json['diagramLabels'] != null
          ? List<Map<String, dynamic>>.from(json['diagramLabels'] as List)
          : json['diagram_labels'] != null
              ? List<Map<String, dynamic>>.from(json['diagram_labels'] as List)
              : null,
      words: json['words'] != null
          ? List<String>.from(json['words'] as List)
          : null,
      clues: json['clues'] != null
          ? List<Map<String, dynamic>>.from(json['clues'] as List)
          : null,
      bubbles: json['bubbles'] != null
          ? List<Map<String, dynamic>>.from(json['bubbles'] as List)
          : null,
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
      if (imageUrl != null) 'imageUrl': imageUrl,
      if (gridData != null) 'gridData': gridData,
      if (dragItems != null) 'dragItems': dragItems,
      if (dropZones != null) 'dropZones': dropZones,
      if (puzzlePieces != null) 'puzzlePieces': puzzlePieces,
      if (diagramLabels != null) 'diagramLabels': diagramLabels,
      if (words != null) 'words': words,
      if (clues != null) 'clues': clues,
      if (bubbles != null) 'bubbles': bubbles,
    };
  }
}

/// Game metadata
class GameMetadata {
  final String source;
  final String generatedAt;
  final String difficulty;
  final int totalItems;
  final String? topic;

  GameMetadata({
    required this.source,
    required this.generatedAt,
    required this.difficulty,
    required this.totalItems,
    this.topic,
  });

  factory GameMetadata.fromJson(Map<String, dynamic> json) {
    return GameMetadata(
      source: json['source'] as String? ?? 'document',
      generatedAt: json['generatedAt'] ?? json['generated_at'] as String? ?? '',
      difficulty: json['difficulty'] as String? ?? 'medium',
      totalItems: json['totalItems'] ?? json['total_items'] as int? ?? 0,
      topic: json['topic'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'source': source,
      'generatedAt': generatedAt,
      'difficulty': difficulty,
      'totalItems': totalItems,
      if (topic != null) 'topic': topic,
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
