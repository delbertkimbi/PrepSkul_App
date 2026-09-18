import 'package:flutter/material.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/core/utils/responsive_helper.dart';
import 'package:prepskul/features/onboarding/learner/learner_onboarding_chrome.dart';

/// Paper wallet card for tutor earnings on home and payouts.
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
      padding: EdgeInsets.all(pad),
      decoration: OnboardPalette.paperCard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.skyBlueLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.primaryColor, width: 2),
                ),
                child: const Icon(
                  Icons.account_balance_wallet_rounded,
                  color: AppTheme.primaryColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Wallet', style: onboardDisplay(size: isMobile ? 18 : 20)),
                    Text(
                      'Your earnings and balance',
                      style: onboardFont(
                        size: 12,
                        weight: FontWeight.w700,
                        color: AppTheme.textMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'TOTAL BALANCE',
            style: onboardFont(
              size: 11,
              weight: FontWeight.w800,
              color: AppTheme.textMedium,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${total.toStringAsFixed(0)} XAF',
            style: onboardDisplay(size: isMobile ? 24 : 28),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _PaperStat(
                  label: 'Active',
                  amount: activeBalance,
                  dotColor: const Color(0xFF15803D),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _PaperStat(
                  label: 'Pending',
                  amount: pendingBalance,
                  dotColor: const Color(0xFFC2410C),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: onViewEarnings,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primaryColor,
                side: const BorderSide(color: AppTheme.primaryColor, width: 2),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'View earnings',
                    style: onboardFont(size: 14),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.arrow_forward_rounded, size: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PaperStat extends StatelessWidget {
  final String label;
  final double amount;
  final Color dotColor;

  const _PaperStat({
    required this.label,
    required this.amount,
    required this.dotColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: OnboardPalette.cream,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.18),
          width: 2,
        ),
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
                  style: onboardFont(
                    size: 11,
                    weight: FontWeight.w700,
                    color: AppTheme.textMedium,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${amount.toStringAsFixed(0)} XAF',
            style: onboardDisplay(size: 16),
          ),
        ],
      ),
    );
  }
}
