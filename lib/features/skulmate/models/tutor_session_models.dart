class TutorSessionSummary {
  final String id;
  final String? title;
  final DateTime lastTurnAt;
  final String? preview;
  final String? accountRole;

  TutorSessionSummary({
    required this.id,
    this.title,
    required this.lastTurnAt,
    this.preview,
    this.accountRole,
  });

  factory TutorSessionSummary.fromJson(Map<String, dynamic> json) {
    return TutorSessionSummary(
      id: json['id'] as String,
      title: json['title'] as String?,
      lastTurnAt: DateTime.parse(
        json['lastTurnAt'] as String? ??
            json['last_turn_at'] as String? ??
            DateTime.now().toIso8601String(),
      ),
      preview: json['preview'] as String?,
      accountRole: json['accountRole'] as String? ??
          json['account_role'] as String?,
    );
  }
}

class TutorTurn {
  final String? id;
  final bool isUser;
  final String text;
  final PracticeSurface? surface;
  final TutorBoard? board;
  final bool speak;
  final bool escalate;
  final String? move;

  const TutorTurn({
    this.id,
    required this.isUser,
    required this.text,
    this.surface,
    this.board,
    this.speak = false,
    this.escalate = false,
    this.move,
  });
}

class TutorBoardStep {
  final String kind;
  final String text;

  const TutorBoardStep({required this.kind, required this.text});

  factory TutorBoardStep.fromJson(Map<String, dynamic> json) {
    return TutorBoardStep(
      kind: (json['kind'] as String?) ?? 'note',
      text: (json['text'] as String?) ?? '',
    );
  }

  Map<String, dynamic> toJson() => {'kind': kind, 'text': text};
}

class TutorBoard {
  final String title;
  final List<TutorBoardStep> steps;

  const TutorBoard({required this.title, required this.steps});

  factory TutorBoard.fromJson(Map<String, dynamic> json) {
    return TutorBoard(
      title: (json['title'] as String?) ?? 'Board',
      steps: (json['steps'] as List<dynamic>? ?? [])
          .whereType<Map>()
          .map((e) => TutorBoardStep.fromJson(Map<String, dynamic>.from(e)))
          .where((s) => s.text.trim().isNotEmpty)
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'title': title,
        'steps': steps.map((s) => s.toJson()).toList(),
      };
}

class PracticeSurface {
  final String gameType;
  final String title;
  final String? conceptId;
  final List<Map<String, dynamic>> items;

  const PracticeSurface({
    required this.gameType,
    required this.title,
    this.conceptId,
    required this.items,
  });

  factory PracticeSurface.fromJson(Map<String, dynamic> json) {
    return PracticeSurface(
      gameType: (json['gameType'] ?? json['game_type'] ?? 'quiz') as String,
      title: (json['title'] as String?) ?? 'Check',
      conceptId: json['conceptId'] as String?,
      items: (json['items'] as List<dynamic>? ?? [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'gameType': gameType,
        'title': title,
        'conceptId': conceptId,
        'items': items,
      };
}

PracticeSurface? practiceSurfaceFromPayload(dynamic raw) {
  if (raw is! Map) return null;
  final map = Map<String, dynamic>.from(raw);
  final nested = map['surface'];
  final candidate = nested is Map ? Map<String, dynamic>.from(nested) : map;
  if (candidate['gameType'] == null &&
      candidate['game_type'] == null &&
      candidate['items'] == null) {
    return null;
  }
  try {
    return PracticeSurface.fromJson(candidate);
  } catch (_) {
    return null;
  }
}

TutorBoard? tutorBoardFromPayload(dynamic raw, {dynamic boardField}) {
  if (boardField is Map) {
    return TutorBoard.fromJson(Map<String, dynamic>.from(boardField));
  }
  if (raw is! Map) return null;
  final map = Map<String, dynamic>.from(raw);
  if (map['board'] is Map) {
    return TutorBoard.fromJson(Map<String, dynamic>.from(map['board'] as Map));
  }
  if (map['steps'] is List) {
    return TutorBoard.fromJson(map);
  }
  return null;
}

class TutorTurnResult {
  final String sessionId;
  final String turnId;
  final String message;
  final String move;
  final bool speak;
  final PracticeSurface? surface;
  final TutorBoard? board;
  final bool escalate;
  final String? model;
  final bool demo;

  const TutorTurnResult({
    required this.sessionId,
    required this.turnId,
    required this.message,
    required this.move,
    required this.speak,
    this.surface,
    this.board,
    this.escalate = false,
    this.model,
    this.demo = false,
  });

  factory TutorTurnResult.fromJson(Map<String, dynamic> json) {
    final payload = json['tool_payload'] is Map
        ? Map<String, dynamic>.from(json['tool_payload'] as Map)
        : <String, dynamic>{};
    final surfaceRaw = json['surface'] is Map
        ? json['surface']
        : payload['surface'];
    final boardRaw = json['board'] is Map ? json['board'] : payload['board'];
    return TutorTurnResult(
      sessionId: json['sessionId'] as String? ?? '',
      turnId: json['turnId'] as String? ?? '',
      message: json['message'] as String? ?? '',
      move: json['move'] as String? ?? 'focus',
      speak: json['speak'] as bool? ?? true,
      surface: surfaceRaw is Map
          ? PracticeSurface.fromJson(Map<String, dynamic>.from(surfaceRaw))
          : null,
      board: boardRaw is Map
          ? TutorBoard.fromJson(Map<String, dynamic>.from(boardRaw))
          : null,
      escalate: json['escalate'] as bool? ?? false,
      model: json['model'] as String?,
      demo: json['demo'] as bool? ?? false,
    );
  }
}
