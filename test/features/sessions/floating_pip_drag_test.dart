import 'package:flutter_test/flutter_test.dart';
import 'package:prepskul/features/sessions/utils/floating_pip_drag.dart';

void main() {
  group('FloatingPipDrag', () {
    test('dragging up makes dy negative so bottom-anchored PiP moves up', () {
      const start = Offset.zero;
      // Finger moves up → negative dy.
      final next = FloatingPipDrag.applyPanDelta(start, const Offset(0, -20));
      expect(next.dy, -20);
      // bottom: anchor - dy → dy negative → larger bottom → widget higher.
    });

    test('dragging right increases dx so right-anchored PiP moves right', () {
      const start = Offset.zero;
      final next = FloatingPipDrag.applyPanDelta(start, const Offset(12, 0));
      expect(next.dx, 12);
    });

    test('clamp keeps the tile on screen', () {
      final clamped = FloatingPipDrag.clamp(
        offset: const Offset(-500, -40),
        maxUp: 100,
        maxLeft: 200,
      );
      expect(clamped.dx, -200);
      expect(clamped.dy, -40);
    });
  });
}
