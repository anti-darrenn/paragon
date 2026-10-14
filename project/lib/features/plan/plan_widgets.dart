import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/feature_access.dart';
import '../../core/exam/waec_grade.dart';
import '../../core/plan/study_plan.dart';
import '../../core/plan/weekly_goal.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/repositories/course_repository.dart';
import '../../core/repositories/plan_repository.dart';
import '../../core/repositories/progress_repository.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/ui/ui.dart';

/// The topics of a live course, as the plan sees them, with the student's
/// counters. Placeholder topics (catalog-only) are left out.
List<PlanTopic> planTopicsFor(Course course, UserProgress progress) => [
  for (final m in course.modules)
    for (final t in m.topics)
      if (!t.isPlaceholder)
        PlanTopic(
          id: t.id,
          name: t.name,
          pastQuestions: t.counts.past,
          progress: progress.forTopic(t.id),
        ),
];

/// "This week" on Home: the weekly goal's ring, the countdown to the exam,
/// and the way into the plan. Accounts only; a guest sees nothing here
/// (the guest notice above already invites them to keep their progress).
class ThisWeekCard extends ConsumerWidget {
  const ThisWeekCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!canUse(Feature.studyPlan, isGuest: ref.watch(isGuestProvider))) {
      return const SizedBox.shrink();
    }
    final plan =
        ref.watch(planSettingsProvider).asData?.value ?? PlanSettings.none;
    final done = ref.watch(weeklyAttemptsCountProvider).asData?.value ?? 0;
    final goal = WeeklyGoalProgress(goal: plan.weeklyGoal, done: done);
    final exam = plan.examDate;
    final weeks = exam == null ? null : weeksUntil(exam, DateTime.now());
    final palette = context.palette;

    return Padding(
      padding: const EdgeInsets.only(bottom: kSectionGap),
      child: SurfaceCard(
        onTap: () => context.push('/plan'),
        child: Row(
          children: [
            Semantics(
              label:
                  '$done of ${goal.goal} questions this week'
                  '${goal.met ? ', goal met' : ''}',
              excludeSemantics: true,
              child: SizedBox(
                width: 56,
                height: 56,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: goal.fraction,
                      strokeWidth: 6,
                      backgroundColor: palette.track,
                      color: goal.met ? AppColors.correct : AppColors.primary,
                    ),
                    Icon(
                      goal.met ? Icons.check_rounded : Icons.flag_outlined,
                      size: 20,
                      color: goal.met ? AppColors.correct : palette.textPrimary,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'This week',
                    style: AppTheme.heading3.copyWith(
                      color: palette.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    goal.met
                        ? 'Goal met: $done questions. Well done.'
                        : '$done of ${goal.goal} questions · ${goal.left} to go',
                    style: AppTheme.bodyMd.copyWith(
                      color: palette.textSecondary,
                    ),
                  ),
                  Text(
                    weeks == null
                        ? 'Set your exam date to plan your weeks'
                        : weeks == 0
                        ? 'Your exam is this week. Good luck.'
                        : '$weeks ${weeks == 1 ? 'week' : 'weeks'} to your exam',
                    style: AppTheme.caption.copyWith(
                      color: palette.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: palette.textSecondary),
          ],
        ),
      ),
    );
  }
}

/// For one course: the grade estimate from practice and the shortest path
/// up. On the course page, where the outline is already loaded, and on
/// the plan page. Costs no reads.
class CoursePlanPanel extends StatelessWidget {
  const CoursePlanPanel({
    super.key,
    required this.course,
    required this.progress,
    this.examDate,
    this.showHeading = true,
  });

  final Course course;
  final UserProgress progress;
  final DateTime? examDate;
  final bool showHeading;

  @override
  Widget build(BuildContext context) {
    if (!course.isLive) return const SizedBox.shrink();
    final topics = planTopicsFor(course, progress);
    if (topics.isEmpty) return const SizedBox.shrink();
    final palette = context.palette;
    final weights = topicWeights(topics);
    final estimate = estimateGrade(topics);
    final next = shortestPath(topics, take: 3);
    final weeks = examDate == null
        ? null
        : weeksUntil(examDate!, DateTime.now());
    final perWeek = weeks == null ? null : topicsPerWeek(topics, weeks);
    final answered = topics.fold<int>(0, (n, t) => n + t.progress.answered);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showHeading) SectionHeader('Your ${course.name} plan'),
        SurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Grade estimate',
                style: AppTheme.caption.copyWith(color: palette.textSecondary),
              ),
              const SizedBox(height: 4),
              if (estimate == null)
                Text(
                  'Answer ${kMinAnswersForEstimate - answered} more drill '
                  'questions in ${course.name} to see one.',
                  style: AppTheme.bodyMd.copyWith(color: palette.textPrimary),
                )
              else ...[
                Text(
                  estimate.label,
                  style: AppTheme.heading2.copyWith(color: palette.textPrimary),
                ),
                Text(
                  estimate.isRange
                      ? 'A range until you have answered '
                            '${GradeEstimate.kNarrowAfter} questions here '
                            '($answered so far).'
                      : 'From $answered drill answers in ${course.name}.',
                  style: AppTheme.caption.copyWith(
                    color: palette.textSecondary,
                  ),
                ),
              ],
              const SizedBox(height: 6),
              Text(
                kGradeEstimateNote,
                style: AppTheme.caption.copyWith(color: palette.textSecondary),
              ),
            ],
          ),
        ),
        if (next.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            perWeek == null || perWeek == 0
                ? 'Shortest path up'
                : 'Shortest path up · about $perWeek '
                      '${perWeek == 1 ? 'topic' : 'topics'} a week to cover '
                      'the rest before your exam',
            style: AppTheme.bodyMd.copyWith(
              color: palette.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          RowGroup(
            children: [
              for (final t in next)
                ListRow(
                  title: t.name,
                  subtitle: [
                    t.progress.level.label,
                    if (weights.basis == WeightBasis.pastPapers)
                      ?frequencyPhrase(
                        weights.weights[t.id] ?? 0,
                      )?.replaceFirst('WAEC', 'WAEC ${course.name}'),
                  ].join(' · '),
                  onTap: () => context.push(
                    '/subject/${course.key}/course/topic/${t.id}',
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            weights.basis == WeightBasis.pastPapers
                ? 'Ranked by how often each topic comes up in WAEC past '
                      'papers and how much of it you still have to learn.'
                : 'Paragon has no ${course.name} past papers yet, so every '
                      'topic counts the same; ranked by what you still have '
                      'to learn.',
            style: AppTheme.caption.copyWith(color: palette.textSecondary),
          ),
        ],
      ],
    );
  }
}

