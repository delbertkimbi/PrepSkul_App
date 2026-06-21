/// A single step in a SkulMate lesson path (Phase D1).
class LessonPlanStep {
  final String type;
  final String title;
  final String? body;
  final List<String> bullets;
  final String? gameType;
  final String status;

  const LessonPlanStep({
    required this.type,
    required this.title,
    this.body,
    this.bullets = const [],
    this.gameType,
    this.status = 'pending',
  });

  bool get isCompleted => status == 'completed' || status == 'skipped';
  bool get isInteractive => type == 'drill' || type == 'quiz';
  bool get isContentOnly =>
      type == 'overview' || type == 'concepts' || type == 'recap';

  LessonPlanStep copyWith({String? status}) {
    return LessonPlanStep(
      type: type,
      title: title,
      body: body,
      bullets: bullets,
      gameType: gameType,
      status: status ?? this.status,
    );
  }

  factory LessonPlanStep.fromJson(Map<String, dynamic> json) {
    final rawBullets = json['bullets'];
    return LessonPlanStep(
      type: json['type']?.toString() ?? 'overview',
      title: json['title']?.toString() ?? 'Step',
      body: json['body']?.toString(),
      bullets: rawBullets is List
          ? rawBullets.map((e) => e.toString()).toList()
          : const [],
      gameType: json['gameType']?.toString(),
      status: json['status']?.toString() ?? 'pending',
    );
  }

  Map<String, dynamic> toJson() => {
        'type': type,
        'title': title,
        if (body != null) 'body': body,
        if (bullets.isNotEmpty) 'bullets': bullets,
        if (gameType != null) 'gameType': gameType,
        'status': status,
      };
}

/// Persisted lesson path from skulmate_lessons.
class LessonPlan {
  final String id;
  final String topic;
  final List<LessonPlanStep> steps;
  final int currentStep;
  final String? sourceGameId;
  final String? childId;

  const LessonPlan({
    required this.id,
    required this.topic,
    required this.steps,
    this.currentStep = 0,
    this.sourceGameId,
    this.childId,
  });

  LessonPlanStep? get activeStep {
    if (steps.isEmpty || currentStep < 0 || currentStep >= steps.length) {
      return null;
    }
    return steps[currentStep];
  }

  bool get isComplete =>
      steps.isNotEmpty && steps.every((s) => s.isCompleted);

  LessonPlan copyWith({
    List<LessonPlanStep>? steps,
    int? currentStep,
  }) {
    return LessonPlan(
      id: id,
      topic: topic,
      steps: steps ?? this.steps,
      currentStep: currentStep ?? this.currentStep,
      sourceGameId: sourceGameId,
      childId: childId,
    );
  }

  factory LessonPlan.fromJson(Map<String, dynamic> json) {
    final rawSteps = json['steps'];
    final steps = rawSteps is List
        ? rawSteps
            .whereType<Map>()
            .map((e) => LessonPlanStep.fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : <LessonPlanStep>[];

    return LessonPlan(
      id: json['id']?.toString() ?? '',
      topic: json['topic']?.toString() ?? 'Lesson',
      steps: steps,
      currentStep: (json['current_step'] as num?)?.toInt() ?? 0,
      sourceGameId: json['source_game_id']?.toString(),
      childId: json['child_id']?.toString(),
    );
  }
}
