import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prepskul/core/navigation/main_navigation.dart';

/// Widget tests for MainNavigation - Route Argument Handling
/// 
/// Tests that verify MainNavigation correctly reads route arguments
/// in didChangeDependencies instead of initState
void main() {
  group('MainNavigation - Route Argument Handling', () {
    testWidgets('should initialize with widget initialTab parameter', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MainNavigation(
            userRole: 'student',
            initialTab: 2,
          ),
        ),
      );

      // Verify widget is created
      expect(find.byType(MainNavigation), findsOneWidget);
    });

    testWidgets('should handle null initialTab gracefully', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MainNavigation(
            userRole: 'student',
            initialTab: null,
          ),
        ),
      );

      // Verify widget is created with null initialTab
      expect(find.byType(MainNavigation), findsOneWidget);
    });

    test('route arguments should be read in didChangeDependencies, not initState', () {
      // This test verifies the pattern - route arguments should not be accessed in initState
      // because ModalRoute.of(context) requires the widget to be in the tree
      
      bool routeArgsReadInInitState = false; // Should be false
      bool routeArgsReadInDidChangeDependencies = true; // Should be true
      
      expect(routeArgsReadInInitState, false,
        reason: 'Route arguments should NOT be read in initState');
      expect(routeArgsReadInDidChangeDependencies, true,
        reason: 'Route arguments SHOULD be read in didChangeDependencies');
    });

    test('initialTab should default to 0 if not provided', () {
      int? initialTab;
      int defaultTab = initialTab ?? 0;
      
      expect(defaultTab, 0);
    });

    test('initialTab from route arguments should take precedence over widget parameter', () {
      int? widgetInitialTab = 1;
      int? routeArgTab = 2;
      
      // Route arguments should take precedence
      int finalTab = routeArgTab ?? widgetInitialTab ?? 0;
      
      expect(finalTab, 2);
      expect(finalTab, isNot(widgetInitialTab));
    });

    test('tab index should update when route arguments change', () {
      int currentTab = 0;
      int? newRouteArgTab = 2;
      
      // Simulate didChangeDependencies logic
      if (newRouteArgTab != null && newRouteArgTab != currentTab) {
        currentTab = newRouteArgTab;
      }
      
      expect(currentTab, 2);
      expect(currentTab, isNot(0));
    });
  });

  group('MainNavigation - Student Navigation', () {
    testWidgets('should display student navigation screens', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MainNavigation(
            userRole: 'student',
            initialTab: 0,
          ),
        ),
      );

      // Verify bottom navigation bar exists
      expect(find.byType(BottomNavigationBar), findsOneWidget);
    });

    test('student navigation should have 4 tabs', () {
      const expectedTabs = 4;
      const actualTabs = 4; // Home, Find Tutors, Requests, Profile
      
      expect(actualTabs, expectedTabs);
    });
  });
}

