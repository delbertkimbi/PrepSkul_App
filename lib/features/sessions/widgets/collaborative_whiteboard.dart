import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:prepskul/features/sessions/domain/workspace_sync_state.dart';

/// Tutor-drawn vector strokes; learners see the same [strokes] list from realtime state.
class CollaborativeWhiteboard extends StatefulWidget {
  const CollaborativeWhiteboard({
    super.key,
    required this.strokes,
    required this.readOnly,
    this.onPublish,
  });

  final List<WhiteboardStroke> strokes;
  final bool readOnly;
  final Future<void> Function(WorkspacePacket packet)? onPublish;

  @override
  State<CollaborativeWhiteboard> createState() => _CollaborativeWhiteboardState();
}

class _CollaborativeWhiteboardState extends State<CollaborativeWhiteboard> {
  List<double>? _livePoints;
  int _strokeColorArgb = 0xFF7DD3FC;
  double _strokeWidthNorm = 0.0045;

  static const List<int> _paletteArgb = <int>[
    0xFF111827,
    0xFFE53935,
    0xFF43A047,
    0xFF7DD3FC,
  ];

  static const List<double> _widthNormPresets = <double>[
    0.003,
    0.0045,
    0.008,
  ];

  static const double _minSegSq = 0.000004;

  void _addNormPoint(List<double> buf, double nx, double ny) {
    final x = nx.clamp(0.0, 1.0);
    final y = ny.clamp(0.0, 1.0);
    if (buf.length >= 2) {
      final ox = buf[buf.length - 2];
      final oy = buf[buf.length - 1];
      final dx = x - ox;
      final dy = y - oy;
      if (dx * dx + dy * dy < _minSegSq) return;
    }
    buf.add(x);
    buf.add(y);
    if (buf.length > kWorkspaceMaxPointsPerStroke) {
      buf.removeRange(0, buf.length - kWorkspaceMaxPointsPerStroke);
    }
  }

  Future<void> _commitStroke(List<double> pts) async {
    if (widget.readOnly || widget.onPublish == null) return;
    if (pts.length < 4) return;
    final stroke = WhiteboardStroke(
      id: 'wb-${DateTime.now().microsecondsSinceEpoch}',
      points: List<double>.unmodifiable(pts),
      colorArgb: _strokeColorArgb,
      widthNorm: _strokeWidthNorm,
    );
    await widget.onPublish!(StrokePathPacket(stroke: stroke));
  }

