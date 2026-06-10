import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/core/utils/responsive_helper.dart';

/// Premium wallet card — rich gradient, mesh pattern, glass accents.
class PrepSkulWalletCard extends StatelessWidget {
  final double activeBalance;
  final double pendingBalance;
  final VoidCallback onViewEarnings;

  const PrepSkulWalletCard({
    super.key,
    required this.activeBalance,
    required this.pendingBalance,
    required this.onViewEarnings,
  });

  @override
  Widget build(BuildContext context) {
    final total = activeBalance + pendingBalance;
    final isMobile = ResponsiveHelper.isMobile(context);
    final pad = isMobile ? 16.0 : 18.0;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryDark.withValues(alpha: 0.12),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            // Base gradient
            Positioned.fill(
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment(-1.1, -1.0),
                    end: Alignment(1.2, 1.1),
                    colors: [
                      Color(0xFF0C1528),
                      Color(0xFF1B2C4F),
                      Color(0xFF243B6B),
                      Color(0xFF2E4A82),
                    ],
                    stops: [0.0, 0.35, 0.7, 1.0],
                  ),
                ),
              ),
            ),
            // Sky accent wash (top-right)
            Positioned(
              top: -40,
              right: -30,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppTheme.skyBlue.withValues(alpha: 0.28),
                      AppTheme.skyBlue.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
            // Warm gold glint (bottom-left)
            Positioned(
              bottom: -50,
              left: -20,
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppTheme.softYellow.withValues(alpha: 0.14),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            // Mesh / line pattern
            Positioned.fill(
              child: CustomPaint(painter: _WalletMeshPainter()),
            ),
            // Diagonal shine
            Positioned.fill(
              child: CustomPaint(painter: _WalletShinePainter()),
            ),
            // Content
            Padding(
              padding: EdgeInsets.all(pad),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.18),
                          ),
                        ),
                        child: const Icon(
                          Icons.account_balance_wallet_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'PrepSkul Wallet',
                              style: GoogleFonts.poppins(
                                fontSize: isMobile ? 16 : 17,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: -0.2,
                              ),
                            ),
                            Text(
                              'Your earnings and balance',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.white.withValues(alpha: 0.72),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'TOTAL BALANCE',
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.55),
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [Colors.white, Color(0xFFE0F2FE)],
                    ).createShader(bounds),
                    child: Text(
                      '${total.toStringAsFixed(0)} XAF',
                      style: GoogleFonts.poppins(
                        fontSize: isMobile ? 24 : 28,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1.05,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: _GlassStat(label: 'Active', amount: activeBalance, dotColor: AppTheme.accentGreen)),
                      const SizedBox(width: 8),
                      Expanded(child: _GlassStat(label: 'Pending', amount: pendingBalance, dotColor: AppTheme.softYellow)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: onViewEarnings,
                      borderRadius: BorderRadius.circular(12),
                      child: Ink(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          gradient: LinearGradient(
                            colors: [
                              Colors.white.withValues(alpha: 0.22),
                              Colors.white.withValues(alpha: 0.08),
                            ],
                          ),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'View earnings',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Icon(
                                Icons.arrow_forward_rounded,
                                size: 16,
                                color: Colors.white.withValues(alpha: 0.9),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Frosted stat tile — same plane as card, not a raised sub-card.
class _GlassStat extends StatelessWidget {
  final String label;
  final double amount;
  final Color dotColor;

  const _GlassStat({
    required this.label,
    required this.amount,
    required this.dotColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: Colors.white.withValues(alpha: 0.06),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    color: Colors.white.withValues(alpha: 0.75),
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${amount.toStringAsFixed(0)} XAF',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

/// Subtle diagonal mesh like premium card stock.
class _WalletMeshPainter extends CustomPainter {
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

    final dotPaint = Paint()..color = Colors.white.withValues(alpha: 0.06);
    for (var i = 0; i < 8; i++) {
      final dx = size.width * (0.15 + i * 0.1);
      final dy = size.height * (0.2 + (i % 3) * 0.22);
      canvas.drawCircle(Offset(dx, dy), 1.2, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Soft diagonal highlight sweep across the card face.
class _WalletShinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final gradient = LinearGradient(
      begin: const Alignment(-0.8, -1.0),
      end: const Alignment(0.6, 1.2),
      colors: [
        Colors.white.withValues(alpha: 0.14),
        Colors.white.withValues(alpha: 0.03),
        Colors.transparent,
        Colors.white.withValues(alpha: 0.05),
      ],
      stops: const [0.0, 0.25, 0.55, 1.0],
      transform: GradientRotation(math.pi / 5),
    );
    canvas.drawRect(rect, Paint()..shader = gradient.createShader(rect));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
