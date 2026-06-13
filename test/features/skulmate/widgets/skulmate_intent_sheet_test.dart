import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prepskul/core/localization/language_notifier.dart';
import 'package:prepskul/features/skulmate/l10n/skulmate_copy.dart';
import 'package:prepskul/features/skulmate/models/skulmate_intake_models.dart';
import 'package:prepskul/features/skulmate/widgets/skulmate_intent_sheet.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('SkulMateIntentSheet defaults to Play and returns selection', (
    tester,
  ) async {
    SkulMateIntentMode? result;

    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider(
          create: (_) => LanguageNotifier(),
          child: Builder(
            builder: (context) {
              return Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () async {
                      result = await showModalBottomSheet<SkulMateIntentMode>(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => SkulMateIntentSheet(
                          payload: const SkulMateIntakePayload(
                            source: SkulMateIntakeSource.paste,
                            text: 'Photosynthesis is how plants make food.',
                          ),
                          copy: SkulMateCopy(false),
                        ),
                      );
                    },
                    child: const Text('Open'),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Play'), findsOneWidget);
    expect(find.text('Drill'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Start playing'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Start playing'));
    await tester.pumpAndSettle();

    expect(result, SkulMateIntentMode.play);
  });

  test('SkulMateCopy mode labels are bilingual', () {
    final en = SkulMateCopy(false);
    final fr = SkulMateCopy(true);

    expect(en.modeLabel(SkulMateIntentMode.play), 'Play');
    expect(fr.modeLabel(SkulMateIntentMode.play), 'Jouer');
    expect(en.jumpBackIn, 'Jump back in');
    expect(fr.jumpBackIn, 'Reprendre');
  });
}
