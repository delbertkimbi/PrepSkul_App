import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prepskul/core/localization/language_notifier.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/features/skulmate/models/puzzle_step_model.dart';
import 'package:prepskul/features/skulmate/widgets/puzzle_sequence_widgets.dart';
import 'package:provider/provider.dart';

Widget _wrap(Widget child) {
  return ChangeNotifierProvider(
    create: (_) => LanguageNotifier(),
    child: MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PuzzleStepDefinition', () {
    test('parses puzzleSteps from map', () {
      final steps = PuzzleStepDefinition.parseFromGameItem(
        puzzleSteps: [
          {
            'id': 's1',
            'type': 'pick_one',
            'prompt': 'Which starts SOA?',
            'choices': [
              {'id': 'a', 'text': 'Reusability', 'correct': true},
              {'id': 'b', 'text': 'Random', 'correct': false},
            ],
          },
        ],
      );
      expect(steps.length, 1);
      expect(steps.first.type, PuzzleStepType.pickOne);
      expect(steps.first.choices.length, 2);
    });

    test('legacy puzzlePieces converts to pick_one steps', () {
      final steps = PuzzleStepDefinition.fromLegacyPieces([
        {'id': '1', 'text': 'First', 'order': 0},
        {'id': '2', 'text': 'Second', 'order': 1},
      ]);
      expect(steps.length, 2);
      expect(steps.every((s) => s.type == PuzzleStepType.pickOne), isTrue);
      expect(steps.first.choices.any((c) => c.correct), isTrue);
    });
  });

  group('PuzzleStepProgress', () {
    testWidgets('does not overflow at narrow width with many steps', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const SizedBox(
            width: 360,
            child: PuzzleStepProgress(
              currentIndex: 11,
              total: 12,
              completedCount: 11,
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Step 12 of 12'), findsOneWidget);
    });
  });

  group('PuzzleChoiceGrid', () {
    testWidgets('renders up to four choice cells', (tester) async {
      await tester.pumpWidget(
        _wrap(
          SizedBox(
            width: 360,
            child: PuzzleChoiceGrid(
              choices: [
                (id: 'a', text: 'Alpha'),
                (id: 'b', text: 'Beta'),
                (id: 'c', text: 'Gamma'),
                (id: 'd', text: 'Delta'),
              ],
              onTap: (_) {},
            ),
          ),
        ),
      );
      expect(find.text('Alpha'), findsOneWidget);
      expect(find.text('Delta'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
