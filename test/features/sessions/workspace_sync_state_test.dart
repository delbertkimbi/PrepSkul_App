import 'package:flutter_test/flutter_test.dart';
import 'package:prepskul/features/sessions/domain/workspace_sync_state.dart';

void main() {
  group('WorkspacePacket.tryParse', () {
    test('parses SCROLL_TO', () {
      final p = WorkspacePacket.tryParse({
        'type': 'SCROLL_TO',
        'page': 2,
        'offset': 0.45,
      });
      expect(p, isA<ScrollToPacket>());
      final s = p! as ScrollToPacket;
      expect(s.page, 2);
      expect(s.offsetNormalized, 0.45);
    });

    test('parses TOOL_CHANGE', () {
      final p = WorkspacePacket.tryParse({
        'type': 'TOOL_CHANGE',
        'surface': 'pdfDocument',
      });
      expect(p, isA<ToolChangePacket>());
      expect((p! as ToolChangePacket).surface, WorkspaceSurface.pdfDocument);
    });

    test('parses SLIDE_INDEX', () {
      final p = WorkspacePacket.tryParse({
        'type': 'SLIDE_INDEX',
        'index': 7,
      });
      expect(p, isA<SlideIndexPacket>());
      expect((p! as SlideIndexPacket).index, 7);
    });

    test('parses STROKE_PATH', () {
      final p = WorkspacePacket.tryParse({
        'type': 'STROKE_PATH',
        'stroke': {
          'id': 's1',
          'points': [0.0, 0.0, 1.0, 1.0],
          'color': 0xFF00FF00,
          'width': 0.01,
        },
      });
      expect(p, isA<StrokePathPacket>());
      final st = (p! as StrokePathPacket).stroke;
      expect(st.id, 's1');
      expect(st.points, [0.0, 0.0, 1.0, 1.0]);
    });

    test('parses CLEAR_WHITEBOARD', () {
      final p = WorkspacePacket.tryParse({'type': 'CLEAR_WHITEBOARD'});
      expect(p, isA<ClearWhiteboardPacket>());
    });

    test('parses AGENDA_STEP', () {
      final p = WorkspacePacket.tryParse({'type': 'AGENDA_STEP', 'index': 2});
      expect(p, isA<AgendaStepPacket>());
      expect((p! as AgendaStepPacket).index, 2);
    });

    test('parses TEACHING_LANE', () {
      final p = WorkspacePacket.tryParse({'type': 'TEACHING_LANE', 'open': true});
      expect(p, isA<TeachingLaneOpenPacket>());
      expect((p! as TeachingLaneOpenPacket).open, isTrue);
      final p2 = WorkspacePacket.tryParse({'type': 'TEACHING_LANE', 'open': false});
      expect((p2! as TeachingLaneOpenPacket).open, isFalse);
    });

    test('parses UNDO_LAST_STROKE', () {
      final p = WorkspacePacket.tryParse({'type': 'UNDO_LAST_STROKE'});
      expect(p, isA<UndoLastStrokePacket>());
    });

    test('parses SET_MATERIALS_PDF', () {
      final p = WorkspacePacket.tryParse({
        'type': 'SET_MATERIALS_PDF',
        'url': 'https://example.com/lesson.pdf',
      });
      expect(p, isA<SetMaterialsPdfUrlPacket>());
      expect((p! as SetMaterialsPdfUrlPacket).url, 'https://example.com/lesson.pdf');
    });

    test('returns null for unknown or invalid payloads', () {
      expect(WorkspacePacket.tryParse(null), isNull);
      expect(WorkspacePacket.tryParse({}), isNull);
      expect(WorkspacePacket.tryParse({'type': 'UNKNOWN'}), isNull);
      expect(
        WorkspacePacket.tryParse({
          'type': 'SCROLL_TO',
          'page': 'x',
          'offset': 0,
        }),
        isNull,
      );
    });
  });

  group('reduceWorkspace', () {
    test('applies packets in order and bumps revision', () {
      var s = WorkspaceViewState(surface: WorkspaceSurface.whiteboard);
      s = reduceWorkspace(s, const ToolChangePacket(surface: WorkspaceSurface.pdfDocument));
      expect(s.surface, WorkspaceSurface.pdfDocument);
      expect(s.revision, 1);

      s = reduceWorkspace(s, const SlideIndexPacket(index: 3));
      expect(s.pdfPageIndex, 3);
      expect(s.revision, 2);

      s = reduceWorkspace(
        s,
        const ScrollToPacket(page: 4, offsetNormalized: 0.2),
      );
      expect(s.pdfPageIndex, 4);
      expect(s.scrollOffsetNormalized, 0.2);
      expect(s.revision, 3);
    });

    test('appends and clears whiteboard strokes', () {
      var s = WorkspaceViewState(surface: WorkspaceSurface.whiteboard);
      final stroke = WhiteboardStroke(
        id: 'a',
        points: const [0.1, 0.1, 0.2, 0.2],
      );
      s = reduceWorkspace(s, StrokePathPacket(stroke: stroke));
      expect(s.whiteboardStrokes.length, 1);
      expect(s.whiteboardStrokes.single.id, 'a');
      s = reduceWorkspace(s, const ClearWhiteboardPacket());
      expect(s.whiteboardStrokes, isEmpty);
    });

    test('updates agenda step index', () {
      var s = WorkspaceViewState(surface: WorkspaceSurface.whiteboard);
      s = reduceWorkspace(s, const AgendaStepPacket(index: 1));
      expect(s.agendaStepIndex, 1);
    });

    test('teaching lane open toggles', () {
      var s = WorkspaceViewState(surface: WorkspaceSurface.launcher);
      expect(s.teachingLaneOpen, false);
      s = reduceWorkspace(s, const TeachingLaneOpenPacket(open: true));
      expect(s.teachingLaneOpen, isTrue);
      s = reduceWorkspace(s, const TeachingLaneOpenPacket(open: false));
      expect(s.teachingLaneOpen, isFalse);
    });

    test('undo last stroke removes most recent path', () {
      var s = WorkspaceViewState(surface: WorkspaceSurface.whiteboard);
      s = reduceWorkspace(
        s,
        StrokePathPacket(
          stroke: WhiteboardStroke(
            id: 'a',
            points: const [0.0, 0.0, 1.0, 1.0],
          ),
        ),
      );
      s = reduceWorkspace(
        s,
        StrokePathPacket(
          stroke: WhiteboardStroke(
            id: 'b',
            points: const [0.2, 0.2, 0.3, 0.3],
          ),
        ),
      );
      expect(s.whiteboardStrokes.length, 2);
      s = reduceWorkspace(s, const UndoLastStrokePacket());
      expect(s.whiteboardStrokes.length, 1);
      expect(s.whiteboardStrokes.single.id, 'a');
    });

    test('SET_MATERIALS_PDF stores URL and resets page', () {
      var s = WorkspaceViewState(
        surface: WorkspaceSurface.pdfDocument,
        pdfPageIndex: 4,
      );
      s = reduceWorkspace(
        s,
        SetMaterialsPdfUrlPacket(url: ' https://cdn.example.com/x.pdf '),
      );
      expect(s.materialsPdfUrl, 'https://cdn.example.com/x.pdf');
      expect(s.pdfPageIndex, 0);
    });

    test('SET_MATERIALS_PDF empty clears URL', () {
      var s = WorkspaceViewState(
        surface: WorkspaceSurface.pdfDocument,
        materialsPdfUrl: 'https://x/y.pdf',
      );
      s = reduceWorkspace(s, SetMaterialsPdfUrlPacket(url: '   '));
      expect(s.materialsPdfUrl, isNull);
    });
  });

  group('WorkspaceSyncController', () {
    test('defaults to launcher surface and closed teaching lane', () async {
      final c = WorkspaceSyncController();
      expect(c.state.surface, WorkspaceSurface.launcher);
      expect(c.state.teachingLaneOpen, false);
      await c.dispose();
    });

    test('emits on stateStream when applyPacket is used', () async {
      final c = WorkspaceSyncController();
      final events = <WorkspaceViewState>[];
      final sub = c.stateStream.listen(events.add);

      c.applyPacket(const ToolChangePacket(surface: WorkspaceSurface.lessonNotes));
      await Future<void>.delayed(Duration.zero);

      expect(events.length, 1);
      expect(events.single.surface, WorkspaceSurface.lessonNotes);
      expect(c.state.surface, WorkspaceSurface.lessonNotes);

      await sub.cancel();
      await c.dispose();
    });

    test('applyRemoteJson delegates to tryParse', () {
      final c = WorkspaceSyncController();
      expect(
        c.applyRemoteJson({
          'type': 'TOOL_CHANGE',
          'surface': 'whiteboard',
        }),
        isNotNull,
      );
      expect(c.state.surface, WorkspaceSurface.whiteboard);
      expect(c.applyRemoteJson({'type': 'nope'}), isNull);
    });
  });

  group('WorkspacePacket round-trip', () {
    test('toJson matches tryParse for known types', () {
      final samples = <WorkspacePacket>[
        const ScrollToPacket(page: 1, offsetNormalized: 0.99),
        const ToolChangePacket(surface: WorkspaceSurface.pdfDocument),
        const SlideIndexPacket(index: 0),
        StrokePathPacket(
          stroke: WhiteboardStroke(
            id: 'r1',
            points: const [0.0, 0.5, 0.5, 0.0],
          ),
        ),
        const ClearWhiteboardPacket(),
        const AgendaStepPacket(index: 3),
        const TeachingLaneOpenPacket(open: true),
        const UndoLastStrokePacket(),
        SetMaterialsPdfUrlPacket(url: 'https://example.com/doc.pdf'),
      ];
      for (final original in samples) {
        final copy = WorkspacePacket.tryParse(original.toJson());
        expect(copy, isNotNull);
        expect(copy!.toJson(), original.toJson());
      }
    });
  });
}
