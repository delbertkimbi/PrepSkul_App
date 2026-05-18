import 'dart:async';

/// Teaching workspace surface — orthogonal to Agora video lanes (dual-pane shell).
enum WorkspaceSurface {
  /// Launcher tiles — tutor picks Board / Materials / Notes before drawing loads.
  launcher,
  whiteboard,
  pdfDocument,
  lessonNotes,
}

/// Upper bound so Realtime payloads and memory stay predictable.
const int kWorkspaceMaxWhiteboardStrokes = 140;

/// Per-stroke point cap (each point is two doubles).
const int kWorkspaceMaxPointsPerStroke = 600;

/// One polyline on the shared board (normalized coordinates).
class WhiteboardStroke {
  const WhiteboardStroke({
    required this.id,
    required this.points,
    this.colorArgb = 0xFF7DD3FC,
    this.widthNorm = 0.0045,
  });

  /// Flat [x0, y0, x1, y1, ...] in 0..1 relative to board width/height.
  final List<double> points;
  final String id;
  final int colorArgb;
  /// Stroke width as a fraction of `min(layoutWidth, layoutHeight)`.
  final double widthNorm;

  Map<String, dynamic> toJson() => {
        'id': id,
        'points': points,
        'color': colorArgb,
        'width': widthNorm,
      };

  static WhiteboardStroke? tryParse(Map<String, dynamic>? json) {
    if (json == null) return null;
    final id = json['id'];
    if (id is! String || id.isEmpty) return null;
    final raw = json['points'];
    if (raw is! List) return null;
    final out = <double>[];
    for (final item in raw) {
      if (item is num) {
        out.add(item.toDouble().clamp(0.0, 1.0));
      } else {
        return null;
      }
    }
    if (out.length < 4 || out.length.isOdd) return null;
    if (out.length > kWorkspaceMaxPointsPerStroke) {
      out.removeRange(kWorkspaceMaxPointsPerStroke, out.length);
    }
    return WhiteboardStroke(
      id: id,
      points: List<double>.unmodifiable(out),
      colorArgb: (json['color'] is int) ? json['color'] as int : 0xFF7DD3FC,
      widthNorm: (json['width'] is num)
          ? (json['width'] as num).toDouble().clamp(0.001, 0.05)
          : 0.0045,
    );
  }
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
      case 'STROKE_PATH':
        final strokeMap = json['stroke'];
        if (strokeMap is! Map) return null;
        final stroke = WhiteboardStroke.tryParse(Map<String, dynamic>.from(strokeMap));
        if (stroke == null) return null;
        return StrokePathPacket(stroke: stroke);
      case 'CLEAR_WHITEBOARD':
        return const ClearWhiteboardPacket();
      case 'AGENDA_STEP':
        final index = json['index'];
        if (index is! int || index < 0) return null;
        return AgendaStepPacket(index: index);
      case 'TEACHING_LANE':
        final open = json['open'];
        if (open is! bool) return null;
        return TeachingLaneOpenPacket(open: open);
      case 'UNDO_LAST_STROKE':
        return const UndoLastStrokePacket();
      case 'SET_MATERIALS_PDF':
        final url = json['url'];
        if (url is! String) return null;
        if (url.length > 4096) return null;
        return SetMaterialsPdfUrlPacket(url: url);
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

final class StrokePathPacket extends WorkspacePacket {
  const StrokePathPacket({required this.stroke});

  final WhiteboardStroke stroke;

  @override
  Map<String, dynamic> toJson() => {
        'type': 'STROKE_PATH',
        'stroke': stroke.toJson(),
      };
}

final class ClearWhiteboardPacket extends WorkspacePacket {
  const ClearWhiteboardPacket();

  @override
  Map<String, dynamic> toJson() => {'type': 'CLEAR_WHITEBOARD'};
}

final class AgendaStepPacket extends WorkspacePacket {
  const AgendaStepPacket({required this.index});

  final int index;

  @override
  Map<String, dynamic> toJson() => {
        'type': 'AGENDA_STEP',
        'index': index,
      };
}

/// Wide layout: show video + teaching rail only when [open] is true (tutor-driven; learners mirror).
final class TeachingLaneOpenPacket extends WorkspacePacket {
  const TeachingLaneOpenPacket({required this.open});

  final bool open;

  @override
  Map<String, dynamic> toJson() => {
        'type': 'TEACHING_LANE',
        'open': open,
      };
}

/// Tutor-only: remove the last whiteboard stroke (learners receive via broadcast).
final class UndoLastStrokePacket extends WorkspacePacket {
  const UndoLastStrokePacket();

  @override
  Map<String, dynamic> toJson() => {'type': 'UNDO_LAST_STROKE'};
}

/// Tutor sets or clears the shared materials PDF URL (signed Supabase URL or HTTPS).
final class SetMaterialsPdfUrlPacket extends WorkspacePacket {
  const SetMaterialsPdfUrlPacket({required this.url});

