import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';

/// Gizmo-style section title with optional View all (right) or + action.
class SkulMateHomeSectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onViewAll;
  final VoidCallback? onAdd;
  final String? viewAllLabel;

  const SkulMateHomeSectionHeader({
    super.key,
    required this.title,
    this.onViewAll,
    this.onAdd,
    this.viewAllLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppTheme.textDark,
              letterSpacing: -0.2,
            ),
          ),
        ),
        if (onViewAll != null)
          GestureDetector(
            onTap: onViewAll,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              child: Text(
                viewAllLabel ?? 'View all',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textMedium,
                ),
              ),
            ),
          ),
        if (onAdd != null)
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onAdd,
              borderRadius: BorderRadius.circular(999),
              child: const Padding(
                padding: EdgeInsets.all(6),
                child: Icon(
                  Icons.add_rounded,
                  size: 24,
                  color: AppTheme.textDark,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
