import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prepskul/features/sessions/services/incall_chat_realtime.dart';
import 'package:prepskul/features/sessions/services/session_profile_service.dart';
import 'package:prepskul/features/sessions/widgets/incall_chat_panel.dart';

void main() {
  IncallChatRealtime buildSync() {
    return IncallChatRealtime(
      sessionId: 's1',
      bundle: const SessionParticipantBundle(
        tutorUserId: 'tutor_1',
        learnerUserId: 'learner_1',
      ),
    );
  }

  Widget buildPanel({
    required EdgeInsets viewInsets,
    bool railMode = false,
  }) {
    return MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData().copyWith(viewInsets: viewInsets),
        child: Scaffold(
          body: IncallChatPanel(
            sync: buildSync(),
            localUserId: 'tutor_1',
            localDisplayName: 'Tutor',
            peerLabel: 'learner',
            railMode: railMode,
            onClose: () {},
          ),
        ),
      ),
    );
  }

  testWidgets('shows helper copy when keyboard is closed', (tester) async {
    await tester.pumpWidget(buildPanel(viewInsets: EdgeInsets.zero));

    expect(find.text('In-call messages'), findsOneWidget);
    expect(
      find.text('Messages with your learner are not saved when this lesson ends.'),
      findsOneWidget,
    );
    expect(find.text('Message your learner'), findsOneWidget);
  });

  testWidgets('remains stable when keyboard is open', (tester) async {
    await tester.pumpWidget(
      buildPanel(viewInsets: const EdgeInsets.only(bottom: 320)),
    );

    expect(find.text('In-call messages'), findsOneWidget);
    expect(find.text('Message your learner'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'hello');
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
