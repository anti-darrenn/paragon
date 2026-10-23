import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import 'tone.dart';

/// A small label on a row or card: a status ("Draft", "Unlocked"), a
/// kind ("Video"), a count. Tinted by [tone]; [outlined] for a quieter
/// one beside other tags.
class Tag extends StatelessWidget {
  const Tag(
    this.label, {
    super.key,
    this.tone = Tone.neutral,
    this.icon,
    this.outlined = false,
    this.color,
  });

  final String label;
  final Tone tone;
  final IconData? icon;
  final bool outlined;

  /// A colour of its own (a subject's), instead of the tone's. Used as the
  /// tint and border; the words stay in the tone's readable colour unless
  /// the tone is neutral.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final fill = color ?? tone.fill(context);
    final fg = tone.foreground(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: outlined ? null : fill.withAlpha(30),
        borderRadius: BorderRadius.circular(Radii.sm),
        border: Border.all(color: fill.withAlpha(outlined ? 140 : 60)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: fg),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.label.copyWith(
                color: fg,
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
