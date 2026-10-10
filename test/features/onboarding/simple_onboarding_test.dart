import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prepskul/core/localization/app_localizations.dart';
import 'package:prepskul/core/localization/language_notifier.dart';
import 'package:prepskul/features/onboarding/screens/simple_onboarding_screen.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('intro is Mate plus people, not old slogans', (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => LanguageNotifier(),
        child: const MediaQuery(
          data: MediaQueryData(size: Size(390, 844), disableAnimations: true),
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: SimpleOnboardingScreen(),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.textContaining('I’m Mate'), findsOneWidget);
    expect(find.textContaining('school system'), findsOneWidget);
    expect(find.text('A tutor that actually teaches'), findsNothing);
    expect(find.textContaining('not another product'), findsNothing);
    expect(find.text('Get Started'), findsNothing);
    expect(find.text('NEXT'), findsOneWidget);
  });
}
