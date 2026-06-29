import '../models/game_model.dart';
import '../models/revision_deck_model.dart';

/// Builds a revision deck locally when the API did not return one.
class RevisionDeckBuilder {
  static RevisionDeckModel fromGame(GameModel game) {
    final gameType = game.gameType.toString();
    final topicLabel = game.metadata.topic?.trim().isNotEmpty == true
        ? game.metadata.topic!.trim()
        : game.title;
    const units = <RevisionKnowledgeUnit>[];
    const defaultUnitId = 'core-1';

    final builtCards = <RevisionDeckCard>[];
    for (var i = 0; i < game.items.length; i++) {
      final card = _cardFromItem(game.items[i], i, game.gameType, defaultUnitId);
      if (card != null) builtCards.add(card);
    }

    final cards = game.gameType == GameType.flashcards
        ? _enrichFlashcardDeck(builtCards, _notesFromGame(game, topicLabel))
        : builtCards;

    final conceptIds = _pickConceptCheckIds(cards);

    return RevisionDeckModel(
      id: game.id,
      title: game.title,
      topicLabel: topicLabel,
      sourceType: game.sourceType ?? 'text',
      notes: _notesFromGame(game, topicLabel),
      knowledgeUnits: units,
      cards: cards,
      conceptCheckCardIds: conceptIds,
      linkedGameId: game.id,
      gameType: gameType,
    );
  }

  static String _notesFromGame(GameModel game, String topicLabel) {
    final snapshot = game.sourceTextSnapshot?.trim();
    if (snapshot != null && snapshot.length >= 80) {
      return snapshot.length > 900 ? snapshot.substring(0, 900) : snapshot;
    }
    return 'Revision deck for $topicLabel. Review the cards, then choose how you want to practice.';
  }

  static RevisionDeckCard? _cardFromItem(
    GameItem item,
    int index,
    GameType gameType,
    String unitId,
  ) {
    switch (gameType) {
      case GameType.flashcards:
        return _termCard(item, index, unitId);
      case GameType.matching:
        return _pairCard(item, index, unitId);
      case GameType.fillBlank:
        return _clozeCard(item, index, unitId);
      case GameType.quiz:
        return _mcqCard(item, index, unitId) ?? _genericCard(item, index, unitId);
      default:
        return _mcqCard(item, index, unitId) ??
            _termCard(item, index, unitId) ??
            _pairCard(item, index, unitId) ??
            _clozeCard(item, index, unitId) ??
            _genericCard(item, index, unitId);
    }
  }

  static RevisionDeckCard? _termCard(GameItem item, int index, String unitId) {
    final term = item.term?.trim() ?? '';
    final definition = item.definition?.trim() ?? '';
    if (term.isEmpty || definition.isEmpty) return null;
    return RevisionDeckCard(
      id: 'card-${index + 1}',
      knowledgeUnitId: unitId,
      cardType: RevisionDeckCardType.termDef,
      prompt: term,
      answer: definition,
      difficulty: 'easy',
      tags: const ['flashcard'],
      gameItemIndex: index,
    );
  }

  static RevisionDeckCard? _pairCard(GameItem item, int index, String unitId) {
    final left = item.leftItem?.trim() ?? '';
    final right = item.rightItem?.trim() ?? '';
    if (left.isEmpty || right.isEmpty) return null;
    return RevisionDeckCard(
      id: 'card-${index + 1}',
      knowledgeUnitId: unitId,
      cardType: RevisionDeckCardType.pair,
      prompt: left,
      answer: right,
      difficulty: 'medium',
      tags: const ['matching'],
      gameItemIndex: index,
    );
  }

  static RevisionDeckCard? _clozeCard(GameItem item, int index, String unitId) {
    final blank = item.blankText?.trim() ?? '';
    if (blank.isEmpty) return null;
    final answer = _stringCorrectAnswer(item) ?? blank;
    return RevisionDeckCard(
      id: 'card-${index + 1}',
      knowledgeUnitId: unitId,
      cardType: RevisionDeckCardType.cloze,
      prompt: blank,
      answer: answer,
      difficulty: 'medium',
      tags: const ['fill_blank'],
      gameItemIndex: index,
    );
  }

  static RevisionDeckCard? _mcqCard(GameItem item, int index, String unitId) {
    final question = item.question?.trim() ?? '';
    final options = item.options ?? const [];
    if (question.isEmpty || options.length < 2) return null;
    final correct = _resolveMcqAnswer(item, options);
    final distractors = options
        .map((o) => o.trim())
        .where((o) => o.isNotEmpty && o != correct)
        .toList();
    return RevisionDeckCard(
      id: 'card-${index + 1}',
      knowledgeUnitId: unitId,
      cardType: RevisionDeckCardType.mcq,
      prompt: question,
      answer: correct,
      distractors: distractors,
      difficulty: 'medium',
      tags: const ['quiz'],
      gameItemIndex: index,
    );
  }

