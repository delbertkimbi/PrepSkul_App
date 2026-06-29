import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';

/// Bold, modern SkulMate typography — game-feeling but not oversized.
class SkulMateTypography {
  SkulMateTypography._();

  static TextStyle sectionTitle({Color? color}) => GoogleFonts.plusJakartaSans(
        fontSize: 15,
        fontWeight: FontWeight.w900,
        color: color ?? AppTheme.textDark,
        letterSpacing: -0.2,
        height: 1.2,
      );

  static TextStyle heroTitle({Color? color}) => GoogleFonts.plusJakartaSans(
        fontSize: 22,
        fontWeight: FontWeight.w900,
        color: color ?? AppTheme.textDark,
        letterSpacing: -0.45,
        height: 1.2,
      );

  static TextStyle screenTitle({Color? color}) => GoogleFonts.plusJakartaSans(
        fontSize: 20,
        fontWeight: FontWeight.w800,
        color: color ?? AppTheme.textDark,
        height: 1.2,
      );

  static TextStyle cardTitle({Color? color, double size = 14}) =>
      GoogleFonts.plusJakartaSans(
        fontSize: size,
        fontWeight: FontWeight.w800,
        color: color ?? AppTheme.textDark,
        height: 1.2,
      );

  /// Home / library game tiles — extra weight for the bold Gizmo feel.
  static TextStyle gameCardTitle({Color? color, double size = 14}) =>
      GoogleFonts.plusJakartaSans(
        fontSize: size,
        fontWeight: FontWeight.w900,
        color: color ?? AppTheme.textDark,
        letterSpacing: -0.28,
        height: 1.15,
      );

  static TextStyle gameCardMeta({Color? color, double size = 11}) =>
      GoogleFonts.plusJakartaSans(
        fontSize: size,
        fontWeight: FontWeight.w600,
        color: color ?? AppTheme.textMedium,
        height: 1.2,
      );

  static TextStyle cardMeta({Color? color, double size = 12}) =>
      GoogleFonts.plusJakartaSans(
        fontSize: size,
        fontWeight: FontWeight.w500,
        color: color ?? AppTheme.textMedium,
        height: 1.3,
      );

  static TextStyle body({Color? color, double size = 14}) =>
      GoogleFonts.plusJakartaSans(
        fontSize: size,
        fontWeight: FontWeight.w500,
        color: color ?? AppTheme.textDark,
        height: 1.45,
      );

  static TextStyle linkAction({Color? color}) => GoogleFonts.plusJakartaSans(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: color ?? AppTheme.primaryColor,
      );

  static TextStyle chipLabel({Color? color}) => GoogleFonts.plusJakartaSans(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: color ?? AppTheme.textDark,
        height: 1.15,
      );

  static TextStyle nextStopEyebrow({Color? color}) =>
      GoogleFonts.plusJakartaSans(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: color ?? AppTheme.primaryColor,
        letterSpacing: 0.2,
      );

  static TextStyle tabLabel({required bool selected}) =>
      GoogleFonts.plusJakartaSans(
        fontSize: 14,
        fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
        color: selected ? AppTheme.textDark : AppTheme.textMedium,
      );

  static TextStyle answerHighlight({Color? color}) => GoogleFonts.plusJakartaSans(
        fontSize: 14,
        fontWeight: FontWeight.w800,
        color: color ?? AppTheme.accentGreen,
        height: 1.35,
      );
}
