import 'package:flutter/material.dart';
import 'package:prepskul/core/utils/responsive_helper.dart';

/// Constrains tutor tab content on wide screens (laptops / web) for readable line
/// length and consistent gutters. Use as the root wrapper inside each tutor shell tab.
class TutorPageBody extends StatelessWidget {
  const TutorPageBody({
    super.key,
    required this.child,
    this.maxWidth = 1280,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    // Mobile tabs manage their own gutters — avoid double padding with screen scroll views.
    final horizontalPad = ResponsiveHelper.isMobile(context)
        ? 0.0
        : ResponsiveHelper.responsiveHorizontalPadding(context);
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: horizontalPad > 0
            ? Padding(
                padding: EdgeInsets.symmetric(horizontal: horizontalPad),
                child: child,
              )
            : child,
      ),
    );
  }
}
