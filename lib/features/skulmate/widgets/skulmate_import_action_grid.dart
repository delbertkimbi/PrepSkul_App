import 'dart:io' show File;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:prepskul/core/theme/app_theme.dart';

import '../l10n/skulmate_copy.dart';
import '../models/skulmate_intake_models.dart';
import '../services/skulmate_intake_coordinator.dart';
import 'photo_upload_bottom_sheet.dart';
import 'skulmate_from_class_sheet.dart';
import 'skulmate_intake_popup_menu.dart';
import 'skulmate_surface_styles.dart';
import 'skulmate_youtube_import_sheet.dart';

/// Import tool chips below the intent card.
class SkulMateImportActionGrid extends StatelessWidget {
  final String? childId;

  const SkulMateImportActionGrid({super.key, this.childId});

  static const _chipHeight = 44.0;

  @override
  Widget build(BuildContext context) {
    final copy = SkulMateCopy.of(context);

    final chips = [
      _ChipDef(copy.upload, Icons.file_upload_rounded, (ctx, _) => _pickDocument(ctx)),
      _ChipDef(copy.photo, Icons.photo_camera_rounded, (ctx, _) => _pickPhoto(ctx)),
      _ChipDef(copy.paste, Icons.content_paste_rounded, (ctx, _) => _paste(ctx)),
      _ChipDef(copy.youtube, Icons.play_circle_rounded, (ctx, _) => _youtube(ctx)),
      _ChipDef(copy.sessions, Icons.video_library_rounded, (ctx, _) => _fromClass(ctx)),
      _ChipDef(copy.more, Icons.more_horiz_rounded, (ctx, box) => _more(ctx, box)),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        mainAxisExtent: _chipHeight,
      ),
      itemCount: chips.length,
      itemBuilder: (context, index) => _ChipButton(def: chips[index]),
    );
  }

  Future<void> _pickDocument(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'docx', 'txt', 'jpg', 'jpeg', 'png'],
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty || !context.mounted) return;

    if (kIsWeb) {
      final webFile = result.files.first;
      await SkulMateIntakeCoordinator.start(
        context,
        SkulMateIntakePayload(
          source: SkulMateIntakeSource.document,
          filesWeb: [webFile],
          childId: childId,
        ),
      );
    } else if (result.files.first.path != null) {
      await SkulMateIntakeCoordinator.start(
        context,
        SkulMateIntakePayload(
          source: SkulMateIntakeSource.document,
          files: [File(result.files.first.path!)],
          childId: childId,
        ),
      );
    }
  }

  Future<void> _pickPhoto(BuildContext context) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (_) => PhotoUploadBottomSheet(),
    );
    if (source == null || !context.mounted) return;

    final picker = ImagePicker();
    final List<XFile> images;
    if (source == ImageSource.gallery) {
      images = await picker.pickMultiImage(imageQuality: 85);
    } else {
      final shot = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );
      images = shot != null ? [shot] : [];
    }

    if (images.isEmpty || !context.mounted) return;
    await SkulMateIntakeCoordinator.start(
      context,
      SkulMateIntakePayload(
        source: SkulMateIntakeSource.photo,
        images: images,
        childId: childId,
      ),
    );
  }

  Future<void> _paste(BuildContext context) async {
    await SkulMateIntakeCoordinator.openPasteFlow(context, childId: childId);
  }

  Future<void> _youtube(BuildContext context) async {
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

  Future<void> _fromClass(BuildContext context) async {
    await SkulMateFromClassSheet.show(context, childId: childId);
  }

  Future<void> _more(BuildContext context, RenderBox anchor) async {
    await SkulMateIntakePopupMenu.showExtraTools(
      context,
      anchor: anchor,
      childId: childId,
    );
  }
}

class _ChipDef {
  final String label;
  final IconData icon;
  final void Function(BuildContext context, RenderBox anchor) onTap;

  const _ChipDef(this.label, this.icon, this.onTap);
}

class _ChipButton extends StatelessWidget {
  final _ChipDef def;

  const _ChipButton({required this.def});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          final box = context.findRenderObject() as RenderBox?;
          if (box != null && box.hasSize) def.onTap(context, box);
        },
        borderRadius: BorderRadius.circular(SkulMateSurfaceStyles.pillRadius),
        child: Container(
          alignment: Alignment.center,
          decoration: SkulMateSurfaceStyles.chipCard(),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(def.icon, size: 20, color: AppTheme.textDark),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  def.label,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textDark,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
