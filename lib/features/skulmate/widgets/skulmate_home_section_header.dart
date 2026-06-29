import 'package:flutter/material.dart';
import 'package:prepskul/core/theme/app_theme.dart';

import '../l10n/skulmate_copy.dart';
import 'skulmate_typography.dart';

/// Section header for SkulMate home rows — bold title, optional View all / +.
class SkulMateHomeSectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onViewAll;
  final String? viewAllLabel;
  final VoidCallback? onAdd;

  const SkulMateHomeSectionHeader({
    super.key,
    required this.title,
    this.onViewAll,
    this.viewAllLabel,
    this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final copy = SkulMateCopy.of(context);
    final actionLabel = viewAllLabel ?? copy.viewAll;

    return Row(
      children: [
        Expanded(
          child: Text(title, style: SkulMateTypography.sectionTitle()),
        ),
        if (onViewAll != null)
          TextButton(
            onPressed: onViewAll,
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.primaryColor,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(actionLabel, style: SkulMateTypography.linkAction()),
          ),
        if (onAdd != null)
          IconButton(
            onPressed: onAdd,
            tooltip: copy.addDeckCta,
            icon: const Icon(Icons.add_rounded),
            color: AppTheme.primaryColor,
            visualDensity: VisualDensity.compact,
          ),
      ],
    );
  }
}
