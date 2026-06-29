import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../l10n/skulmate_copy.dart';
import '../models/scroll_feed_item.dart';

/// TikTok-style full-bleed scroll card with right action rail.
class SkulMateImmersiveScrollPage extends StatelessWidget {
  final ScrollFeedItem item;
  final int index;
  final int total;
  final bool flipped;
  final bool musicEnabled;
  final bool soundsEnabled;
  final VoidCallback onFlip;
  final VoidCallback onKnew;
  final VoidCallback onAgain;
  final VoidCallback onToggleMusic;
  final VoidCallback onToggleSfx;
  final SkulMateCopy copy;

  const SkulMateImmersiveScrollPage({
    super.key,
    required this.item,
    required this.index,
    required this.total,
    required this.flipped,
    required this.musicEnabled,
    required this.soundsEnabled,
    required this.onFlip,
    required this.onKnew,
    required this.onAgain,
    required this.onToggleMusic,
    required this.onToggleSfx,
    required this.copy,
  });

  static const _gradients = [
    [Color(0xFF0A2A66), Color(0xFF1E4FA8), Color(0xFF3D7AE8)],
    [Color(0xFF1A0F3D), Color(0xFF4A1D7A), Color(0xFF8B3FD4)],
    [Color(0xFF0D3B2E), Color(0xFF1A6B52), Color(0xFF2DA87A)],
    [Color(0xFF3D1A0A), Color(0xFF8B3A1A), Color(0xFFE07A3A)],
  ];

  @override
  Widget build(BuildContext context) {
    final colors = _gradients[index % _gradients.length];
    final body = flipped ? item.definition : item.term;
    final hint = flipped ? copy.scrollTapTerm : copy.scrollTapReveal;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
      child: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  HapticFeedback.selectionClick();
                  onFlip();
                },
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 72, 88, 120),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (item.gameTitle?.isNotEmpty == true) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            item.gameTitle!,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      Text(
                        flipped ? copy.scrollRevealAction.toUpperCase() : 'TERM',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.1,
                          color: Colors.white.withValues(alpha: 0.65),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 260),
                            switchInCurve: Curves.easeOutCubic,
                            switchOutCurve: Curves.easeInCubic,
                            child: Text(
                              body,
                              key: ValueKey('$flipped-$body'),
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: flipped ? 22 : 28,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                height: 1.25,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Text(
                        hint,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              right: 12,
              bottom: 120,
              child: Column(
                children: [
                  _RailButton(
                    icon: musicEnabled
                        ? Icons.music_note_rounded
                        : Icons.music_off_rounded,
                    label: musicEnabled ? copy.scrollMusicOn : copy.scrollMusicOff,
                    onTap: onToggleMusic,
                  ),
                  const SizedBox(height: 14),
                  _RailButton(
                    icon: soundsEnabled
                        ? Icons.volume_up_rounded
                        : Icons.volume_off_rounded,
                    label: soundsEnabled ? copy.scrollSfxOn : copy.scrollSfxOff,
                    onTap: onToggleSfx,
                  ),
                  const SizedBox(height: 14),
                  _RailButton(
                    icon: flipped
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                    label: copy.scrollRevealAction,
                    onTap: onFlip,
                  ),
                  const SizedBox(height: 14),
                  _RailButton(
                    icon: Icons.check_circle_outline_rounded,
                    label: copy.scrollGotIt,
                    accent: const Color(0xFF4ADE80),
                    onTap: onKnew,
                  ),
                  const SizedBox(height: 14),
                  _RailButton(
                    icon: Icons.replay_rounded,
                    label: copy.scrollAgain,
                    accent: const Color(0xFFFBBF24),
                    onTap: onAgain,
                  ),
                ],
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 28,
              child: Column(
                children: [
                  Icon(
                    Icons.keyboard_arrow_up_rounded,
                    color: Colors.white.withValues(alpha: 0.55),
                    size: 28,
                  ),
                  Text(
                    copy.scrollSwipeHint,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.55),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${index + 1} / $total',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white.withValues(alpha: 0.75),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RailButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? accent;

  const _RailButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.28),
              shape: BoxShape.circle,
              border: Border.all(
                color: (accent ?? Colors.white).withValues(alpha: 0.35),
              ),
            ),
            child: Icon(icon, color: accent ?? Colors.white, size: 24),
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: 56,
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Colors.white.withValues(alpha: 0.9),
                height: 1.1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
