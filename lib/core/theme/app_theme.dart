import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Primary Colors - PrepSkul Deep Blue Palette
  static const Color primaryColor = Color(0xFF1B2C4F); // Deep Blue
  static const Color mateBodyBlue = Color(0xFF496FBC);
  static const Color mateBellyTeal = Color(0xFF0EA5E9);
  static const Color mateAntennaYellow = Color(0xFFEAB308);
  static const Color primaryLight = Color(0xFF4A6FBF); // Lighter blue
  static const Color primaryDark = Color(0xFF0F1A2E); // Darker blue

  // Paper palette shared by onboarding and every app surface.
  static const Color backgroundColor = Color(
    0xFFFAF8F3,
  ); // Warm onboarding paper
  static const Color surfaceColor = Color(0xFFFFFFFF); // Pure white
  static const Color cardColor = Color(0xFFFFFFFF); // White paper cards

  // Soft Background Colors for the glassy effect
  static const Color softBackground = backgroundColor; // Warm page background
  static const Color softCard = Color(0xFFFFFFFF); // White paper cards
  static const Color softBorder = Color(0xFFD1D5DE); // Navy-tinted paper border

  // Accent Colors - Complementary soft colors
  static const Color accentBlue = Color(0xFF4A6FBF);
  static const Color accentPurple = Color(0xFF6366F1);
  static const Color accentPink = Color(0xFFEC4899);
  static const Color accentGreen = Color(0xFF10B981);
  static const Color accentOrange = Color(0xFFF59E0B);

  // Light accent colors for neumorphic effects
  static const Color accentLightBlue = Color(0xFFD0E0FF);
  static const Color accentLightPurple = Color(0xFFF3E8FF);
  static const Color accentLightPink = Color(0xFFFCE7F3);
  static const Color accentLightGreen = Color(0xFFD1FAE5);
  static const Color accentLightOrange = Color(0xFFFEF3C7);

  // PrepSkul brand accents (deep blue + sky blue + yellow): soft and exciting
  /// Sky blue — calm, focus; pairs with deep blue header
  static const Color skyBlue = Color(0xFF0EA5E9);
  static const Color skyBlueLight = Color(0xFFE0F2FE);

  /// Soft yellow — warmth, energy; use for key stats and CTAs
  static const Color softYellow = Color(0xFFEAB308);
  static const Color softYellowLight = Color(0xFFFEF9C3);

  // Neutral Colors - Soft grays
  static const Color neutral50 = Color(0xFFF9FAFB);
  static const Color neutral100 = Color(0xFFF3F4F6);
  static const Color neutral200 = Color(0xFFE5E7EB);
  static const Color neutral300 = Color(0xFFD1D5DB);
  static const Color neutral400 = Color(0xFF9CA3AF);
  static const Color neutral500 = Color(0xFF6B7280);
  static const Color neutral600 = Color(0xFF4B5563);
  static const Color neutral700 = Color(0xFF374151);
  static const Color neutral800 = Color(0xFF1F2937);
  static const Color neutral900 = Color(0xFF111827);

  // Text Colors
  static const Color textDark = primaryColor;
  static const Color textMedium = Color(0xFF526078);
  static const Color textLight = Color(0xFF667085);

  // Status Colors
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);

  /// Gentle in-game nudge for wrong answers (warm amber, not alarm red).
  static const Color gameNudgeBg = Color(0xFFFFFBEB);
  static const Color gameNudgeFg = Color(0xFF92400E);
  static const Color gameNudgeBorder = Color(0xFFFDE68A);
  static const Color gameNudgeGlow = Color(0xFFF59E0B);

  // Gradient Colors
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF1B2C4F), Color(0xFF4A6FBF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Stitch color-pair token mapping (deep blue / sky blue / yellow).
  static const LinearGradient stitchDeepBlueGradient = primaryGradient;
  static const LinearGradient stitchSkyBlueGradient = LinearGradient(
    colors: [skyBlue, skyBlueLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient stitchYellowGradient = LinearGradient(
    colors: [softYellow, softYellowLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Soft top-to-bottom gradient for app bar / auth headers. Stays close to deep blue for theme-color consistency; subtle neumorphic depth.
  static const LinearGradient headerGradient = LinearGradient(
    colors: [Color(0xFF1B2C4F), Color(0xFF1E3254)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient softGradient = LinearGradient(
    colors: [Color(0xFFF8FAFC), Color(0xFFE2E8F0)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // Get the app theme data
  static ThemeData get lightTheme {
    return ThemeData(
      primaryColor: primaryColor,
      scaffoldBackgroundColor: backgroundColor,
      colorScheme: ColorScheme.light(
        primary: primaryColor,
        secondary: mateBodyBlue,
        tertiary: softYellow,
        onTertiary: primaryColor,
        primaryContainer: skyBlueLight,
        onPrimaryContainer: primaryColor,
        secondaryContainer: softYellowLight,
        onSecondaryContainer: primaryColor,
        outline: softBorder,
        surface: surfaceColor,
        background: backgroundColor,
        error: error,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: textDark,
        onBackground: textDark,
        onError: Colors.white,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: backgroundColor,
        surfaceTintColor: Colors.transparent,
        foregroundColor: textDark,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontFamily: 'Fredoka',
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: textDark,
        ),
      ),
      textTheme: GoogleFonts.nunitoTextTheme().copyWith(
        displayLarge: TextStyle(
          fontFamily: 'Fredoka',
          fontSize: 32,
          fontWeight: FontWeight.w800,
          color: textDark,
          letterSpacing: -0.5,
        ),
        displayMedium: TextStyle(
          fontFamily: 'Fredoka',
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: textDark,
          letterSpacing: -0.25,
        ),
        displaySmall: TextStyle(
          fontFamily: 'Fredoka',
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: textDark,
        ),
        headlineLarge: TextStyle(
          fontFamily: 'Fredoka',
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: textDark,
        ),
        headlineMedium: TextStyle(
          fontFamily: 'Fredoka',
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: textDark,
        ),
        headlineSmall: TextStyle(
          fontFamily: 'Fredoka',
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: textDark,
        ),
        titleLarge: GoogleFonts.nunito(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: textDark,
        ),
        titleMedium: GoogleFonts.nunito(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: textDark,
        ),
        titleSmall: GoogleFonts.nunito(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: textMedium,
        ),
        bodyLarge: GoogleFonts.nunito(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: textDark,
          height: 1.6,
        ),
        bodyMedium: GoogleFonts.nunito(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: textMedium,
          height: 1.5,
        ),
        bodySmall: GoogleFonts.nunito(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: textLight,
          height: 1.4,
        ),
        labelLarge: GoogleFonts.nunito(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: textDark,
        ),
        labelMedium: GoogleFonts.nunito(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: textMedium,
        ),
        labelSmall: GoogleFonts.nunito(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: textLight,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(48, 56),
          shadowColor: primaryColor.withOpacity(0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(
              24,
            ), // More rounded for softness
          ),
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 36),
          textStyle: GoogleFonts.nunito(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            height: 1.2,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryColor,
          minimumSize: const Size(48, 48),
          side: const BorderSide(color: primaryColor, width: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          textStyle: GoogleFonts.nunito(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            height: 1.2,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: softCard, // Soft white for glassy effect
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20), // More rounded for softness
          borderSide: const BorderSide(color: softBorder, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: softBorder, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: error, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: error, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 24,
          vertical: 20,
        ),
        labelStyle: GoogleFonts.nunito(
          color: textMedium,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        hintStyle: GoogleFonts.nunito(
          color: textLight,
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surfaceColor,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: softBorder, width: 2),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: backgroundColor,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: mateBodyBlue,
        linearTrackColor: skyBlueLight,
      ),
      cardTheme: CardThemeData(
        color: softCard,
        elevation: 2, // Subtle elevation for softness
        shadowColor: Colors.black.withOpacity(0.05),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: softBorder, width: 1.5),
        ),
      ),
    );
  }
}
