import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_palette.dart';
import '../theme/app_theme.dart';
import 'full_latex_view.dart';

/// The hints revealed so far, and the button for the next one.
///
/// The parent owns [shown] because it records how many hints an answer
/// used. Renders nothing when [steps] is empty (see `hintSteps`).
class HintPanel extends StatelessWidget {
  const HintPanel({
    super.key,
    required this.steps,
    required this.shown,
    required this.onShowNext,
  });

  final List<String> steps;

  /// How many of [steps] are on screen.
  final int shown;

  /// Null once the question is answered: no more hints then.
  final VoidCallback? onShowNext;

  @override
  Widget build(BuildContext context) {
    if (steps.isEmpty) return const SizedBox.shrink();
    final more = shown < steps.length && onShowNext != null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < shown && i < steps.length; i++)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.accentBlue.withAlpha(20),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.accentBlue.withAlpha(90)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Hint ${i + 1}',
                    style: AppTheme.caption.copyWith(
                      color: AppColors.accentBlue,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  FullLatexView(
                    latex: steps[i],
                    textStyle: AppTheme.bodyMd.copyWith(
                      color: context.palette.onHigh,
                    ),
                  ),
                ],
              ),
            ),
          if (more)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: onShowNext,
                icon: const Icon(
                  Icons.lightbulb_outline_rounded,
                  size: 18,
                  color: AppColors.accentBlue,
                ),
                label: Text(
                  shown == 0
                      ? 'Get a hint'
                      : 'Next hint (${shown + 1} of ${steps.length})',
                  style: AppTheme.bodyMd.copyWith(color: AppColors.accentBlue),
                ),
              ),
            ),
          if (shown == 0 && more)
            Text(
              'Answers given after a hint are saved, but do not count '
              'toward your mastery level.',
              style: AppTheme.caption.copyWith(
                color: context.palette.textSecondary,
              ),
            ),
        ],
      ),
    );
  }
}
