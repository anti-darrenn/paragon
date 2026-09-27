import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/exam/exam_result.dart';
import '../core/exam/waec_grade.dart';
import '../core/models/question.dart';
import '../core/repositories/course_repository.dart';
import '../core/repositories/exam_result_repository.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_palette.dart';
import '../core/theme/app_theme.dart';
import '../core/widgets/answer_option.dart';
import '../core/widgets/full_latex_view.dart';
import '../core/widgets/load_error.dart';
import '../core/widgets/question_image.dart';
import '../core/widgets/report_problem_button.dart';
import 'study/notes/notes_widgets.dart' show QuestionBookmarkButton;

/// `/waec/review/:examId`: a finished exam, marked.
///
/// Every question locked, with the student's pick, the right answer and
/// the working; the weakest topics, linked to their lessons; and an
/// estimated grade that says it is one. Nothing here can be re-answered —
/// this is the exam's results, not more of the exam, so the "no instant
/// feedback during an exam" rule is untouched.
///
/// Opened straight from the results with the exam in memory ([initial]),
/// or by id after a reload or from the history list.
class ExamReviewScreen extends ConsumerWidget {
  const ExamReviewScreen({super.key, required this.examId, this.initial});

  final String examId;
  final ExamReview? initial;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Widget body;
    if (initial != null) {
      body = _Review(review: initial!);
    } else {
      body = ref
          .watch(examReviewProvider(examId))
          .when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => LoadError(
              error: e,
              onRetry: () => ref.invalidate(examReviewProvider(examId)),
            ),
            data: (review) => review == null
                ? Center(
                    child: Text(
                      'This exam could not be found.',
                      style: AppTheme.bodyMd.copyWith(
                        color: context.palette.textSecondary,
                      ),
                    ),
                  )
                : _Review(review: review),
          );
    }
    return Scaffold(
      backgroundColor: context.palette.background,
      appBar: AppBar(title: const Text('Exam review')),
      body: body,
    );
  }
}

class _Review extends ConsumerStatefulWidget {
  const _Review({required this.review});
  final ExamReview review;

  @override
  ConsumerState<_Review> createState() => _ReviewState();
}

class _ReviewState extends ConsumerState<_Review> {
  bool _missedOnly = false;

