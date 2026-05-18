import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prepskul/features/tutor/widgets/tutor_dashboard_layout.dart';

void main() {
  testWidgets('TutorZRow stacks on narrow width', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(400, 800)),
          child: Scaffold(
            body: TutorZRow(
              rowIndex: 0,
              primary: const Text('Primary'),
              secondary: const Text('Secondary'),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Primary'), findsOneWidget);
    expect(find.text('Secondary'), findsOneWidget);
    final primaryPos = tester.getTopLeft(find.text('Primary'));
    final secondaryPos = tester.getTopLeft(find.text('Secondary'));
    expect(secondaryPos.dy, greaterThan(primaryPos.dy));
  });

  testWidgets('TutorZRow uses side-by-side on desktop width', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(1280, 900)),
          child: Scaffold(
            body: TutorZRow(
              rowIndex: 1,
              primary: const SizedBox(height: 40, child: Text('Wide')),
              secondary: const SizedBox(height: 40, child: Text('Narrow')),
            ),
          ),
        ),
      ),
    );

    final widePos = tester.getTopLeft(find.text('Wide'));
    final narrowPos = tester.getTopLeft(find.text('Narrow'));
    expect(widePos.dx, greaterThan(narrowPos.dx));
  });
}
