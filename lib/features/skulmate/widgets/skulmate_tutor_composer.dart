import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/features/skulmate/l10n/skulmate_copy.dart';
import 'package:prepskul/features/skulmate/widgets/skulmate_import_action_grid.dart';
import 'package:prepskul/features/skulmate/widgets/skulmate_surface_styles.dart';

class SkulMateTutorComposer extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final VoidCallback onHoldStart;
  final VoidCallback onHoldEnd;
  final bool busy;
  final bool recording;
  final String? childId;
  final bool attachOpen;
  final VoidCallback onToggleAttach;

  const SkulMateTutorComposer({
    super.key,
    required this.controller,
    required this.onSend,
    required this.onHoldStart,
    required this.onHoldEnd,
    required this.busy,
    required this.recording,
    required this.attachOpen,
    required this.onToggleAttach,
    this.childId,
  });

  @override
  Widget build(BuildContext context) {
    final copy = SkulMateCopy.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (attachOpen)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: SkulMateImportActionGrid(childId: childId),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: GestureDetector(
            onLongPressStart: (_) => onHoldStart(),
            onLongPressEnd: (_) => onHoldEnd(),
            child: Container(
              height: 64,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: recording ? AppTheme.skyBlue : AppTheme.primaryColor,
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryColor.withValues(alpha: 0.35),
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Text(
                recording ? copy.tutorListening : copy.tutorHoldToTalk,
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Container(
            decoration: SkulMateSurfaceStyles.homeCard(radius: 22),
            padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
            child: Row(
              children: [
                IconButton(
                  tooltip: copy.orImportMaterial,
                  onPressed: busy ? null : onToggleAttach,
                  icon: Icon(
                    attachOpen
                        ? Icons.close_rounded
                        : Icons.add_circle_outline_rounded,
                    color: AppTheme.primaryColor,
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: controller,
                    minLines: 1,
                    maxLines: 4,
                    enabled: !busy,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => onSend(),
                    decoration: InputDecoration(
                      hintText: copy.tutorComposerHint,
                      border: InputBorder.none,
                      hintStyle: GoogleFonts.plusJakartaSans(
                        color: AppTheme.neutral400,
                      ),
                    ),
                  ),
                ),
                IconButton.filled(
                  onPressed: busy ? null : onSend,
                  style: IconButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                  ),
                  icon: busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.arrow_upward_rounded),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
