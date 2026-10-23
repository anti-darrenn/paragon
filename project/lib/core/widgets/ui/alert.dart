import 'package:flutter/material.dart';

import '../../theme/app_palette.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import 'tone.dart';

/// A message that sits in the page: an icon, an optional title, the
/// message, and optionally an action and a close button. Persistent and
/// non-modal; the student can act on it or carry on.
///
/// Use it for a caution before a test, an offline notice, a "this is a
/// draft" strip — anything that used to be grey 11px text or a red line.
class InlineAlert extends StatelessWidget {
  const InlineAlert({
    super.key,
    required this.message,
    this.tone = Tone.info,
    this.title,
    this.action,
    this.onDismiss,
    this.icon,
    this.announce = false,
  });

  final String message;
  final Tone tone;
  final String? title;

  /// A button or link at the end (a `TextButton` or `AppButton.ghost`).
  final Widget? action;

  /// Shows a close button when given.
  final VoidCallback? onDismiss;

  /// Overrides the tone's own icon.
  final IconData? icon;

  /// Read out by a screen reader as soon as it appears (a live region),
  /// for an alert that appears in answer to something the student did.
  final bool announce;

  @override
  Widget build(BuildContext context) {
    final fill = tone.fill(context);
    final fg = tone.foreground(context);
    final p = context.palette;
    return Semantics(
      liveRegion: announce,
      container: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
        decoration: BoxDecoration(
          color: fill.withAlpha(24),
          borderRadius: BorderRadius.circular(Radii.md),
          border: Border.all(color: fill.withAlpha(90)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(icon ?? tone.icon, size: 20, color: fg),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (title != null) ...[
                      Text(
                        title!,
                        style: AppTheme.bodyMd.copyWith(
                          color: p.textStrong,
                          fontWeight: FontWeight.w600,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 2),
                    ],
                    Text(
                      message,
                      style: AppTheme.bodyMd.copyWith(
                        color: p.textPrimary,
                        height: 1.45,
                      ),
                    ),
                    if (action != null) ...[
                      const SizedBox(height: 4),
                      Align(alignment: Alignment.centerLeft, child: action),
                    ],
                  ],
                ),
              ),
            ),
            if (onDismiss != null)
              IconButton(
                onPressed: onDismiss,
                tooltip: 'Dismiss',
                visualDensity: VisualDensity.compact,
                icon: Icon(Icons.close_rounded, size: 18, color: p.textSecondary),
              ),
          ],
        ),
      ),
    );
  }
}

/// A full-width strip across the top of a page or session (offline, a
/// draft preview): the same message as [InlineAlert], without the card.
class PageBanner extends StatelessWidget {
  const PageBanner({
    super.key,
    required this.message,
    this.tone = Tone.info,
    this.action,
    this.icon,
  });

  final String message;
  final Tone tone;
  final Widget? action;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final fill = tone.fill(context);
    final fg = tone.foreground(context);
    return Semantics(
      container: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: fill.withAlpha(28),
          border: Border(bottom: BorderSide(color: fill.withAlpha(80))),
        ),
        child: Row(
          children: [
            Icon(icon ?? tone.icon, size: 18, color: fg),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: AppTheme.label.copyWith(
                  color: context.palette.textPrimary,
                  fontSize: 13,
                ),
              ),
            ),
            ?action,
          ],
        ),
      ),
    );
  }
}
