/// Catalog kinds for SkulMate adaptive surfaces (genui-compatible vocabulary).
///
/// When [genui] ^0.9.2 is added (requires Flutter >=3.35.7, Dart >=3.10),
/// map each kind to a [CatalogItem] and stream A2UI messages from the LLM.
enum SkulMateCatalogKind {
  flashcard,
  scrollCard,
  quizQuestion,
  matchingPair,
  puzzlePrompt,
  notesBlock,
}

/// One renderable adaptive surface with bound data paths.
class SkulMateAdaptiveSurfaceSpec {
  final String surfaceId;
  final SkulMateCatalogKind kind;
  final Map<String, Object?> initialData;

  const SkulMateAdaptiveSurfaceSpec({
    required this.surfaceId,
    required this.kind,
    required this.initialData,
  });
}
