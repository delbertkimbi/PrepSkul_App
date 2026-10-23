import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:prepskul/features/skulmate/screens/mate_local_lesson_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    GoogleFonts.config.allowRuntimeFetching = false;
  });
  testWidgets(
    'local counting rejects wrong answer and resumes review on device',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: MateLocalLessonScreen(counting: true)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('3'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Continue'))
            .onPressed,
        isNull,
      );
      expect(find.textContaining('Try touching each dot'), findsOneWidget);
      await tester.tap(find.text('4'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('Look what you explored'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        const MaterialApp(home: MateLocalLessonScreen(counting: true)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Look what you explored'), findsOneWidget);
    },
  );
  testWidgets('force exploration computes acceleration from the chosen force', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: MateLocalLessonScreen()));
    await tester.pumpAndSettle();
    expect(find.text('a = F ÷ m = 10 ÷ 2 = 5.0 m/s²'), findsOneWidget);
    tester.widget<Slider>(find.byType(Slider)).onChanged!(20);
    await tester.pump();
    expect(find.text('a = F ÷ m = 20 ÷ 2 = 10.0 m/s²'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
