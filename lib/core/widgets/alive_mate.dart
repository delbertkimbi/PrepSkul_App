import 'package:flutter/material.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/features/primar/presentation/mascot.dart';

export 'package:prepskul/features/primar/presentation/mascot.dart'
    show Mate, Mood;

/// Marketplace Mate: the same vector rig as Primar, painted in the site colors.
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

  /// Shared PrepSkul site palette. Keep app Mate identical to the website.
  @override
  Widget build(BuildContext context) {
    return Mate(
      mood: mood,
      size: size,
      flip: flip,
      // Let Mate react to what the learner does. A permanent hop makes him
      // jittery and competes with the lesson; celebrations are event-driven.
      keepHopping: false,
      ink: AppTheme.primaryColor,
      body: AppTheme.mateBodyBlue,
      belly: AppTheme.mateBellyTeal,
      accent: AppTheme.mateAntennaYellow,
    );
  }
}
