import 'package:flutter/material.dart';

import '../../core/sound/sfx.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/motion/confetti.dart';
import '../../core/widgets/ui/ui.dart';

/// The end of onboarding: a moment that says the account is ready, before
/// Home. A dialog over the last step rather than a route of its own, so
/// nothing about the funnel's navigation changes; dismissing it does the
/// same as its button.
Future<void> showAllSetDialog(BuildContext context) {
  Sfx.play(SfxCue.celebrate);
  return showDialog<void>(
    context: context,
    builder: (dialog) {
      final p = dialog.palette;
      return Stack(
        children: [
          AlertDialog(
            contentPadding: const EdgeInsets.fromLTRB(24, 28, 24, 8),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Illustration(IllustrationAsset.celebrate, height: 120),
                  const SizedBox(height: 16),
                  Text(
                    "You're all set",
                    textAlign: TextAlign.center,
                    style: AppTheme.heading2.copyWith(color: p.textStrong),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your subjects are ready. Start with a topic, or try five '
                    'quick questions from Home.',
                    textAlign: TextAlign.center,
                    style: AppTheme.bodyMd.copyWith(color: p.textSecondary),
                  ),
                ],
              ),
            ),
            actionsPadding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            actions: [
              AppButton(
                label: 'Start learning',
                expand: true,
                autofocus: true,
                onPressed: () => Navigator.of(dialog).pop(),
              ),
            ],
          ),
          const Positioned.fill(child: Confetti(pieces: 80)),
        ],
      );
    },
  );
}
