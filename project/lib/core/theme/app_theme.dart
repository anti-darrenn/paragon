import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTheme {
  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.backgroundDark,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.primary,
      surface: AppColors.surfaceDark,
      error: AppColors.wrong,
    ),
    textTheme: GoogleFonts.montserratTextTheme(
      ThemeData.dark().textTheme,
    ),
    cardTheme: CardThemeData(
      color: AppColors.surfaceDark,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.borderDark, width: 0.5),
      ),
      elevation: 0,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.backgroundDark,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
    ),
  );

  static ThemeData get light => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: AppColors.backgroundLight,
    colorScheme: const ColorScheme.light(
      primary: AppColors.primary,
      surface: AppColors.surfaceLight,
      error: AppColors.wrong,
    ),
    textTheme: GoogleFonts.montserratTextTheme(
      ThemeData.light().textTheme,
    ),
    cardTheme: CardThemeData(
      color: AppColors.surfaceLight,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.borderLight, width: 0.5),
      ),
      elevation: 0,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.backgroundLight,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
    ),
  );

  // ── Text styles (Figma type scale) ──────────────────────────────────
  // TODO(figma): font weights are placeholders (regular) pending lookup
  // in the Figma file — see PR discussion. Update once confirmed.
  static TextStyle get displayLg        => GoogleFonts.montserrat(fontSize: 32, height: 1.2);
  static TextStyle get heading1         => GoogleFonts.montserrat(fontSize: 24, height: 1.3);
  static TextStyle get heading2         => GoogleFonts.montserrat(fontSize: 20, height: 1.3);
  static TextStyle get heading3         => GoogleFonts.montserrat(fontSize: 18, height: 1.4);
  static TextStyle get bodyLg           => GoogleFonts.montserrat(fontSize: 16, height: 1.6);
  static TextStyle get bodyMd           => GoogleFonts.montserrat(fontSize: 14, height: 1.6);
  static TextStyle get label            => GoogleFonts.montserrat(fontSize: 12, height: 1.4);
  static TextStyle get caption          => GoogleFonts.montserrat(fontSize: 11, height: 1.4);
  static TextStyle get btnLabel         => GoogleFonts.montserrat(fontSize: 14, height: 1.4);
  static TextStyle get navLabelActive   => GoogleFonts.montserrat(fontSize: 10, height: 1.2);
  static TextStyle get navLabelInactive => GoogleFonts.montserrat(fontSize: 10, height: 1.2);
}