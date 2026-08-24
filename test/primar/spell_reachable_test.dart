import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prepskul/features/primar/domain/figure.dart';
import 'package:prepskul/features/primar/domain/learner.dart';
import 'package:prepskul/features/primar/domain/misconception.dart';
import 'package:prepskul/features/primar/domain/policy.dart';
import 'package:prepskul/features/primar/domain/screener.dart';
import 'package:prepskul/features/primar/domain/subjects.dart';
import 'package:prepskul/features/primar/presentation/primar_screen.dart';
import 'package:prepskul/features/primar/presentation/primar_strings.dart';
import 'package:prepskul/features/primar/presentation/primar_theme.dart';
import 'package:prepskul/features/primar/presentation/mechanic_card.dart';
import 'package:prepskul/features/primar/presentation/spell_row.dart';
import 'package:prepskul/features/primar/services/evidence_store.dart';
import 'package:prepskul/features/primar/services/primar_voice.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The rung a child reaches once letters stop being the hard part.
///
/// `decode.build` — building a short word out of its sounds — is the skill the
/// whole decoding strand sits on: `decode.read` lists it as a prerequisite, so
/// a child who cannot clear it cannot go anywhere. It is the only skill in the
/// graph whose generator returns [Interaction.spell].
///
/// This file exists because the path test could not reach it. A session is
/// fourteen questions and a new child starts on letter shapes, so a walk from a
/// cold start never gets this far — the questions after the fourteenth were
/// never rendered by anything, by anyone, at any point.
void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

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
    PrimarVoice.instance.setMuted(true);
  });

  tearDown(() {
    PrimarVoice.instance.setMuted(false);
    for (final name in silenced) {
      binding.defaultBinaryMessenger
          .setMockMethodCallHandler(MethodChannel(name), null);
    }
  });

  /// A child who has letters and is now due the next rung.
  ///
  /// Written as evidence rather than as a level, because evidence is the only
  /// thing the engine reads — setting a level would be testing a field that
  /// does not exist.
  List<Evidence> confidentWithLetters() {
    final at = DateTime.now().subtract(const Duration(minutes: 5));
    return [
      // Every teachable skill that sits below decode.build in the graph. The
      // list is spelled out rather than derived, so a future skill inserted
      // underneath makes this test fail loudly instead of quietly testing a
      // different rung.
      for (final skill in [
        'pa.rhyme',
        'pa.syllable',
        'pa.initial',
        'pa.blend',
        'pa.segment',
        'letter.shape',
        'letter.shape.reversal',
        'letter.sound',
      ])
        for (var i = 0; i < 8; i++)
          Evidence(
            skillId: skill,
            correct: true,
            elapsedMs: 2000,
            at: at.add(Duration(seconds: i)),
            misconception: Misconception.unclear,
            isTransfer: i > 5,
          ),
    ];
  }

  test('the engine really does send a strong reader to decode.build', () {
    final learner = learnerFrom(confidentWithLetters());
    final decision = nextSkill(learner);
    expect(decision.skillId, 'decode.build',
        reason: 'the fixture no longer lands on the skill this file is about');
  });

  testWidgets('a spelling question gives the child something to answer with',
      (tester) async {
    EvidenceStore.instance.seed(confidentWithLetters());
    addTearDown(EvidenceStore.instance.resetCache);

    tester.view.physicalSize = const Size(420, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const MaterialApp(home: PrimarScreen()));
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pump(const Duration(milliseconds: 350));

    Future<void> tick() async {
      await tester.pump(const Duration(milliseconds: 450));
      await tester.pump(const Duration(milliseconds: 350));
    }

    const s = S('en');
    await tester.tap(find.text('English'));
    await tick();
    await tester.tap(find.text('Skul Mate'));
    await tick();
    await tester.enterText(find.byType(TextField), 'Ayuk');
    await tester.tap(find.text(s.next));
    await tick();
    await tester.tap(find.text('9'));
    await tick();
    await tester.tap(find.text(s.schoolDaily));
    await tick();
    await tester.tap(find.text(Subject.reading.label('en')));
    await tick();
    await tester.tap(find.text(SeenDoing.confident.prompt(Subject.reading)));
    await tick();
    await tester.tap(find.text('Start'));
    await tick();
    await tester.tap(find.text(s.handoffButton));
    await tick();

    final forward = find.byIcon(Icons.chevron_right_rounded);
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 2800));
      await tester.pump(const Duration(milliseconds: 100));
      final button = tester.widget<PaperButton>(
        find.ancestor(of: forward, matching: find.byType(PaperButton)).first,
      );
      if (button.onPressed != null) break;
    }
    await tester.tap(forward);
    await tick();

    for (var i = 0; i < 3; i++) {
      await tester.tap(find
          .byWidgetPredicate((w) => w.runtimeType.toString() == '_OptionTile')
          .first);
      await tester.pump(const Duration(milliseconds: 1000));
      await tester.pump(const Duration(milliseconds: 300));
    }
    await tester.pump(const Duration(milliseconds: 600));
    await tick();

    // Spelling is a way of answering the child has never met — the
    // demonstration only ever showed tap-one-of-these — so it is introduced
    // before it is asked for.
    expect(find.byType(MechanicCard), findsOneWidget,
        reason: 'a brand new way of answering arrived with no explanation');
    await tester.tap(find.byType(MechanicCard));
    await tick();

    // Whatever the engine chose, the child must be able to act on it. A
    // question a child can look at but cannot answer is not a hard question,
    // it is a dead end — and the ring running out marks it as needing help,
    // over and over, on the one skill the rest of decoding is built on.
    final answerable = find
            .byWidgetPredicate((w) => w.runtimeType.toString() == '_OptionTile')
            .evaluate()
            .isNotEmpty ||
        find.byType(SpellRow).evaluate().isNotEmpty;

    expect(answerable, isTrue,
        reason: 'the session rendered a question with nothing to answer it with');
    expect(find.byType(SpellRow), findsOneWidget,
        reason: 'decode.build is a spelling rung and must render as one');

    // The pool has to be able to spell the word it is asking for. A pool
    // missing one of its own target letters is a question with no answer, and
    // it would look exactly like a child who cannot spell.
    final row = tester.widget<SpellRow>(find.byType(SpellRow));
    for (final letter in row.item.spellTarget) {
      expect(row.item.spellPool, contains(letter),
          reason: 'the pool cannot spell its own target word');
    }

    // Shown once per session. A card in front of every spelling question would
    // be an interruption rather than an introduction.
    expect(find.byType(MechanicCard), findsNothing,
        reason: 'the explanation came back after it had been read');
  });
}
