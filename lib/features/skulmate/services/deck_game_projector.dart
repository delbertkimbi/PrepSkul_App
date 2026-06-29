import 'dart:math';

import '../models/game_model.dart';
import '../models/revision_deck_model.dart';
import '../widgets/deck_study_launcher_sheet.dart';

/// Projects revision deck cards into a playable [GameModel] for a study mode.
class DeckGameProjector {
  static final Random _random = Random();

  static GameModel project({
    required GameModel game,
    required RevisionDeckModel deck,
    required DeckStudyMode studyMode,
  }) {
    final targetType = _gameTypeForStudyMode(studyMode);
    if (targetType == null) return game;

    final items = _projectItems(deck, targetType);
    if (items.isEmpty) return game;

    return GameModel(
      id: game.id,
      userId: game.userId,
      childId: game.childId,
      title: game.title,
      gameType: targetType,
      documentUrl: game.documentUrl,
      sourceType: game.sourceType,
      sourceFileName: game.sourceFileName,
      sourceTextSnapshot: game.sourceTextSnapshot,
      createdAt: game.createdAt,
      updatedAt: game.updatedAt,
      isDeleted: game.isDeleted,
      items: items,
      metadata: GameMetadata(
        source: game.metadata.source,
        generatedAt: game.metadata.generatedAt,
        difficulty: game.metadata.difficulty,
        totalItems: items.length,
        topic: game.metadata.topic ?? deck.topicLabel,
      ),
    );
  }

  static GameType? _gameTypeForStudyMode(DeckStudyMode mode) {
    switch (mode) {
      case DeckStudyMode.scroll:
        return null;
      case DeckStudyMode.memorise:
        return GameType.flashcards;
      case DeckStudyMode.quiz:
        return GameType.quiz;
      case DeckStudyMode.matching:
        return GameType.matching;
      case DeckStudyMode.fillBlank:
        return GameType.fillBlank;
    }
  }

  static List<GameItem> _projectItems(
    RevisionDeckModel deck,
    GameType targetType,
  ) {
    final items = <GameItem>[];
    for (final card in deck.cards) {
      final item = switch (targetType) {
        GameType.quiz => _toQuizItem(card, deck.cards),
        GameType.flashcards => _toFlashcardItem(card),
        GameType.matching => _toMatchingItem(card),
        GameType.fillBlank => _toFillBlankItem(card),
        _ => _toQuizItem(card, deck.cards) ?? _toFlashcardItem(card),
      };
      if (item != null) items.add(item);
    }
    return items;
  }

  static GameItem? _toQuizItem(
    RevisionDeckCard card,
    List<RevisionDeckCard> allCards,
  ) {
    final question = card.cardType == RevisionDeckCardType.termDef
        ? 'What is the definition of "${card.prompt}"?'
        : card.prompt;
    if (question.isEmpty || card.answer.isEmpty) return null;

    final options = _uniqueStrings([
      card.answer,
      ...card.distractors,
      ..._distractorsForCard(card, allCards),
    ]);
    if (options.length < 2) return null;

    final correctIndex = options.indexWhere(
      (option) => option.toLowerCase() == card.answer.toLowerCase(),
    );

    return GameItem(
      question: question,
      options: options.take(4).toList(),
      correctAnswer: correctIndex >= 0 ? correctIndex : 0,
      explanation: card.explanation,
    );
  }

  static GameItem? _toFlashcardItem(RevisionDeckCard card) {
    if (card.answer.isEmpty) return null;
    switch (card.cardType) {
      case RevisionDeckCardType.pair:
      case RevisionDeckCardType.termDef:
      case RevisionDeckCardType.mcq:
        return GameItem(
          term: card.prompt,
          definition: card.answer,
        );
      case RevisionDeckCardType.cloze:
        return GameItem(
          term: 'Complete the sentence',
          definition: card.answer,
        );
      default:
        if (card.prompt.isEmpty || card.answer.isEmpty) return null;
        return GameItem(
          term: card.prompt,
          definition: card.answer,
        );
    }
  }

  static GameItem? _toMatchingItem(RevisionDeckCard card) {
    if (card.prompt.isEmpty || card.answer.isEmpty) return null;
    switch (card.cardType) {
      case RevisionDeckCardType.pair:
      case RevisionDeckCardType.termDef:
      case RevisionDeckCardType.mcq:
        return GameItem(
          leftItem: card.prompt,
          rightItem: card.answer,
        );
      default:
        return null;
    }
  }

  static GameItem? _toFillBlankItem(RevisionDeckCard card) {
    if (card.answer.isEmpty) return null;
    switch (card.cardType) {
      case RevisionDeckCardType.cloze:
        return GameItem(
          blankText: card.prompt,
          correctAnswer: card.answer,
        );
      case RevisionDeckCardType.mcq:
      case RevisionDeckCardType.termDef:
        final blank = card.prompt.contains('____')
            ? card.prompt
            : '${card.prompt}: ____';
        return GameItem(
          blankText: blank,
          correctAnswer: card.answer,
        );
      default:
        return null;
    }
  }

  static List<String> _distractorsForCard(
    RevisionDeckCard card,
    List<RevisionDeckCard> allCards, {
    int count = 3,
  }) {
    final pool = allCards
        .where((other) => other.id != card.id)
        .map((other) => other.answer)
        .where((answer) => answer.toLowerCase() != card.answer.toLowerCase());
    return _uniqueStrings(pool).take(count).toList();
  }

  static List<String> _uniqueStrings(Iterable<String> values) {
    final seen = <String>{};
    final out = <String>[];
    for (final value in values) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) continue;
      final key = trimmed.toLowerCase();
      if (seen.contains(key)) continue;
      seen.add(key);
      out.add(trimmed);
    }
    out.shuffle(_random);
    return out;
  }
}

class DeckAppendResult {
  final RevisionDeckModel deck;
  final GameModel game;
  final int addedCount;

  const DeckAppendResult({
    required this.deck,
    required this.game,
    required this.addedCount,
  });
}
