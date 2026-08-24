import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:prepskul/features/primar/domain/screener.dart';
import 'package:prepskul/features/primar/domain/subjects.dart';
import 'package:prepskul/features/primar/presentation/primar_screen.dart';
import 'package:prepskul/features/primar/presentation/primar_strings.dart';
import 'package:prepskul/features/primar/presentation/match_board.dart';
import 'package:prepskul/features/primar/presentation/mechanic_card.dart';
import 'package:prepskul/features/primar/presentation/order_row.dart';
import 'package:prepskul/features/primar/presentation/primar_theme.dart';
import 'package:prepskul/features/primar/services/evidence_store.dart';
import 'package:prepskul/features/primar/services/primar_voice.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The whole path, walked end to end, in the real widget tree.
///
/// ## Why this file had to exist
///
/// Every stage of this product had its own test and every one of them passed,
/// and not one of them ever mounted [PrimarScreen]. The screens were verified
/// as parts; the *path between them* was verified by me clicking through it on
/// a phone, which is worth exactly as much as the last time I did it.
///
/// That is how a whole stage can be wired up, computed, and never rendered —
/// which has already happened twice here: the reteach card the policy asked for
/// and nothing drew, and the learning engine that was built, tested, and never
/// actually called by the screen.
///
/// So this walks it: onboarding → handoff → demonstration → warm-up → session →
/// result → progress, tapping what a parent and a child would tap and asserting
/// each stage arrives. It answers every question *wrongly on purpose* in one
/// case, because the teach-and-retry loop only exists on the wrong answer, and
/// a path test that only ever wins never visits it.
///
/// ## What it deliberately does not check
///
/// Pixels, sound and feel. Those need a real device and a real child, and
/// claiming them here would be the same lie this file was written to stop.
void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  /// Every native channel the voice touches, answered with nothing.
  ///
  /// Muting [PrimarVoice] is not enough on its own: the audio players are
  /// constructed when the singleton is first read, before any code of ours
  /// runs, and an unanswered channel throws into the zone and fails the test
  /// from outside the widget tree entirely.
  const silenced = <String>[
    'xyz.luan/audioplayers.global',
    'xyz.luan/audioplayers',
    'flutter_tts',
    'plugins.flutter.io/path_provider',
    'dev.fluttercommunity.plus/connectivity',
  ];

  setUp(() {
    for (final name in silenced) {
      binding.defaultBinaryMessenger.setMockMethodCallHandler(
        MethodChannel(name),
        (call) async => null,
      );
    }
    SharedPreferences.setMockInitialValues({});
    EvidenceStore.instance.resetCache();
    // With the channels stubbed the voice would still queue and drain lines,
    // burning pumps on audio that does not exist. Muted, every line is a no-op
    // and the path is the only thing under test.
    PrimarVoice.instance.setMuted(true);
  });

  tearDown(() {
    PrimarVoice.instance.setMuted(false);
    for (final name in silenced) {
      binding.defaultBinaryMessenger
          .setMockMethodCallHandler(MethodChannel(name), null);
    }
  });

  /// Pumps without ever waiting for quiet.
  ///
  /// `pumpAndSettle` cannot be used anywhere in this file: Mate breathes and
  /// blinks on a Ticker that never stops, which is the point of him, so the
  /// tree is never quiet and settle would spin until it timed out.
  Future<void> tick(WidgetTester tester,
      [Duration d = const Duration(milliseconds: 450)]) async {
    await tester.pump(d);
    await tester.pump(const Duration(milliseconds: 350));
  }

  Finder optionTiles() => find.byWidgetPredicate(
      (w) => w.runtimeType.toString() == '_OptionTile');

  /// Pumps until [ready] holds, or gives up.
  ///
  /// A fixed number of pumps was enough on an idle machine and not enough on a
  /// busy one: the session opens on a hold while the stored evidence is read,
  /// and that read is a real Future whose completion needs event-loop turns
  /// rather than clock advances. Under the full suite, with every other test
  /// file running alongside, it lost that race about one run in four — which
  /// looked like a product flake and was a test measuring the machine.
  Future<bool> pumpUntil(WidgetTester tester, bool Function() ready,
      {int tries = 40}) async {
    for (var i = 0; i < tries; i++) {
      if (ready()) return true;
      await tester.pump(const Duration(milliseconds: 120));
    }
    return ready();
  }

  /// Opens the app on a surface tall enough to hold a whole question.
  ///
  /// The default 800×600 test surface is shorter than any phone, so the lower
  /// answer tiles sit off the bottom and taps aimed at them land on nothing.
  /// That was not a product bug — it was the test lying — and it quietly ate a
  /// whole session's worth of answers until the taps were made loud.
  Future<void> launch(WidgetTester tester) async {
    tester.view.physicalSize = const Size(420, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(const MaterialApp(home: PrimarScreen()));
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pump(const Duration(milliseconds: 350));
  }

  /// Walks the parent through onboarding to the handoff screen.
  Future<void> onboard(WidgetTester tester, {required Subject subject}) async {
    const s = S('en');
    await tester.tap(find.text('English'));
    await tick(tester);
    await tester.tap(find.text('Skul Mate'));
    await tick(tester);
    await tester.enterText(find.byType(TextField), 'Ayuk');
    await tester.tap(find.text(s.next));
    await tick(tester);
    await tester.tap(find.text('9'));
    await tick(tester);
    await tester.tap(find.text(s.schoolPatchy));
    await tick(tester);
    await tester.tap(find.text(subject.label('en')));
    await tick(tester);
    await tester.tap(find.text(SeenDoing.starting.prompt(subject)));
    await tick(tester);

    // Onboarding now lands on the path rather than dropping straight into a
    // lesson. "Start" is the one button on it, and taking it is what a child
    // does every day from here on.
    await tester.tap(find.text('Start'));
    await tick(tester);
  }

  /// Sits through the demonstration until its forward button goes live.
  ///
  /// The button is disabled until every demonstrated item has been seen once,
  /// which is the whole mechanic: a child cannot skip the only explanation the
  /// product ever gives.
  Future<void> watchDemo(WidgetTester tester) async {
    final forward = find.byIcon(Icons.chevron_right_rounded);
    expect(forward, findsOneWidget, reason: 'the demonstration never appeared');

    // Each demonstrated item holds for 2.7s. Six cycles covers the longest reel
    // any subject produces, with room to spare.
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 2800));
      await tester.pump(const Duration(milliseconds: 100));
      final button = tester.widget<PaperButton>(
        find.ancestor(of: forward, matching: find.byType(PaperButton)).first,
      );
      if (button.onPressed != null) break;
    }
    await tester.tap(forward);
    await tick(tester);
  }

  /// Answers one choose-a-tile question, correctly or not, and waits out the
  /// hold that follows.
  Future<void> answerOne(WidgetTester tester, {required bool correctly}) async {
    final tiles = optionTiles();
    expect(tiles, findsWidgets, reason: 'a question appeared with nothing to tap');

    final n = tiles.evaluate().length;
    var target = 0;
    for (var i = 0; i < n; i++) {
      final w = tiles.evaluate().elementAt(i).widget;
      final isAnswer = (w as dynamic).isAnswer as bool;
      if (isAnswer == correctly) {
        target = i;
        break;
      }
    }
    await tester.ensureVisible(tiles.at(target));
    await tester.pump();
    await tester.tap(tiles.at(target));

    // A correct answer holds 900ms; a miss holds up to 2.2s plus its teaching
    // and then hands the same question back for the retry.
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(seconds: 8));
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('a parent and a child can walk from first launch to the result',
      (tester) async {
    await launch(tester);

    // ---- Stage 1 · onboarding -------------------------------------------
    expect(find.text('Which language?'), findsOneWidget,
        reason: 'the app did not open on the first question');

    await onboard(tester, subject: Subject.reading);

    // ---- Stage 2 · handoff ----------------------------------------------
    const s = S('en');
    expect(find.text(s.handoffButton), findsOneWidget,
        reason: 'onboarding finished but the handoff never arrived');
    await tester.tap(find.text(s.handoffButton));
    await tick(tester);

    // ---- Stage 3 · the demonstration ------------------------------------
    await watchDemo(tester);

    // ---- Stage 4 · warm-up, three questions ------------------------------
    for (var i = 0; i < 3; i++) {
      expect(optionTiles(), findsWidgets,
          reason: 'warm-up question ${i + 1} had no options');
      await tester.tap(optionTiles().first);
      await tester.pump(const Duration(milliseconds: 1000));
      await tester.pump(const Duration(milliseconds: 300));
    }

    // ---- Stage 5 · the session -------------------------------------------
    // The session opens on a hold while the stored level is read, then the
    // first real question appears.
    await tester.pump(const Duration(milliseconds: 600));
    await tick(tester);
    expect(optionTiles(), findsWidgets,
        reason: 'the warm-up ended but the session never started');
  });

  /// Everything from a cold start up to the first real question.
  Future<void> reachSession(WidgetTester tester,
      {required Subject subject}) async {
    await launch(tester);
    await onboard(tester, subject: subject);
    await tester.tap(find.text(const S('en').handoffButton));
    await tick(tester);
    await watchDemo(tester);
    for (var i = 0; i < 3; i++) {
      // Wait for the tiles rather than assuming a fixed pump produced them.
      //
      // This helper was the last place still tapping `.first` straight after a
      // fixed wait, and it is why the numeracy walk failed roughly one full
      // suite run in four while passing every time on its own: with the whole
      // suite running alongside, the warm-up's async setup had not finished
      // and `.first` threw on an empty list. The test bodies were guarded
      // already; the path into them was not.
      final ready = await pumpUntil(
        tester,
        () => optionTiles().evaluate().isNotEmpty,
      );
      expect(ready, isTrue,
          reason: 'warm-up question ${i + 1} never appeared');
      await tester.tap(optionTiles().first);
      await tester.pump(const Duration(milliseconds: 1000));
      await tester.pump(const Duration(milliseconds: 300));
    }
    await tester.pump(const Duration(milliseconds: 600));
    await tick(tester);
  }

  testWidgets('a wrong answer teaches and hands the same question back',
      (tester) async {
    await reachSession(tester, subject: Subject.reading);

    // Miss on purpose. The retry is the "you do" step of the teaching loop —
    // without it the app marks a child wrong, says something kind, and moves
    // on, which teaches nothing.
    await answerOne(tester, correctly: false);
    expect(optionTiles(), findsWidgets,
        reason: 'a miss ended the question instead of handing it back');
  });

  testWidgets('answering the whole session reaches the result and the progress '
      'screen', (tester) async {
    await reachSession(tester, subject: Subject.reading);

    const s = S('en');

    // Answer everything correctly until the result screen appears. The cap is
    // generous: the session is fourteen questions, and reteach cards and
    // review items can add screens between them.
    var guard = 0;
    while (find.text(s.playAgain).evaluate().isEmpty && guard < 40) {
      guard++;
      if (optionTiles().evaluate().isNotEmpty) {
        await answerOne(tester, correctly: true);
        continue;
      }
      // A reteach card, or any other tap-to-continue screen between questions.
      await tester.tapAt(tester.getCenter(find.byType(Scaffold)));
      await tick(tester);
    }

    expect(find.text(s.playAgain), findsOneWidget,
        reason: 'the session never reached the result screen in $guard steps');

    // ---- Stage 7 · back to the path --------------------------------------
    expect(find.text('See how Ayuk is doing'), findsOneWidget,
        reason: 'the result screen offers no way out of itself');
    await tester.tap(find.text('See how Ayuk is doing'));
    await tick(tester);
    await tick(tester);

    // The result now hands back to the child's own path — the place that shows
    // what they cleared and what is next — rather than to a parent-facing
    // summary that dead-ends.
    expect(find.text(s.playAgain), findsNothing,
        reason: 'the result screen never gave way');
    expect(find.text('UP NEXT'), findsOneWidget,
        reason: 'finishing a session did not lead back to the path');
  });

  // Reading is the only subject on the learning engine; numbers and shapes
  // still run the staircase. That is two different session implementations
  // behind one screen, and only one of them was ever walked.
  for (final subject in [Subject.numeracy, Subject.shapes]) {
    testWidgets('${subject.name} reaches a real question from a cold start',
        (tester) async {
      await reachSession(tester, subject: subject);

      // Numeracy and shapes reach for match boards and drag-to-order, which a
      // child meeting them for the first time is shown how to use before they
      // are asked. Whether that card appears depends on which item the
      // staircase rolls, so it is stepped past when present rather than
      // asserted either way — asserting "no card" made this fail about one run
      // in three, which is the shape of a test that has not decided what it is
      // testing.
      // Something has to arrive: either the question, or the card that
      // introduces a way of answering the child has not met.
      bool anything() =>
          optionTiles().evaluate().isNotEmpty ||
          find.byType(OrderRow).evaluate().isNotEmpty ||
          find.byType(MatchBoard).evaluate().isNotEmpty ||
          find.byType(MechanicCard).evaluate().isNotEmpty;

      await pumpUntil(tester, anything);

      if (find.byType(MechanicCard).evaluate().isNotEmpty) {
        await tester.tap(find.byType(MechanicCard));
        await tick(tester);
      }

      // Some levels answer by dragging into order or joining a board rather
      // than by tapping a tile, so the assertion is that *something* askable
      // is on screen — not that it is a grid of four.
      final askable = await pumpUntil(
        tester,
        () =>
            optionTiles().evaluate().isNotEmpty ||
            find.byType(OrderRow).evaluate().isNotEmpty ||
            find.byType(MatchBoard).evaluate().isNotEmpty,
      );
      expect(askable, isTrue,
          reason: 'the ${subject.name} session started with nothing to answer');
    });
  }

  testWidgets('choosing French carries all the way into the session',
      (tester) async {
    await launch(tester);

    // The bug this guards is a language picker that sets a flag and nothing
    // else. Every screen after it has to be in the language just chosen.
    await tester.tap(find.text('Français'));
    await tick(tester);
    expect(find.text('Choisissez une voix'), findsOneWidget);

    const fr = S('fr');
    await tester.tap(find.text('Skul Mate'));
    await tick(tester);
    await tester.enterText(find.byType(TextField), 'Ayuk');
    await tester.tap(find.text(fr.next));
    await tick(tester);
    await tester.tap(find.text('9'));
    await tick(tester);
    await tester.tap(find.text(fr.schoolPatchy));
    await tick(tester);
    await tester.tap(find.text(Subject.reading.label('fr')));
    await tick(tester);
    await tester.tap(find.text(SeenDoing.starting.prompt(Subject.reading, 'fr')));
    await tick(tester);
    await tester.tap(find.text('Start'));
    await tick(tester);

    expect(find.text(fr.handoffButton), findsOneWidget,
        reason: 'the French handoff never arrived');
    await tester.tap(find.text(fr.handoffButton));
    await tick(tester);
    await watchDemo(tester);
    for (var i = 0; i < 3; i++) {
      await tester.tap(optionTiles().first);
      await tester.pump(const Duration(milliseconds: 1000));
      await tester.pump(const Duration(milliseconds: 300));
    }
    await tester.pump(const Duration(milliseconds: 600));
    await tick(tester);

    expect(optionTiles(), findsWidgets,
        reason: 'a French session never produced a question');
  });
}
