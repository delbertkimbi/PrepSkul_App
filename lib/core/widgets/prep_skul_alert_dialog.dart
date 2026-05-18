import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';

/// Branded alert content for [showDialog] (errors, confirmations).
class PrepSkulAlertDialog extends StatelessWidget {
  const PrepSkulAlertDialog({
    super.key,
    required this.title,
    required this.message,
    required this.actions,
    this.leadingIcon = Icons.error_outline_rounded,
    this.iconColor,
  });

  final String title;
  final String message;
  final List<Widget> actions;
  final IconData leadingIcon;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final iconTint = iconColor ?? AppTheme.error;
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      title: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(leadingIcon, color: iconTint, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppTheme.textDark,
              ),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Text(
          message,
          style: GoogleFonts.poppins(
            fontSize: 14,
            height: 1.5,
            color: AppTheme.textMedium,
          ),
        ),
      ),
      actions: actions,
    );
  }
}

/// Convenience wrapper around [showDialog] with [PrepSkulAlertDialog].
Future<T?> showPrepSkulAlert<T>({
  required BuildContext context,
  required String title,
  required String message,
  IconData leadingIcon = Icons.error_outline_rounded,
  Color? iconColor,
  List<Widget>? actions,
}) {
  if (!context.mounted) return Future.value();
  return showDialog<T>(
    context: context,
    builder: (ctx) => PrepSkulAlertDialog(
      title: title,
      message: message,
      leadingIcon: leadingIcon,
      iconColor: iconColor,
      actions: actions ?? <Widget>[],
    ),
  );
}
