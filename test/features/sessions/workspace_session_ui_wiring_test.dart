import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('video session screen exposes workspace teaching rail + stream binding', () async {
    final file = File('lib/features/sessions/screens/agora_video_session_screen.dart');
    final content = await file.readAsString();

    expect(content.contains('_buildWorkspaceTeachingRail'), isTrue);
    expect(content.contains('ClassroomWorkspaceIndexedStack'), isTrue);
    expect(content.contains('_buildClassroomSplitBody'), isTrue);
    expect(content.contains('_kClassroomDualPaneMinWidth'), isTrue);
    expect(content.contains('workspace.stateStream'), isTrue);
    expect(content.contains('ToolChangePacket'), isTrue);
    expect(content.contains('SlideIndexPacket'), isTrue);
    expect(content.contains('AgendaStepPacket'), isTrue);
    expect(content.contains('if (_anyScreenShareActive) return const SizedBox.shrink();'), isTrue);
    expect(content.contains('showPdfPagingControls ='), isTrue);
    expect(content.contains('data.surface == WorkspaceSurface.pdfDocument'), isTrue);
    expect(content.contains('if (showPdfPagingControls) ...['), isTrue);
    expect(content.contains('Expanded(flex: 13, child: videoLaneWidget)'), isTrue);
    expect(
      content.contains('if (_layout == VideoLayout.gallery)'),
      isTrue,
    );
    expect(
      content.contains('// Gallery (3+ remotes) stays video-only'),
      isTrue,
    );
    expect(
      content.contains('await _publishTeachingLaneOpen(true)'),
      isTrue,
    );
  });
}
