import 'package:flutter/material.dart';
import 'package:prepskul/core/theme/app_theme.dart';

import '../l10n/skulmate_copy.dart';
import '../services/skulmate_import_actions.dart';
import 'deck_create_sheet.dart';
import 'skulmate_surface_styles.dart';
import 'skulmate_typography.dart';

/// Soft bottom sheet — create a deck or import material (Gizmo-style).
class DeckAddSheet {
  DeckAddSheet._();

  static Future<void> show(
    BuildContext context, {
    String? childId,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final copy = SkulMateCopy.of(sheetContext);
        final bottom = MediaQuery.paddingOf(sheetContext).bottom;

        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
          ),
          child: Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, 16, 20, 12 + bottom),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            copy.addDeckTitle,
                            style: SkulMateTypography.screenTitle(),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(sheetContext),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      copy.addDeckSubtitle,
                      style: SkulMateTypography.cardMeta(),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        DeckCreateSheet.show(context, childId: childId);
                      },
                      icon: const Icon(Icons.create_new_folder_rounded),
                      label: Text(copy.addDeckCta),
                      style: SkulMateSurfaceStyles.deckAccentButton(
                        minHeight: 50,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      copy.orImportMaterial,
                      style: SkulMateTypography.cardMeta(),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _ImportCard(
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
                          child: _ImportCard(
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
                          child: _ImportCard(
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
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _ImportCard(
                            icon: Icons.play_circle_rounded,
                            label: copy.youtube,
                            onTap: () async {
                              Navigator.pop(sheetContext);
                              await SkulMateImportActions.importYoutube(
                                context,
                                childId: childId,
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ImportCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ImportCard({
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
