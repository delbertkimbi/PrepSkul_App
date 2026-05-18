import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prepskul/features/tutor/widgets/tutor_navigation_shell.dart';

List<BottomNavigationBarItem> _fakeBottomItems() {
  return const [
    BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: 'A'),
    BottomNavigationBarItem(icon: Icon(Icons.mail_outline), label: 'B'),
    BottomNavigationBarItem(icon: Icon(Icons.school_outlined), label: 'C'),
    BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'D'),
  ];
}

List<NavigationRailDestination> _fakeRailDestinations() {
  return const [
    NavigationRailDestination(icon: Icon(Icons.home_outlined), label: Text('A')),
    NavigationRailDestination(icon: Icon(Icons.mail_outline), label: Text('B')),
    NavigationRailDestination(icon: Icon(Icons.school_outlined), label: Text('C')),
    NavigationRailDestination(icon: Icon(Icons.person_outline), label: Text('D')),
  ];
}

void main() {
  testWidgets('TutorNavigationShell shows NavigationRail when useRail is true', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TutorNavigationShell(
          useRail: true,
          selectedIndex: 0,
          onIndexChanged: (_) {},
          tabBody: const Center(child: Text('Body')),
          bottomBarItems: _fakeBottomItems(),
          railDestinations: _fakeRailDestinations(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(BottomNavigationBar), findsNothing);
    expect(find.text('Body'), findsOneWidget);
  });

  testWidgets('TutorNavigationShell shows BottomNavigationBar when useRail is false', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TutorNavigationShell(
          useRail: false,
          selectedIndex: 0,
          onIndexChanged: (_) {},
          tabBody: const Center(child: Text('Body')),
          bottomBarItems: _fakeBottomItems(),
          railDestinations: _fakeRailDestinations(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(BottomNavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
  });
}
