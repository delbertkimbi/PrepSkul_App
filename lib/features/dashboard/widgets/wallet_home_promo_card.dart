import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/core/widgets/premium_promo_card_shell.dart';
import 'package:prepskul/features/dashboard/models/wallet_snapshot.dart';

/// Payment-card style wallet slide on the premium gold background.
class WalletHomePromoCard extends StatelessWidget {
  static const double cardHeight = 184;

  final WalletSnapshot wallet;
  final bool isParent;
  final VoidCallback onTap;

  const WalletHomePromoCard({
    super.key,
    required this.wallet,
    this.isParent = false,
    required this.onTap,
  });

  static final _numberFormat = NumberFormat.decimalPattern();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: PremiumPromoCardShell(
          height: cardHeight,
          accent: AppTheme.softYellow,
          gradientColors: PremiumPromoCardShell.walletGradient,
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  _chip(),
                  const Spacer(),
                  Text(
                    'PREPSKUL WALLET',
                    style: GoogleFonts.poppins(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.5),
                      letterSpacing: 1.4,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              _balanceRow(
                label: 'Session credits',
                value: wallet.sessionCredits,
                icon: PhosphorIcons.calendarCheck(PhosphorIconsStyle.fill),
              ),
              const SizedBox(height: 10),
              _balanceRow(
                label: 'SkulMate credits',
                value: wallet.skulMateCredits,
                icon: PhosphorIcons.sparkle(PhosphorIconsStyle.fill),
              ),
              const Spacer(),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      wallet.footerCta(isParent: isParent),
                      style: GoogleFonts.poppins(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.78),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 12,
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatValue(int value) => _numberFormat.format(value);

  Widget _chip() {
    return Container(
      width: 34,
      height: 26,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(5),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.softYellow.withValues(alpha: 0.75),
            AppTheme.softYellow.withValues(alpha: 0.45),
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(5),
        child: CustomPaint(painter: _ChipLinesPainter()),
      ),
    );
  }

  Widget _balanceRow({
    required String label,
    required int value,
    required IconData icon,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Icon(
          icon,
          size: 13,
          color: Colors.white.withValues(alpha: 0.45),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: Colors.white.withValues(alpha: 0.72),
            ),
          ),
        ),
        Text(
          _formatValue(value),
          style: GoogleFonts.poppins(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            height: 1,
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }
}

class _ChipLinesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF2C2416).withValues(alpha: 0.35)
      ..strokeWidth = 1.2;
    const gap = 4.0;
    for (var i = 0; i < 3; i++) {
      final y = 2.0 + i * gap;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
