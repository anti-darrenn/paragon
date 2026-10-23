import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';
import 'app_palette.dart';
import 'tokens.dart';

class AppTheme {
  static ThemeData get dark => _build(Brightness.dark, AppPalette.dark);

  static ThemeData get light => _build(Brightness.light, AppPalette.light);

  /// Corner radii, so cards, buttons and fields agree. Aliases of
  /// [Radii], kept so older call sites read the same.
  static const double radiusSm = Radii.sm;
  static const double radiusMd = Radii.md;
  static const double radiusLg = Radii.lg;

  /// One theme for both brightnesses, built from the palette. Every
  /// Material component a screen uses without styling it — buttons,
  /// fields, dialogs, snackbars, chips, switches, menus — takes its look
  /// from here, so a screen that writes no styling still matches the rest.
  static ThemeData _build(Brightness brightness, AppPalette p) {
    final isDark = brightness == Brightness.dark;
    final base = isDark ? ThemeData.dark() : ThemeData.light();
    final scheme =
        (isDark ? const ColorScheme.dark() : const ColorScheme.light())
            .copyWith(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              secondary: AppColors.secondary,
              surface: p.surface,
              onSurface: p.textPrimary,
              onSurfaceVariant: p.textSecondary,
              surfaceContainerHighest: p.track,
              outline: p.border,
              outlineVariant: p.border,
              error: AppColors.wrong,
            );
    final shapeMd = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radiusMd),
    );
    final buttonText = btnLabel.copyWith(fontWeight: FontWeight.w600);
    const buttonPadding = EdgeInsets.symmetric(horizontal: 18, vertical: 14);
    OutlineInputBorder fieldBorder(Color c, [double w = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide(color: c, width: w),
        );
    WidgetStateProperty<Color> whenSelected(Color on, Color off) =>
        WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? on : off,
        );
    // A visible ring on a button that has keyboard focus. Material's own
    // focus overlay is a 10% tint, which on an orange button is invisible.
    WidgetStateProperty<BorderSide?> focusRing(BorderSide? rest) =>
        WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.focused)
              ? BorderSide(color: p.textStrong, width: 2)
              : rest,
        );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: p.background,
      canvasColor: p.background,
      colorScheme: scheme,
      // Material's text theme, on the app's type scale where screens read
      // it (`textTheme.titleMedium`, `bodySmall`), so a widget styled
      // through the theme lands on the same sizes as one using AppTheme.
      textTheme: GoogleFonts.spaceGroteskTextTheme(base.textTheme)
          .copyWith(
            displayLarge: display,
            displayMedium: displayLg,
            displaySmall: heading1,
            headlineLarge: heading1,
            headlineMedium: heading2,
            headlineSmall: heading3,
            titleLarge: heading2,
            titleMedium: bodyLg.copyWith(
              fontWeight: FontWeight.w600,
              height: 1.45,
            ),
            titleSmall: bodyMd.copyWith(
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
            bodySmall: label,
            labelLarge: btnLabel,
            labelMedium: label,
            labelSmall: caption,
          )
          .apply(bodyColor: p.textPrimary, displayColor: p.textPrimary),
      hoverColor: p.track.withAlpha(120),
      focusColor: AppColors.primary.withAlpha(46),
      pageTransitionsTheme: PageTransitionsTheme(
        builders: {
          for (final platform in TargetPlatform.values)
            platform: const _FadePageTransitionsBuilder(),
        },
      ),
      dividerTheme: DividerThemeData(color: p.border, thickness: 1, space: 1),
      iconTheme: IconThemeData(color: p.textSecondary),
      cardTheme: CardThemeData(
        color: p.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          side: BorderSide(color: p.border),
        ),
        elevation: 0,
        margin: EdgeInsets.zero,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: p.background,
        foregroundColor: p.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: heading3.copyWith(color: p.textPrimary),
        iconTheme: IconThemeData(color: p.textPrimary),
        actionsIconTheme: IconThemeData(color: p.textSecondary),
        shape: Border(bottom: BorderSide(color: p.border.withAlpha(110))),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: p.track,
          disabledForegroundColor: p.textSecondary,
          elevation: 0,
          padding: buttonPadding,
          minimumSize: const Size(64, 48),
          shape: shapeMd,
          textStyle: buttonText,
        ).copyWith(side: focusRing(null)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: p.track,
          disabledForegroundColor: p.textSecondary,
          padding: buttonPadding,
          minimumSize: const Size(64, 48),
          shape: shapeMd,
          textStyle: buttonText,
        ).copyWith(side: focusRing(null)),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: p.textPrimary,
          side: BorderSide(color: p.border),
          padding: buttonPadding,
          minimumSize: const Size(64, 48),
          shape: shapeMd,
          textStyle: buttonText,
        ).copyWith(side: focusRing(BorderSide(color: p.border))),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: p.primaryFg,
          // Tall enough to tap: it had no minimum and sat shorter than
          // every other button.
          minimumSize: const Size(48, 40),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusSm),
          ),
          textStyle: buttonText,
        ).copyWith(side: focusRing(null)),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusSm + 2),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        hintStyle: bodyMd.copyWith(color: p.textSecondary),
        labelStyle: bodyMd.copyWith(color: p.textSecondary),
        floatingLabelStyle: bodyMd.copyWith(color: p.primaryFg),
        helperStyle: label.copyWith(color: p.textSecondary),
        errorStyle: label.copyWith(color: p.dangerFg),
        prefixIconColor: p.textSecondary,
        suffixIconColor: p.textSecondary,
        border: fieldBorder(p.border),
        enabledBorder: fieldBorder(p.border),
        disabledBorder: fieldBorder(p.border.withAlpha(120)),
        focusedBorder: fieldBorder(AppColors.primary, 1.5),
        errorBorder: fieldBorder(AppColors.wrong),
        focusedErrorBorder: fieldBorder(AppColors.wrong, 1.5),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: AppColors.primary,
        selectionColor: AppColors.primary.withAlpha(70),
        selectionHandleColor: AppColors.primary,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
          side: BorderSide(color: p.border),
        ),
        titleTextStyle: heading3.copyWith(color: p.textPrimary),
        contentTextStyle: bodyMd.copyWith(color: p.textSecondary),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: p.border,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(radiusLg)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: p.textStrong,
        contentTextStyle: bodyMd.copyWith(color: p.background),
        // The snackbar is inverted (light on dark, dark on light), so the
        // action takes the orange that reads on the snackbar's own fill.
        actionTextColor: isDark
            ? AppColors.primaryTextLight
            : AppColors.primary,
        shape: shapeMd,
        insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: p.surface,
        selectedColor: AppColors.primary.withAlpha(40),
        side: BorderSide(color: p.border),
        labelStyle: label.copyWith(color: p.textPrimary),
        secondaryLabelStyle: label.copyWith(color: p.primaryFg),
        checkmarkColor: AppColors.primary,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSm + 2),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: whenSelected(Colors.white, p.textSecondary),
        trackColor: whenSelected(AppColors.primary, p.track),
        trackOutlineColor: whenSelected(Colors.transparent, p.border),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: whenSelected(AppColors.primary, Colors.transparent),
        checkColor: const WidgetStatePropertyAll(Colors.white),
        side: BorderSide(color: p.textSecondary, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      ),
      radioTheme: RadioThemeData(
        fillColor: whenSelected(AppColors.primary, p.textSecondary),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: AppColors.primary,
        inactiveTrackColor: p.track,
        thumbColor: AppColors.primary,
        overlayColor: AppColors.primary.withAlpha(40),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: AppColors.primary,
        linearTrackColor: p.track,
        circularTrackColor: Colors.transparent,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: p.textSecondary,
        textColor: p.textPrimary,
        titleTextStyle: bodyMd.copyWith(
          color: p.textPrimary,
          fontWeight: FontWeight.w500,
        ),
        subtitleTextStyle: label.copyWith(color: p.textSecondary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSm + 2),
        ),
      ),
      expansionTileTheme: ExpansionTileThemeData(
        iconColor: p.textSecondary,
        collapsedIconColor: p.textSecondary,
        shape: const Border(),
        collapsedShape: const Border(),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: p.textStrong,
          borderRadius: BorderRadius.circular(radiusSm),
        ),
        textStyle: label.copyWith(color: p.background),
        waitDuration: const Duration(milliseconds: 400),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: p.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          side: BorderSide(color: p.border),
        ),
        textStyle: bodyMd.copyWith(color: p.textPrimary),
      ),
      menuTheme: MenuThemeData(
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(p.surface),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radiusMd),
              side: BorderSide(color: p.border),
            ),
          ),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          selectedBackgroundColor: AppColors.primary.withAlpha(40),
          selectedForegroundColor: p.primaryFg,
          foregroundColor: p.textSecondary,
          side: BorderSide(color: p.border),
          textStyle: label,
        ),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: p.primaryFg,
        unselectedLabelColor: p.textSecondary,
        indicatorColor: AppColors.primary,
        dividerColor: p.border,
        labelStyle: bodyMd.copyWith(fontWeight: FontWeight.w600),
        unselectedLabelStyle: bodyMd,
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        textStyle: bodyMd.copyWith(color: p.textPrimary),
        menuStyle: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(p.surface),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radiusMd),
              side: BorderSide(color: p.border),
            ),
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
        ),
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStatePropertyAll(p.border),
        radius: const Radius.circular(8),
        thickness: const WidgetStatePropertyAll(6),
      ),
      extensions: [p],
    );
  }

  /// The welcome page's headline: one size above [displayLg].
  static TextStyle get display => GoogleFonts.spaceGrotesk(
    fontSize: 40,
    fontWeight: FontWeight.w700,
    height: 1.15,
    letterSpacing: -0.5,
  );

  /// A question's stem in a session: larger than body text, because it is
  /// what the student is reading most closely.
  static TextStyle get questionStem => GoogleFonts.spaceGrotesk(
    fontSize: 18,
    fontWeight: FontWeight.w500,
    height: 1.5,
  );

  // ── Text styles (Figma type scale, file 29nbJDmGOJI3bBj5AtburF,
  // "_Foundations" page) — family/size/lineHeight/weight read from Figma.
  static TextStyle get displayLg => GoogleFonts.spaceGrotesk(
    fontSize: 32,
    fontWeight: FontWeight.w700,
    height: 1.2,
  );
  static TextStyle get heading1 => GoogleFonts.spaceGrotesk(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    height: 1.25,
  );
  static TextStyle get heading2 => GoogleFonts.spaceGrotesk(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    height: 1.3,
  );
  static TextStyle get heading3 => GoogleFonts.spaceGrotesk(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    height: 1.35,
  );
  static TextStyle get bodyLg => GoogleFonts.spaceGrotesk(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.6,
  );
  static TextStyle get bodyMd => GoogleFonts.spaceGrotesk(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.6,
  );
  static TextStyle get label => GoogleFonts.spaceGrotesk(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.4,
  );
  static TextStyle get caption => GoogleFonts.spaceGrotesk(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    height: 1.4,
  );
  static TextStyle get btnLabel => GoogleFonts.spaceGrotesk(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.4,
  );

  // navLabelActive/navLabelInactive weight (Figma MCP quota for nodes
  // 7:29/8:31 on file 29nbJDmGOJI3bBj5AtburF was still exhausted, so
  // supplied directly): Medium (500) / Regular (400).
  static TextStyle get navLabelActive => GoogleFonts.spaceGrotesk(
    fontSize: 10,
    fontWeight: FontWeight.w500,
    height: 1.2,
  );
  static TextStyle get navLabelInactive => GoogleFonts.spaceGrotesk(
    fontSize: 10,
    fontWeight: FontWeight.w400,
    height: 1.2,
  );
}

/// Pages fade in, briefly; with reduced motion they simply appear.
class _FadePageTransitionsBuilder extends PageTransitionsBuilder {
  const _FadePageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (reduceMotion(context)) return child;
    return FadeTransition(
      opacity: CurvedAnimation(parent: animation, curve: Motion.curve),
      child: child,
    );
  }
}
