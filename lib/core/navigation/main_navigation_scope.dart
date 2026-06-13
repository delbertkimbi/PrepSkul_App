import 'package:flutter/material.dart';

/// Lets child tabs (e.g. student home) switch bottom-nav index without
/// replacing the navigation route.
class MainNavigationScope extends InheritedWidget {
  final void Function(int index) switchTab;
  final int selectedIndex;

  const MainNavigationScope({
    super.key,
    required this.switchTab,
    required this.selectedIndex,
    required super.child,
  });

  static MainNavigationScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<MainNavigationScope>();
  }

  static MainNavigationScope of(BuildContext context) {
    final scope = maybeOf(context);
    assert(scope != null, 'MainNavigationScope not found in widget tree');
    return scope!;
  }

  @override
  bool updateShouldNotify(MainNavigationScope oldWidget) {
    return selectedIndex != oldWidget.selectedIndex ||
        switchTab != oldWidget.switchTab;
  }
}
