import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prepskul/features/primar/domain/screener.dart';
import 'package:prepskul/features/primar/domain/subjects.dart';
import 'package:prepskul/features/primar/presentation/choice_art.dart';
import 'package:prepskul/features/primar/presentation/onboarding.dart';
import 'package:prepskul/features/primar/presentation/primar_strings.dart';

/// The onboarding is the only screen a parent has to get through before their
/// child ever sees a question, so its failure modes are all the same failure:
/// the parent gives up and the child never plays.
void main() {
  ScreenerAnswers? collected;

  Widget harness({Size size = const Size(390, 844)}) {
    collected = null;
    return MediaQuery(
      data: MediaQueryData(size: size),
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Onboarding(onDone: (a) => collected = a),
          ),
        ),
      ),
    );
  }

  /// Settles the page transition without waiting for the tree to go quiet.
  ///
  /// `pumpAndSettle` never returns here: Mate breathes and blinks on a Ticker
  /// that runs forever, which is the point of him. So the pumps are explicit —
  /// long enough to cover the 380ms auto-advance and the 300ms switch after it.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 200));
  }

  /// Walks the whole flow, answering every page.
  Future<void> answerEverything(
    WidgetTester tester, {
    required Subject subject,
    String locale = 'en',
  }) async {
    await tester.tap(find.text(locale == 'fr' ? 'Français' : 'English'));
    await settle(tester);

    // Who teaches, before who is taught. The default is fine here — what
    // matters is that the page exists and does not swallow the flow.
    await tester.tap(find.text('Skul Mate'));
    await settle(tester);

    await tester.enterText(find.byType(TextField), 'Ayuk');
    await tester.tap(find.text('Next'));
    await settle(tester);

    await tester.tap(find.text('9'));
    await settle(tester);

    await tester.tap(find.text(S(locale).schoolPatchy));
    await settle(tester);

    await tester.tap(find.text(subject.label(locale)));
    await settle(tester);

    await tester.tap(find.text(SeenDoing.starting.prompt(subject)));
    await settle(tester);
  }

  /// The same walk, minus the language page, for tests that already chose.
  Future<void> answerEverythingFromName(
    WidgetTester tester, {
    required Subject subject,
    required String locale,
  }) async {
    await tester.enterText(find.byType(TextField), 'Ayuk');
    await tester.tap(find.text(S(locale).next));
    await settle(tester);
    await tester.tap(find.text('9'));
    await settle(tester);
    await tester.tap(find.text(S(locale).schoolPatchy));
    await settle(tester);
    await tester.tap(find.text(subject.label(locale)));
    await settle(tester);
    // In the chosen language. This used to pass an English string in the
    // French walk and still find it, because the last page had never been
    // translated — the test was documenting the bug rather than catching it.
    await tester.tap(find.text(SeenDoing.starting.prompt(subject, locale)));
    await settle(tester);
  }

  testWidgets('one question is on screen at a time, and only one', (tester) async {
    await tester.pumpWidget(harness());
    await settle(tester);

    // The old form asked for age, subject and name together. If any two of
    // those ever share a screen again, this fails.
    expect(find.text('Which language?'), findsOneWidget);
    expect(find.text('What should we call them?'), findsNothing);
    expect(find.text('How old are they?'), findsNothing);
    expect(find.text('What should we look at first?'), findsNothing);
  });

  testWidgets('every answer reaches the screener', (tester) async {
    await tester.pumpWidget(harness());
    await settle(tester);
    await answerEverything(tester, subject: Subject.reading);

    expect(collected, isNotNull);
    expect(collected!.name, 'Ayuk');
    expect(collected!.age, 9);
    expect(collected!.schooling, Schooling.patchy);
    expect(collected!.subject, Subject.reading);
    expect(collected!.seenDoing, SeenDoing.starting);
    expect(collected!.signalCount, 3, reason: 'a page was collected but not kept');
    expect(collected!.locale, 'en');
  });

  testWidgets('choosing French changes the questions, not just a flag',
      (tester) async {
    await tester.pumpWidget(harness());
    await settle(tester);

    await tester.tap(find.text('Français'));
    await settle(tester);

    // The page after the picker has to be in the language just chosen. A
    // picker that only sets a variable is the bug this replaced.
    expect(find.text('Choisissez une voix'), findsOneWidget);

    await tester.tap(find.text('Skul Mate'));
    await settle(tester);
    expect(find.text('Comment doit-on les appeler ?'), findsOneWidget);

    await answerEverythingFromName(tester, subject: Subject.reading, locale: 'fr');
    expect(collected!.locale, 'fr');
    expect(collected!.subject, Subject.reading);
  });

  testWidgets('the last question is asked in the chosen subject\'s own terms',
      (tester) async {
    for (final subject in Subject.values) {
      // A fresh tree each time. Pumping `harness()` again on its own reuses the
      // existing State, so the second subject would start on whichever page the
      // first one finished on.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(harness());
      await settle(tester);

      await tester.tap(find.text('English'));
      await settle(tester);
      await tester.tap(find.text('Skul Mate'));
      await settle(tester);
      await tester.enterText(find.byType(TextField), 'Bih');
      await tester.tap(find.text('Next'));
      await settle(tester);
      await tester.tap(find.text('7'));
      await settle(tester);
      await tester.tap(find.text('Most days'));
      await settle(tester);
      await tester.tap(find.text(subject.label('en')));
      await settle(tester);

      // Asking "can they read short words" of a child whose parent chose
      // shapes is a question with no answer.
      for (final seen in SeenDoing.values) {
        expect(find.text(seen.prompt(subject)), findsOneWidget,
            reason: 'missing $seen option for $subject');
      }
    }
  });

  testWidgets('the age picker reaches past the ages we market to', (tester) async {
    await tester.pumpWidget(harness());
    await settle(tester);
    await tester.tap(find.text('English'));
    await settle(tester);
    await tester.tap(find.text('Skul Mate'));
    await settle(tester);
    await tester.tap(find.text('Next'));
    await settle(tester);

    // Marketing says five to twelve. The picker has to go further, because a
    // fifteen-year-old who cannot read a sentence is ordinary here, and a list
    // that stopped at eleven told their parent this was not for them.
    // A bare "13" alongside "13+" was two tiles for one answer. Thirteen and
    // above are placed identically, so they are one button.
    expect(find.text('12'), findsOneWidget);
    expect(find.text('13'), findsNothing);
    expect(find.text('13+'), findsOneWidget);

    await tester.tap(find.text('13+'));
    await settle(tester);
    expect(find.text('How much school have they had?'), findsOneWidget);
  });

  testWidgets('being older stops adding levels once age stops predicting', (tester) async {
    // A fifteen-year-old non-reader must not be started above a nine-year-old
    // one purely for the year they were born.
    const base = ScreenerAnswers(schooling: Schooling.none, seenDoing: SeenDoing.notYet);
    final eleven = Screener.estimate(base.copyWith(age: 11)).level;
    for (final age in [12, Screener.olderThanListed]) {
      expect(Screener.estimate(base.copyWith(age: age)).level, eleven,
          reason: 'age $age was worth more than eleven');
    }
  });

  testWidgets('back goes back, and keeps what was already answered', (tester) async {
    await tester.pumpWidget(harness());
    await settle(tester);

    await tester.tap(find.text('English'));
    await settle(tester);
    await tester.tap(find.text('Skul Mate'));
    await settle(tester);
    await tester.enterText(find.byType(TextField), 'Ndip');
    await tester.tap(find.text('Next'));
    await settle(tester);
    await tester.tap(find.text('8'));
    await settle(tester);

    expect(find.text('How much school have they had?'), findsOneWidget);

    await tester.tap(find.text('Back'));
    await settle(tester);

    // A parent who mistyped an age and went back to fix it should not find
    // their earlier answers wiped.
    expect(find.text('How old are they?'), findsOneWidget);
    await tester.tap(find.text('Back'));
    await settle(tester);
    expect(find.text('Ndip'), findsOneWidget);
  });

  testWidgets('a parent who skips the questions still gets a session', (tester) async {
    await tester.pumpWidget(harness());
    await settle(tester);

    await tester.tap(find.text('English'));
    await settle(tester);
    await tester.tap(find.text('Skul Mate'));
    await settle(tester);

    // Name is optional, so Next alone advances. Every later page is answered
    // by tapping, so the only way through them is to answer — but the flow
    // must not depend on the name being filled in.
    await tester.tap(find.text('Next'));
    await settle(tester);
    expect(find.text('How old are they?'), findsOneWidget);

    final blind = Screener.estimate(const ScreenerAnswers());
    expect(blind.level, inInclusiveRange(1, 10));
  });

  group('nothing runs off the side of a small phone', () {
    // A 320pt-wide screen is the narrowest Android still in real use, and it is
    // exactly the kind of phone this product is for.
    for (final width in [320.0, 360.0, 390.0]) {
      testWidgets('every page fits at ${width.toInt()}pt', (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(harness(size: Size(width, 900)));
        await settle(tester);
        await answerEverything(tester, subject: Subject.numeracy);

        expect(tester.takeException(), isNull);
      });
    }
  });

  group('the pictures', () {
    testWidgets('every kind paints without throwing', (tester) async {
      for (final kind in ArtKind.values) {
        await tester.pumpWidget(
          MaterialApp(home: Center(child: ChoiceArt(kind: kind, size: 56))),
        );
        await tester.pump();
        expect(tester.takeException(), isNull, reason: '$kind threw while painting');
      }
    });

    testWidgets('every option a parent chooses between has its own picture',
        (tester) async {
      // Two options sharing an icon is the same defect as two answer tiles
      // rendering identically: the parent is asked to distinguish something
      // that looks the same either way.
      for (final subject in Subject.values) {
        final kinds = <ArtKind>{};
        for (final seen in SeenDoing.values) {
          kinds.add(artFor(subject, seen));
        }
        expect(kinds.length, SeenDoing.values.length,
            reason: '$subject reuses a picture across two answers');
      }
    });
  });
}