/// "Comes up in about 1 in 25 WAEC Mathematics questions" for one topic,
/// or nothing when the course has no past papers or the topic is rare.
String? topicFrequencyLine(Course course, String topicId) {
  final topics = [
    for (final m in course.modules)
      for (final t in m.topics)
        if (!t.isPlaceholder)
          PlanTopic(id: t.id, name: t.name, pastQuestions: t.counts.past),
  ];
  final w = topicWeights(topics);
  if (w.basis != WeightBasis.pastPapers) return null;
  final phrase = frequencyPhrase(w.weights[topicId] ?? 0);
  if (phrase == null) return null;
  return 'Comes up in ${phrase.replaceFirst('WAEC', 'WAEC ${course.name}')}';
}

/// Under an exam result: how this paper compares with the estimate from
/// practice (PLAN.md P7.3). Nothing for a guest or with too little
/// practice to estimate. The outline comes from the device cache.
class PracticeComparison extends ConsumerWidget {
  const PracticeComparison({
    super.key,
    required this.subjectId,
    required this.percent,
  });

  final String subjectId;
  final double percent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!canUse(Feature.studyPlan, isGuest: ref.watch(isGuestProvider))) {
      return const SizedBox.shrink();
    }
    final course = ref.watch(courseProvider(subjectId)).asData?.value;
    final progress =
        ref.watch(userProgressProvider).asData?.value ?? UserProgress.empty;
    if (course == null) return const SizedBox.shrink();
    final estimate = estimateGrade(planTopicsFor(course, progress));
    if (estimate == null) return const SizedBox.shrink();
    final paper = waecGradeFor(percent).code;
    final verdict = percent > estimate.highPercent
        ? 'above what your practice suggested.'
        : percent < estimate.lowPercent
        ? 'below what your practice suggested: exam conditions matter.'
        : 'in line with your practice.';
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Text(
        'This paper: $paper. Your practice estimate: ${estimate.label}. '
        'That is $verdict',
        textAlign: TextAlign.center,
        style: AppTheme.bodyMd.copyWith(color: context.palette.textSecondary),
      ),
    );
  }
}
