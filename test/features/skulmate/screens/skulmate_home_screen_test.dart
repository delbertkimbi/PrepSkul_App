import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prepskul/core/localization/language_notifier.dart';
import 'package:prepskul/features/skulmate/screens/skulmate_home_screen.dart';
import 'package:prepskul/features/skulmate/widgets/skulmate_home_top_bar.dart';
import 'package:prepskul/features/skulmate/widgets/skulmate_tutor_composer.dart';
import 'package:prepskul/core/widgets/alive_mate.dart';
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
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: ChangeNotifierProvider(
          create: (_) => LanguageNotifier(),
          child: const SkulMateHomeScreen(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Let’s figure it out together.'), findsOneWidget);
    expect(find.byType(AliveMate), findsOneWidget);
    expect(find.byType(SkulMateHomeTopBar), findsOneWidget);
    expect(find.text('History'), findsNothing);
    expect(find.byTooltip('New conversation'), findsNothing);
    expect(
      tester.getCenter(find.byTooltip('Session menu')).dx,
      greaterThan(tester.getCenter(find.byTooltip('Learning streak')).dx),
    );
    await tester.tap(find.byTooltip('Session menu'));
    await tester.pumpAndSettle();
    expect(find.text('New session'), findsOneWidget);
    expect(find.text('Past sessions'), findsOneWidget);
    expect(find.byType(PopupMenuButton<String>), findsNothing);
    expect(find.byTooltip('Close'), findsOneWidget);
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.byType(SkulMateTutorComposer), findsOneWidget);
    expect(find.text('Explain it'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
