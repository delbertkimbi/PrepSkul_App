import 'package:flutter/material.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/core/widgets/alive_mate.dart';

import 'skulmate_mascot_media_widget.dart';

/// Live vector Mate with a paper ground shadow, matching the site SVG hop.
class SkulMateHeroMascot extends StatelessWidget {
  final SkulMateMascotState state;
  final double size;

  const SkulMateHeroMascot({
    super.key,
    this.state = SkulMateMascotState.encouraging,
    this.size = 72,
  });

  @override
  Widget build(BuildContext context) {
    final mood = moodForMascotState(state);
    return SizedBox(
      width: size,
      height: size + 12,
      child: Stack(
        alignment: Alignment.bottomCenter,
        clipBehavior: Clip.none,
        children: [
          Positioned(
            bottom: 2,
            child: Container(
              width: size * 0.42,
              height: 8,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                color: AppTheme.textDark.withValues(alpha: 0.12),
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: AliveMate(mood: mood, size: size),
          ),
        ],
      ),
    );
  }
}
