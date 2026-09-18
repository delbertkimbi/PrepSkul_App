import 'package:flutter/material.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/features/onboarding/learner/learner_onboarding_chrome.dart';

/// Paper home promo card: cream fill, navy border, offset shadow. No gradients.
class PremiumPromoCardShell extends StatelessWidget {
  final double height;
  final double radius;
  final Color accent;
  final EdgeInsets padding;
  final List<Color>? gradientColors;
  final Widget child;

  static const List<Color> defaultGradient = [
    Color(0xFFFAF8F3),
    Color(0xFFFFFFFF),
  ];

  static const List<Color> walletGradient = [
    Color(0xFFFAF8F3),
    Color(0xFFFFFFFF),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: AppTheme.primaryColor, width: 2.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x381E3A8A),
            offset: Offset(0, 5),
            blurRadius: 0,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius - 2),
        child: ColoredBox(
          color: OnboardPalette.cream,
          child: Padding(padding: padding, child: child),
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
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          decoration: BoxDecoration(
            color: AppTheme.primaryColor,
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [
              BoxShadow(
                color: AppTheme.primaryDark,
                offset: Offset(0, 3),
                blurRadius: 0,
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 14, color: Colors.white),
                  const SizedBox(width: 5),
                ],
                Text(
                  label,
                  style: onboardFont(
                    size: 13,
                    weight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 3),
                const Icon(
                  Icons.arrow_forward_rounded,
                  size: 13,
                  color: Colors.white,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
