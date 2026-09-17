import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prepskul/core/localization/language_notifier.dart';
import 'package:prepskul/features/skulmate/screens/skulmate_home_screen.dart';
import 'package:prepskul/features/skulmate/widgets/skulmate_home_top_bar.dart';
import 'package:prepskul/features/skulmate/widgets/skulmate_tutor_composer.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('SkulMateHomeScreen is a tutor canvas, not a game picker', (
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
    expect(find.byType(SkulMateTutorComposer), findsOneWidget);
            expect(
              find.textContaining('This board is yours'),
              findsOneWidget,
            );
    expect(find.byType(FloatingActionButton), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
