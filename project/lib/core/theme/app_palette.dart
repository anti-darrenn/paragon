import 'package:flutter/material.dart';

import 'app_colors.dart';

/// The colours that differ between the dark and light themes.
///
/// Widgets read them as `context.palette.surface` and so on, never as
/// `AppColors.surfaceDark`, so the same widget draws correctly in either
/// theme. [AppColors] stays the only place a colour is *defined*: these are
/// two selections from it, one per theme, registered as a
/// [ThemeExtension] on [ThemeData] by `AppTheme`.
///
/// Colours that are the same in both themes — the brand orange, the
/// correct/wrong greens and reds, the subject colours — are still read from
/// [AppColors] directly.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.background,
    required this.surface,
    required this.border,
    required this.track,
    required this.textPrimary,
    required this.textSecondary,
    required this.textStrong,
    required this.onHigh,
    required this.onMedium,
    required this.onLow,
    required this.outline,
    required this.outlineFaint,
  });

  /// Page background.
  final Color background;

  /// Cards, sheets, dialogs, inputs.
  final Color surface;

  /// Hairlines and outlines.
  final Color border;

  /// Progress tracks, inactive dots, disabled fills.
  final Color track;

  /// Body text and icons.
  final Color textPrimary;

  /// Captions, hints, secondary icons.
  final Color textSecondary;

  // The screens written before the palette used translucent white on the
  // dark background (white, white70, white54, white38, white24, white12).
  // These reproduce those exactly in the dark theme, so moving a widget
  // onto the palette changes nothing there, and give the light theme the
  // matching translucent black.

  /// Headline text: pure white on dark.
  final Color textStrong;

  /// `white70` on dark: option text, secondary body.
  final Color onHigh;

  /// `white54` on dark: supporting text.
  final Color onMedium;

  /// Faint text, chevrons, disabled: 50% white on dark (was `white38`,
  /// raised to pass WCAG AA in October 2026).
  final Color onLow;

  /// `white24` on dark: option outlines.
  final Color outline;

  /// `white12` on dark: the faintest outlines and fills.
  final Color outlineFaint;

  static const dark = AppPalette(
    background: AppColors.backgroundDark,
    surface: AppColors.surfaceDark,
    border: AppColors.borderDark,
    track: AppColors.trackDark,
    textPrimary: AppColors.textPrimaryDark,
    textSecondary: AppColors.textSecondaryDark,
    textStrong: Colors.white,
    onHigh: Colors.white70,
    onMedium: Colors.white54,
    // 50% white, not white38: 38% is 3.5:1 on the background and fails
    // WCAG AA for the small text it is used for (exam question numbers,
    // "Untimed"); 50% is 4.6:1 on the background and on surfaces.
    onLow: Color(0x80FFFFFF),
    outline: Colors.white24,
    outlineFaint: Colors.white12,
  );

  static const light = AppPalette(
    background: AppColors.backgroundLight,
    surface: AppColors.surfaceLight,
    border: AppColors.borderLight,
    track: AppColors.trackLight,
    textPrimary: AppColors.textPrimaryLight,
    textSecondary: AppColors.textSecondaryLight,
    textStrong: AppColors.textStrongLight,
    onHigh: Colors.black87,
    onMedium: Colors.black54,
    // 56% black, not black38 (2.6:1): 4.6:1 on the light background and
    // on white surfaces — WCAG AA for small text.
    onLow: Color(0x8F000000),
    outline: Colors.black26,
    outlineFaint: Colors.black12,
  );

  @override
  AppPalette copyWith({
    Color? background,
    Color? surface,
    Color? border,
    Color? track,
    Color? textPrimary,
    Color? textSecondary,
    Color? textStrong,
    Color? onHigh,
    Color? onMedium,
    Color? onLow,
    Color? outline,
    Color? outlineFaint,
  }) => AppPalette(
    background: background ?? this.background,
    surface: surface ?? this.surface,
    border: border ?? this.border,
    track: track ?? this.track,
    textPrimary: textPrimary ?? this.textPrimary,
    textSecondary: textSecondary ?? this.textSecondary,
    textStrong: textStrong ?? this.textStrong,
    onHigh: onHigh ?? this.onHigh,
    onMedium: onMedium ?? this.onMedium,
    onLow: onLow ?? this.onLow,
    outline: outline ?? this.outline,
    outlineFaint: outlineFaint ?? this.outlineFaint,
  );

  @override
  AppPalette lerp(AppPalette? other, double t) {
    if (other == null) return this;
    return AppPalette(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      border: Color.lerp(border, other.border, t)!,
      track: Color.lerp(track, other.track, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textStrong: Color.lerp(textStrong, other.textStrong, t)!,
      onHigh: Color.lerp(onHigh, other.onHigh, t)!,
      onMedium: Color.lerp(onMedium, other.onMedium, t)!,
      onLow: Color.lerp(onLow, other.onLow, t)!,
      outline: Color.lerp(outline, other.outline, t)!,
      outlineFaint: Color.lerp(outlineFaint, other.outlineFaint, t)!,
    );
  }
}

extension PaletteOf on BuildContext {
  /// This theme's palette. Dark when none is registered — a widget test
  /// that pumps a bare `MaterialApp` still gets the app's usual colours.
  AppPalette get palette =>
      Theme.of(this).extension<AppPalette>() ?? AppPalette.dark;
}
