import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:prepskul/core/localization/language_notifier.dart';
import 'package:prepskul/core/design/prepskul_icon.dart';
import 'package:prepskul/features/skulmate/widgets/skulmate_tutor_composer.dart';

void main() {
  testWidgets(
    'voice is default; typing replaces it with send; clearing restores voice',
    (tester) async {
      final controller = TextEditingController();
      var calls = 0;
      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => LanguageNotifier(),
          child: MaterialApp(
            home: Scaffold(
              body: SkulMateTutorComposer(
                controller: controller,
                onSend: () => calls++,
                onHoldStart: () {},
                onHoldEnd: () {},
                onMicTap: () {},
                busy: false,
                recording: false,
                speaking: false,
                attachOpen: false,
                onToggleAttach: () {},
              ),
            ),
          ),
        ),
      );
      expect(find.byTooltip('Talk to Mate'), findsOneWidget);
      expect(find.byTooltip('Send'), findsNothing);
      controller.text = 'Why does it move?';
      await tester.pump();
      await tester.tap(find.byTooltip('Send'));
      expect(calls, 1);
      controller.clear();
      await tester.pump();
      expect(find.byTooltip('Talk to Mate'), findsOneWidget);
    },
  );
  testWidgets('custom progress icon remains square inside a wide list', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 600,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [PrepSkulIcon(PrepSkulGlyph.streak, size: 64)],
            ),
          ),
        ),
      ),
    );
    final painter = find.descendant(
      of: find.byType(PrepSkulIcon),
      matching: find.byType(CustomPaint),
    );
    expect(tester.getSize(painter), const Size(64, 64));
  });
}
