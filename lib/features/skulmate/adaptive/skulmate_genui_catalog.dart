import 'package:flutter/material.dart';
import 'package:genui/genui.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

import 'skulmate_adaptive_data_model.dart';
import 'skulmate_adaptive_surface.dart';
import 'skulmate_adaptive_types.dart';
import 'skulmate_genui_host.dart';

/// Catalog ID for SkulMate A2UI surfaces (genui v0.9).
const String skulMateCatalogId = 'com.prepskul.skulmate_catalog.v1';

/// Custom genui catalog: scroll cards, flashcards, and future drill surfaces.
abstract final class SkulMateGenuiCatalog {
  SkulMateGenuiCatalog._();

  static Catalog asCatalog() {
    return Catalog(
      [
        skulMateScrollCard,
        skulMateFlashcard,
      ],
      catalogId: skulMateCatalogId,
    );
  }

  static final CatalogItem skulMateScrollCard = CatalogItem(
    name: 'SkulMateScrollCard',
    dataSchema: S.object(
      description: 'Vertical scroll revision card with term/definition flip.',
      properties: {
        'term': S.string(description: 'Front side text.'),
        'definition': S.string(description: 'Back side text.'),
        'gameTitle': S.string(description: 'Optional game title.'),
        'flipped': S.boolean(description: 'Whether the card shows the definition.'),
        'tapHint': S.string(description: 'Hint when term is visible.'),
        'revealHint': S.string(description: 'Hint when definition is visible.'),
      },
    ),
    widgetBuilder: (ctx) => _SkulMateGenuiBridge(
      ctx: ctx,
      kind: SkulMateCatalogKind.scrollCard,
    ),
  );

  static final CatalogItem skulMateFlashcard = CatalogItem(
    name: 'SkulMateFlashcard',
    dataSchema: S.object(
      description: 'Flashcard drill surface with term/definition flip.',
      properties: {
        'term': S.string(description: 'Front side text.'),
        'definition': S.string(description: 'Back side text.'),
        'gameTitle': S.string(description: 'Optional game title.'),
        'flipped': S.boolean(description: 'Whether the card shows the definition.'),
      },
    ),
    widgetBuilder: (ctx) => _SkulMateGenuiBridge(
      ctx: ctx,
      kind: SkulMateCatalogKind.flashcard,
    ),
  );
}

/// Bridges genui [DataContext] to [SkulMateAdaptiveSurface] widgets.
class _SkulMateGenuiBridge extends StatefulWidget {
  final CatalogItemContext ctx;
  final SkulMateCatalogKind kind;

  const _SkulMateGenuiBridge({
    required this.ctx,
    required this.kind,
  });

  @override
  State<_SkulMateGenuiBridge> createState() => _SkulMateGenuiBridgeState();
}

class _SkulMateGenuiBridgeState extends State<_SkulMateGenuiBridge> {
  late final SkulMateAdaptiveDataModel _dataModel;
  final List<ValueNotifier<Object?>> _notifiers = [];

  @override
  void initState() {
    super.initState();
    _dataModel = SkulMateAdaptiveDataModel();
    _bindDataPaths();
    _syncFromContext();
  }

  @override
  void didUpdateWidget(covariant _SkulMateGenuiBridge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ctx.surfaceId != widget.ctx.surfaceId) {
      for (final n in _notifiers) {
        n.removeListener(_onDataChanged);
        n.dispose();
      }
      _notifiers.clear();
      _bindDataPaths();
    }
    _syncFromContext();
  }

  @override
  void dispose() {
    for (final n in _notifiers) {
      n.removeListener(_onDataChanged);
      n.dispose();
    }
    _dataModel.dispose();
    super.dispose();
  }

  void _bindDataPaths() {
    final dc = widget.ctx.dataContext;
    for (final key in _watchedKeys) {
      final notifier = dc.subscribe<Object?>(DataPath(key));
      notifier.addListener(_onDataChanged);
      _notifiers.add(notifier);
    }
  }

  void _onDataChanged() {
    _syncFromContext();
    if (mounted) setState(() {});
  }

  List<String> get _watchedKeys => const [
        'term',
        'definition',
        'gameTitle',
        'flipped',
        'tapHint',
        'revealHint',
      ];

  void _syncFromContext() {
    final dc = widget.ctx.dataContext;
    _dataModel.applyAll({
      'term': dc.getValue<String>(DataPath('term')) ?? '',
      'definition': dc.getValue<String>(DataPath('definition')) ?? '',
      'gameTitle': dc.getValue<String>(DataPath('gameTitle')) ?? '',
      'flipped': dc.getValue<bool>(DataPath('flipped')) ?? false,
      'tapHint': dc.getValue<String>(DataPath('tapHint')),
      'revealHint': dc.getValue<String>(DataPath('revealHint')),
    });
  }

  @override
  Widget build(BuildContext context) {
    final actions =
        SkulMateGenuiScope.of(context)?.host.actionsFor(widget.ctx.surfaceId);
    final spec = SkulMateAdaptiveSurfaceSpec(
      surfaceId: widget.ctx.surfaceId,
      kind: widget.kind,
      initialData: const {},
    );

    return SkulMateAdaptiveSurface(
      spec: spec,
      dataModel: _dataModel,
      onFlip: actions?.onFlip,
      onPrimaryAction: actions?.onPrimary,
      onSecondaryAction: actions?.onSecondary,
      primaryLabel: actions?.primaryLabel,
      secondaryLabel: actions?.secondaryLabel,
    );
  }
}
