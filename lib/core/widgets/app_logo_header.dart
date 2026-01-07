import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

/// Reusable app logo header for AppBars and headers
class AppLogoHeader extends StatelessWidget {
  final double logoSize;
  final double fontSize;
  final Color textColor;
  final bool showText;

  const AppLogoHeader({
    Key? key,
    this.logoSize = 32,
    this.fontSize = 22,
    this.textColor = AppTheme.primaryColor,
    this.showText = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Build logo with error handling - use blue logo as primary since it's more reliable
    Widget _buildLogo() {
      return Image.asset(
        'assets/images/app_logo(blue).png',
        width: logoSize,
        height: logoSize,
        errorBuilder: (context, error, stackTrace) {
          // Fallback: show icon if asset fails
          return Icon(
            Icons.school,
            size: logoSize,
            color: AppTheme.primaryColor,
          );
        },
      );
    }

    if (!showText) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: _buildLogo(),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          child: _buildLogo(),
        ),
        const SizedBox(width: 12),
        Text(
          'PrepSkul',
          style: GoogleFonts.poppins(
            fontSize: fontSize,
            fontWeight: FontWeight.w700,
            color: textColor,
          ),
        ),
      ],
    );
  }
}

/// App logo without text (just the icon)
class AppLogo extends StatelessWidget {
  final double size;

  const AppLogo({
    Key? key,
    this.size = 32,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.all(Radius.circular(12)),
      child: Image.asset(
        'assets/images/app_logo(blue).png',
        width: size,
        height: size,
      ),
    );
  }
}
