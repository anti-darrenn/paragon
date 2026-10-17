import 'package:flutter/material.dart';

import '../models/question.dart';
import '../questions/difficulty.dart';
import '../theme/app_colors.dart';
import '../theme/app_palette.dart';
import '../theme/app_theme.dart';

/// Where a question came from ("WAEC 2018" or "Paragon practice") and how
/// hard it is ("Brain stretch", with five pips), on every surface that
/// shows a question: drill, tests, exercises, the mistakes notebook and the
/// exam review.
///
/// Past questions and generated practice look alike otherwise, and a
/// student who thinks they are drilling past papers is being misled.
/// The timed WAEC exam passes [showDifficulty] false: a paper does not
/// tell you which questions are the hard ones.
class QuestionSourceBadge extends StatelessWidget {
  const QuestionSourceBadge({
    super.key,
    required this.question,
    this.showDifficulty = true,
  });

  final Question question;
  final bool showDifficulty;

  @override
  Widget build(BuildContext context) {
    final label = question.provenanceLabel;
    if (label == null && !showDifficulty) return const SizedBox.shrink();
    final past = question.isPastQuestion;
    // Orange text fails contrast on the light theme; the icon carries the
    // brand colour and the words stay in the readable secondary colour.
    final text = context.palette.textSecondary;
    final tier = question.tier;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Wrap(
        spacing: 14,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (label != null)
            Semantics(
              label: past ? 'Past question, $label' : label,
              excludeSemantics: true,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    past
                        ? Icons.history_edu_rounded
                        : Icons.auto_awesome_outlined,
                    size: 14,
                    color: past ? AppColors.primary : text,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: AppTheme.caption.copyWith(
                      color: text,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          if (showDifficulty)
            DifficultyBadge(tier: tier, estimated: !question.tierIsSet),
        ],
      ),
    );
  }
}

/// A difficulty tier as five pips and its name, with the tier's line on
/// hover or long press.
class DifficultyBadge extends StatelessWidget {
  const DifficultyBadge({super.key, required this.tier, this.estimated = true});

  final DifficultyTier tier;

  /// Paragon's estimate, as opposed to a reviewer's judgement; said so to
  /// a screen reader and in the tooltip.
  final bool estimated;

  /// Cool to hot, easiest to hardest.
  static Color colourOf(DifficultyTier t) => switch (t) {
    DifficultyTier.easyPeasy => AppColors.correct,
    DifficultyTier.warmingUp => AppColors.accentBlue,
    DifficultyTier.brainStretch => AppColors.primary,
    DifficultyTier.spicy => AppColors.warning,
    DifficultyTier.unnecessarilyHard => AppColors.wrong,
  };

  @override
  Widget build(BuildContext context) {
    final colour = colourOf(tier);
    final text = context.palette.textSecondary;
    return Tooltip(
      message: '${tier.blurb}${estimated ? ' (Paragon\'s estimate)' : ''}',
      child: Semantics(
        label:
            'Difficulty: ${tier.label}, ${tier.level} of 5'
            '${estimated ? ', estimated' : ''}',
        excludeSemantics: true,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 1; i <= 5; i++)
              Container(
                width: 6,
                height: 6,
                margin: const EdgeInsets.only(right: 3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i <= tier.level ? colour : context.palette.track,
                ),
              ),
            const SizedBox(width: 4),
            Text(
              tier.label,
              style: AppTheme.caption.copyWith(
                color: text,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
