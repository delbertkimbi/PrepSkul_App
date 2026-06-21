/// One card in the vertical scroll revision feed.
class ScrollFeedItem {
  final String gameId;
  final int itemIndex;
  final String term;
  final String definition;
  final String? reviewRowId;
  final String? gameTitle;

  const ScrollFeedItem({
    required this.gameId,
    required this.itemIndex,
    required this.term,
    required this.definition,
    this.reviewRowId,
    this.gameTitle,
  });
}
