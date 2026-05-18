import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prepskul/features/sessions/widgets/classroom_offline_banner.dart';

void main() {
  testWidgets('ClassroomOfflineBanner shows message and icon', (
    WidgetTester tester,
  ) async {
    const msg = 'Test offline copy';
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ClassroomOfflineBanner(message: msg),
        ),
      ),
    );
    expect(find.text(msg), findsOneWidget);
    expect(find.byIcon(Icons.wifi_off_rounded), findsOneWidget);
  });
}
