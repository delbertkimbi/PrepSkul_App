import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';

/// Exposes tutor bottom-nav control so tab screens can return to Home (tab 0).
class TutorShellScope extends InheritedWidget {
  const TutorShellScope({
    super.key,
    required this.goToHomeTab,
    required super.child,
  });

  final VoidCallback goToHomeTab;

  static TutorShellScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<TutorShellScope>();
  }

  static void navigateHome(BuildContext context) {
    maybeOf(context)?.goToHomeTab();
  }

  @override
  bool updateShouldNotify(TutorShellScope oldWidget) => false;
}

/// App bar for tutor main tabs (Requests, Sessions, Profile): back goes to Home tab.
class TutorTabAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;

  const TutorTabAppBar({
    super.key,
    required this.title,
    this.actions,
    this.bottom,
  });

  @override
  Size get preferredSize {
    final bottomHeight = bottom?.preferredSize.height ?? 0.0;
    return Size.fromHeight(kToolbarHeight + bottomHeight);
  }

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      automaticallyImplyLeading: false,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: AppTheme.textDark),
        tooltip: 'Back to Home',
        onPressed: () => TutorShellScope.navigateHome(context),
      ),
      title: Text(
        title,
        style: GoogleFonts.poppins(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: AppTheme.textDark,
        ),
      ),
      actions: actions,
      bottom: bottom,
    );
  }
}
