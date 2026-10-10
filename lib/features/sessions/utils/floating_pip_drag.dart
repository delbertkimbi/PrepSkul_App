import 'dart:ui' show Offset;

/// Drag math for the global live-session PiP (bottom/right anchored).
class FloatingPipDrag {
  /// Finger delta in screen space → offset used with
  /// `right: pad - dx` and `bottom: anchor - dy`.
  static Offset applyPanDelta(Offset current, Offset delta) => current + delta;

  static Offset clamp({
    required Offset offset,
    required double maxUp,
    required double maxLeft,
    double maxRight = 0,
    double maxDown = 0,
  }) {
    return Offset(
      offset.dx.clamp(-maxLeft, maxRight),
      offset.dy.clamp(-maxUp, maxDown),
    );
  }
}
