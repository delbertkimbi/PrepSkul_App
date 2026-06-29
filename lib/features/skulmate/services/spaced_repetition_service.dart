import 'dart:convert';

import 'package:prepskul/core/services/log_service.dart';
import 'package:prepskul/core/services/supabase_service.dart';

import '../utils/sm2_lite.dart';

/// A card/concept due for spaced repetition review.
class DueReviewItem {
  final String id;
  final String gameId;
  final int itemIndex;
  final String? conceptKey;
  final String? gameTitle;
  final String? termPreview;
  final DateTime nextReviewAt;

  const DueReviewItem({
    required this.id,
    required this.gameId,
    required this.itemIndex,
    this.conceptKey,
    this.gameTitle,
    this.termPreview,
    required this.nextReviewAt,
  });
}

/// Phase D4 — spaced repetition queue (SM-2 lite). Powers Next stop + Scroll feed.
class SpacedRepetitionService {
  SpacedRepetitionService._();

  /// Record a single item review outcome.
  static Future<void> recordReview({
    required String gameId,
    required int itemIndex,
    required int quality,
    String? conceptKey,
    String? childId,
  }) async {
    if (gameId.isEmpty || itemIndex < 0) return;

    try {
      final userId = SupabaseService.client.auth.currentUser?.id;
      if (userId == null) return;

      final existing = await _fetchRow(
        userId: userId,
        gameId: gameId,
        itemIndex: itemIndex,
        childId: childId,
      );

      final previous = existing == null
          ? null
          : ReviewState(
              easeFactor: (existing['ease_factor'] as num?)?.toDouble() ?? 2.5,
              intervalDays: (existing['interval_days'] as num?)?.toInt() ?? 0,
              repetitions: (existing['repetitions'] as num?)?.toInt() ?? 0,
            );

      final update = computeSm2Update(previous, quality);
      final now = DateTime.now().toUtc();

      final payload = {
        'user_id': userId,
        'child_id': childId,
        'game_id': gameId,
        'item_index': itemIndex,
        'concept_key': conceptKey,
        'ease_factor': update.easeFactor,
        'interval_days': update.intervalDays,
        'repetitions': update.repetitions,
        'next_review_at': update.nextReviewAt.toIso8601String(),
        'last_quality': update.lastQuality,
        'last_reviewed_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      };

      if (existing?['id'] != null) {
        await SupabaseService.client
            .from('skulmate_review_items')
            .update(payload)
            .eq('id', existing!['id'] as String);
      } else {
        await SupabaseService.client.from('skulmate_review_items').insert({
          ...payload,
          'created_at': now.toIso8601String(),
        });
      }
    } catch (e) {
      LogService.debug('SpacedRepetitionService.recordReview: $e');
    }
  }

  /// Batch from flashcard session answers map (index → knew?).
  static Future<void> recordFromFlashcardAnswers({
    required String gameId,
    required Map<String, dynamic> answers,
    required List<Map<String, dynamic>> gameItems,
    String? childId,
  }) async {
    for (final entry in answers.entries) {
      final index = int.tryParse(entry.key);
      if (index == null || index < 0 || index >= gameItems.length) continue;
      final known = entry.value == true;
      final term = gameItems[index]['term']?.toString();
      await recordReview(
        gameId: gameId,
        itemIndex: index,
        quality: qualityFromFlashcardKnown(known),
        conceptKey: conceptKeyFromTerm(term),
        childId: childId,
      );
    }
  }

  /// Batch from quiz breakdown list (order = item index).
  static Future<void> recordFromQuizBreakdown({
    required String gameId,
    required List<dynamic> breakdown,
    required List<Map<String, dynamic>> gameItems,
    String? childId,
  }) async {
    for (var i = 0; i < breakdown.length; i++) {
      final row = breakdown[i];
      if (row is! Map) continue;
      final isCorrect = row['isCorrect'] == true;
      final usedHint = row['usedHint'] == true;
      final term = i < gameItems.length
          ? gameItems[i]['term']?.toString() ??
              gameItems[i]['question']?.toString()
          : null;
      await recordReview(
        gameId: gameId,
        itemIndex: i,
        quality: qualityFromQuizAnswer(isCorrect: isCorrect, usedHint: usedHint),
        conceptKey: conceptKeyFromTerm(term),
        childId: childId,
      );
    }
  }

  /// Called after game session save — parses answers payload shape.
  static Future<void> recordFromGameSession({
    required String gameId,
    Map<String, dynamic>? answers,
    String? childId,
  }) async {
    if (gameId.isEmpty) return;

    try {
      final bundle = await _loadGameItems(gameId);
      if (bundle == null) return;

      final resolvedChildId = childId ?? bundle.childId;
      final itemMaps = bundle.items;

      if (answers == null || answers.isEmpty) {
        await _seedNewItems(
          gameId: gameId,
          itemCount: itemMaps.length,
          childId: resolvedChildId,
        );
        return;
      }

      if (answers.containsKey('breakdown')) {
        final breakdown = answers['breakdown'];
        if (breakdown is List) {
          await recordFromQuizBreakdown(
            gameId: gameId,
            breakdown: breakdown,
            gameItems: itemMaps,
            childId: resolvedChildId,
          );
        }
        return;
      }

      await recordFromFlashcardAnswers(
        gameId: gameId,
        answers: answers,
        gameItems: itemMaps,
        childId: resolvedChildId,
      );
    } catch (e) {
      LogService.debug('SpacedRepetitionService.recordFromGameSession: $e');
    }
  }

  /// Items due now, soonest first.
  static Future<List<DueReviewItem>> fetchDueQueue({
    int limit = 20,
    String? childId,
  }) async {
    if (!SupabaseService.isClientAvailable) return [];
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null) return [];

    try {
      final now = DateTime.now().toUtc().toIso8601String();
      var query = SupabaseService.client
          .from('skulmate_review_items')
          .select('id, game_id, item_index, concept_key, next_review_at')
          .eq('user_id', userId)
          .lte('next_review_at', now);

      if (childId != null) {
        query = query.eq('child_id', childId);
      } else {
        query = query.filter('child_id', 'is', null);
      }

      final rows = await query
          .order('next_review_at', ascending: true)
          .limit(limit);
      if (rows.isEmpty) return [];

      final gameIds = rows
          .map((r) => r['game_id']?.toString())
          .whereType<String>()
          .toSet()
          .toList();

      final titles = <String, String>{};
      final itemTerms = <String, String>{};

      if (gameIds.isNotEmpty) {
        final games = await SupabaseService.client
            .from('skulmate_games')
            .select('id, title, skulmate_game_data (game_content)')
            .inFilter('id', gameIds);
        for (final g in games) {
          final id = g['id']?.toString();
          if (id == null) continue;
          titles[id] = g['title']?.toString() ?? 'Revision game';
          final items = _itemsFromGameRow(Map<String, dynamic>.from(g));
          for (var i = 0; i < items.length; i++) {
            final term = items[i]['term']?.toString() ??
                items[i]['question']?.toString();
            if (term != null && term.isNotEmpty) {
              itemTerms['$id:$i'] = term;
            }
          }
        }
      }

      return rows.map((row) {
        final gameId = row['game_id']?.toString() ?? '';
        final itemIndex = (row['item_index'] as num?)?.toInt() ?? 0;
        return DueReviewItem(
          id: row['id']?.toString() ?? '',
          gameId: gameId,
          itemIndex: itemIndex,
          conceptKey: row['concept_key']?.toString(),
          gameTitle: titles[gameId],
          termPreview: itemTerms['$gameId:$itemIndex'],
          nextReviewAt: DateTime.tryParse(
                row['next_review_at']?.toString() ?? '',
              ) ??
              DateTime.now().toUtc(),
        );
      }).toList();
    } catch (e) {
      LogService.debug('SpacedRepetitionService.fetchDueQueue: $e');
      return [];
    }
  }

