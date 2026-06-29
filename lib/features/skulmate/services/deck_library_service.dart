import 'package:flutter/material.dart';
import 'package:prepskul/core/services/log_service.dart';
import 'package:prepskul/core/services/supabase_service.dart';
import 'package:prepskul/core/theme/app_theme.dart';

import '../models/deck_library_entry.dart';
import '../models/game_model.dart';
import '../models/revision_deck_model.dart';
import 'revision_deck_service.dart';
import 'skulmate_home_refresh_bus.dart';
import 'skulmate_service.dart';

/// Lists study decks (notes + cards) — separate from playable games.
class DeckLibraryService {
  DeckLibraryService._();

  /// Public tab shows coming-soon until discovery API ships.
  static const publicDecksEnabled = true;

  static const _accentPalette = <Color>[
    AppTheme.skyBlue,
    AppTheme.accentGreen,
    Color(0xFF14B8A6),
    AppTheme.accentPurple,
    AppTheme.accentOrange,
    AppTheme.accentPink,
    AppTheme.primaryLight,
  ];

  static Color accentForTitle(String title) {
    var hash = 0;
    for (final unit in title.codeUnits) {
      hash = (hash * 31 + unit) & 0x7fffffff;
    }
    return _accentPalette[hash % _accentPalette.length];
  }

  static Future<List<DeckLibraryEntry>> listDecks({
    String? childId,
    List<GameModel>? games,
  }) async {
    final resolvedGames =
        games ?? await SkulMateService.getGames(childId: childId);

    final entries = <DeckLibraryEntry>[];
    for (final game in resolvedGames) {
      final isSaved = await RevisionDeckService.isLibrarySavedForGame(game.id);
      final deck = await RevisionDeckService.resolveForGame(game);
      final hasContent =
          deck.cards.isNotEmpty || deck.notes.trim().isNotEmpty;
      if (!isSaved && !hasContent) continue;

      entries.add(
        DeckLibraryEntry(
          gameId: game.id,
          title: deck.title.isNotEmpty ? deck.title : game.title,
          topicLabel: deck.topicLabel,
          cardCount: deck.cards.isNotEmpty
              ? deck.cards.length
              : RevisionDeckService.cardCountForGame(game),
          accentColor: deck.accentColorArgb != null
              ? Color(deck.accentColorArgb!)
              : accentForTitle(deck.title),
          deck: deck,
          updatedAt: game.updatedAt,
        ),
      );
    }

    entries.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return entries;
  }

  static Future<List<DeckLibraryEntry>> listPublicDecks({
    String? subject,
    int limit = 40,
  }) async {
    // Future: query skulmate_games where generation_context.revisionDeck.isPublic
    return const [];
  }

  /// Creates an empty deck saved to the learner library (Gizmo-style).
  static Future<DeckLibraryEntry?> createManualDeck({
    required String title,
    required Color accentColor,
    String? childId,
  }) async {
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null) return null;

    final trimmed = title.trim().isEmpty ? 'Untitled' : title.trim();
    final accentArgb = accentColor.toARGB32();
    final deckJson = <String, dynamic>{
      'title': trimmed,
      'topicLabel': trimmed,
      'sourceType': 'manual',
      'notes': '',
      'knowledgeUnits': <dynamic>[],
      'cards': <dynamic>[],
      'conceptCheckCardIds': <dynamic>[],
      'gameType': 'flashcards',
      'librarySaved': true,
      'accentColor': accentArgb,
    };

    try {
      final row = await SupabaseService.client
          .from('skulmate_games')
          .insert({
            'user_id': userId,
            if (childId != null) 'child_id': childId,
            'title': trimmed,
            'game_type': 'flashcards',
            'generation_context': {'revisionDeck': deckJson},
            'is_deleted': false,
          })
          .select('id, created_at, updated_at')
          .single();

      final gameId = row['id'] as String;
      final createdAt = DateTime.parse(row['created_at'] as String);
      final deck = RevisionDeckModel(
        id: gameId,
        title: trimmed,
        topicLabel: trimmed,
        sourceType: 'manual',
        notes: '',
        knowledgeUnits: const [],
        cards: const [],
        conceptCheckCardIds: const [],
        linkedGameId: gameId,
        gameType: 'flashcards',
        librarySaved: true,
        accentColorArgb: accentArgb,
      );
      RevisionDeckService.cacheDeck(deck);
      SkulMateHomeRefreshBus.notify();

      return DeckLibraryEntry(
        gameId: gameId,
        title: trimmed,
        topicLabel: trimmed,
        cardCount: 0,
        accentColor: accentColor,
        deck: deck,
        updatedAt: createdAt,
      );
    } catch (e) {
      LogService.warning('[DeckLibrary] createManualDeck failed: $e');
      return null;
    }
  }
}
