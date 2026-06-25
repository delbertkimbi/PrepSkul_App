import 'package:flutter/material.dart';
import 'package:genui/genui.dart';

import '../l10n/skulmate_copy.dart';
import '../models/scroll_feed_item.dart';
import 'skulmate_adaptive_factory.dart';
import 'skulmate_genui_host.dart';

/// Renders one SkulMate genui surface inside a [SkulMateGenuiHost].
class SkulMateGenuiSurfaceView extends StatelessWidget {
  final SkulMateGenuiHost host;
  final String surfaceId;

  const SkulMateGenuiSurfaceView({
    super.key,
    required this.host,
    required this.surfaceId,
  });

  @override
  Widget build(BuildContext context) {
    return SkulMateGenuiScope(
      host: host,
      child: Surface(
        surfaceContext: host.controller.contextFor(surfaceId),
      ),
    );
  }
}

/// Scroll-feed card powered by genui + A2UI (Pass 2).
class SkulMateGenuiScrollCard extends StatefulWidget {
  final ScrollFeedItem item;
  final bool flipped;
  final VoidCallback onFlip;
  final VoidCallback onKnew;
  final VoidCallback onAgain;
  final SkulMateCopy copy;

  const SkulMateGenuiScrollCard({
    super.key,
    required this.item,
    required this.flipped,
    required this.onFlip,
    required this.onKnew,
    required this.onAgain,
    required this.copy,
  });

  @override
  State<SkulMateGenuiScrollCard> createState() =>
      _SkulMateGenuiScrollCardState();
}

class _SkulMateGenuiScrollCardState extends State<SkulMateGenuiScrollCard> {
  late final SkulMateGenuiHost _host;
  late String _surfaceId;

  @override
  void initState() {
    super.initState();
    _host = SkulMateGenuiHost();
    _mount();
  }

  @override
  void didUpdateWidget(covariant SkulMateGenuiScrollCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item != widget.item ||
        oldWidget.flipped != widget.flipped ||
        oldWidget.copy != widget.copy) {
      _patchData();
    }
    if (oldWidget.onFlip != widget.onFlip ||
        oldWidget.onKnew != widget.onKnew ||
        oldWidget.onAgain != widget.onAgain ||
        oldWidget.copy != widget.copy) {
      _bindActions();
    }
  }

  @override
  void dispose() {
    _host.dispose();
    super.dispose();
  }

  void _mount() {
    final spec = SkulMateAdaptiveFactory.scrollCard(
      item: widget.item,
      flipped: widget.flipped,
      tapHint: widget.copy.scrollTapReveal,
      revealHint: widget.copy.scrollTapTerm,
    );
    _surfaceId = spec.surfaceId;
    _host.mountFromSpec(spec, actions: _actions());
  }

  void _patchData() {
    final spec = SkulMateAdaptiveFactory.scrollCard(
      item: widget.item,
      flipped: widget.flipped,
      tapHint: widget.copy.scrollTapReveal,
      revealHint: widget.copy.scrollTapTerm,
    );
    _host.updateData(_surfaceId, spec.initialData);
  }

  void _bindActions() {
    _host.setActions(_surfaceId, _actions());
  }

  SkulMateGenuiActions _actions() {
    return SkulMateGenuiActions(
      onFlip: widget.onFlip,
      onPrimary: widget.onKnew,
      onSecondary: widget.onAgain,
      primaryLabel: widget.copy.scrollGotIt,
      secondaryLabel: widget.copy.scrollAgain,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SkulMateGenuiSurfaceView(
      host: _host,
      surfaceId: _surfaceId,
    );
  }
}
