import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/core/widgets/premium_promo_card_shell.dart';
import 'package:prepskul/features/onboarding/learner/learner_onboarding_chrome.dart';
import 'package:prepskul/features/dashboard/models/wallet_snapshot.dart';

/// Paper wallet slide on cream with navy border.
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
                    style: onboardFont(
                      size: 9,
                      weight: FontWeight.w800,
                      color: AppTheme.textMedium,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              _balanceRow(
                label: 'Session credits',
                value: wallet.sessionCredits,
                icon: PhosphorIcons.calendarCheckFill,
              ),
              const SizedBox(height: 10),
              _balanceRow(
                label: 'SkulMate credits',
                value: wallet.skulMateCredits,
                icon: PhosphorIcons.sparkleFill,
              ),
              const Spacer(),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      wallet.footerCta(isParent: isParent),
                      style: onboardFont(
                        size: 11,
                        weight: FontWeight.w700,
                        color: AppTheme.textMedium,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 12,
                    color: AppTheme.primaryColor,
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
        color: AppTheme.softYellow,
        border: Border.all(color: AppTheme.primaryColor, width: 1.5),
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
          color: AppTheme.primaryColor.withValues(alpha: 0.45),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            label,
            style: onboardFont(
              size: 11,
              weight: FontWeight.w700,
              color: AppTheme.textMedium,
            ),
          ),
        ),
        Text(
          _formatValue(value),
          style: onboardDisplay(
            size: 22,
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
