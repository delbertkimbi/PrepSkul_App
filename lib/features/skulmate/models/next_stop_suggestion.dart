/// Home "Next stop" suggestion (Maps — What's next?).
enum NextStopKind { dueReview, weakTopic, continueGame, fromSession }

class NextStopSuggestion {
  final NextStopKind kind;
  final String gameId;
  final String title;
  final String? subtitle;
  final String? topicId;
  final String? sessionId;
  final String? sessionSummary;
  final String? tutorName;
  final int? progressPercent;
  final int? currentIndex;
  final int? totalItems;

  const NextStopSuggestion({
    required this.kind,
    required this.gameId,
    required this.title,
    this.subtitle,
    this.topicId,
    this.sessionId,
    this.sessionSummary,
    this.tutorName,
    this.progressPercent,
    this.currentIndex,
    this.totalItems,
  });
}
