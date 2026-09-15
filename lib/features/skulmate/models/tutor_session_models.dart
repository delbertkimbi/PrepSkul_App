class TutorSessionSummary {
  final String id;
  final String? title;
  final DateTime lastTurnAt;

  TutorSessionSummary({
    required this.id,
    this.title,
    required this.lastTurnAt,
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
    );
  }
}

class TutorTurn {
  final String? id;
  final bool isUser;
  final String text;
  final PracticeSurface? surface;
  final bool speak;
  final bool escalate;
  final String? move;

  const TutorTurn({
    this.id,
    required this.isUser,
    required this.text,
    this.surface,
    this.speak = false,
    this.escalate = false,
    this.move,
  });
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

class TutorTurnResult {
  final String sessionId;
  final String turnId;
  final String message;
  final String move;
  final bool speak;
  final PracticeSurface? surface;
  final bool escalate;

  const TutorTurnResult({
    required this.sessionId,
    required this.turnId,
    required this.message,
    required this.move,
    required this.speak,
    this.surface,
    this.escalate = false,
  });

  factory TutorTurnResult.fromJson(Map<String, dynamic> json) {
    return TutorTurnResult(
      sessionId: json['sessionId'] as String? ?? '',
      turnId: json['turnId'] as String? ?? '',
      message: json['message'] as String? ?? '',
      move: json['move'] as String? ?? 'teach',
      speak: json['speak'] as bool? ?? true,
      surface: json['surface'] is Map
          ? PracticeSurface.fromJson(
              Map<String, dynamic>.from(json['surface'] as Map),
            )
          : null,
      escalate: json['escalate'] as bool? ?? false,
    );
  }
}
