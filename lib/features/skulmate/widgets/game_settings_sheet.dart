import 'dart:async' show unawaited;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import '../models/game_model.dart';
import '../services/game_sound_service.dart';
import '../services/tts_service.dart';
import 'skulmate_sheet_scaffold.dart';
import 'skulmate_surface_styles.dart';

class GameSettingsSheet {
  static Future<void> show({
    required BuildContext context,
    required GameSoundService soundService,
    required GameType gameType,
    GameType? musicGameTypeOverride,
    String title = 'Game settings',
    TTSService? ttsService,
    bool isTTSEnabled = false,
    ValueChanged<bool>? onTTSToggled,
  }) async {
    await SkulMateSheetScaffold.show<void>(
      context,
      child: _GameSettingsSheetContent(
        title: title,
        soundService: soundService,
        gameType: gameType,
        musicGameTypeOverride: musicGameTypeOverride,
        ttsService: ttsService,
        isTTSEnabled: isTTSEnabled,
        onTTSToggled: onTTSToggled,
      ),
    );
  }
}

class _GameSettingsSheetContent extends StatefulWidget {
  final String title;
  final GameSoundService soundService;
  final GameType gameType;
  final GameType? musicGameTypeOverride;
  final TTSService? ttsService;
  final bool isTTSEnabled;
  final ValueChanged<bool>? onTTSToggled;

  const _GameSettingsSheetContent({
    required this.title,
    required this.soundService,
    required this.gameType,
    this.musicGameTypeOverride,
    this.ttsService,
    this.isTTSEnabled = false,
    this.onTTSToggled,
  });

  @override
  State<_GameSettingsSheetContent> createState() =>
      _GameSettingsSheetContentState();
}

class _GameSettingsSheetContentState extends State<_GameSettingsSheetContent> {
  late bool _ttsEnabled;

  @override
  void initState() {
    super.initState();
    _ttsEnabled = widget.isTTSEnabled;
  }

  GameSoundService get _sound => widget.soundService;
  TTSService? get _tts => widget.ttsService;

  Future<void> _toggleSounds(bool enabled) async {
    await _sound.toggleSounds(enabled);
    if (enabled) unawaited(_sound.playClick());
    if (mounted) setState(() {});
  }

  Future<void> _toggleMusic(bool enabled) async {
    await _sound.toggleMusic(enabled);
    if (enabled) {
      await _sound.playMusicForGame(
        widget.musicGameTypeOverride ?? widget.gameType,
      );
    }
    if (mounted) setState(() {});
  }

  void _toggleTts(bool enabled) {
    _tts?.setEnabled(enabled);
    widget.onTTSToggled?.call(enabled);
    setState(() => _ttsEnabled = enabled);
  }

  @override
  Widget build(BuildContext context) {
    final hasTts = _tts != null && widget.onTTSToggled != null;

    return SkulMateSheetScaffold(
      title: widget.title,
      showWandIcon: false,
      maxHeightFactor: hasTts ? 0.72 : 0.58,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        children: [
          Text(
            'Fine-tune sounds, music, and voice for your session.',
            style: GoogleFonts.poppins(
              fontSize: 13,
              height: 1.45,
              color: AppTheme.textMedium,
            ),
          ),
          const SizedBox(height: 16),
          _AudioSettingCard(
            icon: Icons.sports_esports_rounded,
            accent: AppTheme.accentOrange,
            accentLight: AppTheme.accentLightOrange,
            title: 'Game sounds',
            subtitle: 'Clicks, correct answers, and effects',
            enabled: _sound.soundsEnabled,
            volume: _sound.soundsVolume,
            onToggle: _toggleSounds,
            onVolumeChanged: (v) {
              unawaited(_sound.setSoundsVolume(v));
              setState(() {});
            },
            onVolumeSettled: () => unawaited(_sound.playClick()),
            presets: const [0.25, 0.5, 0.75, 1.0],
          ),
          const SizedBox(height: 12),
          _AudioSettingCard(
            icon: Icons.music_note_rounded,
            accent: AppTheme.accentPurple,
            accentLight: AppTheme.accentLightPurple,
            title: 'Background music',
            subtitle: 'Lo-fi tracks while you play',
            enabled: _sound.musicEnabled,
            volume: _sound.musicVolume,
            onToggle: _toggleMusic,
            onVolumeChanged: (v) {
              unawaited(_sound.setMusicVolume(v));
              setState(() {});
            },
            presets: const [0.25, 0.5, 0.75, 1.0],
          ),
          if (hasTts) ...[
            const SizedBox(height: 12),
            _AudioSettingCard(
              icon: Icons.record_voice_over_rounded,
              accent: AppTheme.skyBlue,
              accentLight: AppTheme.skyBlueLight,
              title: 'Read aloud',
              subtitle: 'Text-to-speech for questions and hints',
              enabled: _ttsEnabled,
              volume: _tts!.volume,
              onToggle: _toggleTts,
              onVolumeChanged: (v) {
                unawaited(_tts!.setVolume(v));
                setState(() {});
              },
              presets: const [0.25, 0.5, 0.75, 1.0],
            ),
          ],
        ],
      ),
    );
  }
}

