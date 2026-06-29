/// Multi-mode puzzle step types for puzzle_pieces games.
enum PuzzleStepType {
  pickOne,
  hotspotDrop,
  orderCheck;

  static PuzzleStepType fromString(String? raw) {
    switch ((raw ?? '').trim().toLowerCase()) {
      case 'hotspot_drop':
      case 'hotspot':
        return PuzzleStepType.hotspotDrop;
      case 'order_check':
      case 'order':
        return PuzzleStepType.orderCheck;
      case 'pick_one':
      case 'pick':
      default:
        return PuzzleStepType.pickOne;
    }
  }

  String get apiValue {
    switch (this) {
      case PuzzleStepType.pickOne:
        return 'pick_one';
      case PuzzleStepType.hotspotDrop:
        return 'hotspot_drop';
      case PuzzleStepType.orderCheck:
        return 'order_check';
    }
  }
}

class PuzzleStepChoice {
  final String id;
  final String text;
  final bool correct;

  const PuzzleStepChoice({
    required this.id,
    required this.text,
    required this.correct,
  });

  factory PuzzleStepChoice.fromMap(Map<String, dynamic> map) {
    return PuzzleStepChoice(
      id: (map['id'] ?? map['choiceId'] ?? '').toString(),
      text: (map['text'] ?? map['label'] ?? '').toString().trim(),
      correct: map['correct'] == true || map['isCorrect'] == true,
    );
  }
}

class PuzzleHotspot {
  final String id;
  final double x;
  final double y;
  final double w;
  final double h;
  final String? label;
  final String accepts;

  const PuzzleHotspot({
    required this.id,
    required this.x,
    required this.y,
    required this.w,
    required this.h,
    this.label,
    required this.accepts,
  });

  factory PuzzleHotspot.fromMap(Map<String, dynamic> map) {
    double norm(num? v) => (v?.toDouble() ?? 0).clamp(0.0, 1.0);
    final w = norm(map['w'] ?? map['width'] ?? 0.12);
    final h = norm(map['h'] ?? map['height'] ?? 0.1);
    return PuzzleHotspot(
      id: (map['id'] ?? '').toString(),
      x: norm(map['x']),
      y: norm(map['y']),
      w: w > 0 ? w : 0.12,
      h: h > 0 ? h : 0.1,
      label: (map['label'] as String?)?.trim(),
      accepts: (map['accepts'] ?? map['acceptsId'] ?? map['label'] ?? '')
          .toString()
          .trim(),
    );
  }
}

class PuzzleDragLabel {
  final String id;
  final String text;

  const PuzzleDragLabel({required this.id, required this.text});

  factory PuzzleDragLabel.fromMap(Map<String, dynamic> map) {
    return PuzzleDragLabel(
      id: (map['id'] ?? '').toString(),
      text: (map['text'] ?? map['label'] ?? '').toString().trim(),
    );
  }
}

class PuzzleStepDefinition {
  final String id;
  final PuzzleStepType type;
  final String prompt;
  final String? explanation;
  final List<PuzzleStepChoice> choices;
  final List<PuzzleHotspot> hotspots;
  final List<PuzzleDragLabel> dragLabels;
  final bool needsImage;
  final String? imagePrompt;
  final String? imageUrl;
  /// For order_check: ids in correct tap order.
  final List<String> orderSequence;

  const PuzzleStepDefinition({
    required this.id,
    required this.type,
    required this.prompt,
    this.explanation,
    this.choices = const [],
    this.hotspots = const [],
    this.dragLabels = const [],
    this.needsImage = false,
    this.imagePrompt,
    this.imageUrl,
    this.orderSequence = const [],
  });

  String get displayTitle {
    if (prompt.trim().isNotEmpty) {
      final p = prompt.trim();
      return p.length > 48 ? '${p.substring(0, 45)}…' : p;
    }
    return 'Step';
  }