  final String url;

  @override
  Map<String, dynamic> toJson() => {
        'type': 'SET_MATERIALS_PDF',
        'url': url,
      };
}

/// Canonical workspace view model — drives IndexedStack / PDF / board UI later.
class WorkspaceViewState {
  WorkspaceViewState({
    required this.surface,
    this.pdfPageIndex = 0,
    this.scrollOffsetNormalized = 0,
    this.agendaStepIndex = 0,
    this.revision = 0,
    this.teachingLaneOpen = false,
    this.materialsPdfUrl,
    List<WhiteboardStroke>? whiteboardStrokes,
  }) : whiteboardStrokes = List<WhiteboardStroke>.unmodifiable(
          whiteboardStrokes ?? const <WhiteboardStroke>[],
        );

  final WorkspaceSurface surface;
  final int pdfPageIndex;
  final double scrollOffsetNormalized;
  final int agendaStepIndex;
  final int revision;
  /// When true on wide layouts, video shares the row with the workspace rail (tutor + learner).
  final bool teachingLaneOpen;
  /// Signed HTTPS URL for in-call PDF materials (session broadcast).
  final String? materialsPdfUrl;
  final List<WhiteboardStroke> whiteboardStrokes;

  WorkspaceViewState copyWith({
    WorkspaceSurface? surface,
    int? pdfPageIndex,
    double? scrollOffsetNormalized,
    int? agendaStepIndex,
    int? revision,
    bool? teachingLaneOpen,
    String? materialsPdfUrl,
    bool clearMaterialsPdfUrl = false,
    List<WhiteboardStroke>? whiteboardStrokes,
  }) {
    return WorkspaceViewState(
      surface: surface ?? this.surface,
      pdfPageIndex: pdfPageIndex ?? this.pdfPageIndex,
      scrollOffsetNormalized:
          scrollOffsetNormalized ?? this.scrollOffsetNormalized,
      agendaStepIndex: agendaStepIndex ?? this.agendaStepIndex,
      revision: revision ?? this.revision,
      teachingLaneOpen: teachingLaneOpen ?? this.teachingLaneOpen,
      materialsPdfUrl: clearMaterialsPdfUrl
          ? null
          : (materialsPdfUrl ?? this.materialsPdfUrl),
      whiteboardStrokes: whiteboardStrokes ?? this.whiteboardStrokes,
    );
  }
}

WorkspaceViewState _appendStroke(
  WorkspaceViewState current,
  WhiteboardStroke stroke,
  int nextRevision,
) {
  final next = List<WhiteboardStroke>.from(current.whiteboardStrokes)..add(stroke);
  while (next.length > kWorkspaceMaxWhiteboardStrokes) {
    next.removeAt(0);
  }
  return current.copyWith(
    whiteboardStrokes: List<WhiteboardStroke>.unmodifiable(next),
    revision: nextRevision,
  );
}

WorkspaceViewState _undoLastStroke(WorkspaceViewState current, int nextRevision) {
  if (current.whiteboardStrokes.isEmpty) {
    return current.copyWith(revision: nextRevision);
  }
  final next = List<WhiteboardStroke>.from(current.whiteboardStrokes)
    ..removeLast();
  return current.copyWith(
    whiteboardStrokes: List<WhiteboardStroke>.unmodifiable(next),
    revision: nextRevision,
  );
}

WorkspaceViewState _applyMaterialsPdfUrl(
  WorkspaceViewState current,
  String url,
  int nextRevision,
) {
  final t = url.trim();
  if (t.isEmpty) {
    return current.copyWith(
      clearMaterialsPdfUrl: true,
      pdfPageIndex: 0,
      revision: nextRevision,
    );
  }
  return current.copyWith(
    materialsPdfUrl: t,
    pdfPageIndex: 0,
    scrollOffsetNormalized: 0,
    revision: nextRevision,
  );
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
    StrokePathPacket(:final stroke) => _appendStroke(current, stroke, nextRevision),
    ClearWhiteboardPacket() => current.copyWith(
        whiteboardStrokes: const <WhiteboardStroke>[],
        revision: nextRevision,
      ),
    AgendaStepPacket(:final index) => current.copyWith(
        agendaStepIndex: index,
        revision: nextRevision,
      ),
    TeachingLaneOpenPacket(:final open) => current.copyWith(
        teachingLaneOpen: open,
        revision: nextRevision,
      ),
    UndoLastStrokePacket() => _undoLastStroke(current, nextRevision),
    SetMaterialsPdfUrlPacket(:final url) =>
        _applyMaterialsPdfUrl(current, url, nextRevision),
  };
}

/// Broadcast hub for workspace packets — UI listens on [stateStream]; transport calls [applyRemote].
class WorkspaceSyncController {
  WorkspaceSyncController({
    WorkspaceViewState? initial,
  }) : _state = initial ??
            WorkspaceViewState(surface: WorkspaceSurface.launcher);

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
