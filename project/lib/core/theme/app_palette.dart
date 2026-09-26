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

  static const dark = AppPalette(
    background: AppColors.backgroundDark,
    surface: AppColors.surfaceDark,
    border: AppColors.borderDark,
    track: AppColors.trackDark,
    textPrimary: AppColors.textPrimaryDark,
    textSecondary: AppColors.textSecondaryDark,
  );

  static const light = AppPalette(
    background: AppColors.backgroundLight,
    surface: AppColors.surfaceLight,
    border: AppColors.borderLight,
    track: AppColors.trackLight,
    textPrimary: AppColors.textPrimaryLight,
    textSecondary: AppColors.textSecondaryLight,
  );

  @override
  AppPalette copyWith({
    Color? background,
    Color? surface,
    Color? border,
    Color? track,
    Color? textPrimary,
    Color? textSecondary,
  }) => AppPalette(
    background: background ?? this.background,
    surface: surface ?? this.surface,
    border: border ?? this.border,
    track: track ?? this.track,
    textPrimary: textPrimary ?? this.textPrimary,
    textSecondary: textSecondary ?? this.textSecondary,
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
    );
  }
}

extension PaletteOf on BuildContext {
  /// This theme's palette. Dark when none is registered — a widget test
  /// that pumps a bare `MaterialApp` still gets the app's usual colours.
  AppPalette get palette =>
      Theme.of(this).extension<AppPalette>() ?? AppPalette.dark;
}
