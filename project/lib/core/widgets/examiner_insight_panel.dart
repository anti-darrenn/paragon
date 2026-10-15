import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../insights/examiner_insight.dart';
import '../models/question.dart';
import '../theme/app_colors.dart';
import '../theme/app_palette.dart';
import '../theme/app_theme.dart';

/// "What examiners saw", under a question's worked answer — in practice
/// after answering, and in exam review. Draws nothing (and reads nothing)
/// unless `question.hasInsight`.
///
/// If the student chose the option most candidates chose, it says so
/// first: that is the moment the report is most useful.
class ExaminerInsightPanel extends ConsumerWidget {
  const ExaminerInsightPanel({
    super.key,
    required this.question,
    this.selected,
  });

  final Question question;
  final int? selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!question.hasInsight) return const SizedBox.shrink();
    final insight = ref
        .watch(publishedInsightProvider(question.id))
        .asData
        ?.value;
    if (insight == null) return const SizedBox.shrink();
    final palette = context.palette;
    final sameAsMost =
        selected != null &&
        insight.commonWrongOption != null &&
        selected == insight.commonWrongOption;
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.accentBlue.withAlpha(24),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.accentBlue.withAlpha(90)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.fact_check_outlined,
                size: 18,
                color: AppColors.accentBlue,
              ),
              const SizedBox(width: 8),
              Text(
                'What examiners saw',
                style: AppTheme.bodyMd.copyWith(
                  color: palette.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            sameAsMost
                ? 'Most candidates chose this too. ${insight.summary}'
                : insight.summary,
            style: AppTheme.bodyMd.copyWith(color: palette.textPrimary),
          ),
          if (insight.tip.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Tip: ${insight.tip}',
              style: AppTheme.bodyMd.copyWith(color: palette.textPrimary),
            ),
          ],
          const SizedBox(height: 6),
          Text(
            'From the WAEC Chief Examiner\'s report: ${insight.reportRef}. '
            'Summarised by Paragon.',
            style: AppTheme.caption.copyWith(color: palette.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// "Where students lose marks" on a topic page: its recurring weaknesses
/// across years. Nothing unless the topic is flagged.
class ExaminerThemesBlock extends ConsumerWidget {
  const ExaminerThemesBlock({
    super.key,
    required this.topicId,
    required this.flagged,
  });

  final String topicId;
  final bool flagged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!flagged) return const SizedBox.shrink();
    final insight = ref
        .watch(publishedInsightProvider(ExaminerInsight.topicDocId(topicId)))
        .asData
        ?.value;
    if (insight == null) return const SizedBox.shrink();
    final palette = context.palette;
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Where students lose marks',
            style: AppTheme.heading3.copyWith(color: palette.textPrimary),
          ),
          const SizedBox(height: 8),
          Text(
            insight.summary,
            style: AppTheme.bodyMd.copyWith(color: palette.textPrimary),
          ),
          if (insight.tip.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Tip: ${insight.tip}',
              style: AppTheme.bodyMd.copyWith(color: palette.textPrimary),
            ),
          ],
          const SizedBox(height: 6),
          Text(
            insight.years.isEmpty
                ? 'From WAEC Chief Examiners\' reports. Summarised by Paragon.'
                : 'Reported by WAEC\'s Chief Examiners in '
                      '${insight.years.join(', ')}. Summarised by Paragon.',
            style: AppTheme.caption.copyWith(color: palette.textSecondary),
          ),
        ],
      ),
    );
  }
}
