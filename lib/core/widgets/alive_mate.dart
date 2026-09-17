import 'package:flutter/material.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/features/primar/presentation/mascot.dart';

export 'package:prepskul/features/primar/presentation/mascot.dart' show Mate, Mood;

/// Marketplace Mate: the same vector rig as Primar, painted in the site SVG
/// colors, with the 0.9s hop that makes the mascot feel alive.
class AliveMate extends StatelessWidget {
  const AliveMate({
    super.key,
    required this.mood,
    this.size = 96,
    this.flip = false,
  });

  final Mood mood;
  final double size;
  final bool flip;

  /// Body fill from the site `MatePoint` SVG.
  static const bodyBlue = Color(0xFF1B6FCF);

  /// Belly fill from the site `MatePoint` SVG.
  static const bellyTeal = Color(0xFF3DB8C4);

  @override
  Widget build(BuildContext context) {
    return Mate(
      mood: mood,
      size: size,
      flip: flip,
      keepHopping: true,
      ink: AppTheme.primaryColor,
      body: bodyBlue,
      belly: bellyTeal,
      accent: AppTheme.softYellow,
    );
  }
}
