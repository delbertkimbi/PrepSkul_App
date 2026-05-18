import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('peer left uses dedicated empty state not waiting placeholder', () async {
    final file = File(
      'lib/features/sessions/screens/agora_video_session_screen.dart',
    );
    final content = await file.readAsString();

    expect(content.contains('Widget _buildPeerLeftMainState'), isTrue);
    expect(content.contains('Left the session'), isTrue);
    expect(
      content.contains(
        "return Container(color: _kSoftDark, child: _buildPeerLeftMainState());",
      ),
      isTrue,
    );
    expect(
      content.contains("statusText = 'Learner left'"),
      isFalse,
    );
  });
}
