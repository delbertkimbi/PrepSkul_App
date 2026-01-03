import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';

/// Branded SnackBar Widget
/// 
/// Custom SnackBar with PrepSkul branding:
/// - Curved border radius
/// - White app logo next to text
/// - Consistent styling across the app
class BrandedSnackBar extends StatelessWidget {
  final String message;
  final Color backgroundColor;
  final IconData? icon;
  final Color? iconColor;
  final Widget? leading;
  final Duration duration;

  const BrandedSnackBar({
    super.key,
    required this.message,
    required this.backgroundColor,
    this.icon,
    this.iconColor,
    this.leading,
    this.duration = const Duration(seconds: 3),
  });

  /// Show a success SnackBar
  static void showSuccess(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: BrandedSnackBar(
          message: message,
          backgroundColor: AppTheme.accentGreen,
          icon: Icons.check_circle,
          iconColor: Colors.white,
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        duration: duration,
      ),
    );
  }

  /// Show an error SnackBar
  static void showError(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 5),
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: BrandedSnackBar(
          message: message,
          backgroundColor: AppTheme.primaryColor, // Deep blue instead of red
          icon: Icons.info_outline,
          iconColor: Colors.white,
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        duration: duration,
      ),
    );
  }

  /// Show an info SnackBar
  static void showInfo(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: BrandedSnackBar(
          message: message,
          backgroundColor: AppTheme.primaryColor,
          icon: Icons.info_outline,
          iconColor: Colors.white,
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        duration: duration,
      ),
    );
  }

  /// Show a loading SnackBar
  static void showLoading(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 30),
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: BrandedSnackBar(
          message: message,
          backgroundColor: AppTheme.primaryColor,
          leading: const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        duration: duration,
      ),
    );
  }

  /// Show a custom SnackBar
  static void show(
    BuildContext context, {
    required String message,
    required Color backgroundColor,
    IconData? icon,
    Color? iconColor,
    Widget? leading,
    Duration duration = const Duration(seconds: 3),
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: BrandedSnackBar(
          message: message,
          backgroundColor: backgroundColor,
          icon: icon,
          iconColor: iconColor,
          leading: leading,
          duration: duration,
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        duration: duration,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16), // Curved border radius
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // White app logo
          Image.asset(
            'assets/images/app_logo(white).png',
            width: 24,
            height: 24,
            errorBuilder: (context, error, stackTrace) {
              // Fallback if logo not found
              return const SizedBox(width: 24, height: 24);
            },
          ),
          const SizedBox(width: 12),
          // Leading widget (icon or loading indicator)
          if (leading != null) ...[
            leading!,
            const SizedBox(width: 8),
          ] else if (icon != null) ...[
            Icon(
              icon,
              color: iconColor ?? Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
          ],
          // Message text
          Flexible(
            child: Text(
              message,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
