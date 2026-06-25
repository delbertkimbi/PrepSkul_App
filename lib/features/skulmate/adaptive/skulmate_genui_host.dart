import 'package:flutter/widgets.dart';
import 'package:genui/genui.dart';

import 'game_model_a2ui_adapter.dart';
import 'skulmate_adaptive_types.dart';
import 'skulmate_genui_catalog.dart';

/// User-facing action callbacks bound to a genui surface.
class SkulMateGenuiActions {
  final VoidCallback? onFlip;
  final VoidCallback? onPrimary;
  final VoidCallback? onSecondary;
  final String? primaryLabel;
  final String? secondaryLabel;

  const SkulMateGenuiActions({
    this.onFlip,
    this.onPrimary,
    this.onSecondary,
    this.primaryLabel,
    this.secondaryLabel,
  });
}

/// Owns a [SurfaceController] and applies local A2UI messages (no LLM).
class SkulMateGenuiHost {
  SkulMateGenuiHost()
      : controller = SurfaceController(
          catalogs: [SkulMateGenuiCatalog.asCatalog()],
        );

  final SurfaceController controller;
  final Map<String, SkulMateGenuiActions> _actions = {};

  void dispose() {
    controller.dispose();
  }

  void setActions(String surfaceId, SkulMateGenuiActions actions) {
    _actions[surfaceId] = actions;
  }

  SkulMateGenuiActions? actionsFor(String surfaceId) => _actions[surfaceId];

  void mountFromSpec(
    SkulMateAdaptiveSurfaceSpec spec, {
    SkulMateGenuiActions? actions,
  }) {
    if (actions != null) {
      setActions(spec.surfaceId, actions);
    }
    for (final message in GameModelA2uiAdapter.messagesForSpec(spec)) {
      controller.handleMessage(message);
    }
  }

  void applyMessages(Iterable<A2uiMessage> messages) {
    for (final message in messages) {
      controller.handleMessage(message);
    }
  }

  void updateData(String surfaceId, Map<String, Object?> data) {
    controller.handleMessage(
      GameModelA2uiAdapter.dataPatch(surfaceId, data),
    );
  }
}

/// Provides [SkulMateGenuiHost] action lookup to catalog widgets.
class SkulMateGenuiScope extends InheritedWidget {
  final SkulMateGenuiHost host;

  const SkulMateGenuiScope({
    super.key,
    required this.host,
    required super.child,
  });

  static SkulMateGenuiScope? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<SkulMateGenuiScope>();
  }

  SkulMateGenuiActions? actionsFor(String surfaceId) =>
      host.actionsFor(surfaceId);

  @override
  bool updateShouldNotify(SkulMateGenuiScope oldWidget) =>
      oldWidget.host != host;
}
