import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prepskul/features/primar/domain/screener.dart';
import 'package:prepskul/features/primar/domain/subjects.dart';
import 'package:prepskul/features/primar/presentation/home_screen.dart';
import 'package:prepskul/features/primar/presentation/primar_strings.dart';
import 'package:prepskul/features/primar/presentation/profile_screen.dart';
import 'package:prepskul/features/primar/presentation/skulmate_shell.dart';
import 'package:prepskul/features/primar/presentation/tutor_screen.dart';
import 'package:prepskul/features/primar/services/evidence_store.dart';
import 'package:prepskul/features/primar/services/learner_profile_store.dart';
import 'package:prepskul/features/primar/services/primar_voice.dart';
import 'package:prepskul/features/primar/services/tutor_directory.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The app around the lesson, walked.
///
/// The lesson itself has been tested end to end for a while. What had never
/// existed — and so had never been tested — was anywhere else to be: a path
/// showing where the child stands, a page that is theirs, and a way to reach a
/// person. This walks all three and back.
void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  const silenced = <String>[
    'xyz.luan/audioplayers.global',
    'xyz.luan/audioplayers',
    'flutter_tts',
    'plugins.flutter.io/path_provider',
    'dev.fluttercommunity.plus/connectivity',
  ];

  setUp(() async {
    for (final name in silenced) {
      binding.defaultBinaryMessenger.setMockMethodCallHandler(
        MethodChannel(name),
        (call) async => null,
      );
    }
    SharedPreferences.setMockInitialValues({});
    LearnerProfileStore.instance.resetCache();
    await EvidenceStore.instance.resetBinding();
    EvidenceStore.instance.resetCache();
    // No network in a widget test, so the directory would sit on a timeout.
    // Seeded empty, the tab renders its real "nobody yet" state, which is the
    // state most children will actually meet first.
    TutorDirectory.instance.seed(const []);
    PrimarVoice.instance.setMuted(true);
  });

  tearDown(() {
    PrimarVoice.instance.setMuted(false);
    TutorDirectory.instance.resetCache();
    for (final name in silenced) {
      binding.defaultBinaryMessenger
          .setMockMethodCallHandler(MethodChannel(name), null);
    }
  });

  Future<void> tick(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pump(const Duration(milliseconds: 350));
  }

  Future<void> launch(WidgetTester tester) async {
    tester.view.physicalSize = const Size(420, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(const MaterialApp(home: SkulMateShell()));
    // Profile restore is async — leave the boot spinner.
    await tester.pump();
    await tick(tester);
  }

  Future<void> onboardSubject(WidgetTester tester, Subject subject) async {
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
  }

  Future<void> onboard(WidgetTester tester) async {
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
    await tester.tap(find.text(Subject.reading.label('en')));
    await tick(tester);
    await tester.tap(find.text(SeenDoing.starting.prompt(Subject.reading)));
    await tick(tester);
  }

  testWidgets('onboarding hands over to a home with a path on it',
      (tester) async {
    await launch(tester);
    expect(find.text('Which language?'), findsOneWidget);

    await onboard(tester);
    await tick(tester);

    expect(find.byType(HomeScreen), findsOneWidget,
        reason: 'onboarding did not lead anywhere that belongs to the child');
    // The child's own name, not a generic greeting. This is the first screen
    // that is theirs.
    expect(find.text('Ayuk'), findsOneWidget);
    expect(find.text('UP NEXT'), findsOneWidget,
        reason: 'the path does not say what comes next');
    expect(find.text('Start'), findsOneWidget);
  });

  testWidgets('all three tabs are reachable and come back', (tester) async {
    await launch(tester);
    await onboard(tester);
    await tick(tester);

    // ---- Ask ----
    // One frame only — full TutorScreen paint triggers async google_fonts work
    // that the test binding blocks; behaviour is covered in tutor_advice_test.
    await tester.tap(find.text('Ask'));
    await tester.pump();
    expect(find.byType(TutorScreen), findsOneWidget);

    // ---- You ----
    await tester.tap(find.text('You'));
    await tick(tester);
    expect(find.byType(ProfileScreen), findsOneWidget);
    expect(find.text('DAY STREAK'), findsOneWidget);
    expect(find.text('SKILLS'), findsOneWidget);

    // ---- and back to Learn ----
    await tester.tap(find.text('Learn'));
    await tick(tester);
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('a subject with no skill graph is still playable',
      (tester) async {
    // Every subject must have a Start button on home. Shapes now has a skill
    // graph too, but the invariant holds: a child can always begin.
    await launch(tester);
    await onboardSubject(tester, Subject.shapes);
    await tick(tester);

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('Start'), findsOneWidget,
        reason: 'a shapes learner has no way to begin');
    expect(find.text('UP NEXT'), findsOneWidget,
        reason: 'shapes should show a path like reading and numeracy');
  });

  testWidgets('the path locks what the child has no evidence for',
      (tester) async {
    await launch(tester);
    await onboard(tester);
    await tick(tester);

    // A brand new learner has cleared nothing, so the path must show exactly
    // one open step and lock the rest. A path that opened everything would be
    // a menu, and choosing off a menu is the thing the engine exists to
    // replace.
    expect(find.byIcon(Icons.lock_rounded), findsWidgets,
        reason: 'nothing on the path is locked for a learner with no evidence');
  });
}
