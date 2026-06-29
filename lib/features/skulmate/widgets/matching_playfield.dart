import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';

/// Flutter-native Match It board with match/wrong animations.
class MatchingPlayfield extends StatefulWidget {
  final List<int> leftPairIds;
  final List<int> rightPairIds;
  final String Function(int pairId) leftLabel;
  final String Function(int pairId) rightLabel;
  final Set<int> matchedPairIds;
  final int? activeLeftPairId;
  final int? flashWrongRightId;
  final int? celebratePairId;
  final String? connectedLabel;
  final void Function(int pairId) onLeftTap;
  final void Function(int pairId) onRightTap;

  static const rowHeight = 58.0;
  static const rowGap = 6.0;

  const MatchingPlayfield({
    super.key,
    required this.leftPairIds,
    required this.rightPairIds,
    required this.leftLabel,
    required this.rightLabel,
    required this.matchedPairIds,
    required this.activeLeftPairId,
    this.flashWrongRightId,
    this.celebratePairId,
    this.connectedLabel,
    required this.onLeftTap,
    required this.onRightTap,
  });

  @override
  State<MatchingPlayfield> createState() => _MatchingPlayfieldState();
}

class _MatchingPlayfieldState extends State<MatchingPlayfield>
    with TickerProviderStateMixin {
  late AnimationController _shakeController;
  late AnimationController _celebrateController;
  late AnimationController _lineController;
  int? _lastCelebrateId;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _celebrateController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 720),
    );
    _lineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
  }

  @override
  void didUpdateWidget(covariant MatchingPlayfield oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.flashWrongRightId != null &&
        widget.flashWrongRightId != oldWidget.flashWrongRightId) {
      _shakeController.forward(from: 0);
    }
    if (widget.celebratePairId != null &&
        widget.celebratePairId != _lastCelebrateId) {
      _lastCelebrateId = widget.celebratePairId;
      _celebrateController.forward(from: 0);
      _lineController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _shakeController.dispose();
    _celebrateController.dispose();
    _lineController.dispose();
    super.dispose();
  }

  double _stackHeight(int count) {
    if (count <= 0) return 100;
    return count * MatchingPlayfield.rowHeight +
        (count - 1) * MatchingPlayfield.rowGap;
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.leftPairIds.length;
    final height = _stackHeight(count);

    return SizedBox(
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          AnimatedBuilder(
            animation: _lineController,
            builder: (context, _) {
              return CustomPaint(
                size: Size.infinite,
                painter: _ConnectionPainter(
                  matchedPairIds: widget.matchedPairIds,
                  leftPairIds: widget.leftPairIds,
                  rightPairIds: widget.rightPairIds,
                  rowHeight: MatchingPlayfield.rowHeight,
                  rowGap: MatchingPlayfield.rowGap,
                  drawProgress: _lineController.value,
                  highlightPairId: widget.celebratePairId,
                ),
              );
            },
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  children: [
                    for (var i = 0; i < count; i++)
                      _TermCard(
                        label: widget.leftLabel(widget.leftPairIds[i]),
                        pairId: widget.leftPairIds[i],
                        isLast: i == count - 1,
                        selected:
                            widget.activeLeftPairId == widget.leftPairIds[i],
                        matched: widget.matchedPairIds
                            .contains(widget.leftPairIds[i]),
                        celebrating:
                            widget.celebratePairId == widget.leftPairIds[i],
                        celebrateScale: _celebrateController,
                        onTap: () => widget.onLeftTap(widget.leftPairIds[i]),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  children: [
                    for (var i = 0; i < widget.rightPairIds.length; i++)
                      _DefinitionCard(
                        label: widget.rightLabel(widget.rightPairIds[i]),
                        pairId: widget.rightPairIds[i],
                        isLast: i == widget.rightPairIds.length - 1,
                        matched: widget.matchedPairIds
                            .contains(widget.rightPairIds[i]),
                        flashWrong: widget.flashWrongRightId ==
                            widget.rightPairIds[i],
                        shakeController: _shakeController,
                        celebrating:
                            widget.celebratePairId == widget.rightPairIds[i],
                        celebrateScale: _celebrateController,
                        enabled: widget.activeLeftPairId != null &&
                            !widget.matchedPairIds
                                .contains(widget.rightPairIds[i]),
                        onTap: () => widget.onRightTap(widget.rightPairIds[i]),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (widget.celebratePairId != null &&
              widget.connectedLabel != null &&
              widget.connectedLabel!.isNotEmpty)
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _celebrateController,
                  builder: (context, _) {
                    final t = _celebrateController.value;
                    final opacity = (t < 0.45 ? t / 0.45 : (1 - t) / 0.55)
                        .clamp(0.0, 1.0);
                    return Opacity(
                      opacity: opacity,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.accentGreen,
                            borderRadius: BorderRadius.circular(999),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.accentGreen.withValues(alpha: 0.35),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.link_rounded,
                                size: 16,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                widget.connectedLabel!,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TermCard extends StatelessWidget {
  final String label;
  final int pairId;
  final bool isLast;
  final bool selected;
  final bool matched;
  final bool celebrating;
  final AnimationController celebrateScale;
  final VoidCallback onTap;

  const _TermCard({
    required this.label,
    required this.pairId,
    required this.isLast,
    required this.selected,
    required this.matched,
    required this.celebrating,
    required this.celebrateScale,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: isLast ? 0 : MatchingPlayfield.rowGap,
      ),
      child: AnimatedBuilder(
        animation: celebrateScale,
        builder: (context, child) {
          final scale = celebrating
              ? 1.0 + (math.sin(celebrateScale.value * math.pi) * 0.05)
              : 1.0;
          return Transform.scale(scale: scale, child: child);
        },
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: matched ? null : onTap,
            borderRadius: BorderRadius.circular(14),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              height: MatchingPlayfield.rowHeight,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: matched
                    ? AppTheme.accentLightGreen
                    : selected
                        ? AppTheme.skyBlueLight
                        : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: matched
                      ? AppTheme.accentGreen.withValues(alpha: 0.55)
                      : selected
                          ? AppTheme.skyBlue
                          : AppTheme.softBorder,
                  width: selected || matched ? 1.5 : 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: matched ? 18 : 7,
                    height: matched ? 18 : 7,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: matched
                          ? AppTheme.accentGreen
                          : AppTheme.primaryColor.withValues(alpha: 0.35),
                    ),
                    child: matched
                        ? const Icon(Icons.check, size: 11, color: Colors.white)
                        : null,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      label,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textDark,
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DefinitionCard extends StatelessWidget {
  final String label;
  final int pairId;
  final bool isLast;
  final bool matched;
  final bool flashWrong;
  final bool celebrating;
  final bool enabled;
  final AnimationController shakeController;
  final AnimationController celebrateScale;
  final VoidCallback onTap;

  const _DefinitionCard({
    required this.label,
    required this.pairId,
    required this.isLast,
    required this.matched,
    required this.flashWrong,
    required this.celebrating,
    required this.enabled,
    required this.shakeController,
    required this.celebrateScale,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: isLast ? 0 : MatchingPlayfield.rowGap,
      ),
      child: AnimatedBuilder(
        animation: Listenable.merge([shakeController, celebrateScale]),
        builder: (context, child) {
          final shake = flashWrong
              ? math.sin(shakeController.value * math.pi * 6) * 6
              : 0.0;
          final scale = celebrating
              ? 1.0 + (math.sin(celebrateScale.value * math.pi) * 0.05)
              : 1.0;
          return Transform.translate(
            offset: Offset(shake, 0),
            child: Transform.scale(scale: scale, child: child),
          );
        },
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: enabled ? onTap : null,
            borderRadius: BorderRadius.circular(14),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              height: MatchingPlayfield.rowHeight,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: flashWrong
                    ? AppTheme.gameNudgeBg
                    : matched
                        ? AppTheme.accentLightGreen
                        : const Color(0xFFF8FFFA),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: flashWrong
                      ? AppTheme.gameNudgeBorder
                      : matched
                          ? AppTheme.accentGreen.withValues(alpha: 0.55)
                          : AppTheme.softBorder,
                  width: matched || flashWrong ? 1.5 : 1,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textDark,
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: matched ? 18 : 7,
                    height: matched ? 18 : 7,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: matched
                          ? AppTheme.accentGreen
                          : AppTheme.primaryColor.withValues(alpha: 0.2),
                    ),
                    child: matched
                        ? const Icon(Icons.check, size: 11, color: Colors.white)
                        : null,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ConnectionPainter extends CustomPainter {
  final Set<int> matchedPairIds;
  final List<int> leftPairIds;
  final List<int> rightPairIds;
  final double rowHeight;
  final double rowGap;
  final double drawProgress;
  final int? highlightPairId;

  _ConnectionPainter({
    required this.matchedPairIds,
    required this.leftPairIds,
    required this.rightPairIds,
    required this.rowHeight,
    required this.rowGap,
    required this.drawProgress,
    this.highlightPairId,
  });

  double _rowCenterY(int index) =>
      index * (rowHeight + rowGap) + rowHeight / 2;

  @override
  void paint(Canvas canvas, Size size) {
    final midX = size.width / 2;

    for (final pairId in matchedPairIds) {
      final leftIndex = leftPairIds.indexOf(pairId);
      final rightIndex = rightPairIds.indexOf(pairId);
      if (leftIndex < 0 || rightIndex < 0) continue;

      final leftY = _rowCenterY(leftIndex);
      final rightY = _rowCenterY(rightIndex);
      final leftX = size.width * 0.47;
      final rightX = size.width * 0.53;

      final path = Path()
        ..moveTo(leftX, leftY)
        ..cubicTo(midX, leftY, midX, rightY, rightX, rightY);

      final isHighlight = pairId == highlightPairId;
      final progress = isHighlight ? drawProgress.clamp(0.0, 1.0) : 1.0;

      final paint = Paint()
        ..color = AppTheme.accentGreen.withValues(
          alpha: isHighlight ? 0.9 : 0.65,
        )
        ..strokeWidth = isHighlight ? 2.5 : 2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      _drawDashedPath(canvas, path, paint, progress);
    }
  }

  void _drawDashedPath(
    Canvas canvas,
    Path path,
    Paint paint,
    double progress,
  ) {
    const dash = 5.0;
    const gap = 4.0;
    for (final metric in path.computeMetrics()) {
      final total = metric.length * progress;
      var distance = 0.0;
      while (distance < total) {
        final next = distance + dash;
        canvas.drawPath(
          metric.extractPath(distance, next.clamp(0, total)),
          paint,
        );
        distance = next + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ConnectionPainter oldDelegate) {
    return oldDelegate.matchedPairIds != matchedPairIds ||
        oldDelegate.leftPairIds != leftPairIds ||
        oldDelegate.rightPairIds != rightPairIds ||
        oldDelegate.drawProgress != drawProgress ||
        oldDelegate.highlightPairId != highlightPairId;
  }
}
