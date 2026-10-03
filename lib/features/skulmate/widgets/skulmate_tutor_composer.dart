import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/features/skulmate/l10n/skulmate_copy.dart';
import 'package:prepskul/features/skulmate/widgets/skulmate_import_action_grid.dart';

class SkulMateTutorComposer extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final VoidCallback onHoldStart;
  final VoidCallback onHoldEnd;
  final VoidCallback onMicTap;
  final bool busy;
  final bool recording;
  final bool speaking;
  final String? childId;
  final bool attachOpen;
  final VoidCallback onToggleAttach;
  final bool privacyMuted;

  const SkulMateTutorComposer({
    super.key,
    required this.controller,
    required this.onSend,
    required this.onHoldStart,
    required this.onHoldEnd,
    required this.onMicTap,
    required this.busy,
    required this.recording,
    required this.speaking,
    required this.attachOpen,
    required this.onToggleAttach,
    this.childId,
    this.privacyMuted = false,
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
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Semantics(
                button: true,
                label: privacyMuted
                    ? copy.tutorResumeListening
                    : speaking
                    ? copy.tutorInterruptMate
                    : copy.tutorPauseListening,
                child: Material(
                  color: privacyMuted
                      ? AppTheme.neutral300
                      : recording
                      ? AppTheme.skyBlue
                      : AppTheme.primaryColor,
                  shape: const CircleBorder(),
                  child: InkWell(
                    onTap: onMicTap,
                    customBorder: const CircleBorder(),
                    child: SizedBox(
                      width: 56,
                      height: 56,
                      child: Icon(
                        privacyMuted
                            ? PhosphorIcons.microphoneSlash
                            : PhosphorIcons.microphone,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: AppTheme.neutral200),
                  ),
                  padding: const EdgeInsets.fromLTRB(4, 4, 4, 4),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: copy.orImportMaterial,
                        onPressed: busy ? null : onToggleAttach,
                        icon: Icon(
                          attachOpen
                              ? PhosphorIcons.x
                              : PhosphorIcons.notePencil,
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
                            hintText: recording
                                ? copy.tutorListening
                                : copy.tutorComposerHint,
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
                            : const Icon(PhosphorIcons.arrowUp),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
