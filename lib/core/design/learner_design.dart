import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Shared visual contract for the signed-in learner experience.
class LearnerDesign {
  LearnerDesign._();
  static const ink = Color(0xFF1B2C4F);
  static const muted = Color(0xFF69758A);
  static const canvas = Color(0xFFFAF8F3);
  static const line = Color(0xFFE7E9ED);
  static const blue = Color(0xFF0EA5E9);
  static const sky = Color(0xFFE0F2FE);
  static TextStyle title([double size = 26]) => TextStyle(
    fontFamily: 'Fredoka',
    fontSize: size,
    fontWeight: FontWeight.w500,
    color: ink,
    height: 1.2,
    letterSpacing: -.2,
  );
  static TextStyle body([double size = 15]) => GoogleFonts.nunito(
    fontSize: size,
    fontWeight: FontWeight.w500,
    color: muted,
    height: 1.5,
  );
  static TextStyle text({
    double size = 16,
    FontWeight weight = FontWeight.w500,
    Color color = ink,
    double height = 1.4,
  }) => GoogleFonts.nunito(
    fontSize: size,
    fontWeight: weight,
    color: color,
    height: height,
  );
  static TextStyle display({
    double size = 22,
    FontWeight weight = FontWeight.w700,
    Color color = ink,
  }) => text(size: size, weight: weight, color: color, height: 1.25);
  static BoxDecoration surface({bool selected = false}) => BoxDecoration(
    color: selected ? sky : Colors.white,
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: selected ? const Color(0xFFBED8FB) : line),
  );
  static ThemeData theme(ThemeData base) => base.copyWith(
    scaffoldBackgroundColor: canvas,
    colorScheme: base.colorScheme.copyWith(
      primary: blue,
      onPrimary: Colors.white,
      surface: Colors.white,
      onSurface: ink,
      outline: line,
    ),
    textTheme: GoogleFonts.nunitoTextTheme(
      base.textTheme,
    ).apply(bodyColor: ink, displayColor: ink),
    dividerColor: line,
    appBarTheme: AppBarTheme(
      backgroundColor: canvas,
      foregroundColor: ink,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: title(21),
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: Colors.white,
      selectedColor: sky,
      side: const BorderSide(color: line),
      labelStyle: body(14).copyWith(color: ink),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: blue, width: 1.5),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: blue,
        foregroundColor: Colors.white,
        elevation: 0,
        minimumSize: const Size(48, 48),
        textStyle: body(15).copyWith(fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      ),
    ),
  );
}
