import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/features/tutor/widgets/tutor_shell_scope.dart';

/// App bar with a consistent top-left back arrow for pushed sub-pages.
class PrepSkulBackAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;
  final Color? backgroundColor;
  final bool centerTitle;
  final VoidCallback? onBack;
  /// After pop, switch tutor shell to Home tab (fixes landing on Sessions after back).
  final bool returnToTutorHome;

  const PrepSkulBackAppBar({
    super.key,
    required this.title,
    this.actions,
    this.bottom,
    this.backgroundColor,
    this.centerTitle = false,
    this.onBack,
    this.returnToTutorHome = true,
  });

  @override
  Size get preferredSize {
    final bottomHeight = bottom?.preferredSize.height ?? 0.0;
    return Size.fromHeight(kToolbarHeight + bottomHeight);
  }

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: backgroundColor ?? Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: centerTitle,
      automaticallyImplyLeading: false,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: AppTheme.textDark),
        tooltip: 'Back',
        onPressed: onBack ??
            () {
              if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              }
              if (returnToTutorHome) {
                TutorShellScope.navigateHome(context);
              }
            },
      ),
      title: Text(
        title,
        style: GoogleFonts.poppins(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: AppTheme.textDark,
        ),
      ),
      actions: actions,
      bottom: bottom,
    );
  }
}