  /// Count of items due by end of local today (for badge / home).
  static Future<int> dueCountToday({String? childId}) async {
    if (!SupabaseService.isClientAvailable) return 0;
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null) return 0;

    try {
      final now = DateTime.now().toUtc().toIso8601String();
      var query = SupabaseService.client
          .from('skulmate_review_items')
          .select('id')
          .eq('user_id', userId)
          .lte('next_review_at', now);

      if (childId != null) {
        query = query.eq('child_id', childId);
      } else {
        query = query.filter('child_id', 'is', null);
      }

      final rows = await query;
      return rows.length;
    } catch (e) {
      LogService.debug('SpacedRepetitionService.dueCountToday: $e');
      return 0;
    }
  }

  static Future<Map<String, ({String term, String definition})>> loadTermDefinitions(
    List<String> gameIds,
  ) async {
    final out = <String, ({String term, String definition})>{};
    if (gameIds.isEmpty) return out;

    try {
      final games = await SupabaseService.client
          .from('skulmate_games')
          .select('id, skulmate_game_data (game_content)')
          .inFilter('id', gameIds);
      for (final g in games) {
        final id = g['id']?.toString();
        if (id == null) continue;
        final items = _itemsFromGameRow(Map<String, dynamic>.from(g));
        for (var i = 0; i < items.length; i++) {
          final item = items[i];
          final term =
              item['term']?.toString() ?? item['question']?.toString() ?? '';
          final definition = item['definition']?.toString() ??
              item['answer']?.toString() ??
              item['correctAnswer']?.toString() ??
              '';
          if (term.isEmpty) continue;
          out['$id:$i'] = (
            term: term,
            definition: definition.isEmpty ? term : definition,
          );
        }
      }
    } catch (e) {
      LogService.debug('SpacedRepetitionService.loadTermDefinitions: $e');
    }
    return out;
  }

  static Future<({String? childId, List<Map<String, dynamic>> items})?>
      _loadGameItems(String gameId) async {
    final gameRow = await SupabaseService.client
        .from('skulmate_games')
        .select('child_id, skulmate_game_data (game_content)')
        .eq('id', gameId)
        .maybeSingle();
    if (gameRow == null) return null;

    final items = _itemsFromGameRow(Map<String, dynamic>.from(gameRow));
    if (items.isEmpty) return null;

    return (
      childId: gameRow['child_id'] as String?,
      items: items,
    );
  }

  static List<Map<String, dynamic>> _itemsFromGameRow(
    Map<String, dynamic> gameRow,
  ) {
    final relation = gameRow['skulmate_game_data'];
    final dataRows = relation is List
        ? relation
        : relation is Map
            ? [relation]
            : const <dynamic>[];

    for (final row in dataRows) {
      if (row is! Map) continue;
      final content = _decodeIfJsonString(row['game_content']);
      if (content is List) {
        return content
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    }
    return const [];
  }

  static dynamic _decodeIfJsonString(dynamic value) {
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

  static Future<Map<String, dynamic>?> _fetchRow({
    required String userId,
    required String gameId,
    required int itemIndex,
    String? childId,
  }) async {
    var query = SupabaseService.client
        .from('skulmate_review_items')
        .select(
          'id, ease_factor, interval_days, repetitions, next_review_at',
        )
        .eq('user_id', userId)
        .eq('game_id', gameId)
        .eq('item_index', itemIndex);

    if (childId != null) {
      query = query.eq('child_id', childId);
    } else {
      query = query.filter('child_id', 'is', null);
    }

    return query.maybeSingle();
  }

  static Future<void> _seedNewItems({
    required String gameId,
    required int itemCount,
    String? childId,
  }) async {
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null) return;

    final now = DateTime.now().toUtc();
    for (var i = 0; i < itemCount; i++) {
      final existing = await _fetchRow(
        userId: userId,
        gameId: gameId,
        itemIndex: i,
        childId: childId,
      );
      if (existing != null) continue;

      await SupabaseService.client.from('skulmate_review_items').insert({
        'user_id': userId,
        'child_id': childId,
        'game_id': gameId,
        'item_index': i,
        'ease_factor': 2.5,
        'interval_days': 0,
        'repetitions': 0,
        'next_review_at': now.toIso8601String(),
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });
    }
  }
}
