import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import '../models/skulmate_character_model.dart';
import 'skulmate_character_widget.dart';
import 'skulmate_mascot_media_widget.dart';

enum CompanionTone { neutral, tip, success, warning }

class SkulMateCompanionBanner extends StatefulWidget {
  final String message;
  final CompanionTone tone;
  final String label;
  final SkulMateCharacter? character;

  /// Default true: uses a fixed brand mascot identity for guidance.
  final bool useBrandMascot;

  /// Adds celebratory spark animation around mascot.
  final bool celebrate;

  const SkulMateCompanionBanner({
    super.key,
    required this.message,
    this.tone = CompanionTone.neutral,
    this.label = 'SkulMate',
    this.character,
    this.useBrandMascot = true,
    this.celebrate = false,
  });

  @override
  State<SkulMateCompanionBanner> createState() => _SkulMateCompanionBannerState();
}

class _SkulMateCompanionBannerState extends State<SkulMateCompanionBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final toneColors = _toneColors(widget.tone);
    final mascotState = switch (widget.tone) {
      CompanionTone.success => SkulMateMascotState.celebration,
      CompanionTone.warning => SkulMateMascotState.encouraging,
      CompanionTone.tip => SkulMateMascotState.thinking,
      CompanionTone.neutral => SkulMateMascotState.neutral,
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            toneColors.$1.withValues(alpha: 0.18),
            toneColors.$2.withValues(alpha: 0.11),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: toneColors.$1.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.45),
                ),
                child: ClipOval(
                  child: widget.useBrandMascot || widget.character == null
                      ? SkulMateMascotMediaWidget(
                          state: mascotState,
                          useLandscapeFrame: false,
                          borderRadius: 999,
                          autoplay: true,
                          preferStaticImage: false,
                          videoVolume: 0.0,
                        )
                      : SkulMateCharacterWidget(
                          character: widget.character!,
                          size: 40,
                          animated: false,
                        ),
                ),
              ),
              if (widget.celebrate) ..._buildCelebrationSparkles(),
            ],
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.label,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textDark,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  widget.message,
                  style: GoogleFonts.poppins(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textDark,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildCelebrationSparkles() {
    const positions = [
      Offset(-4, -6),
      Offset(28, -10),
      Offset(34, 10),
    ];
    return List<Widget>.generate(positions.length, (index) {
      final base = positions[index];
      return AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final v = _controller.value;
          final drift = math.sin((v + index * 0.22) * math.pi * 2) * 1.4;
          return Positioned(
            left: base.dx + drift,
            top: base.dy - drift * 0.5,
            child: Opacity(
              opacity: 0.45 + (0.45 * (1 - v)),
              child: Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.softYellow,
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.softYellow.withValues(alpha: 0.5),
                      blurRadius: 3,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    });
  }

  (Color, Color) _toneColors(CompanionTone tone) {
    switch (tone) {
      case CompanionTone.tip:
        return (AppTheme.primaryColor, AppTheme.skyBlue);
      case CompanionTone.success:
        return (AppTheme.accentGreen, AppTheme.skyBlue);
      case CompanionTone.warning:
        return (AppTheme.softYellow, AppTheme.accentOrange);
      case CompanionTone.neutral:
        return (AppTheme.primaryLight, AppTheme.primaryColor);
    }
  }
}
