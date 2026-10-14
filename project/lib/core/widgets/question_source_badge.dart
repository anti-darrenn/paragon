import 'package:flutter/material.dart';

import '../models/question.dart';
import '../theme/app_colors.dart';
import '../theme/app_palette.dart';
import '../theme/app_theme.dart';

/// Where a question came from — "WAEC 2018" or "Paragon practice" — on
/// every surface that shows one: drill, the WAEC exam and its review, and
/// the mistakes notebook. Draws nothing for an unclassified question.
///
/// Past questions and generated practice look alike otherwise, and a
/// student who thinks they are drilling past papers is being misled.
class QuestionSourceBadge extends StatelessWidget {
  const QuestionSourceBadge({super.key, required this.question});

  final Question question;

  @override
  Widget build(BuildContext context) {
    final label = question.provenanceLabel;
    if (label == null) return const SizedBox.shrink();
    final past = question.isPastQuestion;
    // Orange text fails contrast on the light theme; the icon carries the
    // brand colour and the words stay in the readable secondary colour.
    final text = context.palette.textSecondary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Semantics(
        label: past ? 'Past question, $label' : label,
        excludeSemantics: true,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              past ? Icons.history_edu_rounded : Icons.auto_awesome_outlined,
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
    );
  }
}
