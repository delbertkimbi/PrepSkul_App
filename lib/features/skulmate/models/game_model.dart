/// Model for skulMate game data
import 'dart:convert';

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

  /// Returns false if game content is invalid/unplayable (e.g. diagramLabel with placeholder image, quiz with no options).
  bool get isPlayable {
    if (items.isEmpty) return false;
    switch (gameType) {
      case GameType.diagramLabel:
        for (final item in items) {
          final url = (item.imageUrl ?? '').trim().toLowerCase();
          if (url.isEmpty || url.contains('url_to_') || url.contains('placeholder')) return false;
        }
        return items.any((i) => (i.diagramLabels ?? []).isNotEmpty);
      case GameType.quiz:
        return items.any(
          (i) =>
              (i.options ?? []).isNotEmpty ||
              (((i.dragItems ?? []).isNotEmpty) && ((i.dropZones ?? []).isNotEmpty)) ||
              ((i.blankText ?? '').isNotEmpty),
        );
      case GameType.flashcards:
        return items.any((i) => ((i.term ?? '').isNotEmpty) && ((i.definition ?? '').isNotEmpty));
      case GameType.matching:
        return items.any((i) => ((i.leftItem ?? '').isNotEmpty) && ((i.rightItem ?? '').isNotEmpty));
      case GameType.fillBlank:
        return items.any((i) => (i.blankText ?? '').isNotEmpty);
      case GameType.dragDrop:
        return items.any(
          (i) => (i.dragItems ?? []).isNotEmpty && (i.dropZones ?? []).isNotEmpty,
        );
      case GameType.match3:
        return items.any((i) => (i.gridData ?? []).isNotEmpty || (i.words ?? []).isNotEmpty);
      case GameType.bubblePop:
        return items.any((i) => (i.bubbles ?? []).isNotEmpty || (i.words ?? []).isNotEmpty);
      case GameType.wordSearch:
        return items.any((i) =>
            (i.words ?? []).isNotEmpty ||
            (i.gridData ?? []).isNotEmpty ||
            ((i.gameData?['words'] as List?)?.isNotEmpty ?? false) ||
            ((i.gameData?['gridData'] as List?)?.isNotEmpty ?? false) ||
            ((i.gameData?['grid'] as List?)?.isNotEmpty ?? false) ||
            ((i.gameData?['board'] as List?)?.isNotEmpty ?? false));
      case GameType.crossword:
        return items.any((i) =>
            (i.clues ?? []).isNotEmpty ||
            ((i.gameData?['clues'] as List?)?.isNotEmpty ?? false) ||
            ((i.gameData?['clueList'] as List?)?.isNotEmpty ?? false));
      case GameType.puzzlePieces:
        return items.any((i) => (i.puzzlePieces ?? []).isNotEmpty);
      case GameType.simulation:
        return items.any(
          (i) =>
              (i.scenarios ?? []).isNotEmpty ||
              (i.gameData != null && i.gameData!.isNotEmpty) ||
              ((i.question ?? '').trim().isNotEmpty),
        );
      case GameType.mystery:
        return items.any(
          (i) =>
              (i.mysteryClues ?? []).isNotEmpty ||
              ((i.solution ?? '').trim().isNotEmpty) ||
              (i.gameData != null &&
                  (((i.gameData!['clues'] as List?)?.isNotEmpty ?? false) ||
                      ((i.gameData!['solution'] as String?)?.trim().isNotEmpty ??
                          false))) ||
              ((i.question ?? '').trim().isNotEmpty),
        );
      case GameType.escapeRoom:
        return items.any(
          (i) =>
              (i.rooms ?? []).isNotEmpty ||
              (i.gameData != null && i.gameData!.isNotEmpty) ||
              ((i.question ?? '').trim().isNotEmpty),
        );
      default:
        return items.any((i) => (i.options ?? []).isNotEmpty || ((i.question ?? '').trim().isNotEmpty));
    }
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
  puzzlePieces,
  simulation, // Decision-based simulations (e.g., "Diagnose the Patient")
  mystery, // Mystery/Detective games (e.g., "Who is the unreliable narrator?")
  escapeRoom; // Concept escape rooms (e.g., "Escape the Lab")

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
      case 'simulation':
        return GameType.simulation;
      case 'mystery':
      case 'story':
      case 'story_game':
      case 'storymode':
        return GameType.mystery;
      case 'escape_room':
      case 'escaperoom':
        return GameType.escapeRoom;
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
      case GameType.simulation:
        return 'simulation';
      case GameType.mystery:
        return 'mystery';
      case GameType.escapeRoom:
        return 'escape_room';
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
  // New fields for simulation, mystery, and escape room games
  final Map<String, dynamic>? gameData; // Dynamic structure for simulation/mystery/escapeRoom
  final List<Map<String, dynamic>>? scenarios; // For simulation games
  final String? role; // For simulation games (e.g., "Public Health Officer")
  final String? caseName; // For mystery games (e.g., "The Failed Experiment")
  final List<Map<String, dynamic>>? mysteryClues; // For mystery games
  final String? solution; // For mystery games
  final List<Map<String, dynamic>>? rooms; // For escape room games
  final bool isBoss; // Boss question (harder, bonus XP)

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
    this.gameData,
    this.scenarios,
    this.role,
    this.caseName,
    this.mysteryClues,
    this.solution,
    this.rooms,
    this.isBoss = false,
  });

  factory GameItem.fromJson(Map<String, dynamic> json) {
    dynamic decodeIfJsonString(dynamic value) {
      if (value is! String) return value;
      final trimmed = value.trim();
      if (trimmed.isEmpty) return value;
      if (!(trimmed.startsWith('{') || trimmed.startsWith('['))) return value;
      try {
        return jsonDecode(trimmed);
      } catch (_) {
        return value;
      }
    }

    List<String>? parseStringList(dynamic raw) {
      final decoded = decodeIfJsonString(raw);
      if (decoded == null) return null;
      if (decoded is! List) return null;
      final out = <String>[];
      for (final e in decoded) {
        if (e == null) continue;
        if (e is String) {
          final s = e.trim();
          if (s.isNotEmpty) out.add(s);
          continue;
        }
        if (e is Map) {
          final candidate = (e['text'] ?? e['word'] ?? e['value'] ?? '').toString().trim();
          if (candidate.isNotEmpty) out.add(candidate);
          continue;
        }
        final s = e.toString().trim();
        if (s.isNotEmpty) out.add(s);
      }
      return out.isEmpty ? null : out;
    }

    List<List<String>>? parseGridData(dynamic raw) {
      final decoded = decodeIfJsonString(raw);
      if (decoded == null) return null;
      if (decoded is! List) return null;
      try {
        final grid = decoded
            .map((row) {
              if (row is! List) return <String>[];
              return row
                  .map((cell) => cell?.toString().trim() ?? '')
                  .toList();
            })
            .toList();
        return grid;
      } catch (_) {
        return null;
      }
    }

    List<Map<String, dynamic>>? parseMapList(dynamic raw) {
      final decoded = decodeIfJsonString(raw);
      if (decoded == null) return null;
      if (decoded is! List) return null;
      final out = <Map<String, dynamic>>[];
      for (final e in decoded) {
        if (e is Map) out.add(e.cast<String, dynamic>());
      }
      return out.isEmpty ? null : out;
    }

    // Support multiple API key formats for flashcards
    final term = json['term'] as String? ??
        json['front'] as String? ??
        json['word'] as String? ??
        json['prompt'] as String?;
    final definition = json['definition'] as String? ??
        json['back'] as String? ??
        json['meaning'] as String? ??
        json['answer'] as String?;

    final decodedGameData =
        decodeIfJsonString(json['gameData'] ?? json['game_data']);
    final gameDataMap = decodedGameData is Map<String, dynamic>
        ? decodedGameData
        : (decodedGameData is Map ? decodedGameData.cast<String, dynamic>() : null);

    return GameItem(
      question: json['question'] as String?,
      term: term,
      definition: definition,
      options: parseStringList(json['options'] ?? json['choices']),
      correctAnswer: json['correctAnswer'] ?? json['correct_answer'],
      explanation: json['explanation'] as String?,
      leftItem: json['leftItem'] ?? json['left_item'] as String?,
      rightItem: json['rightItem'] ?? json['right_item'] as String?,
      blankText: json['blankText'] ?? json['blank_text'] as String?,
      imageUrl: json['imageUrl'] ?? json['image_url'] as String?,
      gridData: parseGridData(
        json['gridData'] ??
            json['grid_data'] ??
            json['grid'] ??
            json['board'] ??
            json['letterGrid'] ??
            gameDataMap?['gridData'] ??
            gameDataMap?['grid_data'] ??
            gameDataMap?['grid'] ??
            gameDataMap?['board'],
      ),
      dragItems: parseMapList(
        json['dragItems'] ?? json['drag_items'] ?? gameDataMap?['dragItems'] ?? gameDataMap?['drag_items'],
      ),
      dropZones: parseMapList(
        json['dropZones'] ?? json['drop_zones'] ?? gameDataMap?['dropZones'] ?? gameDataMap?['drop_zones'],
      ),
      puzzlePieces: parseMapList(
        json['puzzlePieces'] ??
            json['puzzle_pieces'] ??
            gameDataMap?['puzzlePieces'] ??
            gameDataMap?['puzzle_pieces'],
      ),
      diagramLabels: parseMapList(
        json['diagramLabels'] ??
            json['diagram_labels'] ??
            gameDataMap?['diagramLabels'] ??
            gameDataMap?['diagram_labels'],
      ),
      words: parseStringList(
        json['words'] ??
            json['wordList'] ??
            json['word_list'] ??
            gameDataMap?['words'] ??
            gameDataMap?['wordList'] ??
            gameDataMap?['word_list'],
      ),
      clues: parseMapList(
        json['clues'] ??
            json['clueList'] ??
            json['clue_list'] ??
            gameDataMap?['clues'] ??
            gameDataMap?['clueList'] ??
            gameDataMap?['clue_list'],
      ),
      bubbles: parseMapList(
        json['bubbles'] ?? gameDataMap?['bubbles'],
      ),
      gameData: gameDataMap,
      scenarios: parseMapList(
        json['scenarios'] ?? gameDataMap?['scenarios'],
      ),
      role: json['role'] as String?,
      caseName: json['caseName'] ?? json['case_name'] ?? json['case'] as String?,
      mysteryClues: parseMapList(
        json['mysteryClues'] ??
            json['mystery_clues'] ??
            gameDataMap?['mysteryClues'] ??
            gameDataMap?['mystery_clues'] ??
            ((json['clues'] != null &&
                        (json['gameType'] ?? json['game_type'])
                            ?.toString()
                            .toLowerCase() ==
                            'mystery')
                    ? json['clues']
                    : null),
      ),
      solution: json['solution'] as String?,
      rooms: parseMapList(
        json['rooms'] ?? gameDataMap?['rooms'],
      ),
      isBoss: json['isBoss'] as bool? ?? false,
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
      if (gameData != null) 'gameData': gameData,
      if (scenarios != null) 'scenarios': scenarios,
      if (role != null) 'role': role,
      if (caseName != null) 'caseName': caseName,
      if (mysteryClues != null) 'mysteryClues': mysteryClues,
      if (solution != null) 'solution': solution,
      if (rooms != null) 'rooms': rooms,
      if (isBoss) 'isBoss': isBoss,
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

/// Per-question performance used for end-of-game summaries
class QuestionPerformance {
  final String question;
  final bool isCorrect;

  const QuestionPerformance({
    required this.question,
    required this.isCorrect,
  });
}
