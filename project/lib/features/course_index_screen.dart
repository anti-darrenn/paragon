import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/progress/course_progress.dart';
import '../core/repositories/course_repository.dart';
import '../core/repositories/progress_repository.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';
import '../core/widgets/app_top_nav.dart';
import '../core/widgets/course_module_card.dart';
import '../core/widgets/mastery_indicator.dart';

/// Course index for one subject — `/subject/:subjectKey/course`.
///
/// Every module in the subject on one scrollable page, each card carrying
/// its own topic grid, so a student sees the whole syllabus at once instead
/// of drilling unit-by-unit. Topics link to the topic overview page.
///
/// This is additive: `/subject/:subjectId` (UnitListScreen) is untouched
/// and still works.
class CourseIndexScreen extends ConsumerWidget {
  const CourseIndexScreen({super.key, required this.subjectKey});

  /// Either a Firestore subject document id or a catalog slug — see
  /// `courseProvider`.
  final String subjectKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final courseAsync = ref.watch(courseProvider(subjectKey));
    // One document listener for the whole page, not one query per topic —
    // see `progress_repository.dart`. A student with no progress yet
    // resolves to empty rather than to an error, so the page renders
    // identically whether or not they have ever practised.
    final progress =
        ref.watch(userProgressProvider).asData?.value ?? UserProgress.empty;

    return ParagonPage(
      child: courseAsync.when(
        loading: () =>
            const _CenteredMessage(child: CircularProgressIndicator()),
        error: (error, _) => _CourseError(error: error),
        data: (course) => _CourseBody(course: course, progress: progress),
      ),
    );
  }
}

/// Column count for a module card's topic grid, derived from the width of
/// the card list rather than the card's own grid region — the grid gets
/// [CourseModuleCard] `_gridFlex` (72%) of the card minus its 24px padding
/// on each side. Kept as a free function so both the page and its tests can
/// reason about the same thresholds.
int _gridColumnsFor(double listWidth, {required bool isCompact}) {
  // Stacked layout: the grid spans the whole card, but a phone-width card
  // only ever fits one column of topic names comfortably.
  if (isCompact) return 1;

  final gridWidth = listWidth * 0.72 - 48;
  if (gridWidth < 360) return 1;
  if (gridWidth < 560) return 2;
  return 3;
}

class _CourseBody extends StatelessWidget {
  const _CourseBody({required this.course, required this.progress});

  final Course course;
  final UserProgress progress;

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.forSubject(course.name);
    final isCompact = MediaQuery.sizeOf(context).width < kCompactBreakpoint;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: isCompact ? 24 : 40),

        // ── Breadcrumb ───────────────────────────────────────────────────
        _Breadcrumb(
          crumbs: [
            const _Crumb('Courses', '/courses'),
            _Crumb(course.name, null),
          ],
        ),
        const SizedBox(height: 16),

        // ── Page heading ─────────────────────────────────────────────────
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                course.name,
                style: AppTheme.displayLg.copyWith(
                  color: AppColors.textPrimaryDark,
                  fontSize: isCompact ? 28 : 40,
                ),
              ),
            ),
            if (!course.isLive) ...[
              const SizedBox(width: 12),
              const _StatusPill(label: 'Coming soon', color: AppColors.warning),
            ],
          ],
        ),

        if (course.blurb.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            course.blurb,
            style: AppTheme.bodyLg.copyWith(color: AppColors.textSecondaryDark),
          ),
        ],

        const SizedBox(height: 16),
        _CourseMeta(course: course, accent: accent),

        if (course.hasProgressToShow) ...[
          const SizedBox(height: 20),
          _CourseProgressPanel(
            course: course,
            progress: progress,
            accent: accent,
          ),
        ],

        if (!course.isLive) ...[
          const SizedBox(height: 20),
          _PlannedNotice(subjectName: course.name),
        ],

        SizedBox(height: isCompact ? 28 : 40),

        // ── Module cards ─────────────────────────────────────────────────
        if (course.modules.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 48),
            child: Text(
              'No modules yet for this subject.',
              style: AppTheme.bodyLg.copyWith(
                color: AppColors.textSecondaryDark,
              ),
            ),
          )
        else
          // Measured once for the whole list rather than per card, so every
          // module on the page breaks its grid at the same column count.
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = _gridColumnsFor(
                constraints.maxWidth,
                isCompact: isCompact,
              );
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < course.modules.length; i++) ...[
                    if (i > 0) const SizedBox(height: 20),
                    CourseModuleCard(
                      module: course.modules[i],
                      accent: accent,
                      index: i,
                      gridColumns: columns,
                      progress: progress,
                      onTopicTap: course.modules[i].isPlaceholder
                          ? null
                          : (topic) => context.push(
                              '/subject/${course.key}/course/topic/${topic.id}',
                            ),
                    ),
                  ],
                ],
              );
            },
          ),

        const SizedBox(height: 64),
      ],
    );
  }
}

