import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/exam/exam_result.dart';
import '../core/exam/waec_grade.dart';
import '../core/repositories/exam_result_repository.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_palette.dart';
import '../core/theme/app_theme.dart';
import 'exam_review_screen.dart' show GradeEstimateCard;

/// A subject's past exams, newest first, each opening its review, with
/// the rolling grade estimate over the latest three.
///
/// Renders nothing until there is a saved exam, and nothing on a failed
/// load: history is a convenience under the setup form, never a reason
/// to show an error where the student is about to start an exam.
class ExamHistory extends ConsumerWidget {
  const ExamHistory({super.key, required this.subjectId});

  final String subjectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exams = ref.watch(examHistoryProvider(subjectId)).asData?.value;
    if (exams == null || exams.isEmpty) return const SizedBox.shrink();
    final rolling = rollingPercent([for (final e in exams) e.percent]);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Your past exams',
          style: AppTheme.heading3.copyWith(color: context.palette.textPrimary),
        ),
        const SizedBox(height: 10),
        if (rolling != null)
          GradeEstimateCard(
            percent: rolling,
            title: exams.length == 1
                ? 'Estimate from your last exam'
                : 'Estimate from your last ${exams.length < 3 ? exams.length : 3}',
          ),
        const SizedBox(height: 8),
        for (final e in exams) _ExamRow(exam: e),
      ],
    );
  }
}

class _ExamRow extends StatelessWidget {
  const _ExamRow({required this.exam});
  final ExamResult exam;

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  @override
  Widget build(BuildContext context) {
    final grade = waecGradeFor(exam.percent);
    final at = exam.submittedAt?.toLocal();
    final when = at == null
        ? 'Just now'
        : '${at.day} ${_months[at.month - 1]} ${at.year}';
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: (grade.isCredit ? AppColors.correct : AppColors.wrong)
            .withAlpha(30),
        child: Text(
          grade.code,
          style: AppTheme.label.copyWith(
            color: grade.isCredit ? AppColors.correct : AppColors.wrong,
          ),
        ),
      ),
      title: Text(
        '${exam.correct} / ${exam.total}  (${exam.percent.round()}%)',
        style: AppTheme.bodyMd.copyWith(color: context.palette.textPrimary),
      ),
      subtitle: Text(
        '$when${exam.timed ? ' · timed' : ''}',
        style: AppTheme.caption.copyWith(color: context.palette.textSecondary),
      ),
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: context.palette.textSecondary,
      ),
      onTap: () => context.push('/waec/review/${exam.id}'),
    );
  }
}