  factory PuzzleStepDefinition.fromMap(Map<String, dynamic> map) {
    final choicesRaw = map['choices'] as List? ?? const [];
    final hotspotsRaw = map['hotspots'] as List? ?? const [];
    final labelsRaw =
        (map['dragLabels'] ?? map['drag_labels'] ?? const []) as List;
    final orderRaw =
        (map['orderSequence'] ?? map['order_sequence']) as List?;

    final choices = choicesRaw
        .whereType<Map>()
        .map((e) => PuzzleStepChoice.fromMap(e.cast<String, dynamic>()))
        .where((c) => c.text.isNotEmpty)
        .take(4)
        .toList();

    final orderSequence = orderRaw != null
        ? orderRaw.map((e) => e.toString()).toList()
        : choices.where((c) => c.correct).map((c) => c.id).toList();

    final hotspots = hotspotsRaw
        .whereType<Map>()
        .map((e) => PuzzleHotspot.fromMap(e.cast<String, dynamic>()))
        .toList();

    final dragLabels = labelsRaw
        .whereType<Map>()
        .map<PuzzleDragLabel>(
          (e) => PuzzleDragLabel.fromMap(e.cast<String, dynamic>()),
        )
        .toList();

    return PuzzleStepDefinition(
      id: (map['id'] ?? 'step').toString(),
      type: PuzzleStepType.fromString(map['type'] as String?),
      prompt: (map['prompt'] ?? map['question'] ?? '').toString().trim(),
      explanation: (map['explanation'] as String?)?.trim(),
      choices: choices,
      hotspots: hotspots,
      dragLabels: dragLabels,
      needsImage: map['needsImage'] == true || map['needs_image'] == true,
      imagePrompt: ((map['imagePrompt'] ?? map['image_prompt']) as String?)
          ?.trim(),
      imageUrl: ((map['imageUrl'] ?? map['image_url']) as String?)?.trim(),
      orderSequence: orderSequence,
    );
  }

  /// Convert legacy flat puzzlePieces into pick_one steps.
  static List<PuzzleStepDefinition> fromLegacyPieces(
    List<Map<String, dynamic>> pieces,
  ) {
    final sorted = List<Map<String, dynamic>>.from(pieces);
    sorted.sort((a, b) {
      final ao = (a['order'] as num?)?.toInt() ??
          (a['sequence'] as num?)?.toInt() ??
          (a['correctOrder'] as num?)?.toInt() ??
          0;
      final bo = (b['order'] as num?)?.toInt() ??
          (b['sequence'] as num?)?.toInt() ??
          (b['correctOrder'] as num?)?.toInt() ??
          0;
      return ao.compareTo(bo);
    });

    final steps = <PuzzleStepDefinition>[];
    for (var i = 0; i < sorted.length; i++) {
      final piece = sorted[i];
      final id = piece['id']?.toString() ?? 'piece_$i';
      final text = (piece['text'] as String? ?? 'Step ${i + 1}').trim();
      final distractors = sorted
          .where((p) => p['id']?.toString() != id)
          .map((p) => PuzzleStepChoice(
                id: p['id']?.toString() ?? '',
                text: (p['text'] as String? ?? '').trim(),
                correct: false,
              ))
          .where((c) => c.text.isNotEmpty)
          .take(3)
          .toList();

      final choices = [
        PuzzleStepChoice(id: id, text: text, correct: true),
        ...distractors,
      ]..shuffle();

      steps.add(
        PuzzleStepDefinition(
          id: id,
          type: PuzzleStepType.pickOne,
          prompt: i == 0
              ? 'What happens first in this process?'
              : 'What comes next?',
          choices: choices.take(4).toList(),
        ),
      );
    }
    return steps;
  }

  static List<PuzzleStepDefinition> parseFromGameItem({
    List<Map<String, dynamic>>? puzzleSteps,
    List<Map<String, dynamic>>? puzzlePieces,
    Map<String, dynamic>? gameData,
  }) {
    final rawSteps = puzzleSteps ??
        (gameData?['puzzleSteps'] as List?)
            ?.whereType<Map>()
            .map((e) => e.cast<String, dynamic>())
            .toList() ??
        (gameData?['puzzle_steps'] as List?)
            ?.whereType<Map>()
            .map((e) => e.cast<String, dynamic>())
            .toList();

    if (rawSteps != null && rawSteps.isNotEmpty) {
      return rawSteps
          .map(PuzzleStepDefinition.fromMap)
          .where(
            (s) =>
                s.prompt.isNotEmpty ||
                s.choices.isNotEmpty ||
                s.hotspots.isNotEmpty ||
                s.orderSequence.isNotEmpty,
          )
          .toList();
    }

    if (puzzlePieces != null && puzzlePieces.isNotEmpty) {
      return fromLegacyPieces(puzzlePieces);
    }
    return [];
  }
}
