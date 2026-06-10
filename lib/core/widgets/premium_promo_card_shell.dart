import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:prepskul/core/theme/app_theme.dart';

/// Wallet-style premium card background (mesh + shine + soft neumorphic lift).
class PremiumPromoCardShell extends StatelessWidget {
  final double height;
  final double radius;
  final Color accent;
  final EdgeInsets padding;
  final List<Color>? gradientColors;
  final Widget child;

  static const List<Color> defaultGradient = [
    Color(0xFF0C1528),
    Color(0xFF1B2C4F),
    Color(0xFF243B6B),
    Color(0xFF2E4A82),
  ];

  /// Warm gold gradient for wallet / credits cards.
  static const List<Color> walletGradient = [
    Color(0xFF1A1408),
    Color(0xFF2D2210),
    Color(0xFF3D3018),
    Color(0xFF4A3A1E),
  ];

  const PremiumPromoCardShell({
    super.key,
    required this.child,
    this.height = 172,
    this.radius = 20,
    this.accent = AppTheme.skyBlue,
    this.padding = const EdgeInsets.fromLTRB(14, 12, 14, 12),
    this.gradientColors,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryDark.withValues(alpha: 0.1),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.85),
            blurRadius: 6,
            offset: const Offset(-2, -2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: const Alignment(-1.1, -1.0),
                    end: const Alignment(1.2, 1.1),
                    colors: gradientColors ?? defaultGradient,
                    stops: const [0.0, 0.35, 0.7, 1.0],
                  ),
                ),
              ),
            ),
            Positioned(
              top: -36,
              right: -24,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      accent.withValues(alpha: 0.26),
                      accent.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
            Positioned.fill(child: CustomPaint(painter: _PremiumMeshPainter())),
            Positioned.fill(child: CustomPaint(painter: _PremiumShinePainter())),
            Padding(padding: padding, child: child),
          ],
        ),
      ),
    );
  }
}

class PremiumGlassButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final IconData? icon;

  const PremiumGlassButton({
    super.key,
    required this.label,
    this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            gradient: LinearGradient(
              colors: [
                Colors.white.withValues(alpha: 0.2),
                Colors.white.withValues(alpha: 0.07),
              ],
            ),
            border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 14, color: Colors.white.withValues(alpha: 0.92)),
                  const SizedBox(width: 5),
                ],
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 3),
                Icon(
                  Icons.arrow_forward_rounded,
                  size: 13,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PremiumMeshPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.04)
      ..strokeWidth = 0.8;
    const spacing = 14.0;
    for (var x = -size.height; x < size.width + size.height; x += spacing) {
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x + size.height * 0.55, 0),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _PremiumShinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final gradient = LinearGradient(
      begin: const Alignment(-0.8, -1.0),
      end: const Alignment(0.6, 1.2),
      colors: [
        Colors.white.withValues(alpha: 0.12),
        Colors.white.withValues(alpha: 0.02),
        Colors.transparent,
      ],
      transform: GradientRotation(math.pi / 5),
    );
    canvas.drawRect(rect, Paint()..shader = gradient.createShader(rect));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
