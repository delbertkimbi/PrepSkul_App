import 'dart:async' show unawaited;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import '../models/game_model.dart';
import '../services/game_sound_service.dart';
import '../services/tts_service.dart';

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
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, modalSetState) {
            final mq = MediaQuery.of(context);
            return SafeArea(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: mq.size.height * 0.88),
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    8,
                    16,
                    16 + mq.viewInsets.bottom,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textDark,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text('Game sounds', style: GoogleFonts.poppins()),
                        value: soundService.soundsEnabled,
                        onChanged: (v) async {
                          await soundService.toggleSounds(v);
                          modalSetState(() {});
                        },
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'SFX volume: ${(soundService.soundsVolume * 100).round()}%',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textMedium,
                              ),
                            ),
                            Slider(
                              value: soundService.soundsVolume,
                              min: 0,
                              max: 1,
                              divisions: 100,
                              onChanged: soundService.soundsEnabled
                                  ? (v) {
                                      unawaited(soundService.setSoundsVolume(v));
                                      modalSetState(() {});
                                    }
                                  : null,
                            ),
                          ],
                        ),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text('Music', style: GoogleFonts.poppins()),
                        value: soundService.musicEnabled,
                        onChanged: (v) async {
                          await soundService.toggleMusic(v);
                          if (v) {
                            await soundService.playMusicForGame(
                              musicGameTypeOverride ?? gameType,
                            );
                          }
                          modalSetState(() {});
                        },
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Music volume: ${(soundService.musicVolume * 100).round()}%',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textMedium,
                              ),
                            ),
                            Slider(
                              value: soundService.musicVolume,
                              min: 0,
                              max: 1,
                              divisions: 100,
                              onChanged: soundService.musicEnabled
                                  ? (v) {
                                      unawaited(soundService.setMusicVolume(v));
                                      modalSetState(() {});
                                    }
                                  : null,
                            ),
                          ],
                        ),
                      ),
                      if (ttsService != null && onTTSToggled != null) ...[
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            'Read aloud (TTS)',
                            style: GoogleFonts.poppins(),
                          ),
                          value: isTTSEnabled,
                          onChanged: (v) {
                            ttsService.setEnabled(v);
                            onTTSToggled(v);
                            modalSetState(() {});
                          },
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Voice volume: ${(ttsService.volume * 100).round()}%',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textMedium,
                                ),
                              ),
                              Slider(
                                value: ttsService.volume,
                                min: 0,
                                max: 1,
                                divisions: 100,
                                onChanged: isTTSEnabled
                                    ? (v) {
                                        unawaited(ttsService.setVolume(v));
                                        modalSetState(() {});
                                      }
                                    : null,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