  @override
  Widget build(BuildContext context) {
    final r = widget.review.result;
    final questions = widget.review.questions;
    final weak = weakestTopics(r.items, questions);
    final grade = waecGradeFor(r.percent);
    final pct = r.percent.round();

    final shown = [
      for (var i = 0; i < r.items.length; i++)
        if (questions[r.items[i].questionId] case final q?)
          if (!_missedOnly || r.items[i].selected != q.correctIndex)
            (number: i + 1, item: r.items[i], question: q),
    ];

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
          children: [
            Text(
              '${r.correct} / ${r.total}  ($pct%)',
              textAlign: TextAlign.center,
              style: AppTheme.heading1.copyWith(
                color: grade.isCredit ? AppColors.correct : AppColors.wrong,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${r.answered} of ${r.total} answered'
              '${r.durationSeconds > 0 ? ' · ${_minutes(r.durationSeconds)}' : ''}',
              textAlign: TextAlign.center,
              style: AppTheme.bodyMd.copyWith(
                color: context.palette.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            GradeEstimateCard(percent: r.percent),
            if (weak.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text(
                'Work on these next',
                style: AppTheme.heading3.copyWith(
                  color: context.palette.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              for (final t in weak)
                _WeakTopicRow(subjectId: r.subjectId, score: t),
            ],
            const SizedBox(height: 20),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: Text('All ${r.total}'),
                  selected: !_missedOnly,
                  onSelected: (_) => setState(() => _missedOnly = false),
                ),
                ChoiceChip(
                  label: Text('Missed ${r.total - r.correct}'),
                  selected: _missedOnly,
                  onSelected: (_) => setState(() => _missedOnly = true),
                ),
              ],
            ),
            const SizedBox(height: 12),
            for (final e in shown)
              ExamReviewCard(
                number: e.number,
                item: e.item,
                question: e.question,
              ),
            if (shown.length < (_missedOnly ? r.total - r.correct : r.total))
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Some questions from this exam are no longer available.',
                  style: AppTheme.caption.copyWith(
                    color: context.palette.textSecondary,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  static String _minutes(int seconds) {
    final m = (seconds / 60).round();
    return m <= 1 ? 'about a minute' : '$m minutes';
  }
}

/// The estimated grade, always with the words that say what it is not.
class GradeEstimateCard extends StatelessWidget {
  const GradeEstimateCard({
    super.key,
    required this.percent,
    this.title = 'Estimated grade',
  });

  final double percent;
  final String title;

  @override
  Widget build(BuildContext context) {
    final grade = waecGradeFor(percent);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.palette.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.palette.border),
      ),
      child: Row(
        children: [
          Text(
            grade.code,
            style: AppTheme.heading1.copyWith(
              color: grade.isCredit ? AppColors.correct : AppColors.wrong,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$title: ${grade.label}',
                  style: AppTheme.bodyMd.copyWith(
                    color: context.palette.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  kGradeEstimateNote,
                  style: AppTheme.caption.copyWith(
                    color: context.palette.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WeakTopicRow extends ConsumerWidget {
  const _WeakTopicRow({required this.subjectId, required this.score});
  final String subjectId;
  final TopicScore score;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final course = ref.watch(courseProvider(subjectId)).asData?.value;
    final name = course?.findTopic(score.topicId)?.$2.name ?? 'A topic';
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.trending_down_rounded, color: AppColors.wrong),
      title: Text(
        name,
        style: AppTheme.bodyMd.copyWith(color: context.palette.textPrimary),
      ),
      subtitle: Text(
        '${score.correct} of ${score.total} right',
        style: AppTheme.caption.copyWith(color: context.palette.textSecondary),
      ),
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: context.palette.textSecondary,
      ),
      onTap: () =>
          context.push('/subject/$subjectId/course/topic/${score.topicId}'),
    );
  }
}

class ExamReviewCard extends StatelessWidget {
  const ExamReviewCard({
    super.key,
    required this.number,
    required this.item,
    required this.question,
  });

  final int number;
  final ExamItem item;
  final Question question;

  @override
  Widget build(BuildContext context) {
    final q = question;
    final right = item.selected == q.correctIndex;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.palette.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: right
              ? context.palette.border
              : AppColors.wrong.withAlpha(110),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Question $number · ${!item.answered
                ? 'Not answered'
                : right
                ? 'Right'
                : 'Wrong'}',
            style: AppTheme.caption.copyWith(
              color: right ? AppColors.correct : AppColors.wrong,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          FullLatexView(
            latex: q.text,
            textStyle: AppTheme.bodyLg.copyWith(
              color: context.palette.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          QuestionImage(assetId: q.imageId),
          const SizedBox(height: 12),
          for (var i = 0; i < q.options.length; i++)
            AnswerOption(
              index: i,
              text: q.options[i],
              state: i == q.correctIndex
                  ? AnswerOptionState.correct
                  : i == item.selected
                  ? AnswerOptionState.wrong
                  : AnswerOptionState.idle,
            ),
          if (q.explanation.trim().isNotEmpty ||
              q.explanationImageId != null) ...[
            const SizedBox(height: 4),
            if (q.explanation.trim().isNotEmpty)
              FullLatexView(
                latex: q.explanation,
                textStyle: AppTheme.bodyMd.copyWith(
                  color: context.palette.onHigh,
                ),
              ),
            QuestionImage(assetId: q.explanationImageId),
          ],
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ReportProblemButton(questionId: q.id),
                QuestionBookmarkButton(question: q),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
