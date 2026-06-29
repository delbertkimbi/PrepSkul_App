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

  static void _applyStatusBar() {
    SystemChrome.setSystemUIOverlayStyle(
      SkulMateSurfaceStyles.lightStatusBarOverlay,
    );
  }

  /// Pop one route (game screen back to SkulMate home / deck hub).
  static Future<void> popGame(BuildContext context, {dynamic result}) async {
    if (!context.mounted) return;
    final navigator = Navigator.of(context);
    unawaited(GameSoundService().stopMusic(force: true));
    if (navigator.canPop()) {
      navigator.pop(result);
    }
    _applyStatusBar();
  }

  /// Leave game stack and focus the SkulMate tab on the main shell.
  static Future<void> exitToSkulMateHome(BuildContext context) async {
    if (!context.mounted) return;
    final navigator = Navigator.of(context);
    final scope = MainNavigationScope.maybeOf(context);
    unawaited(GameSoundService().stopMusic(force: true));
    if (navigator.canPop()) {
      navigator.popUntil((route) => route.isFirst);
    }
    scope?.switchTab(StudentTabIndex.skulMate);
    _applyStatusBar();
  }

  /// Stop audio, persist if needed, then pop one level — preferred game quit path.
  static Future<void> quitGame(
    BuildContext context, {
    Future<void> Function()? beforePop,
    bool toSkulMateTab = false,
  }) async {
    if (!context.mounted) return;
    unawaited(GameSoundService().stopMusic(force: true));
    if (beforePop != null) {
      await beforePop();
    }
    if (!context.mounted) return;
    if (toSkulMateTab) {
      await exitToSkulMateHome(context);
    } else {
      await popGame(context);
    }
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
