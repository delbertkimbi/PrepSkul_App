import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prepskul/features/primar/domain/screener.dart';
import 'package:prepskul/features/primar/domain/subjects.dart';
import 'package:prepskul/features/primar/presentation/primar_screen.dart';
import 'package:prepskul/features/primar/presentation/primar_strings.dart';
import 'package:prepskul/features/primar/services/evidence_store.dart';
import 'package:prepskul/features/primar/services/primar_voice.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The warm-up has to reach the engine.
///
/// ## What was wrong
///
/// A child answered three questions and every one was discarded. The warm-up
/// turned them into a `beginAt` via `startFromProbe`; the reading session never
/// reads `beginAt`, because reading runs on the learning engine, which reads
/// the evidence log — which the warm-up never wrote to.
///
/// So a new reader answered five parent questions and three of their own, and
/// the engine still opened on an empty log. Nothing crashed and nothing looked
/// wrong. The onboarding felt pointless because for reading it *was*.
///
/// That is the same failure as the reteach card that was computed and never
/// drawn, and the engine that was built and never called: a whole stage wired
/// up to nothing. This test is the tripwire for the third occurrence.
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
    EvidenceStore.instance.resetCache();
    PrimarVoice.instance.setMuted(true);
  });

  tearDown(() {
    PrimarVoice.instance.setMuted(false);
    for (final name in silenced) {
      binding.defaultBinaryMessenger
          .setMockMethodCallHandler(MethodChannel(name), null);
    }
  });

  Future<void> tick(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pump(const Duration(milliseconds: 350));
  }

  Finder optionTiles() => find.byWidgetPredicate(
      (w) => w.runtimeType.toString() == '_OptionTile');

  Future<bool> pumpUntil(WidgetTester tester, bool Function() ready,
      {int tries = 40}) async {
    for (var i = 0; i < tries; i++) {
      if (ready()) return true;
      await tester.pump(const Duration(milliseconds: 120));
    }
    return ready();
  }

  testWidgets('the three warm-up answers land in the evidence log',
      (tester) async {
    tester.view.physicalSize = const Size(420, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const MaterialApp(
      home: PrimarScreen(
        answers: ScreenerAnswers(
          name: 'Ayuk',
          age: 9,
          schooling: Schooling.patchy,
          subject: Subject.reading,
          seenDoing: SeenDoing.starting,
        ),
      ),
    ));
    await tick(tester);

    expect(await EvidenceStore.instance.load(), isEmpty,
        reason: 'the log should start empty for a new learner');

    const s = S('en');
    await tester.tap(find.text('Start'));
    await tick(tester);
    await tester.tap(find.text(s.handoffButton));
    await tick(tester);

    // Sit through the demonstration.
    final forward = find.byIcon(Icons.chevron_right_rounded);
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 2800));
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.tap(forward);
    await tick(tester);

    // Three warm-up questions, answered.
    for (var i = 0; i < 3; i++) {
      await pumpUntil(tester, () => optionTiles().evaluate().isNotEmpty);
      await tester.tap(optionTiles().first, warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 1000));
      await tester.pump(const Duration(milliseconds: 400));
    }
    await tick(tester);

    final log = await EvidenceStore.instance.load();
    expect(log.length, 3,
        reason: 'the child answered three questions and the engine was told '
            'about ${log.length} of them');

    // Tagged with real skills, not invented ids — an evidence row whose skill
    // is not in the graph is silently ignored by the learner model, which
    // would look exactly like this bug never being fixed.
    for (final e in log) {
      expect(e.skillId, isNotEmpty);
      expect(e.isTransfer, isFalse,
          reason: 'three unscaffolded questions must never count as transfer '
              'evidence — that is what marks a skill solid');
    }
  });

  testWidgets('a session that follows starts from what the warm-up showed',
      (tester) async {
    tester.view.physicalSize = const Size(420, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const MaterialApp(
      home: PrimarScreen(
        answers: ScreenerAnswers(
          name: 'Ayuk',
          age: 9,
          subject: Subject.reading,
          seenDoing: SeenDoing.starting,
        ),
      ),
    ));
    await tick(tester);

    const s = S('en');
    await tester.tap(find.text('Start'));
    await tick(tester);
    await tester.tap(find.text(s.handoffButton));
    await tick(tester);
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 2800));
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.tap(find.byIcon(Icons.chevron_right_rounded));
    await tick(tester);

    for (var i = 0; i < 3; i++) {
      await pumpUntil(tester, () => optionTiles().evaluate().isNotEmpty);
      await tester.tap(optionTiles().first, warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 1000));
      await tester.pump(const Duration(milliseconds: 400));
    }

    // The session must open on a real question rather than hanging on the
    // warming hold — which is what a lost race between the evidence write and
    // the engine's first read would look like.
    final asked = await pumpUntil(
        tester, () => optionTiles().evaluate().isNotEmpty, tries: 60);
    expect(asked, isTrue,
        reason: 'the session never presented a question after the warm-up');
  });
}