/// Course mastery: the ring, and what it is counting.
///
/// The ring is the aggregate of every practisable topic in the subject, so
/// it moves slowly and deliberately — a student who has taken two topics
/// of forty-three to proficiency has done real work and the number should
/// say so without pretending they are nearly done. The counts beside it
/// are what actually answers "how am I doing", which is why they are words
/// and not just a percentage.
class _CourseProgressPanel extends StatelessWidget {
  const _CourseProgressPanel({
    required this.course,
    required this.progress,
    required this.accent,
  });

  final Course course;
  final UserProgress progress;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final total = course.practisableTopicCount;
    final started = course.startedCountIn(progress);
    final complete = course.completedCountIn(progress);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderDark),
      ),
      child: Row(
        children: [
          MasteryRing(
            fraction: course.masteryIn(progress),
            accent: accent,
            size: 64,
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  started == 0
                      ? 'You have not started this course yet'
                      : 'Course mastery',
                  style: AppTheme.bodyLg.copyWith(
                    color: AppColors.textPrimaryDark,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  started == 0
                      ? 'Pick any topic below to begin. Each circle fills as '
                            'you answer questions in that topic.'
                      : '$started of $total topics started  ·  $complete at '
                            'proficient or above',
                  style: AppTheme.bodyMd.copyWith(
                    color: AppColors.textSecondaryDark,
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

/// The "9 modules · 43 topics · 1,716 questions" line under the heading.
class _CourseMeta extends StatelessWidget {
  const _CourseMeta({required this.course, required this.accent});

  final Course course;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final parts = <String>[
      '${course.modules.length} '
          '${course.modules.length == 1 ? 'module' : 'modules'}',
      '${course.topicCount} ${course.topicCount == 1 ? 'topic' : 'topics'}',
      if (course.isLive) '${course.questionCount} questions',
    ];

    return Row(
      children: [
        Container(
          width: 3,
          height: 16,
          decoration: BoxDecoration(
            color: accent,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            parts.join('  ·  '),
            style: AppTheme.bodyMd.copyWith(color: AppColors.textSecondaryDark),
          ),
        ),
      ],
    );
  }
}

/// Says plainly that the outline below is a plan, not content. Without
/// this, a full-looking page of topic links reads as shipped material.
class _PlannedNotice extends StatelessWidget {
  const _PlannedNotice({required this.subjectName});

  final String subjectName;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.warning.withAlpha((0.08 * 255).round()),
        border: Border.all(
          color: AppColors.warning.withAlpha((0.35 * 255).round()),
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            size: 18,
            color: AppColors.warning,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$subjectName questions are not in Paragon yet. The outline '
              'below is the planned syllabus — topics will become '
              'practisable as content lands.',
              style: AppTheme.bodyMd.copyWith(
                color: AppColors.textSecondaryDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withAlpha((0.12 * 255).round()),
        border: Border.all(color: color.withAlpha((0.4 * 255).round())),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: AppTheme.caption.copyWith(color: color)),
    );
  }
}

class _Crumb {
  const _Crumb(this.label, this.path);
  final String label;
  final String? path;
}

class _Breadcrumb extends StatelessWidget {
  const _Breadcrumb({required this.crumbs});

  final List<_Crumb> crumbs;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (var i = 0; i < crumbs.length; i++) ...[
          if (i > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                '/',
                style: AppTheme.label.copyWith(color: AppColors.borderDark),
              ),
            ),
          if (crumbs[i].path == null)
            Text(
              crumbs[i].label,
              style: AppTheme.label.copyWith(
                color: AppColors.textSecondaryDark,
              ),
            )
          else
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () => context.go(crumbs[i].path!),
                child: Text(
                  crumbs[i].label,
                  style: AppTheme.label.copyWith(color: AppColors.primary),
                ),
              ),
            ),
        ],
      ],
    );
  }
}

class _CenteredMessage extends StatelessWidget {
  const _CenteredMessage({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 120),
      child: Center(child: child),
    );
  }
}

class _CourseError extends StatelessWidget {
  const _CourseError({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    final isMissing = error is CourseNotFoundException;

    return _CenteredMessage(
      child: Column(
        children: [
          Icon(
            isMissing ? Icons.search_off_rounded : Icons.error_outline_rounded,
            size: 32,
            color: AppColors.textSecondaryDark,
          ),
          const SizedBox(height: 12),
          Text(
            isMissing
                ? "We couldn't find that course."
                : "That course couldn't be loaded.",
            style: AppTheme.heading3.copyWith(color: AppColors.textPrimaryDark),
          ),
          const SizedBox(height: 8),
          Text(
            isMissing ? '$error' : 'Check your connection and try again.',
            textAlign: TextAlign.center,
            style: AppTheme.bodyMd.copyWith(color: AppColors.textSecondaryDark),
          ),
          const SizedBox(height: 20),
          OutlinedButton(
            onPressed: () => context.go('/courses'),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.primary),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Back to courses',
              style: AppTheme.btnLabel.copyWith(color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }
}
