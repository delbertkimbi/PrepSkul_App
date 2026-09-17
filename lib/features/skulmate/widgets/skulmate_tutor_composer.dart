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
  final VoidCallback onMicTap;
  final bool busy;
  final bool recording;
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
              GestureDetector(
                onTap: onMicTap,
                child: Container(
                  width: 56,
                  height: 56,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: privacyMuted
                        ? AppTheme.neutral300
                        : recording
                            ? AppTheme.skyBlue
                            : AppTheme.primaryColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: (privacyMuted
                                ? AppTheme.neutral300
                                : AppTheme.skyBlue)
                            .withValues(alpha: 0.45),
                        offset: const Offset(0, 4),
                        blurRadius: privacyMuted ? 0 : 12,
                      ),
                    ],
                  ),
                  child: Icon(
                    privacyMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  decoration: SkulMateSurfaceStyles.homeCard(radius: 22),
                  padding: const EdgeInsets.fromLTRB(4, 4, 4, 4),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: copy.orImportMaterial,
                        onPressed: busy ? null : onToggleAttach,
                        icon: Icon(
                          attachOpen
                              ? Icons.close_rounded
                              : Icons.note_add_outlined,
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
                            : const Icon(Icons.arrow_upward_rounded),
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
