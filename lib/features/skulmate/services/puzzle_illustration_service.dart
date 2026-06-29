import 'dart:async';

import 'package:prepskul/core/services/log_service.dart';

import '../models/game_model.dart';
import '../models/puzzle_step_model.dart';
import 'skulmate_service.dart';

/// Ensures puzzle hero diagrams exist — server may omit imageUrl on production.
class PuzzleIllustrationService {
  PuzzleIllustrationService._();

  /// Build a rich diagram prompt from game content when the API omits imagePrompt.
  static String buildHeroPrompt(GameModel game) {
    if (game.items.isEmpty) {
      return 'Educational diagram illustrating ${game.title}';
    }
    final item = game.items.first;
    final existing = item.imagePrompt?.trim();
    if (existing != null && existing.isNotEmpty) return existing;

    final steps = PuzzleStepDefinition.parseFromGameItem(
      puzzleSteps: item.puzzleSteps,
      puzzlePieces: item.puzzlePieces,
      gameData: item.gameData,
    );

    final snippets = <String>[];
    for (final step in steps.take(5)) {
      if (step.prompt.isNotEmpty) snippets.add(step.prompt);
      for (final c in step.choices.where((c) => c.correct).take(1)) {
        if (c.text.isNotEmpty) snippets.add(c.text);
      }
    }

    if (snippets.isEmpty && item.puzzlePieces != null) {
      for (final p in item.puzzlePieces!.take(5)) {
        final t = (p['text'] as String?)?.trim();
        if (t != null && t.isNotEmpty) snippets.add(t);
      }
    }

    final topic = game.title.trim().isNotEmpty ? game.title.trim() : 'the topic';
    if (snippets.isEmpty) {
      return 'Educational process diagram for $topic with clear flow arrows and icons';
    }
    return 'Educational diagram for $topic: ${snippets.take(4).join(', ')}';
  }

  static String? existingHeroUrl(GameModel game) {
    if (game.items.isEmpty) return null;
    final url = game.items.first.imageUrl?.trim();
    return url != null && url.isNotEmpty ? url : null;
  }

  /// Fetch hero illustration when missing; returns URL or null.
  static Future<String?> ensureHeroImageUrl(GameModel game) async {
    final existing = existingHeroUrl(game);
    if (existing != null) return existing;

    final prompt = buildHeroPrompt(game);
    LogService.info('🧩 [Puzzle] Generating vault diagram for "${game.title}"');

    final url = await SkulMateService.fetchIllustration(
      gameId: game.id.isNotEmpty ? game.id : null,
      prompt: prompt,
      topic: game.title,
    );

    if (url != null && url.isNotEmpty) {
      LogService.success('🧩 [Puzzle] Vault diagram ready');
      if (game.id.isNotEmpty) {
        unawaited(
          SkulMateService.persistPuzzleHeroImage(
            gameId: game.id,
            imageUrl: url,
            imagePrompt: prompt,
          ),
        );
      }
    } else {
      LogService.warning('🧩 [Puzzle] Vault diagram generation returned no URL');
    }
    return url;
  }

  static GameModel gameWithHeroImage(GameModel game, String imageUrl) {
    if (game.items.isEmpty) return game;
    final first = game.items.first;
    final updatedFirst = GameItem(
      question: first.question,
      term: first.term,
      definition: first.definition,
      options: first.options,
      correctAnswer: first.correctAnswer,
      explanation: first.explanation,
      leftItem: first.leftItem,
      rightItem: first.rightItem,
      blankText: first.blankText,
      imageUrl: imageUrl,
      imagePrompt: first.imagePrompt ?? buildHeroPrompt(game),
      needsImage: true,
      gridData: first.gridData,
      dragItems: first.dragItems,
      dropZones: first.dropZones,
      puzzlePieces: first.puzzlePieces,
      puzzleSteps: first.puzzleSteps,
      diagramLabels: first.diagramLabels,
      words: first.words,
      clues: first.clues,
      bubbles: first.bubbles,
      gameData: first.gameData,
      scenarios: first.scenarios,
      role: first.role,
      caseName: first.caseName,
      mysteryClues: first.mysteryClues,
      solution: first.solution,
      rooms: first.rooms,
      isBoss: first.isBoss,
    );
    return GameModel(
      id: game.id,
      userId: game.userId,
      childId: game.childId,
      title: game.title,
      gameType: game.gameType,
      documentUrl: game.documentUrl,
      sourceType: game.sourceType,
      sourceFileName: game.sourceFileName,
      sourceTextSnapshot: game.sourceTextSnapshot,
      createdAt: game.createdAt,
      updatedAt: game.updatedAt,
      isDeleted: game.isDeleted,
      items: [updatedFirst, ...game.items.skip(1)],
      metadata: game.metadata,
    );
  }
}
