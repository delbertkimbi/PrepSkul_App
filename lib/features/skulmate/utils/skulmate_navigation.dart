import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/navigation/main_navigation_scope.dart';
import '../../../core/navigation/student_tab_index.dart';
import '../services/game_sound_service.dart';
import '../widgets/skulmate_surface_styles.dart';

/// Shared navigation helpers for SkulMate game flows.
class SkulMateNavigation {
  SkulMateNavigation._();

  /// Pop one route (game screen back to SkulMate home).
  static void popGame(BuildContext context, {dynamic result}) {
    if (!context.mounted) return;
    Navigator.of(context).pop(result);
    SystemChrome.setSystemUIOverlayStyle(
      SkulMateSurfaceStyles.lightStatusBarOverlay,
    );
  }

  /// Leave game/results stack and return to SkulMate tab on main shell.
  static void exitToSkulMateHome(BuildContext context) {
    if (!context.mounted) return;
    unawaited(GameSoundService().stopMusic(force: true));
    Navigator.of(context).popUntil((route) => route.isFirst);
    MainNavigationScope.maybeOf(context)
        ?.switchTab(StudentTabIndex.skulMate);
    SystemChrome.setSystemUIOverlayStyle(
      SkulMateSurfaceStyles.lightStatusBarOverlay,
    );
  }

  static Widget gameBackButton(
    BuildContext context, {
    required VoidCallback onPressed,
  }) {
    return IconButton(
      icon: const Icon(Icons.arrow_back, color: Colors.white),
      onPressed: onPressed,
    );
  }
}
