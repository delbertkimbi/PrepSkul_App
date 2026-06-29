import 'package:flutter/material.dart';
import 'package:prepskul/core/theme/app_theme.dart';

import '../l10n/skulmate_copy.dart';
import '../models/skulmate_intake_models.dart';
import '../services/skulmate_import_actions.dart';
import '../services/skulmate_intake_coordinator.dart';
import 'skulmate_record_lecture_sheet.dart';
import 'skulmate_surface_styles.dart';
import 'skulmate_typography.dart';

/// Supported import sources for a deck — PDF, photo, paste, YouTube, lecture.
Future<void> showDeckAddContentSheet({
  required BuildContext context,
  required String deckTitle,
  String? childId,
}) {
  final copy = SkulMateCopy.read(context);

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      final bottom = MediaQuery.paddingOf(sheetContext).bottom;

      return Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + bottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        copy.magicImport,
                        style: SkulMateTypography.screenTitle(),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(sheetContext),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                Text(
                  copy.magicImportSubtitle,
                  style: SkulMateTypography.cardMeta(),
                ),
                const SizedBox(height: 16),
                _ImportRow(
                  icon: Icons.photo_camera_outlined,
                  color: AppTheme.accentGreen,
                  title: copy.photoNotes,
                  onTap: () {
                    Navigator.pop(sheetContext);
                    SkulMateImportActions.pickPhotos(context, childId: childId);
                  },
                ),
                const SizedBox(height: 8),
                _ImportRow(
                  icon: Icons.picture_as_pdf_rounded,
                  color: const Color(0xFFE53935),
                  title: 'PDF',
                  onTap: () {
                    Navigator.pop(sheetContext);
                    SkulMateImportActions.pickDocuments(
                      context,
                      childId: childId,
                    );
                  },
                ),
                const SizedBox(height: 8),
                _ImportRow(
                  icon: Icons.notes_rounded,
                  color: AppTheme.skyBlue,
                  title: copy.paste,
                  onTap: () {
                    Navigator.pop(sheetContext);
                    SkulMateImportActions.openPaste(context, childId: childId);
                  },
                ),
                const SizedBox(height: 8),
                _ImportRow(
                  icon: Icons.play_circle_filled_rounded,
                  color: const Color(0xFFFF0000),
                  title: copy.youtube,
                  onTap: () {
                    Navigator.pop(sheetContext);
                    SkulMateImportActions.importYoutube(
                      context,
                      childId: childId,
                    );
                  },
                ),
                const SizedBox(height: 8),
                _ImportRow(
                  icon: Icons.mic_none_rounded,
                  color: AppTheme.accentPurple,
                  title: copy.recordLecture,
                  onTap: () {
                    Navigator.pop(sheetContext);
                    SkulMateRecordLectureSheet.show(context, childId: childId);
                  },
                ),
                const SizedBox(height: 8),
                _ImportRow(
                  icon: Icons.edit_note_rounded,
                  color: AppTheme.primaryColor,
                  title: copy.writeCards,
                  onTap: () {
                    Navigator.pop(sheetContext);
                    SkulMateIntakeCoordinator.start(
                      context,
                      SkulMateIntakePayload(
                        source: SkulMateIntakeSource.paste,
                        topicHint: deckTitle,
                        childId: childId,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _ImportRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final VoidCallback onTap;

  const _ImportRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Ink(
          decoration: SkulMateSurfaceStyles.homeCard(radius: 16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: SkulMateTypography.cardTitle(size: 15),
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: AppTheme.textMedium),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
