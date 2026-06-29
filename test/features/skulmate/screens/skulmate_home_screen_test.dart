import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prepskul/core/localization/language_notifier.dart';
import 'package:prepskul/features/skulmate/screens/skulmate_home_screen.dart';
import 'package:prepskul/features/skulmate/widgets/skulmate_home_top_bar.dart';
import 'package:prepskul/features/skulmate/widgets/skulmate_import_action_grid.dart';
import 'package:prepskul/features/skulmate/widgets/skulmate_study_intent_card.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('SkulMateHomeScreen shows hero, intent card, and chips', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider(
          create: (_) => LanguageNotifier(),
          child: const SkulMateHomeScreen(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('What shall we revise today?'), findsOneWidget);
    expect(find.byType(SkulMateHomeTopBar), findsOneWidget);
    expect(find.text('History'), findsOneWidget);
    expect(find.text('More'), findsNWidgets(2));
    expect(find.byType(SkulMateStudyIntentCard), findsOneWidget);
    expect(find.byType(SkulMateImportActionGrid), findsOneWidget);
    expect(find.text('Upload'), findsOneWidget);
    expect(find.text('Sessions'), findsOneWidget);
    expect(find.text('My games'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsNothing);
    expect(find.text('Profile'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
