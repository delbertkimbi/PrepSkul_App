import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';

enum KycMascotVariant { submitted, pending }

/// Hero illustration for KYC status screens. Uses PNG assets when present;
/// otherwise renders a soft branded fallback (no generic icon tile).
class KycMascotIllustration extends StatelessWidget {
  final KycMascotVariant variant;

  const KycMascotIllustration({super.key, required this.variant});

  static const _submittedAsset = 'assets/images/kyc/kyc_submitted.png';
  static const _pendingAsset = 'assets/images/kyc/kyc_pending.png';

  String get _assetPath => switch (variant) {
        KycMascotVariant.submitted => _submittedAsset,
        KycMascotVariant.pending => _pendingAsset,
      };

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 4 / 3,
      child: Image.asset(
        _assetPath,
        fit: BoxFit.contain,
        gaplessPlayback: true,
        filterQuality: FilterQuality.medium,
        errorBuilder: (context, error, stackTrace) {
          if (kDebugMode) {
            debugPrint(
              'KycMascotIllustration: failed to load $_assetPath — $error',
            );
          }
          return _KycMascotFallback(variant: variant);
        },
      ),
    );
  }
}

class _KycMascotFallback extends StatelessWidget {
  final KycMascotVariant variant;

  const _KycMascotFallback({required this.variant});

  @override
  Widget build(BuildContext context) {
    final isSubmitted = variant == KycMascotVariant.submitted;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.skyBlueLight.withValues(alpha: 0.9),
            AppTheme.primaryColor.withValues(alpha: 0.12),
          ],
        ),
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.15),
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            top: 16,
            right: 24,
            child: _decoCircle(28, 0.08),
          ),
          Positioned(
            bottom: 20,
            left: 20,
            child: _decoCircle(18, 0.06),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 120,
                height: 100,
                child: CustomPaint(
                  painter: _CatMascotPainter(
                    accent: AppTheme.primaryColor,
                    showCheck: isSubmitted,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isSubmitted ? 'Submitted for review' : 'Review in progress',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _decoCircle(double size, double opacity) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppTheme.primaryColor.withValues(alpha: opacity),
      ),
    );
  }
}

class _CatMascotPainter extends CustomPainter {
  final Color accent;
  final bool showCheck;

  _CatMascotPainter({required this.accent, required this.showCheck});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2 + 4;

    final facePaint = Paint()..color = accent.withValues(alpha: 0.9);
    final earPaint = Paint()..color = accent.withValues(alpha: 0.75);

    // Ears
    final leftEar = Path()
      ..moveTo(cx - 38, cy - 18)
      ..lineTo(cx - 22, cy - 48)
      ..lineTo(cx - 8, cy - 22)
      ..close();
    final rightEar = Path()
      ..moveTo(cx + 38, cy - 18)
      ..lineTo(cx + 22, cy - 48)
      ..lineTo(cx + 8, cy - 22)
      ..close();
    canvas.drawPath(leftEar, earPaint);
    canvas.drawPath(rightEar, earPaint);

    // Face
    canvas.drawCircle(Offset(cx, cy), 42, facePaint);

    // Eyes
    final eye = Paint()..color = Colors.white;
    canvas.drawCircle(Offset(cx - 14, cy - 4), 7, eye);
    canvas.drawCircle(Offset(cx + 14, cy - 4), 7, eye);
    final pupil = Paint()..color = accent.withValues(alpha: 0.35);
    canvas.drawCircle(Offset(cx - 14, cy - 3), 3.5, pupil);
    canvas.drawCircle(Offset(cx + 14, cy - 3), 3.5, pupil);

    // Smile
    final smile = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCenter(center: Offset(cx, cy + 6), width: 28, height: 16),
      0.15,
      2.9,
      false,
      smile,
    );

    if (showCheck) {
      final checkBg = Paint()..color = AppTheme.success;
      canvas.drawCircle(Offset(cx + 36, cy - 36), 16, checkBg);
      final check = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round;
      final path = Path()
        ..moveTo(cx + 28, cy - 36)
        ..lineTo(cx + 34, cy - 30)
        ..lineTo(cx + 46, cy - 44);
      canvas.drawPath(path, check);
    } else {
      // Hourglass hint for pending
      final sand = Paint()
        ..color = Colors.white.withValues(alpha: 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(cx + 36, cy - 34),
            width: 14,
            height: 20,
          ),
          const Radius.circular(3),
        ),
        sand,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CatMascotPainter oldDelegate) =>
      oldDelegate.showCheck != showCheck;
}
