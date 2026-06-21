/// Gentle resurfacing suggestion — internal topic id only; UI uses game title.
class RerouteSuggestion {
  final String topicId;
  final String gameId;
  final String gameTitle;

  const RerouteSuggestion({
    required this.topicId,
    required this.gameId,
    required this.gameTitle,
  });
}
