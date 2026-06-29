import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';

import '../l10n/skulmate_copy.dart';
import '../models/skulmate_intake_models.dart';
import '../services/skulmate_intake_coordinator.dart';
import '../services/skulmate_import_actions.dart';
import '../utils/deck_navigation.dart';
import 'skulmate_record_lecture_sheet.dart';
import 'skulmate_surface_styles.dart';
import 'skulmate_youtube_import_sheet.dart';

/// Gizmo-style anchored popup menus (not bottom sheets).
class SkulMateIntakePopupMenu {
  SkulMateIntakePopupMenu._();

  static const _menuWidth = 272.0;

  /// Full source list anchored above the + button in the intent card.
  static Future<void> showAddSources(
    BuildContext context, {
    required RenderBox anchor,
    String? childId,
  }) {
    final copy = SkulMateCopy.read(context);
    return _show(
      context,
      anchor: anchor,
      preferAbove: true,
      entries: [
        _Entry('PDF', _BrandIcon.pdf(), (p) => SkulMateImportActions.pickDocuments(p, childId: childId)),
        _Entry('PowerPoint', _BrandIcon.powerpoint(), (p) => SkulMateImportActions.pickDocuments(p, childId: childId)),
        _Entry('YouTube', _BrandIcon.youtube(), (p) => _youtube(p, childId)),
        _Entry(copy.paste, _BrandIcon.notes(), (p) => SkulMateImportActions.openPaste(p, childId: childId)),
        _Entry(copy.photo, _BrandIcon.photo(), (p) => SkulMateImportActions.pickPhotos(p, childId: childId)),
        _Entry(copy.recordLecture, _BrandIcon.mic(), (p) => _record(p, childId)),
        _Entry(copy.quizlet, _BrandIcon.quizlet(), (p) async => _comingSoon(p, copy)),
        _Entry(copy.deck, _BrandIcon.folder(), (p) => _openDeck(p, childId)),
      ],
    );
  }

  /// Record lecture + Deck only — anchored near the More tool chip.
  static Future<void> showExtraTools(
    BuildContext context, {
    required RenderBox anchor,
    String? childId,
  }) {
    final copy = SkulMateCopy.read(context);
    return _show(
      context,
      anchor: anchor,
      preferAbove: true,
      alignEnd: true,
      entries: [
        _Entry(copy.recordLecture, _BrandIcon.mic(), (p) => _record(p, childId)),
        _Entry(copy.deck, _BrandIcon.folder(), (p) => _openDeck(p, childId)),
      ],
    );
  }

  static Future<void> _show(
    BuildContext parentContext, {
    required RenderBox anchor,
    required List<_Entry> entries,
    bool preferAbove = true,
    bool alignEnd = false,
  }) async {
    final offset = anchor.localToGlobal(Offset.zero);
    final anchorSize = anchor.size;
    final screen = MediaQuery.sizeOf(parentContext);
    final padding = MediaQuery.paddingOf(parentContext);

    final rowHeight = 48.0;
    final menuHeight = entries.length * rowHeight + 8;
    final left = alignEnd
        ? (offset.dx + anchorSize.width - _menuWidth)
            .clamp(12.0, screen.width - _menuWidth - 12)
        : offset.dx.clamp(12.0, screen.width - _menuWidth - 12);

    final top = preferAbove
        ? (offset.dy - menuHeight - 8).clamp(
            padding.top + 8,
            screen.height - menuHeight - padding.bottom - 8,
          )
        : (offset.dy + anchorSize.height + 8).clamp(
            padding.top + 8,
            screen.height - menuHeight - padding.bottom - 8,
          );

    await showDialog<void>(
      context: parentContext,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.12),
      builder: (dialogContext) {
        return SizedBox.expand(
          child: Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  onTap: () => Navigator.pop(dialogContext),
                  behavior: HitTestBehavior.opaque,
                  child: const SizedBox.expand(),
                ),
              ),
              Positioned(
                left: left,
                top: top,
                width: _menuWidth,
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    decoration: SkulMateSurfaceStyles.homeCard(radius: 18),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (var i = 0; i < entries.length; i++) ...[
                          if (i > 0)
                            Divider(
                              height: 1,
                              thickness: 1,
                              color: AppTheme.softBorder.withValues(alpha: 0.9),
                              indent: 16,
                              endIndent: 16,
                            ),
                          _MenuRow(
                            entry: entries[i],
                            parentContext: parentContext,
                            dialogContext: dialogContext,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static Future<void> _record(BuildContext context, String? childId) async {
    await SkulMateRecordLectureSheet.show(context, childId: childId);
  }

  static Future<void> _youtube(BuildContext context, String? childId) async {
    final url = await SkulMateYoutubeImportSheet.show(context);
    if (url == null || !context.mounted) return;
    await SkulMateIntakeCoordinator.start(
      context,
      SkulMateIntakePayload(
        source: SkulMateIntakeSource.youtube,
        youtubeUrl: url,
        childId: childId,
      ),
    );
  }

  static Future<void> _openDeck(BuildContext context, String? childId) async {
    await DeckNavigation.openDeckPicker(context: context, childId: childId);
  }

  static void _comingSoon(BuildContext context, SkulMateCopy copy) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(copy.comingSoon),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class _Entry {
  final String label;
  final Widget trailing;
  final Future<void> Function(BuildContext parent) onTap;

  const _Entry(this.label, this.trailing, this.onTap);
}

class _MenuRow extends StatelessWidget {
  final _Entry entry;
  final BuildContext parentContext;
  final BuildContext dialogContext;

  const _MenuRow({
    required this.entry,
    required this.parentContext,
    required this.dialogContext,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        Navigator.pop(dialogContext);
        await entry.onTap(parentContext);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                entry.label,
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textDark,
                ),
              ),
            ),
            entry.trailing,
          ],
        ),
      ),
    );
  }
}

/// Brand-tinted trailing icons (Gizmo-style).
class _BrandIcon {
  static Widget pdf() => _tinted(Icons.picture_as_pdf_rounded, const Color(0xFFE53935));
  static Widget powerpoint() => _tinted(Icons.slideshow_rounded, const Color(0xFFD84315));
  static Widget youtube() => _tinted(Icons.play_circle_filled_rounded, const Color(0xFFFF0000));
  static Widget notes() => _tinted(Icons.sticky_note_2_outlined, AppTheme.textDark);
  static Widget photo() => _tinted(Icons.image_outlined, AppTheme.textDark);
  static Widget mic() => _tinted(Icons.mic_none_rounded, AppTheme.textDark);
  static Widget quizlet() => _tinted(Icons.layers_rounded, const Color(0xFF4255FF));
  static Widget folder() => _tinted(Icons.folder_outlined, AppTheme.textDark);

  static Widget _tinted(IconData icon, Color color) {
    return Icon(icon, size: 22, color: color);
  }
}
