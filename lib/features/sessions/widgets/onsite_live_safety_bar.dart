import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';

/// Safety actions during live onsite sessions — compact sheet instead of 3+ buttons.
class OnsiteLiveSafetyBar extends StatelessWidget {
  final VoidCallback? onReport;
  final VoidCallback? onPanic;
  final VoidCallback? onShareLocation;
  final bool isLoading;

  const OnsiteLiveSafetyBar({
    super.key,
    this.onReport,
    this.onPanic,
    this.onShareLocation,
    this.isLoading = false,
  });

  static Future<void> showSafetySheet(
    BuildContext context, {
    VoidCallback? onReport,
    VoidCallback? onShareLocation,
    VoidCallback? onPanic,
    bool isLoading = false,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Text(
                  'Safety & help',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textDark,
                  ),
                ),
              ),
              if (onShareLocation != null)
                ListTile(
                  leading: Icon(Icons.share_location_outlined, color: AppTheme.skyBlue),
                  title: Text(
                    'Share live location',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    'Send your location to your emergency contact',
                    style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textMedium),
                  ),
                  onTap: isLoading
                      ? null
                      : () {
                          Navigator.pop(ctx);
                          onShareLocation();
                        },
                ),
              if (onReport != null)
                ListTile(
                  leading: Icon(Icons.flag_outlined, color: AppTheme.primaryColor),
                  title: Text(
                    'Report an issue',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                  ),
                  onTap: isLoading
                      ? null
                      : () {
                          Navigator.pop(ctx);
                          onReport();
                        },
                ),
              if (onPanic != null)
                ListTile(
                  leading: Icon(Icons.warning_amber_rounded, color: Colors.red.shade700),
                  title: Text(
                    'Panic — get help now',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      color: Colors.red.shade700,
                    ),
                  ),
                  onTap: isLoading
                      ? null
                      : () {
                          Navigator.pop(ctx);
                          onPanic();
                        },
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: isLoading
          ? null
          : () => showSafetySheet(
                context,
                onReport: onReport,
                onShareLocation: onShareLocation,
                onPanic: onPanic,
                isLoading: isLoading,
              ),
      icon: Icon(Icons.shield_outlined, size: 18, color: AppTheme.textMedium),
      label: Text(
        'Safety & help',
        style: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppTheme.textMedium,
        ),
      ),
    );
  }
}
