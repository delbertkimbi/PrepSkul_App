import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/core/utils/safe_set_state.dart';

import '../services/skulmate_study_audio_service.dart';

/// Listen/read toggle + music mute for deck & tutor study screens.
class SkulMateStudyAudioControls extends StatefulWidget {
  /// When true, uses light icons/text for purple/dark headers.
  final bool onDark;

  const SkulMateStudyAudioControls({super.key, this.onDark = false});

  @override
  State<SkulMateStudyAudioControls> createState() =>
      _SkulMateStudyAudioControlsState();
}

class _SkulMateStudyAudioControlsState extends State<SkulMateStudyAudioControls> {
  final _audio = SkulMateStudyAudioService.instance;
  bool _listen = false;
  bool _music = true;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await _audio.ensureReady();
    if (!mounted) return;
    safeSetState(() {
      _listen = _audio.listenMode;
      _music = _audio.musicEnabled;
      _ready = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) return const SizedBox.shrink();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ChipToggle(
          label: _listen ? 'Listen' : 'Read',
          icon: _listen ? Icons.volume_up_rounded : Icons.menu_book_rounded,
          selected: _listen,
          onDark: widget.onDark,
          onTap: () async {
            await _audio.toggleListenMode();
            safeSetState(() => _listen = _audio.listenMode);
          },
        ),
        const SizedBox(width: 6),
        IconButton(
          tooltip: _music ? 'Mute music' : 'Unmute music',
          onPressed: () async {
            await _audio.toggleMusic();
            safeSetState(() => _music = _audio.musicEnabled);
          },
          icon: Icon(
            _music ? Icons.music_note_rounded : Icons.music_off_rounded,
            color: widget.onDark ? Colors.white : AppTheme.textMedium,
          ),
        ),
      ],
    );
  }
}

class _ChipToggle extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final bool onDark;
  final VoidCallback onTap;

  const _ChipToggle({
    required this.label,
    required this.icon,
    required this.selected,
    this.onDark = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: selected
                ? (onDark
                    ? Colors.white.withValues(alpha: 0.2)
                    : AppTheme.primaryColor.withValues(alpha: 0.1))
                : (onDark
                    ? Colors.white.withValues(alpha: 0.12)
                    : AppTheme.neutral100),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected
                  ? (onDark ? Colors.white : AppTheme.primaryColor)
                  : (onDark
                      ? Colors.white.withValues(alpha: 0.35)
                      : AppTheme.neutral200),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: onDark ? Colors.white : AppTheme.primaryColor,
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: onDark ? Colors.white : AppTheme.textDark,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
