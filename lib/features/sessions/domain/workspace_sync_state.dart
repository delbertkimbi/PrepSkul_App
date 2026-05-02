import 'dart:async';

/// Teaching workspace surface — orthogonal to Agora video lanes (dual-pane shell).
enum WorkspaceSurface {
  whiteboard,
  pdfDocument,
  lessonNotes,
}

/// Serializable packets for realtime workspace sync (Preply-style state-over-pixels).
/// Wire format: JSON map with required `"type"` discriminator.
sealed class WorkspacePacket {
  const WorkspacePacket();

  Map<String, dynamic> toJson();

  /// Parses backend / channel payloads; returns null if malformed or unknown type.
  static WorkspacePacket? tryParse(Map<String, dynamic>? json) {
    if (json == null) return null;
    final type = json['type'];
    if (type is! String) return null;
    switch (type) {
      case 'SCROLL_TO':
        final page = json['page'];
        final offset = json['offset'];
        if (page is! int || offset is! num) return null;
        return ScrollToPacket(page: page, offsetNormalized: offset.clamp(0.0, 1.0).toDouble());
      case 'TOOL_CHANGE':
        final surfaceName = json['surface'];
        if (surfaceName is! String) return null;
        WorkspaceSurface? surface;
        for (final s in WorkspaceSurface.values) {
          if (s.name == surfaceName) {
            surface = s;
            break;
          }
        }
        if (surface == null) return null;
        return ToolChangePacket(surface: surface);
      case 'SLIDE_INDEX':
        final index = json['index'];
        if (index is! int || index < 0) return null;
        return SlideIndexPacket(index: index);
      default:
        return null;
    }
  }
}

final class ScrollToPacket extends WorkspacePacket {
  const ScrollToPacket({
    required this.page,
    required this.offsetNormalized,
  });

  final int page;
  final double offsetNormalized;

  @override
  Map<String, dynamic> toJson() => {
        'type': 'SCROLL_TO',
        'page': page,
        'offset': offsetNormalized,
      };
}

final class ToolChangePacket extends WorkspacePacket {
  const ToolChangePacket({required this.surface});

  final WorkspaceSurface surface;

  @override
  Map<String, dynamic> toJson() => {
        'type': 'TOOL_CHANGE',
        'surface': surface.name,
      };
}

final class SlideIndexPacket extends WorkspacePacket {
  const SlideIndexPacket({required this.index});

  final int index;

  @override
  Map<String, dynamic> toJson() => {
        'type': 'SLIDE_INDEX',
        'index': index,
      };
}

/// Canonical workspace view model — drives IndexedStack / PDF / board UI later.
class WorkspaceViewState {
  const WorkspaceViewState({
    required this.surface,
    this.pdfPageIndex = 0,
    this.scrollOffsetNormalized = 0,
    this.revision = 0,
  });

  final WorkspaceSurface surface;
  final int pdfPageIndex;
  final double scrollOffsetNormalized;
  final int revision;

  WorkspaceViewState copyWith({
    WorkspaceSurface? surface,
    int? pdfPageIndex,
    double? scrollOffsetNormalized,
    int? revision,
  }) {
    return WorkspaceViewState(
      surface: surface ?? this.surface,
      pdfPageIndex: pdfPageIndex ?? this.pdfPageIndex,
      scrollOffsetNormalized:
          scrollOffsetNormalized ?? this.scrollOffsetNormalized,
      revision: revision ?? this.revision,
    );
  }
}

WorkspaceViewState reduceWorkspace(WorkspaceViewState current, WorkspacePacket packet) {
  final nextRevision = current.revision + 1;
  return switch (packet) {
    ToolChangePacket(:final surface) => current.copyWith(
        surface: surface,
        revision: nextRevision,
      ),
    SlideIndexPacket(:final index) => current.copyWith(
        pdfPageIndex: index,
        revision: nextRevision,
      ),
    ScrollToPacket(:final page, :final offsetNormalized) => current.copyWith(
        pdfPageIndex: page,
        scrollOffsetNormalized: offsetNormalized,
        revision: nextRevision,
      ),
  };
}

/// Broadcast hub for workspace packets — UI listens on [stateStream]; transport calls [applyRemote].
class WorkspaceSyncController {
  WorkspaceSyncController({
    WorkspaceViewState initial = const WorkspaceViewState(
      surface: WorkspaceSurface.whiteboard,
    ),
  }) : _state = initial;

  final StreamController<WorkspaceViewState> _controller =
      StreamController<WorkspaceViewState>.broadcast();

  WorkspaceViewState _state;

  WorkspaceViewState get state => _state;
  Stream<WorkspaceViewState> get stateStream => _controller.stream;

  /// Apply a parsed packet (from Realtime/WebSocket). Single reducer entry point.
  WorkspaceViewState applyPacket(WorkspacePacket packet) {
    _state = reduceWorkspace(_state, packet);
    _controller.add(_state);
    return _state;
  }

  /// Convenience for raw JSON payloads from the wire.
  WorkspaceViewState? applyRemoteJson(Map<String, dynamic>? json) {
    final packet = WorkspacePacket.tryParse(json);
    if (packet == null) return null;
    return applyPacket(packet);
  }

  Future<void> dispose() async {
    await _controller.close();
  }
}