class _AudioSettingCard extends StatelessWidget {
  final IconData icon;
  final Color accent;
  final Color accentLight;
  final String title;
  final String subtitle;
  final bool enabled;
  final double volume;
  final ValueChanged<bool> onToggle;
  final ValueChanged<double> onVolumeChanged;
  final VoidCallback? onVolumeSettled;
  final List<double> presets;

  const _AudioSettingCard({
    required this.icon,
    required this.accent,
    required this.accentLight,
    required this.title,
    required this.subtitle,
    required this.enabled,
    required this.volume,
    required this.onToggle,
    required this.onVolumeChanged,
    this.onVolumeSettled,
    required this.presets,
  });

  @override
  Widget build(BuildContext context) {
    final percent = (volume * 100).round();
    final muted = !enabled || volume <= 0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      decoration: SkulMateSurfaceStyles.homeCard(radius: 18).copyWith(
        color: enabled ? Colors.white : AppTheme.softBackground,
        border: Border.all(
          color: enabled
              ? accent.withValues(alpha: 0.28)
              : AppTheme.softBorder.withValues(alpha: 0.9),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: enabled ? accentLight : AppTheme.neutral100,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  size: 22,
                  color: enabled ? accent : AppTheme.textLight,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: enabled
                              ? AppTheme.textDark
                              : AppTheme.textMedium,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          height: 1.35,
                          color: AppTheme.textMedium,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Switch.adaptive(
                value: enabled,
                onChanged: onToggle,
                activeTrackColor: accent.withValues(alpha: 0.45),
                activeThumbColor: accent,
              ),
            ],
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 200),
            crossFadeState: enabled
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            sizeCurve: Curves.easeOutCubic,
            firstChild: Padding(
              padding: const EdgeInsets.only(left: 4, top: 14, right: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(
                        muted
                            ? Icons.volume_off_rounded
                            : Icons.volume_down_rounded,
                        size: 18,
                        color: AppTheme.textLight,
                      ),
                      Expanded(
                        child: SliderTheme(
                          data: _sliderTheme(accent),
                          child: Slider(
                            value: volume.clamp(0.0, 1.0),
                            min: 0,
                            max: 1,
                            divisions: 100,
                            onChanged: onVolumeChanged,
                            onChangeEnd: (_) => onVolumeSettled?.call(),
                          ),
                        ),
                      ),
                      Icon(
                        Icons.volume_up_rounded,
                        size: 18,
                        color: AppTheme.textLight,
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: accentLight,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '$percent%',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: accent,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: presets.map((preset) {
                      final label = '${(preset * 100).round()}%';
                      final selected = (volume - preset).abs() < 0.02;
                      return _VolumePresetChip(
                        label: label,
                        selected: selected,
                        accent: accent,
                        onTap: () {
                          onVolumeChanged(preset);
                          onVolumeSettled?.call();
                        },
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            secondChild: const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  SliderThemeData _sliderTheme(Color accent) {
    return SliderThemeData(
      trackHeight: 5,
      activeTrackColor: accent,
      inactiveTrackColor: AppTheme.neutral200,
      thumbColor: Colors.white,
      overlayColor: accent.withValues(alpha: 0.12),
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9),
      overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
      trackShape: const RoundedRectSliderTrackShape(),
    );
  }
}

class _VolumePresetChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  const _VolumePresetChip({
    required this.label,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? accent.withValues(alpha: 0.12) : AppTheme.neutral100,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? accent : AppTheme.textMedium,
            ),
          ),
        ),
      ),
    );
  }
}
