import 'package:flutter_test/flutter_test.dart';
import 'package:prepskul/features/sessions/domain/gallery_grid_layout.dart';

void main() {
  group('GalleryGridLayout.compute', () {
    test('single tile uses one column and 16:9 aspect', () {
      final plan = GalleryGridLayout.compute(
        innerWidth: 400,
        innerHeight: 600,
        tileCount: 1,
      );

      expect(plan.crossAxisCount, 1);
      expect(plan.childAspectRatio, closeTo(16 / 9, 1e-9));
      expect(plan.rows, 1);
    });

    test('wide short viewport prefers more columns when it improves tile size fit', () {
      final plan = GalleryGridLayout.compute(
        innerWidth: 900,
        innerHeight: 280,
        tileCount: 4,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      );

      expect(plan.crossAxisCount, greaterThanOrEqualTo(2));
      expect(plan.rows, lessThanOrEqualTo(2));
      expect(plan.childAspectRatio, closeTo(16 / 9, 1e-9));
    });

    test('narrow inner width caps columns via minimum tile width', () {
      final plan = GalleryGridLayout.compute(
        innerWidth: 150,
        innerHeight: 600,
        tileCount: 4,
        minTileWidth: 88,
      );

      expect(plan.crossAxisCount, 1);
      expect(plan.rows, greaterThanOrEqualTo(4));
    });

    test('many tiles falls back to minimizing overflow when none fit unscoped height', () {
      final plan = GalleryGridLayout.compute(
        innerWidth: 360,
        innerHeight: 200,
        tileCount: 12,
        maxColumnsCap: 6,
      );

      expect(plan.crossAxisCount, greaterThanOrEqualTo(1));
      expect(plan.rows * plan.crossAxisCount, greaterThanOrEqualTo(12));
    });

    test('clamps tileCount below 1 to one logical tile', () {
      final plan = GalleryGridLayout.compute(
        innerWidth: 200,
        innerHeight: 200,
        tileCount: 0,
      );

      expect(plan.rows, 1);
    });
  });
}
