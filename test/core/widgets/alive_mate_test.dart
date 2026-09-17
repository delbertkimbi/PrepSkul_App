import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prepskul/core/widgets/alive_mate.dart';
import 'package:prepskul/features/dashboard/widgets/student_home_promo_carousel.dart';
import 'package:prepskul/features/skulmate/widgets/skulmate_hero_mascot.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget wrap(Widget child) {
    return MediaQuery(
      data: const MediaQueryData(size: Size(390, 844), disableAnimations: true),
      child: MaterialApp(home: Scaffold(body: child)),
    );
  }

  testWidgets('AliveMate paints the vector Mate, not a PNG', (tester) async {
    await tester.pumpWidget(wrap(const AliveMate(mood: Mood.point, size: 96)));
    await tester.pump();

    expect(find.byType(Mate), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('SkulMate hero mascot is a live Mate pointing, not a still', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(const SkulMateHeroMascot()));
    await tester.pump();

    expect(find.byType(AliveMate), findsOneWidget);
    expect(find.byType(Mate), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('Student home promo uses a live Mate beside the card copy', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      wrap(
        StudentHomePromoCarousel(
          skulMateGames: const [],
          isReady: true,
          onPlayGame: (_, {bool isDailyChallenge = false}) {},
          onFindTutors: () {},
          onOpenSession: (_) {},
          onOpenSkulMate: () {},
          onCreateGame: () {},
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byType(AliveMate), findsWidgets);
    expect(find.byType(Mate), findsWidgets);
    expect(
      find.image(const AssetImage('assets/onboard/art/mate-wave.png')),
      findsNothing,
    );
    expect(
      find.image(const AssetImage('assets/onboard/art/mate-think.png')),
      findsNothing,
    );
    expect(
      find.image(const AssetImage('assets/onboard/art/mate-cheer.png')),
      findsNothing,
    );
  });
}
