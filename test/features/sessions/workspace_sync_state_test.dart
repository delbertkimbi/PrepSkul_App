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
      var s = const WorkspaceViewState(surface: WorkspaceSurface.whiteboard);
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
  });

  group('WorkspaceSyncController', () {
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
      ];
      for (final original in samples) {
        final copy = WorkspacePacket.tryParse(original.toJson());
        expect(copy, isNotNull);
        expect(copy!.toJson(), original.toJson());
      }
    });
  });
}
