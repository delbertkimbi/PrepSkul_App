import 'package:flutter_test/flutter_test.dart';

/// Mirrors chunking rule in [AgoraVideoSessionScreen] for regression safety.
List<List<int>> chunkGalleryTiles(List<int> tiles, int pageSize) {
  if (tiles.isEmpty) return <List<int>>[];
  final pages = <List<int>>[];
  for (var i = 0; i < tiles.length; i += pageSize) {
    final end = i + pageSize > tiles.length ? tiles.length : i + pageSize;
    pages.add(tiles.sublist(i, end));
  }
  return pages;
}

void main() {
  test('chunks 13 tiles into 12 + 1 for paging layout', () {
    final tiles = List<int>.generate(13, (i) => i + 1);
    final pages = chunkGalleryTiles(tiles, 12);
    expect(pages.length, 2);
    expect(pages[0].length, 12);
    expect(pages[1].length, 1);
  });

  test('empty tiles yields empty page list', () {
    expect(chunkGalleryTiles([], 12), isEmpty);
  });
}