  static RevisionDeckCard? _genericCard(GameItem item, int index, String unitId) {
    final question = item.question?.trim() ?? '';
    final answer = _stringCorrectAnswer(item) ??
        item.definition?.trim() ??
        item.solution?.trim() ??
        '';
    if (question.isEmpty || answer.isEmpty) return null;
    return RevisionDeckCard(
      id: 'card-${index + 1}',
      knowledgeUnitId: unitId,
      cardType: RevisionDeckCardType.mcq,
      prompt: question,
      answer: answer,
      difficulty: 'medium',
      gameItemIndex: index,
    );
  }

  static List<String> _pickConceptCheckIds(List<RevisionDeckCard> cards) {
    if (cards.isEmpty) return const [];
    final picked = <RevisionDeckCard>[];
    final mcq = cards.where((c) => c.cardType == RevisionDeckCardType.mcq).toList();
    final terms =
        cards.where((c) => c.cardType == RevisionDeckCardType.termDef).toList();

    void add(RevisionDeckCard? card) {
      if (card == null) return;
      if (picked.any((p) => p.id == card.id)) return;
      picked.add(card);
    }

    add(mcq.isNotEmpty ? mcq.first : null);
    add(terms.isNotEmpty ? terms.first : null);
    add(mcq.length > 1 ? mcq[1] : null);

    for (final card in cards) {
      if (picked.length >= 3) break;
      add(card);
    }

    return picked.take(3).map((c) => c.id).toList();
  }

  static String? _stringCorrectAnswer(GameItem item) {
    final raw = item.correctAnswer;
    if (raw == null) return null;
    if (raw is String && raw.trim().isNotEmpty) return raw.trim();
    if (raw is int && item.options != null && raw >= 0 && raw < item.options!.length) {
      return item.options![raw].trim();
    }
    return raw.toString().trim().isEmpty ? null : raw.toString().trim();
  }

  static String _resolveMcqAnswer(GameItem item, List<String> options) {
    final fromCorrect = _stringCorrectAnswer(item);
    if (fromCorrect != null && fromCorrect.isNotEmpty) return fromCorrect;
    return options.first.trim();
  }

  static List<RevisionDeckCard> _enrichFlashcardDeck(
    List<RevisionDeckCard> cards,
    String extractedText,
  ) {
    if (cards.length < 4) return cards;
    final termCards =
        cards.where((c) => c.cardType == RevisionDeckCardType.termDef).toList();
    if (termCards.length < 4) return cards;

    final answerPool = termCards
        .map((c) => c.answer)
        .where((a) => a.isNotEmpty)
        .fold<List<String>>([], (pool, answer) {
      if (!pool.any((p) => p.toLowerCase() == answer.toLowerCase())) {
        pool.add(answer);
      }
      return pool;
    });

    final enriched = <RevisionDeckCard>[];
    var synthMcq = 0;

    for (var index = 0; index < cards.length; index++) {
      final card = cards[index];
      enriched.add(card);

      if (card.cardType != RevisionDeckCardType.termDef) continue;

      if ((index + 1) % 3 == 0) {
        final distractors = answerPool
            .where((a) => a.toLowerCase() != card.answer.toLowerCase())
            .take(3)
            .toList();
        if (distractors.length >= 2) {
          enriched.add(
            RevisionDeckCard(
              id: '${card.id}-mcq-$synthMcq',
              knowledgeUnitId: card.knowledgeUnitId,
              cardType: RevisionDeckCardType.mcq,
              prompt: 'What is the definition of "${card.prompt}"?',
              answer: card.answer,
              distractors: distractors,
              explanation: card.explanation,
              difficulty: 'medium',
              tags: const ['synthesized_mcq'],
              gameItemIndex: card.gameItemIndex,
            ),
          );
          synthMcq++;
        }
      }

      if ((index + 1) % 5 == 0 && !card.tags.contains('true_false')) {
        final snippet = card.answer.length > 72
            ? '${card.answer.substring(0, 72)}…'
            : card.answer;
        enriched.add(
          RevisionDeckCard(
            id: '${card.id}-tf-$index',
            knowledgeUnitId: card.knowledgeUnitId,
            cardType: RevisionDeckCardType.termDef,
            prompt: '${card.prompt} is defined as: "$snippet"',
            answer: 'True',
            explanation: card.explanation,
            difficulty: 'easy',
            tags: const ['true_false', 'flashcard'],
            gameItemIndex: card.gameItemIndex,
          ),
        );
      }
    }

    return enriched;
  }
}
