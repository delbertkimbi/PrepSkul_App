import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/features/skulmate/services/skulmate_tutor_voice_service.dart';
import 'package:prepskul/features/skulmate/l10n/skulmate_copy.dart';

/// Recording / thinking / speaking — one pill for both directions.
class SkulMateVoicePill extends StatelessWidget {
  final TutorVoiceState state;

  const SkulMateVoicePill({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    if (state == TutorVoiceState.idle) return const SizedBox.shrink();
    final copy = SkulMateCopy.of(context);
    final label = switch (state) {
      TutorVoiceState.recording => copy.isFrench ? 'Je t’écoute' : 'Listening',
      TutorVoiceState.thinking => copy.isFrench ? 'Je réfléchis' : 'Thinking',
      TutorVoiceState.speaking => copy.isFrench ? 'Je parle' : 'Speaking',
      TutorVoiceState.idle => '',
    };
    final color = switch (state) {
      TutorVoiceState.recording => AppTheme.skyBlue,
      TutorVoiceState.thinking => AppTheme.softYellow,
      TutorVoiceState.speaking => AppTheme.mateBellyTeal,
      TutorVoiceState.idle => AppTheme.neutral400,
    };
    return Semantics(
      liveRegion: true,
      label: label,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: state == TutorVoiceState.recording
                  ? [BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 7)]
                  : const [],
            ),
          ),
          const SizedBox(width: 7),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 160),
            child: Text(
              label,
              key: ValueKey(label),
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppTheme.textMedium,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
