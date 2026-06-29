import 'revision_deck_model.dart';

/// One immersive slide in the vertical scroll feed.
enum ScrollSlideKind {
  hook,
  reveal,
  listen,
  mcq,
  match,
  celebrate,
}

class ScrollSlide {
  final ScrollSlideKind kind;
  final String gameId;
  final int itemIndex;
  final String? reviewRowId;
  final String? gameTitle;
  final String? cardId;

  /// POV / trend hook line (hook slides).
  final String? hookLine;

  /// Front face — term or question.
  final String prompt;

  /// Back face — definition or answer.
  final String answer;

  final String? explanation;
  final List<String> options;
  final String? matchLeft;
  final String? matchRight;
  final String? emoji;
  final String? celebrateTitle;
  final String? celebrateBody;
  final int? milestoneIndex;

  const ScrollSlide({
    required this.kind,
    required this.gameId,
    required this.itemIndex,
    this.reviewRowId,
    this.gameTitle,
    this.cardId,
    this.hookLine,
    required this.prompt,
    required this.answer,
    this.explanation,
    this.options = const [],
    this.matchLeft,
    this.matchRight,
    this.emoji,
    this.celebrateTitle,
    this.celebrateBody,
    this.milestoneIndex,
  });

  /// Legacy flat card — reveal slide with term/definition.
  factory ScrollSlide.reveal({
    required String gameId,
    required int itemIndex,
    required String term,
    required String definition,
    String? reviewRowId,
    String? gameTitle,
    String? cardId,
    String? explanation,
    String? emoji,
  }) {
    return ScrollSlide(
      kind: ScrollSlideKind.reveal,
      gameId: gameId,
      itemIndex: itemIndex,
      reviewRowId: reviewRowId,
      gameTitle: gameTitle,
      cardId: cardId,
      prompt: term,
      answer: definition,
      explanation: explanation,
      emoji: emoji,
    );
  }

  factory ScrollSlide.fromDeckCard({
    required RevisionDeckCard card,
    required String gameId,
    required int itemIndex,
    String? reviewRowId,
    String? gameTitle,
  }) {
    final emoji = _emojiForCard(card);
    switch (card.cardType) {
      case RevisionDeckCardType.mcq:
        if (card.mcqOptions.length >= 2) {
          return ScrollSlide(
            kind: ScrollSlideKind.mcq,
            gameId: gameId,
            itemIndex: itemIndex,
            reviewRowId: reviewRowId,
            gameTitle: gameTitle,
            cardId: card.id,
            prompt: card.prompt,
            answer: card.answer,
            explanation: card.explanation,
            options: card.mcqOptions,
            emoji: emoji,
          );
        }
        break;
      case RevisionDeckCardType.pair:
        return ScrollSlide(
          kind: ScrollSlideKind.match,
          gameId: gameId,
          itemIndex: itemIndex,
          reviewRowId: reviewRowId,
          gameTitle: gameTitle,
          cardId: card.id,
          prompt: card.prompt,
          answer: card.answer,
          matchLeft: card.prompt,
          matchRight: card.answer,
          emoji: emoji,
        );
      default:
        break;
    }
    return ScrollSlide.reveal(
      gameId: gameId,
      itemIndex: itemIndex,
      term: card.prompt,
      definition: card.answer,
      reviewRowId: reviewRowId,
      gameTitle: gameTitle,
      cardId: card.id,
      explanation: card.explanation,
      emoji: emoji,
    );
  }

  static String? _emojiForCard(RevisionDeckCard card) {
    final tags = card.tags.map((t) => t.toLowerCase()).toList();
    if (tags.contains('true_false')) return '✅';
    if (card.cardType == RevisionDeckCardType.mcq) return '🧠';
    if (card.cardType == RevisionDeckCardType.pair) return '🔗';
    if (card.cardType == RevisionDeckCardType.cloze) return '✏️';
    if (card.cardType == RevisionDeckCardType.order) return '📋';
    return '💡';
  }

  String get term => prompt;
  String get definition => answer;

  bool get isInteractive =>
      kind == ScrollSlideKind.mcq || kind == ScrollSlideKind.match;

  bool get needsRecallButtons =>
      kind == ScrollSlideKind.reveal ||
      kind == ScrollSlideKind.listen ||
      kind == ScrollSlideKind.hook;
}
