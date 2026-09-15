import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/features/skulmate/services/skulmate_tutor_voice_service.dart';

/// Recording / thinking / speaking — one pill for both directions.
class SkulMateVoicePill extends StatelessWidget {
  final TutorVoiceState state;

  const SkulMateVoicePill({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    if (state == TutorVoiceState.idle) return const SizedBox.shrink();
    final label = switch (state) {
      TutorVoiceState.recording => 'Listening',
      TutorVoiceState.thinking => 'Thinking',
      TutorVoiceState.speaking => 'Speaking',
      TutorVoiceState.idle => '',
    };
    final color = switch (state) {
      TutorVoiceState.recording => AppTheme.accentPink,
      TutorVoiceState.thinking => AppTheme.accentPurple,
      TutorVoiceState.speaking => AppTheme.skyBlue,
      TutorVoiceState.idle => AppTheme.neutral400,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
