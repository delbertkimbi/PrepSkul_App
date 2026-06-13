 import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';

/// App bar for game screens with deep blue background.
/// Uses white text and icons for clear contrast (avoids black text on deep blue).
class SkulMateGameAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  /// When set, used as the leading (e.g. back to dashboard instead of upload).
  final Widget? leading;
  final bool centerTitle;

  const SkulMateGameAppBar({
    Key? key,
    required this.title,
    this.actions,
    this.leading,
    this.centerTitle = true,
  }) : super(key: key);

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: AppTheme.primaryColor,
      foregroundColor: Colors.white,
      iconTheme: const IconThemeData(color: Colors.white),
      automaticallyImplyLeading: false,
      leading: leading ??
          (Navigator.canPop(context)
              ? IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                )
              : null),
      centerTitle: centerTitle,
      actionsIconTheme: const IconThemeData(size: 20, color: Colors.white),
      titleTextStyle: GoogleFonts.poppins(
        color: Colors.white,
        fontWeight: FontWeight.w600,
        fontSize: 16,
      ),
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: AppTheme.primaryColor,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: AppTheme.softBackground,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      elevation: 0,
      title: Text(
        title,
        style: GoogleFonts.poppins(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      actions: actions == null
          ? null
          : [
              ...actions!,
              const SizedBox(width: 8),
            ],
    );
  }
}