  Future<void> _undoLastStroke() async {
    if (widget.readOnly || widget.onPublish == null) return;
    await widget.onPublish!(const UndoLastStrokePacket());
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final hint = widget.readOnly
            ? 'View only — board follows your tutor.'
            : 'Draw here — learners see strokes in real time.';
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Text(
                hint,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.white54,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (!widget.readOnly) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 10,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      'Color',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: Colors.white54,
                      ),
                    ),
                    for (final c in _paletteArgb)
                      GestureDetector(
                        onTap: () => setState(() => _strokeColorArgb = c),
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: Color(c),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _strokeColorArgb == c
                                  ? Colors.white
                                  : Colors.white24,
                              width: _strokeColorArgb == c ? 2 : 1,
                            ),
                          ),
                        ),
                      ),
                    Text(
                      'Width',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: Colors.white54,
                      ),
                    ),
                    for (final w in _widthNormPresets)
                      ChoiceChip(
                        label: Text(
                          w == _widthNormPresets.first
                              ? 'S'
                              : w == _widthNormPresets[1]
                                  ? 'M'
                                  : 'L',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        selected: _strokeWidthNorm == w,
                        onSelected: (_) =>
                            setState(() => _strokeWidthNorm = w),
                      ),
                    IconButton(
                      tooltip: 'Undo last stroke',
                      onPressed: _undoLastStroke,
                      icon: const Icon(Icons.undo_rounded),
                      color: Colors.white70,
                    ),
                  ],
                ),
              ),
            ],
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: RepaintBoundary(
                      child: Builder(
                        builder: (hitCtx) {
                          if (widget.readOnly) {
                            return CustomPaint(
                              painter: _WhiteboardPainter(
                                strokes: widget.strokes,
                                livePoints: null,
                                liveColorArgb: 0xFF7DD3FC,
                                liveWidthNorm: 0.0045,
                              ),
                              child: const SizedBox.expand(),
                            );
                          }
                          return GestureDetector(
                            onPanStart: (d) {
                              final box =
                                  hitCtx.findRenderObject() as RenderBox?;
                              if (box == null) return;
                              final local = box.globalToLocal(d.globalPosition);
                              final w = box.size.width;
                              final h = box.size.height;
                              if (w <= 0 || h <= 0) return;
                              setState(() {
                                _livePoints = <double>[
                                  (local.dx / w).clamp(0.0, 1.0),
                                  (local.dy / h).clamp(0.0, 1.0),
                                ];
                              });
                            },
                            onPanUpdate: (d) {
                              if (_livePoints == null) return;
                              final box =
                                  hitCtx.findRenderObject() as RenderBox?;
                              if (box == null) return;
                              final local = box.globalToLocal(d.globalPosition);
                              final w = box.size.width;
                              final h = box.size.height;
                              if (w <= 0 || h <= 0) return;
                              setState(() {
                                _addNormPoint(
                                  _livePoints!,
                                  local.dx / w,
                                  local.dy / h,
                                );
                              });
                            },
                            onPanEnd: (_) async {
                              final pts = _livePoints;
                              setState(() => _livePoints = null);
                              if (pts != null) await _commitStroke(pts);
                            },
                            onPanCancel: () =>
                                setState(() => _livePoints = null),
                            child: CustomPaint(
                              painter: _WhiteboardPainter(
                                strokes: widget.strokes,
                                livePoints: _livePoints,
                                liveColorArgb: _strokeColorArgb,
                                liveWidthNorm: _strokeWidthNorm,
                              ),
                              child: const SizedBox.expand(),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _WhiteboardPainter extends CustomPainter {
  _WhiteboardPainter({
    required this.strokes,
    required this.livePoints,
    required this.liveColorArgb,
    required this.liveWidthNorm,
  });

  final List<WhiteboardStroke> strokes;
  final List<double>? livePoints;
  final int liveColorArgb;
  final double liveWidthNorm;

  @override
  void paint(Canvas canvas, Size size) {
    void paintStroke(WhiteboardStroke s) {
      final pts = s.points;
      if (pts.length < 4) return;
      final paint = Paint()
        ..color = Color(s.colorArgb)
        ..strokeWidth = (s.widthNorm * (size.shortestSide)).clamp(1.2, 14.0)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..isAntiAlias = true;
      final path = Path();
      path.moveTo(pts[0] * size.width, pts[1] * size.height);
      for (var i = 2; i < pts.length; i += 2) {
        path.lineTo(pts[i] * size.width, pts[i + 1] * size.height);
      }
      canvas.drawPath(path, paint);
    }

    for (final s in strokes) {
      paintStroke(s);
    }

    if (livePoints != null && livePoints!.length >= 4) {
      paintStroke(
        WhiteboardStroke(
          id: '_live',
          points: livePoints!,
          colorArgb: liveColorArgb,
          widthNorm: liveWidthNorm,
        ),
      );
    } else if (livePoints != null && livePoints!.length == 2) {
      final r =
          (liveWidthNorm * size.shortestSide).clamp(1.2, 14.0) * 0.55;
      final dot = Paint()
        ..color = Color(liveColorArgb)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(
        Offset(livePoints![0] * size.width, livePoints![1] * size.height),
        r,
        dot,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WhiteboardPainter oldDelegate) {
    if (!listEquals(oldDelegate.livePoints, livePoints)) return true;
    if (oldDelegate.liveColorArgb != liveColorArgb ||
        oldDelegate.liveWidthNorm != liveWidthNorm) {
      return true;
    }
    if (oldDelegate.strokes.length != strokes.length) return true;
    for (var i = 0; i < strokes.length; i++) {
      final a = strokes[i];
      final b = oldDelegate.strokes[i];
      if (a.id != b.id ||
          a.points.length != b.points.length ||
          a.colorArgb != b.colorArgb ||
          a.widthNorm != b.widthNorm) {
        return true;
      }
    }
    return false;
  }
}
