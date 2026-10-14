import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/features/skulmate/models/tutor_session_models.dart';
import 'package:prepskul/features/skulmate/widgets/skulmate_in_thread_surface.dart';

void main() {
  setUp(() => GoogleFonts.config.allowRuntimeFetching = false);
  const surface = PracticeSurface(gameType: 'quiz', title: 'Fractions', items: [
    {'question': 'First', 'options': ['A', 'B'], 'correctAnswer': 0},
    {'question': 'Second', 'options': ['C', 'D'], 'correctAnswer': 0},
  ]);
  testWidgets('a final correct answer does not erase an earlier miss', (tester) async {
    final results = <bool>[];
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: SkulMateInThreadSurface(
      surface: surface, onOutcome: (value) async { results.add(value); },
    ))));
    await tester.tap(find.text('B'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('C'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
    expect(results, [false]);
    expect(find.text('Progress saved'), findsOneWidget);
  });
  testWidgets('failed saving stays visible and retries the same result', (tester) async {
    var calls = 0;
    final results = <bool>[];
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: SkulMateInThreadSurface(
      surface: const PracticeSurface(gameType: 'quiz', title: 'Check', items: [
        {'question': 'One', 'options': ['A', 'B'], 'correctAnswer': 0},
      ]), onOutcome: (value) async { results.add(value); if (++calls == 1) throw Exception('offline'); },
    ))));
    await tester.tap(find.text('A'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
    expect(find.text('Progress saved'), findsNothing);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(results, [true, true]);
    expect(find.text('Progress saved'), findsOneWidget);
  });
  testWidgets('an empty generated surface does not crash', (tester) async {
    await tester.pumpWidget(MaterialApp(home: SkulMateInThreadSurface(
      surface: const PracticeSurface(gameType: 'quiz', title: 'Empty', items: []),
      onOutcome: (_) async {},
    )));
    expect(tester.takeException(), isNull);
  });
}
