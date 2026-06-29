import 'game_model.dart';

/// Canonical revision deck returned alongside generated games.
class RevisionDeckModel {
  final String? id;
  final String title;
  final String topicLabel;
  final String sourceType;
  final String notes;
  final List<RevisionKnowledgeUnit> knowledgeUnits;
  final List<RevisionDeckCard> cards;
  final List<String> conceptCheckCardIds;
  final String? linkedGameId;
  final String gameType;
  final bool librarySaved;
  final int? accentColorArgb;

  const RevisionDeckModel({
    this.id,
    required this.title,
    required this.topicLabel,
    required this.sourceType,
    required this.notes,
    required this.knowledgeUnits,
    required this.cards,
    required this.conceptCheckCardIds,
    this.linkedGameId,
    required this.gameType,
    this.librarySaved = false,
    this.accentColorArgb,
  });

  factory RevisionDeckModel.fromJson(Map<String, dynamic> json) {
    return RevisionDeckModel(
      id: json['id'] as String?,
      title: (json['title'] as String? ?? 'Study Deck').trim(),
      topicLabel: (json['topicLabel'] as String? ?? json['title'] as String? ?? 'Study')
          .trim(),
      sourceType: (json['sourceType'] as String? ?? 'text').trim(),
      notes: (json['notes'] as String? ?? '').trim(),
      knowledgeUnits: (json['knowledgeUnits'] as List<dynamic>? ?? const [])
          .map(
            (unit) => RevisionKnowledgeUnit.fromJson(
              Map<String, dynamic>.from(unit as Map),
            ),
          )
          .toList(),
      cards: (json['cards'] as List<dynamic>? ?? const [])
          .map(
            (card) => RevisionDeckCard.fromJson(
              Map<String, dynamic>.from(card as Map),
            ),
          )
          .toList(),
      conceptCheckCardIds: (json['conceptCheckCardIds'] as List<dynamic>? ?? const [])
          .map((id) => id.toString())
          .toList(),
      linkedGameId: json['linkedGameId'] as String?,
      gameType: (json['gameType'] as String? ?? 'quiz').trim(),
      librarySaved: json['librarySaved'] as bool? ?? false,
      accentColorArgb: (json['accentColor'] as num?)?.toInt(),
    );
  }

  RevisionDeckCard? cardById(String cardId) {
    for (final card in cards) {
      if (card.id == cardId) return card;
    }
    return null;
  }

  List<RevisionDeckCard> get conceptCheckCards {
    if (conceptCheckCardIds.isEmpty) {
      return cards.take(3).toList();
    }
    return conceptCheckCardIds
        .map(cardById)
        .whereType<RevisionDeckCard>()
        .toList();
  }

  String get deckKey => id ?? linkedGameId ?? title;
}

class RevisionKnowledgeUnit {
  final String id;
  final String name;
  final String priority;

  const RevisionKnowledgeUnit({
    required this.id,
    required this.name,
    required this.priority,
  });

  factory RevisionKnowledgeUnit.fromJson(Map<String, dynamic> json) {
    return RevisionKnowledgeUnit(
      id: (json['id'] as String? ?? 'core').trim(),
      name: (json['name'] as String? ?? 'Core concepts').trim(),
      priority: (json['priority'] as String? ?? 'medium').trim(),
    );
  }
}

enum RevisionDeckCardType {
  termDef,
  mcq,
  cloze,
  multiSelect,
  pair,
  order,
  unknown;

  static RevisionDeckCardType fromString(String? raw) {
    switch ((raw ?? '').toLowerCase()) {
      case 'term_def':
        return RevisionDeckCardType.termDef;
      case 'mcq':
        return RevisionDeckCardType.mcq;
      case 'cloze':
        return RevisionDeckCardType.cloze;
      case 'multi_select':
        return RevisionDeckCardType.multiSelect;
      case 'pair':
        return RevisionDeckCardType.pair;
      case 'order':
        return RevisionDeckCardType.order;
      default:
        return RevisionDeckCardType.unknown;
    }
  }
}

class RevisionDeckCard {
  final String id;
  final String knowledgeUnitId;
  final RevisionDeckCardType cardType;
  final String prompt;
  final String answer;
  final List<String> distractors;
  final String? explanation;
  final String? sourceQuote;
  final String difficulty;
  final List<String> tags;
  final int? gameItemIndex;

  const RevisionDeckCard({
    required this.id,
    required this.knowledgeUnitId,
    required this.cardType,
    required this.prompt,
    required this.answer,
    this.distractors = const [],
    this.explanation,
    this.sourceQuote,
    this.difficulty = 'medium',
    this.tags = const [],
    this.gameItemIndex,
  });

  factory RevisionDeckCard.fromJson(Map<String, dynamic> json) {
    return RevisionDeckCard(
      id: (json['id'] as String? ?? '').trim(),
      knowledgeUnitId: (json['knowledgeUnitId'] as String? ?? 'core').trim(),
      cardType: RevisionDeckCardType.fromString(json['cardType'] as String?),
      prompt: (json['prompt'] as String? ?? '').trim(),
      answer: (json['answer'] as String? ?? '').trim(),
      distractors: (json['distractors'] as List<dynamic>? ?? const [])
          .map((value) => value.toString().trim())
          .where((value) => value.isNotEmpty)
          .toList(),
      explanation: (json['explanation'] as String?)?.trim(),
      sourceQuote: (json['sourceQuote'] as String?)?.trim(),
      difficulty: (json['difficulty'] as String? ?? 'medium').trim(),
      tags: (json['tags'] as List<dynamic>? ?? const [])
          .map((value) => value.toString())
          .toList(),
      gameItemIndex: json['gameItemIndex'] as int?,
    );
  }

  List<String> get mcqOptions {
    final options = <String>[answer, ...distractors];
    final unique = <String>[];
    for (final option in options) {
      if (option.isEmpty) continue;
      if (!unique.any((existing) => existing.toLowerCase() == option.toLowerCase())) {
        unique.add(option);
      }
    }
    unique.shuffle();
    return unique;
  }

  bool get supportsMcqProbe =>
      cardType == RevisionDeckCardType.mcq && mcqOptions.length >= 2;
}

class SkulMateGenerateResult {
  final GameModel game;
  final RevisionDeckModel? deck;

  const SkulMateGenerateResult({
    required this.game,
    this.deck,
  });
}
