import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prepskul/features/onboarding/learner/learner_onboarding_screen.dart';

void main() {
  Future<void> settle(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 200));
  }

  testWidgets('Mate-first onboarding asks school world, not tutor matching', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MediaQuery(
        data: MediaQueryData(size: Size(390, 844)),
        child: MaterialApp(home: LearnerOnboardingScreen()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('PrepSkul'), findsWidgets);
    expect(find.textContaining('tutor-matching form'), findsOneWidget);
    expect(find.textContaining('best tutor'), findsNothing);
    expect(find.textContaining('your child'), findsNothing);

    await tester.tap(find.text('Let’s go'));
    await settle(tester);

    expect(find.text('English'), findsOneWidget);
    expect(find.text('Français'), findsOneWidget);

    await tester.tap(find.text('English'));
    await settle(tester);

    expect(find.text('I’m the student'), findsOneWidget);
    expect(find.textContaining('I’m a parent'), findsOneWidget);
    expect(find.textContaining('watch'), findsNothing);
  });
}
