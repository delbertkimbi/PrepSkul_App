import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:prepskul/core/config/app_config.dart';
import 'package:prepskul/core/services/log_service.dart';
import 'package:prepskul/core/services/supabase_service.dart';

import '../models/game_model.dart';
import '../models/revision_deck_model.dart';
import 'revision_deck_builder.dart';
import 'skulmate_home_refresh_bus.dart';

/// Resolves revision decks from API storage or local game content.
class RevisionDeckService {
  static final Map<String, RevisionDeckModel> _memoryCache = {};

  static void cacheDeck(RevisionDeckModel deck) {
    final key = deck.linkedGameId ?? deck.id;
    if (key == null || key.isEmpty) return;
    _memoryCache[key] = deck;
  }

  static RevisionDeckModel? cachedDeckForGame(String gameId) => _memoryCache[gameId];

  /// Persist a learner-chosen deck title after generation.
  static Future<RevisionDeckModel> renameDeck({
    required String gameId,
    required String title,
    required RevisionDeckModel deck,
  }) async {
    final renamed = RevisionDeckModel(
      id: gameId,
      title: title,
      topicLabel: title,
      sourceType: deck.sourceType,
      notes: deck.notes,
      knowledgeUnits: deck.knowledgeUnits,
      cards: deck.cards,
      conceptCheckCardIds: deck.conceptCheckCardIds,
      linkedGameId: gameId,
      gameType: deck.gameType,
      librarySaved: true,
    );
    _memoryCache[gameId] = renamed;

    try {
      final row = await SupabaseService.client
          .from('skulmate_games')
          .select('generation_context')
          .eq('id', gameId)
          .maybeSingle();
      if (row != null) {
        final context = _asMap(row['generation_context']) ?? {};
        final deckRaw = _asMap(context['revisionDeck']) ?? {};
        deckRaw['title'] = title;
        deckRaw['topicLabel'] = title;
        deckRaw['librarySaved'] = true;
        context['revisionDeck'] = deckRaw;
        await SupabaseService.client
            .from('skulmate_games')
            .update({'generation_context': context, 'title': title})
            .eq('id', gameId);
      }
    } catch (e) {
      LogService.warning('[RevisionDeck] rename failed for $gameId: $e');
    }

    SkulMateHomeRefreshBus.notify();
    return renamed;
  }

  /// Only decks the learner explicitly saved appear in My decks.
  static Future<bool> isLibrarySavedForGame(String gameId) async {
    if (gameId.isEmpty) return false;

    try {
      final row = await SupabaseService.client
          .from('skulmate_games')
          .select('generation_context')
          .eq('id', gameId)
          .maybeSingle();
      if (row != null) {
        final context = _asMap(row['generation_context']);
        final deckRaw = _asMap(context?['revisionDeck']);
        if (deckRaw?['librarySaved'] == true) return true;
      }
    } catch (e) {
      LogService.debug('[RevisionDeck] librarySaved check failed: $e');
    }

    final cached = _memoryCache[gameId];
    return cached?.librarySaved ?? false;
  }

  /// Prefer cached deck card count; fall back to game item count.
  static int cardCountForGame(GameModel game) {
    final cached = _memoryCache[game.id];
    if (cached != null && cached.cards.isNotEmpty) {
      return cached.cards.length;
    }
    return game.items.length;
  }

  static Future<RevisionDeckModel> resolveForGame(GameModel game) async {
    final cached = _memoryCache[game.id];
    if (cached != null && cached.cards.isNotEmpty) return cached;

    final fromDb = await _fetchFromGenerationContext(game.id);
    if (fromDb != null && fromDb.cards.isNotEmpty) {
      _memoryCache[game.id] = fromDb;
      return fromDb;
    }

    final built = RevisionDeckBuilder.fromGame(game);
    _memoryCache[game.id] = built;
    return built;
  }

  /// Pull latest deck from API when hub opens (non-blocking).
  static Future<RevisionDeckModel?> refreshFromApi(String gameId) async {
    if (gameId.isEmpty) return null;

    final token =
        SupabaseService.client.auth.currentSession?.accessToken;
    if (token == null || token.isEmpty) return null;

    final url =
        '${AppConfig.skulMateHttpApiBase}/skulmate/deck?gameId=$gameId';
    try {
      final response = await http
          .get(
            Uri.parse(url),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode >= 400) return null;

      final decoded = jsonDecode(response.body) as Map<String, dynamic>?;
      final deckRaw = decoded?['deck'];
      if (deckRaw is! Map) return null;

      final deck = RevisionDeckModel.fromJson(
        Map<String, dynamic>.from(deckRaw),
      );
      final linked = RevisionDeckModel(
        id: gameId,
        title: deck.title,
        topicLabel: deck.topicLabel,
        sourceType: deck.sourceType,
        notes: deck.notes,
        knowledgeUnits: deck.knowledgeUnits,
        cards: deck.cards,
        conceptCheckCardIds: deck.conceptCheckCardIds,
        linkedGameId: gameId,
        gameType: deck.gameType,
        librarySaved: deck.librarySaved,
      );
      if (linked.cards.isEmpty) return null;
      _memoryCache[gameId] = linked;
      return linked;
    } catch (e) {
      LogService.warning('[RevisionDeck] API refresh failed for $gameId: $e');
      return null;
    }
  }

  static Future<RevisionDeckModel?> _fetchFromGenerationContext(String gameId) async {
    try {
      final row = await SupabaseService.client
          .from('skulmate_games')
          .select('id, generation_context')
          .eq('id', gameId)
          .maybeSingle();

      if (row == null) return null;

      final context = _asMap(row['generation_context']);
      final deckRaw = context?['revisionDeck'];
      if (deckRaw is! Map) return null;

      final deck = RevisionDeckModel.fromJson(
        Map<String, dynamic>.from(deckRaw),
      );
      return RevisionDeckModel(
        id: gameId,
        title: deck.title,
        topicLabel: deck.topicLabel,
        sourceType: deck.sourceType,
        notes: deck.notes,
        knowledgeUnits: deck.knowledgeUnits,
        cards: deck.cards,
        conceptCheckCardIds: deck.conceptCheckCardIds,
        linkedGameId: gameId,
        gameType: deck.gameType,
        librarySaved: deck.librarySaved,
      );
    } catch (e) {
      LogService.warning('[RevisionDeck] Could not load deck for $gameId: $e');
      return null;
    }
  }

  static Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return value.cast<String, dynamic>();
    if (value is String) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is Map) return decoded.cast<String, dynamic>();
      } catch (_) {}
    }
    return null;
  }
}
