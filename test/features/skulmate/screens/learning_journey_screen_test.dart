import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:prepskul/core/localization/language_notifier.dart';
import 'package:prepskul/features/skulmate/screens/skulmate_home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/features/skulmate/models/lesson_plan_model.dart';
import 'package:prepskul/features/skulmate/screens/learning_journey_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => GoogleFonts.config.allowRuntimeFetching = false);
  Widget page(
    Future<List<LessonPlan>> Function() loader, {
    VoidCallback? onMate,
  }) => MaterialApp(
    home: Scaffold(
      body: LearningJourneyScreen(
        loadPlans: loader,
        onMate: onMate ?? () {},
        onTutors: () {},
      ),
    ),
  );
  testWidgets('empty account offers a start without invented progress', (
    tester,
  ) async {
    await tester.pumpWidget(page(() async => []));
    await tester.pumpAndSettle();
    expect(find.text('What will we learn today?'), findsOneWidget);
    expect(find.text('Start with Mate'), findsOneWidget);
    expect(find.text('Worked through'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('starting a path opens a separate fresh Mate session', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => LanguageNotifier(),
        child: page(() async => []),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start with Mate'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    final mate = tester.widget<SkulMateHomeScreen>(
      find.byType(SkulMateHomeScreen),
    );
    expect(mate.startFresh, isTrue);
    expect(mate.onExit, isNotNull);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'failed saved path load remains distinct from an empty account and retries',
    (tester) async {
      var attempts = 0;
      await tester.pumpWidget(
        page(() async {
          if (++attempts == 1) throw Exception('network');
          return [];
        }),
      );
      await tester.pumpAndSettle();
      expect(find.text('Your saved path couldn’t load.'), findsOneWidget);
      expect(find.text('What will we learn today?'), findsNothing);
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(attempts, 2);
      expect(find.text('What will we learn today?'), findsOneWidget);
    },
  );
  testWidgets('failed refresh preserves a loaded path and retry updates it', (
    tester,
  ) async {
    var calls = 0;
    const plan = LessonPlan(
      id: 'saved',
      topic: 'Forces',
      steps: [LessonPlanStep(type: 'concepts', title: 'Balanced forces')],
    );
    await tester.pumpWidget(
      page(() async {
        calls++;
        if (calls == 2) throw Exception('offline');
        return calls == 1 ? [plan] : [];
      }),
    );
    await tester.pumpAndSettle();
    tester.state<RefreshIndicatorState>(find.byType(RefreshIndicator)).show();
    await tester.pumpAndSettle();
    expect(find.text('Forces'), findsOneWidget);
    expect(
      find.text('Showing your last loaded path. Refresh unavailable.'),
      findsOneWidget,
    );
    expect(find.text('What will we learn today?'), findsNothing);
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('Forces'), findsNothing);
    expect(find.text('What will we learn today?'), findsOneWidget);
  });
  testWidgets('saved path distinguishes completed, current and skipped steps', (
    tester,
  ) async {
    const plan = LessonPlan(
      id: 'saved-plan',
      topic: 'Forces',
      currentStep: 1,
      steps: [
        LessonPlanStep(
          type: 'overview',
          title: 'What is a force?',
          status: 'completed',
        ),
        LessonPlanStep(type: 'concepts', title: 'Balanced forces'),
        LessonPlanStep(
          type: 'quiz',
          title: 'Check your reasoning',
          status: 'skipped',
        ),
        LessonPlanStep(type: 'recap', title: 'You have mastered everything'),
      ],
    );
    await tester.pumpWidget(page(() async => [plan]));
    await tester.pumpAndSettle();
    expect(find.text('Forces'), findsOneWidget);
    await tester.tap(find.text('My learning path'));
    await tester.pumpAndSettle();
    expect(find.text('Worked through'), findsOneWidget);
    expect(find.text('Continue here'), findsOneWidget);
    expect(find.text('Skipped for now'), findsOneWidget);
    expect(find.text('You have mastered everything'), findsNothing);
    expect(find.text('Look back together'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('completed lesson reopens with Mate for review', (tester) async {
    SharedPreferences.setMockInitialValues({});
    const plan = LessonPlan(
      id: 'review',
      topic: 'Forces',
      currentStep: 1,
      steps: [
        LessonPlanStep(
          type: 'concepts',
          title: 'Push and pull',
          status: 'completed',
        ),
        LessonPlanStep(type: 'quiz', title: 'Try a force question'),
        LessonPlanStep(type: 'recap', title: 'Summary'),
      ],
    );
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => LanguageNotifier(),
        child: page(() async => [plan]),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('My learning path'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Push and pull'));
    await tester.pumpAndSettle();
    final mate = tester.widget<SkulMateHomeScreen>(
      find.byType(SkulMateHomeScreen),
    );
    expect(mate.initialMessage, contains('Review my completed lesson'));
    expect(mate.onPracticeSaved, isNull);
    expect(mate.lessonStep, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('small phone with larger text retains a working Mate action', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var opened = false;
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.3)),
          child: child!,
        ),
        home: Scaffold(
          body: LearningJourneyScreen(
            loadPlans: () async => [],
            onMate: () => opened = true,
            onTutors: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.byTooltip('Talk to Mate'), 220);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byTooltip('Talk to Mate'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Talk to Mate'));
    expect(opened, isTrue);
    expect(tester.takeException(), isNull);
  });
}
