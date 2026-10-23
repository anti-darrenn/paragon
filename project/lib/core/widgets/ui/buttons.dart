import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_theme.dart';

/// How much a button asks for attention, and what it does.
///
/// - [primary]: the one main action on a screen (filled orange).
/// - [secondary]: an alternative (outlined).
/// - [ghost]: a quiet action, a link-like button (text only).
/// - [destructive]: deletes or leaves something behind (filled red).
/// - [success]: moves on after something went right (filled green).
enum ButtonTone { primary, secondary, ghost, destructive, success }

/// Button heights: 36, 48 (the theme's default) and 56.
enum ButtonSize { sm, md, lg }

/// The app's button: one widget for every tone and size, with an icon,
/// a loading state and a full-width option, so screens stop restyling
/// Material buttons one by one.
///
/// While [loading] it is disabled, keeps its width (the label stays in
/// place, invisible, under a spinner) and is announced as "…, loading".
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.tone = ButtonTone.primary,
    this.size = ButtonSize.md,
    this.icon,
    this.trailingIcon,
    this.loading = false,
    this.expand = false,
    this.autofocus = false,
    this.focusNode,
  });

  final String label;
  final VoidCallback? onPressed;
  final ButtonTone tone;
  final ButtonSize size;
  final IconData? icon;
  final IconData? trailingIcon;
  final bool loading;

  /// Fill the width of the parent.
  final bool expand;
  final bool autofocus;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final style = AppButtonStyle.of(context, tone, size);
    final iconSize = size == ButtonSize.sm ? 16.0 : 18.0;
    Widget content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: iconSize),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: Text(label, overflow: TextOverflow.ellipsis, maxLines: 1),
        ),
        if (trailingIcon != null) ...[
          const SizedBox(width: 8),
          Icon(trailingIcon, size: iconSize),
        ],
      ],
    );
    if (loading) {
      content = Stack(
        alignment: Alignment.center,
        children: [
          Visibility(
            visible: false,
            maintainSize: true,
            maintainAnimation: true,
            maintainState: true,
            child: content,
          ),
          SizedBox.square(
            dimension: iconSize,
            child: const CircularProgressIndicator(strokeWidth: 2.2),
          ),
        ],
      );
    }
    final pressed = loading ? null : onPressed;
    final Widget button = switch (tone) {
      ButtonTone.secondary => OutlinedButton(
        onPressed: pressed,
        style: style,
        autofocus: autofocus,
        focusNode: focusNode,
        child: content,
      ),
      ButtonTone.ghost => TextButton(
        onPressed: pressed,
        style: style,
        autofocus: autofocus,
        focusNode: focusNode,
        child: content,
      ),
      _ => FilledButton(
        onPressed: pressed,
        style: style,
        autofocus: autofocus,
        focusNode: focusNode,
        child: content,
      ),
    };
    final sized = expand
        ? SizedBox(width: double.infinity, child: button)
        : button;
    if (!loading) return sized;
    return Semantics(
      label: '$label, loading',
      button: true,
      enabled: false,
      excludeSemantics: true,
      child: sized,
    );
  }
}

/// The [ButtonStyle] behind [AppButton], for a screen that keeps its own
/// Material button but should look like the rest (`style:
/// AppButtonStyle.of(context, ButtonTone.destructive)`). Merged over the
/// theme's button style, so focus rings and shapes still come from there.
abstract final class AppButtonStyle {
  static ButtonStyle of(
    BuildContext context,
    ButtonTone tone, [
    ButtonSize size = ButtonSize.md,
  ]) {
    final p = context.palette;
    final (height, hPad, font) = switch (size) {
      ButtonSize.sm => (36.0, 12.0, 13.0),
      ButtonSize.md => (48.0, 18.0, 14.0),
      ButtonSize.lg => (56.0, 24.0, 16.0),
    };
    final base = ButtonStyle(
      minimumSize: WidgetStatePropertyAll(Size(64, height)),
      padding: WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: hPad, vertical: 0),
      ),
      textStyle: WidgetStatePropertyAll(
        AppTheme.btnLabel.copyWith(fontSize: font, fontWeight: FontWeight.w600),
      ),
    );
    return switch (tone) {
      ButtonTone.primary => base.merge(
        FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: p.track,
          disabledForegroundColor: p.textSecondary,
        ),
      ),
      ButtonTone.destructive => base.merge(
        FilledButton.styleFrom(
          backgroundColor: AppColors.dangerStrong,
          foregroundColor: Colors.white,
          disabledBackgroundColor: p.track,
          disabledForegroundColor: p.textSecondary,
        ),
      ),
      ButtonTone.success => base.merge(
        FilledButton.styleFrom(
          backgroundColor: AppColors.successStrong,
          foregroundColor: Colors.white,
          disabledBackgroundColor: p.track,
          disabledForegroundColor: p.textSecondary,
        ),
      ),
      ButtonTone.secondary => base.merge(
        OutlinedButton.styleFrom(
          foregroundColor: p.textPrimary,
          disabledForegroundColor: p.textSecondary,
        ),
      ),
      ButtonTone.ghost => base.merge(
        TextButton.styleFrom(
          foregroundColor: p.primaryFg,
          disabledForegroundColor: p.textSecondary,
        ),
      ),
    };
  }
}
