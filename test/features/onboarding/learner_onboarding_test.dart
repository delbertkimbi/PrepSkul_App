import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:prepskul/core/localization/language_service.dart';
import 'package:prepskul/features/onboarding/learner/learner_onboarding_answers.dart';
import 'package:prepskul/features/onboarding/learner/learner_onboarding_chrome.dart';
import 'package:prepskul/features/onboarding/learner/learner_onboarding_copy.dart';
import 'package:prepskul/features/onboarding/learner/learner_onboarding_persist.dart';
import 'package:prepskul/features/onboarding/learner/learner_onboarding_screen.dart';

void main() {
  const copy = LearnerOnboardingCopy(false);
  Future<void> settle(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 200));
  }

  Future<void> start(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: const LearnerOnboardingScreen(beforeAuth: true),
      ),
    );
    await settle(tester);
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LanguageService.setLanguage(const Locale('en'));
  });

  testWidgets('one welcome leads directly to learner and school questions', (
    tester,
  ) async {
    await start(tester);
    expect(find.textContaining('Hi, I’m Mate.'), findsOneWidget);
    expect(find.textContaining('I’ll help you understand'), findsOneWidget);
    expect(find.text('EN'), findsOneWidget);
    expect(find.text('FR'), findsOneWidget);
    await tester.tap(find.text('LET’S GO'));
    await settle(tester);
    expect(find.text(copy.whoStudent), findsOneWidget);
    await tester.tap(find.text(copy.whoStudent));
    await settle(tester);
    await tester.enterText(find.byType(TextField), 'Alex');
    await tester.pump();
    final next = tester.widget<OnboardPrimaryButton>(
      find.byType(OnboardPrimaryButton),
    );
    expect(next.enabled, isTrue);
    await tester.tap(find.text('CONTINUE'));
    await settle(tester);
    expect(find.text(copy.countryTitle), findsOneWidget);
    expect(find.textContaining('Nice to meet you'), findsNothing);
    expect(await LearnerOnboardingPersist.loadDraftStepId(), 'country');
  });

  testWidgets('welcome can switch to French before answering anything', (
    tester,
  ) async {
    await start(tester);
    await tester.tap(find.text('FR'));
    await settle(tester);
    expect(find.textContaining('Salut, moi c’est Mate.'), findsOneWidget);
    expect(find.textContaining('Je t’aide à comprendre'), findsOneWidget);
    expect((await LearnerOnboardingPersist.loadDraft())!.locale, 'fr');
  });

  for (final mode in <String?>[null, 'online', 'in-person', 'flexible']) {
    testWidgets('tutor choice $mode asks only the relevant questions', (
      tester,
    ) async {
      await LearnerOnboardingPersist.saveDraft(
        const LearnerOnboardingAnswers(
          name: 'Alex',
          subjectId: 'maths',
          learningGoalId: 'lessons',
        ),
        step: 13,
        stepId: 'tutor',
      );
      await start(tester);
      // Restore by identity, regardless of the old carousel's numeric position.
      expect(find.text(copy.tutorYes), findsOneWidget);
      await tester.tap(find.text(mode == null ? copy.tutorNo : copy.tutorYes));
      await settle(tester);
      if (mode != null) {
        final label = switch (mode) {
          'online' => copy.modeOnline,
          'in-person' => copy.modeInPersonLocation,
          _ => copy.modeFlexibleLocation,
        };
        await tester.tap(find.text(label));
        await settle(tester);
      }
      final needsCity = mode == 'in-person' || mode == 'flexible';
      expect(
        await LearnerOnboardingPersist.loadDraftStepId(),
        needsCity ? 'city' : 'ready',
      );
      expect(
        find.text(copy.cityTitle),
        needsCity ? findsOneWidget : findsNothing,
      );
      expect(find.text(copy.channelTitle), findsNothing);
      expect(find.text(copy.paceTitle), findsNothing);
    });
  }

  testWidgets('legacy numeric drafts retain answers and restart safely', (
    tester,
  ) async {
    await LearnerOnboardingPersist.saveDraft(
      const LearnerOnboardingAnswers(name: 'Alex'),
      step: 13,
    );
    await start(tester);
    expect(find.textContaining('Hi, I’m Mate.'), findsOneWidget);
    expect((await LearnerOnboardingPersist.loadDraft())!.name, 'Alex');
  });
}
