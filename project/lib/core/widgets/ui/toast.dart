import 'package:flutter/material.dart';

import '../../theme/app_palette.dart';
import 'tone.dart';

/// A short message at the bottom of the screen that goes away by itself:
/// "Saved", "Couldn't save — try again". Replaces bare `showSnackBar`
/// calls so every one has the same shape, and the tone's icon says at a
/// glance whether something went right.
///
/// Any toast already showing is replaced, so a fast run of actions never
/// queues a backlog of messages.
ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? showToast(
  BuildContext context,
  String message, {
  Tone tone = Tone.neutral,
  String? actionLabel,
  VoidCallback? onAction,
  Duration duration = const Duration(seconds: 4),
}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return null;
  // The snackbar is drawn inverted (light on dark, dark on light), so its
  // icon takes the other theme's readable tone.
  final dark = Theme.of(context).brightness == Brightness.dark;
  final onToast = dark ? AppPalette.light : AppPalette.dark;
  final iconColour = switch (tone) {
    Tone.neutral => null,
    Tone.info => onToast.infoFg,
    Tone.success => onToast.successFg,
    Tone.warning => onToast.warningFg,
    Tone.danger => onToast.dangerFg,
  };
  messenger.hideCurrentSnackBar();
  return messenger.showSnackBar(
    SnackBar(
      duration: duration,
      content: Row(
        children: [
          if (iconColour != null) ...[
            Icon(tone.icon, size: 20, color: iconColour),
            const SizedBox(width: 10),
          ],
          Expanded(child: Text(message)),
        ],
      ),
      action: actionLabel == null
          ? null
          : SnackBarAction(label: actionLabel, onPressed: onAction ?? () {}),
    ),
  );
}
