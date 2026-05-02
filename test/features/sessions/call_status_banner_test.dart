import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prepskul/features/sessions/models/agora_session_state.dart';
import 'package:prepskul/features/sessions/widgets/call_status_banner.dart';

void main() {
  group('CallStatusBanner quiet UX', () {
    testWidgets('clean connected state shows timer only (no Connected pill)', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CallStatusBanner(
              sessionState: AgoraSessionState.connected,
              showSustainedDegradation: false,
              remoteUserLeft: false,
              isAloneWaiting: false,
              timeRemaining: Duration(minutes: 25, seconds: 30),
            ),
          ),
        ),
      );

      expect(find.textContaining('Connected'), findsNothing);
      expect(find.text('25:30'), findsOneWidget);
    });

    testWidgets('sustained degradation shows compact chip', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CallStatusBanner(
              sessionState: AgoraSessionState.connected,
              showSustainedDegradation: true,
              remoteUserLeft: false,
              isAloneWaiting: false,
              timeRemaining: Duration(minutes: 1),
            ),
          ),
        ),
      );

      expect(find.text('Reconnecting…'), findsOneWidget);
    });
  });
}
