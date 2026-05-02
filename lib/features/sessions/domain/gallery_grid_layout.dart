/// Picks gallery column count and child [childAspectRatio] for a video grid.
///
/// PrepSkul classroom gallery: aim for ~16:9 tiles (widescreen camera) and pick
/// columns so tiles stay as large as possible while preferring layouts that fit
/// the viewport before vertical scroll.
class GalleryGridLayout {
  const GalleryGridLayout({
    required this.crossAxisCount,
    required this.childAspectRatio,
    required this.rows,
    required this.cellWidth,
    required this.cellHeight,
  });

  /// Flutter [SliverGridDelegateWithFixedCrossAxisCount] — width / height.
  static const double targetVideoAspectWidthOverHeight = 16 / 9;

  final int crossAxisCount;
  final double childAspectRatio;
  final int rows;
  final double cellWidth;
  final double cellHeight;

  /// [innerWidth]/[innerHeight] are after grid padding (usable area inside the scroll view).
  static GalleryGridLayout compute({
    required double innerWidth,
    required double innerHeight,
    required int tileCount,
    double crossAxisSpacing = 10,
    double mainAxisSpacing = 10,
    double targetAspect = targetVideoAspectWidthOverHeight,
    int maxColumnsCap = 10,
    double minTileWidth = 88,
  }) {
    final n = tileCount < 1 ? 1 : tileCount;
    final w =
        innerWidth.isFinite && innerWidth > 0 ? innerWidth : 320.0;
    final h =
        innerHeight.isFinite && innerHeight > 0 ? innerHeight : 480.0;

    final rawMaxCols =
        ((w + crossAxisSpacing) / (minTileWidth + crossAxisSpacing)).floor();
    final maxC = rawMaxCols < 1
        ? 1
        : (rawMaxCols > maxColumnsCap ? maxColumnsCap : rawMaxCols);

    GalleryGridLayout? bestFit;
    GalleryGridLayout? bestOverflow;
    var bestOverflowExcess = double.infinity;

    for (var c = 1; c <= maxC; c++) {
      final rows = (n + c - 1) ~/ c;
      final cellW = (w - (c - 1) * crossAxisSpacing) / c;
      if (cellW <= 0) {
        continue;
      }
      final cellH = cellW / targetAspect;
      final totalMain = rows * cellH + (rows - 1) * mainAxisSpacing;
      final plan = GalleryGridLayout(
        crossAxisCount: c,
        childAspectRatio: targetAspect,
        rows: rows,
        cellWidth: cellW,
        cellHeight: cellH,
      );

      if (totalMain <= h + 0.5) {
        if (bestFit == null || cellW > bestFit.cellWidth + 1e-6) {
          bestFit = plan;
        }
      } else {
        final excess = totalMain - h;
        if (bestOverflow == null ||
            excess < bestOverflowExcess - 1e-6 ||
            ((excess - bestOverflowExcess).abs() < 1e-6 &&
                cellW > bestOverflow.cellWidth + 1e-6)) {
          bestOverflow = plan;
          bestOverflowExcess = excess;
        }
      }
    }

    if (bestFit != null) {
      return bestFit;
    }
    if (bestOverflow != null) {
      return bestOverflow;
    }

    final cellW = w;
    final cellH = cellW / targetAspect;
    return GalleryGridLayout(
      crossAxisCount: 1,
      childAspectRatio: targetAspect,
      rows: n,
      cellWidth: cellW,
      cellHeight: cellH,
    );
  }
}
