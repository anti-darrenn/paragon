import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/feature_access.dart';
import '../../core/plan/study_plan.dart';
import '../../core/plan/weekly_goal.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/repositories/course_repository.dart';
import '../../core/repositories/plan_repository.dart';
import '../../core/repositories/progress_repository.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/nav/back_navigation.dart';
import '../../core/widgets/ui/ui.dart';
import 'plan_widgets.dart';

/// `/plan`: the weekly goal, the exam date, and per subject a grade
/// estimate and the shortest path up (PLAN.md P7.2, launch plan phase 2).
///
/// Only the goal and the date are stored (`plan/{uid}`); everything else
/// is computed here from the course outlines and `progress/{uid}`, both
/// already cached. Nothing on this page gates anything.
class PlanScreen extends ConsumerWidget {
  const PlanScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isGuest = ref.watch(isGuestProvider);
    return Scaffold(
      appBar: const ParagonAppBar(title: Text('Your plan')),
      body: !canUse(Feature.studyPlan, isGuest: isGuest)
          ? EmptyState(
              icon: Icons.event_note_outlined,
              title: 'Plan your weeks to the exam',
              message:
                  'A weekly goal, a countdown to your exam, and the topics '
                  'worth the most marks next. Make a free account to keep '
                  'your plan; everything you have done as a guest comes '
                  'with you.',
              action: ElevatedButton(
                onPressed: () => context.push('/account/upgrade'),
                child: const Text('Make an account'),
              ),
            )
          : const _PlanBody(),
    );
  }
}

class _PlanBody extends ConsumerWidget {
  const _PlanBody();

  Future<void> _save(WidgetRef ref, PlanSettings next) async {
    final uid = ref.read(currentUserProvider)?.uid;
    if (uid == null) return;
    await ref.read(planRepositoryProvider).save(uid, next);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plan =
        ref.watch(planSettingsProvider).asData?.value ?? PlanSettings.none;
    final done = ref.watch(weeklyAttemptsCountProvider).asData?.value ?? 0;
    final progress =
        ref.watch(userProgressProvider).asData?.value ?? UserProgress.empty;
    final slugs = ref.watch(selectedSubjectSlugsProvider).toList()..sort();
    final palette = context.palette;
    final weeks = plan.examDate == null
        ? null
        : weeksUntil(plan.examDate!, DateTime.now());

    return PageBody(
      children: [
        const PageIntro(
          title: 'Your plan',
          subtitle:
              'A goal for the week and the topics worth the most marks '
              'next. Change anything, any time.',
        ),
        const SectionHeader('Weekly goal'),
        SurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final g in kWeeklyGoals)
                    ChoiceChip(
                      label: Text('$g a week'),
                      selected: plan.weeklyGoal == g,
                      onSelected: (_) => _save(
                        ref,
                        PlanSettings(weeklyGoal: g, examDate: plan.examDate),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                '$done answered this week (Monday to Sunday). A goal, '
                'not a streak: missing one costs nothing.',
                style: AppTheme.caption.copyWith(color: palette.textSecondary),
              ),
            ],
          ),
        ),
        const SizedBox(height: kSectionGap),
        const SectionHeader('Your exam'),
        SurfaceCard(
          child: Row(
            children: [
              Expanded(
                child: Text(
                  plan.examDate == null
                      ? 'When is your first WASSCE paper?'
                      : '${_date(plan.examDate!)} · '
                            '${weeks == 0 ? 'this week' : '$weeks ${weeks == 1 ? 'week' : 'weeks'} to go'}',
                  style: AppTheme.bodyMd.copyWith(color: palette.textPrimary),
                ),
              ),
              TextButton(
                onPressed: () async {
                  final now = DateTime.now();
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: plan.examDate ?? DateTime(now.year + 1, 5, 1),
                    firstDate: DateTime(now.year, now.month, now.day),
                    lastDate: DateTime(now.year + 2, 12, 31),
                    helpText: 'Your first WASSCE paper',
                  );
                  if (picked != null) {
                    await _save(
                      ref,
                      PlanSettings(
                        weeklyGoal: plan.weeklyGoal,
                        examDate: picked,
                      ),
                    );
                  }
                },
                child: Text(plan.examDate == null ? 'Set date' : 'Change'),
              ),
              if (plan.examDate != null)
                TextButton(
                  onPressed: () =>
                      _save(ref, PlanSettings(weeklyGoal: plan.weeklyGoal)),
                  child: const Text('Clear'),
                ),
            ],
          ),
        ),
        const SizedBox(height: kSectionGap),
        if (slugs.isEmpty)
          EmptyState(
            icon: Icons.menu_book_outlined,
            title: 'Choose your subjects',
            message: 'Your plan follows the subjects you are taking.',
            action: TextButton(
              onPressed: () => context.push('/settings/subjects'),
              child: const Text('Choose subjects'),
            ),
          )
        else
          for (final slug in slugs)
            ref
                .watch(courseProvider(slug))
                .when(
                  loading: () => const Padding(
                    padding: EdgeInsets.only(bottom: kSectionGap),
                    child: SkeletonPage(title: false, count: 2),
                  ),
                  error: (_, _) => const SizedBox.shrink(),
                  data: (course) => course.isLive
                      ? Padding(
                          padding: const EdgeInsets.only(bottom: kSectionGap),
                          child: CoursePlanPanel(
                            course: course,
                            progress: progress,
                            examDate: plan.examDate,
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
      ],
    );
  }
}

String _date(DateTime d) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${d.day} ${months[d.month - 1]} ${d.year}';
}
