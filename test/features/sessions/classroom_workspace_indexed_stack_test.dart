import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:prepskul/features/sessions/domain/workspace_sync_state.dart';
import 'package:prepskul/features/sessions/widgets/classroom_workspace_indexed_stack.dart';
import 'package:prepskul/features/sessions/widgets/collaborative_whiteboard.dart';

void main() {
  testWidgets(
      'IndexedStack keeps SingleChildScrollView for materials and notes slots',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ClassroomWorkspaceIndexedStack(
            workspace: WorkspaceViewState(
              surface: WorkspaceSurface.lessonNotes,
              pdfPageIndex: 2,
            ),
            userRole: 'learner',
          ),
        ),
      ),
    );

    expect(find.byType(IndexedStack), findsOneWidget);
    // Every surface child stays mounted: launcher, materials empty, and notes each
    // use SingleChildScrollView (materials may be wrapped in Scrollbar).
    expect(
      find.byType(SingleChildScrollView, skipOffstage: false),
      findsAtLeastNWidgets(2),
    );
  });

  testWidgets('launcher shows learner-specific hint when read-only', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ClassroomWorkspaceIndexedStack(
            workspace: WorkspaceViewState(surface: WorkspaceSurface.launcher),
            userRole: 'learner',
          ),
        ),
      ),
    );
    expect(find.textContaining('Your tutor will choose'), findsOneWidget);
  });

  testWidgets('whiteboard surface shows draw hint', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ClassroomWorkspaceIndexedStack(
            workspace: WorkspaceViewState(surface: WorkspaceSurface.whiteboard),
            userRole: 'tutor',
          ),
        ),
      ),
    );
    expect(find.byType(CollaborativeWhiteboard), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(CollaborativeWhiteboard),
        matching: find.byType(Text),
      ),
      findsWidgets,
    );
  });

  testWidgets('materials and notes surfaces show empty-state keys', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
      home: Scaffold(
          body: ClassroomWorkspaceIndexedStack(
            workspace: WorkspaceViewState(surface: WorkspaceSurface.pdfDocument),
            userRole: 'tutor',
          ),
        ),
      ),
    );
    expect(find.byKey(const ValueKey<String>('ws_materials_empty')), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ClassroomWorkspaceIndexedStack(
            workspace: WorkspaceViewState(surface: WorkspaceSurface.lessonNotes),
            userRole: 'learner',
          ),
        ),
      ),
    );
    expect(find.byKey(const ValueKey<String>('ws_notes_empty')), findsOneWidget);
  });

  testWidgets(
      'materials slot shows deferred placeholder when URL exists but tab inactive',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ClassroomWorkspaceIndexedStack(
            workspace: WorkspaceViewState(
              surface: WorkspaceSurface.launcher,
              materialsPdfUrl: 'https://example.com/sample.pdf',
            ),
            userRole: 'learner',
          ),
        ),
      ),
    );
    expect(
      find.byKey(
        const ValueKey<String>('ws_materials_pdf_deferred'),
        skipOffstage: false,
      ),
      findsOneWidget,
    );
  });
}
