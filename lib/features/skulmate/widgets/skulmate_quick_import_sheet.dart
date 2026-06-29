import 'package:flutter/material.dart';
import 'package:prepskul/core/theme/app_theme.dart';

import '../l10n/skulmate_copy.dart';
import '../services/skulmate_import_actions.dart';
import 'skulmate_surface_styles.dart';
import 'skulmate_typography.dart';

/// Minimal bottom sheet — one row of the three main import types.
class SkulMateQuickImportSheet {
  SkulMateQuickImportSheet._();

  static Future<void> show(
    BuildContext context, {
    String? childId,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        final copy = SkulMateCopy.of(sheetContext);
        final bottom = MediaQuery.paddingOf(sheetContext).bottom;

        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 12 + bottom),
            child: Row(
              children: [
                Expanded(
                  child: _QuickImportCard(
                    icon: Icons.file_upload_rounded,
                    label: copy.upload,
                    onTap: () async {
                      Navigator.pop(sheetContext);
                      await SkulMateImportActions.pickDocuments(
                        context,
                        childId: childId,
                      );
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _QuickImportCard(
                    icon: Icons.photo_camera_rounded,
                    label: copy.photo,
                    onTap: () async {
                      Navigator.pop(sheetContext);
                      await SkulMateImportActions.pickPhotos(
                        context,
                        childId: childId,
                      );
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _QuickImportCard(
                    icon: Icons.content_paste_rounded,
                    label: copy.paste,
                    onTap: () async {
                      Navigator.pop(sheetContext);
                      await SkulMateImportActions.openPaste(
                        context,
                        childId: childId,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _QuickImportCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickImportCard({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(SkulMateSurfaceStyles.homeCardRadius),
        child: Ink(
          decoration: SkulMateSurfaceStyles.chipCard(
            radius: SkulMateSurfaceStyles.homeCardRadius,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 22, color: AppTheme.textDark),
                const SizedBox(height: 6),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: SkulMateTypography.chipLabel(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
