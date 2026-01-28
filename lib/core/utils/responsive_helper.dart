import 'package:flutter/material.dart';

/// Responsive design helper for consistent breakpoints across all screen sizes
/// Ensures cool, nice UI on phones, tablets, and desktop
class ResponsiveHelper {
  // Breakpoints
  static const double mobileBreakpoint = 600;
  static const double tabletBreakpoint = 900;
  static const double desktopBreakpoint = 1200;

  /// Get screen size category
  static ScreenSize getScreenSize(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < mobileBreakpoint) {
      return ScreenSize.mobile;
    } else if (width < tabletBreakpoint) {
      return ScreenSize.tablet;
    } else {
      return ScreenSize.desktop;
    }
  }

  /// Get screen height category
  static ScreenHeight getScreenHeight(BuildContext context) {
    final height = MediaQuery.of(context).size.height;
    if (height < 600) {
      return ScreenHeight.verySmall;
    } else if (height < 700) {
      return ScreenHeight.small;
    } else if (height < 900) {
      return ScreenHeight.normal;
    } else {
      return ScreenHeight.large;
    }
  }

  /// Responsive padding based on screen size
  static EdgeInsets responsivePadding(BuildContext context) {
    final size = getScreenSize(context);
    switch (size) {
      case ScreenSize.mobile:
        return const EdgeInsets.all(16);
      case ScreenSize.tablet:
        return const EdgeInsets.all(24);
      case ScreenSize.desktop:
        return const EdgeInsets.all(32);
    }
  }

  /// Responsive horizontal padding
  static double responsiveHorizontalPadding(BuildContext context) {
    final size = getScreenSize(context);
    switch (size) {
      case ScreenSize.mobile:
        return 16;
      case ScreenSize.tablet:
        return 24;
      case ScreenSize.desktop:
        return 32;
    }
  }

  /// Responsive vertical padding
  static double responsiveVerticalPadding(BuildContext context) {
    final size = getScreenSize(context);
    switch (size) {
      case ScreenSize.mobile:
        return 16;
      case ScreenSize.tablet:
        return 20;
      case ScreenSize.desktop:
        return 24;
    }
  }

  /// Responsive font size for headings
  static double responsiveHeadingSize(BuildContext context) {
    final size = getScreenSize(context);
    final height = getScreenHeight(context);
    
    // Adjust for very small screens
    if (height == ScreenHeight.verySmall) {
      return size == ScreenSize.mobile ? 20 : 22;
    }
    
    switch (size) {
      case ScreenSize.mobile:
        return 22;
      case ScreenSize.tablet:
        return 26;
      case ScreenSize.desktop:
        return 30;
    }
  }

  /// Responsive font size for body text
  static double responsiveBodySize(BuildContext context) {
    final height = getScreenHeight(context);
    if (height == ScreenHeight.verySmall) {
      return 13;
    }
    return 14;
  }

  /// Responsive font size for subheadings
  static double responsiveSubheadingSize(BuildContext context) {
    final size = getScreenSize(context);
    final height = getScreenHeight(context);
    
    if (height == ScreenHeight.verySmall) {
      return size == ScreenSize.mobile ? 15 : 16;
    }
    
    switch (size) {
      case ScreenSize.mobile:
        return 16;
      case ScreenSize.tablet:
        return 18;
      case ScreenSize.desktop:
        return 20;
    }
  }

  /// Responsive card max width (prevents cards from being too wide on desktop)
  static double responsiveCardMaxWidth(BuildContext context) {
    final size = getScreenSize(context);
    switch (size) {
      case ScreenSize.mobile:
        return double.infinity;
      case ScreenSize.tablet:
        return 600;
      case ScreenSize.desktop:
        return 700;
    }
  }

  /// Responsive spacing between elements
  static double responsiveSpacing(BuildContext context, {double mobile = 16, double tablet = 20, double desktop = 24}) {
    final size = getScreenSize(context);
    switch (size) {
      case ScreenSize.mobile:
        return mobile;
      case ScreenSize.tablet:
        return tablet;
      case ScreenSize.desktop:
        return desktop;
    }
  }

  /// Responsive icon size
  static double responsiveIconSize(BuildContext context, {double mobile = 24, double tablet = 28, double desktop = 32}) {
    final size = getScreenSize(context);
    switch (size) {
      case ScreenSize.mobile:
        return mobile;
      case ScreenSize.tablet:
        return tablet;
      case ScreenSize.desktop:
        return desktop;
    }
  }

  /// Get number of columns for grid layouts
  static int responsiveGridColumns(BuildContext context) {
    final size = getScreenSize(context);
    switch (size) {
      case ScreenSize.mobile:
        return 1;
      case ScreenSize.tablet:
        return 2;
      case ScreenSize.desktop:
        return 3;
    }
  }

  /// Responsive container width (centered with max width on larger screens)
  static Widget responsiveContainer({
    required BuildContext context,
    required Widget child,
    EdgeInsets? padding,
  }) {
    final size = getScreenSize(context);
    final maxWidth = responsiveCardMaxWidth(context);
    
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: padding ?? responsivePadding(context),
          child: child,
        ),
      ),
    );
  }

  /// Check if screen is mobile
  static bool isMobile(BuildContext context) {
    return getScreenSize(context) == ScreenSize.mobile;
  }

  /// Check if screen is tablet
  static bool isTablet(BuildContext context) {
    return getScreenSize(context) == ScreenSize.tablet;
  }

  /// Check if screen is desktop
  static bool isDesktop(BuildContext context) {
    return getScreenSize(context) == ScreenSize.desktop;
  }

  /// Check if screen is small height
  static bool isSmallHeight(BuildContext context) {
    final height = getScreenHeight(context);
    return height == ScreenHeight.verySmall || height == ScreenHeight.small;
  }
}

enum ScreenSize {
  mobile,
  tablet,
  desktop,
}

enum ScreenHeight {
  verySmall, // < 600px
  small,     // 600-700px
  normal,     // 700-900px
  large,      // > 900px
}

