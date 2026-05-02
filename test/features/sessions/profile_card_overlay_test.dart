import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prepskul/features/sessions/widgets/profile_card_overlay.dart';

void main() {
  group('ProfileCardOverlay', () {
    testWidgets('shows Connecting video when waitingForVideo', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ProfileCardOverlay(
              name: 'Alex',
              role: 'learner',
              waitingForVideo: true,
            ),
          ),
        ),
      );
      expect(find.text('Connecting video…'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsWidgets);
    });

    testWidgets('does not show generic unavailable when connecting', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ProfileCardOverlay(
              name: 'Alex',
              role: 'learner',
              waitingForVideo: true,
            ),
          ),
        ),
      );
      expect(find.text('Video is temporarily unavailable'), findsNothing);
    });

    testWidgets('shows camera off and reconnecting when both set', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ProfileCardOverlay(
              name: 'Alex',
              role: 'tutor',
              cameraOff: true,
              reconnecting: true,
            ),
          ),
        ),
      );
      expect(find.text('Camera is off'), findsOneWidget);
      expect(find.textContaining('reconnecting'), findsOneWidget);
    });
  });
}
