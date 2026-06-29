import 'package:flutter/material.dart';
import 'package:prepskul/core/theme/app_theme.dart';

import '../l10n/skulmate_copy.dart';
import '../services/skulmate_import_actions.dart';
import 'skulmate_from_class_sheet.dart';
import 'skulmate_intake_popup_menu.dart';
import 'skulmate_surface_styles.dart';
import 'skulmate_typography.dart';

/// Import tool chips below the intent card — simple rounded pills.
class SkulMateImportActionGrid extends StatelessWidget {
  final String? childId;

  const SkulMateImportActionGrid({super.key, this.childId});

  static const _chipHeight = 44.0;

  @override
  Widget build(BuildContext context) {
    final copy = SkulMateCopy.of(context);

    final chips = [
      _ChipDef(copy.upload, Icons.file_upload_rounded, (ctx, _) async {
        await SkulMateImportActions.pickDocuments(ctx, childId: childId);
      }),
      _ChipDef(copy.photo, Icons.photo_camera_rounded, (ctx, _) async {
        await SkulMateImportActions.pickPhotos(ctx, childId: childId);
      }),
      _ChipDef(copy.paste, Icons.content_paste_rounded, (ctx, _) async {
        await SkulMateImportActions.openPaste(ctx, childId: childId);
      }),
      _ChipDef(copy.youtube, Icons.play_circle_rounded, (ctx, _) async {
        await SkulMateImportActions.importYoutube(ctx, childId: childId);
      }),
      _ChipDef(copy.sessions, Icons.video_library_rounded, (ctx, _) async {
        await SkulMateFromClassSheet.show(ctx, childId: childId);
      }),
      _ChipDef(copy.more, Icons.keyboard_arrow_down_rounded, (ctx, box) async {
        await SkulMateIntakePopupMenu.showExtraTools(
          ctx,
          anchor: box,
          childId: childId,
        );
      }),
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
}

class _ChipDef {
  final String label;
  final IconData icon;
  final Future<void> Function(BuildContext context, RenderBox anchor) onTap;

  const _ChipDef(this.label, this.icon, this.onTap);
}

class _ChipButton extends StatefulWidget {
  final _ChipDef def;

  const _ChipButton({required this.def});

  @override
  State<_ChipButton> createState() => _ChipButtonState();
}

class _ChipButtonState extends State<_ChipButton> {
  bool _busy = false;

  Future<void> _handleTap() async {
    if (_busy) return;
    SkulMateSurfaceStyles.lightTap();
    setState(() => _busy = true);
    try {
      final box = context.findRenderObject() as RenderBox?;
      if (box != null && box.hasSize) {
        await widget.def.onTap(context, box);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _busy ? null : _handleTap,
        borderRadius: BorderRadius.circular(SkulMateSurfaceStyles.pillRadius),
        child: Container(
          alignment: Alignment.center,
          decoration: SkulMateSurfaceStyles.chipCard(),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_busy)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Icon(widget.def.icon, size: 20, color: AppTheme.textDark),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  widget.def.label,
                  style: SkulMateTypography.chipLabel(),
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
