import 'package:flutter/material.dart';

import 'revision_deck_model.dart';

/// Lightweight row for the deck picker — not a playable game.
class DeckLibraryEntry {
  final String gameId;
  final String title;
  final String topicLabel;
  final int cardCount;
  final Color accentColor;
  final RevisionDeckModel deck;
  final DateTime updatedAt;

  const DeckLibraryEntry({
    required this.gameId,
    required this.title,
    required this.topicLabel,
    required this.cardCount,
    required this.accentColor,
    required this.deck,
    required this.updatedAt,
  });
}
