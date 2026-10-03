import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/providers/auth_provider.dart';
import 'lesson/continue_learning.dart';
import '../core/repositories/course_repository.dart';
import '../core/repositories/progress_repository.dart';
import '../core/progress/mastery.dart';
import '../core/theme/app_colors.dart';
import '../core/widgets/guest_notice.dart';
import '../core/theme/app_theme.dart';
import '../core/widgets/mastery_indicator.dart';
import '../core/widgets/page_layout.dart';
import '../core/widgets/ui/ui.dart';
import '../core/widgets/load_error.dart';
import '../core/theme/app_palette.dart';
import '../core/widgets/nav/back_navigation.dart';

/// What home says to the student: a greeting and a line under it, one
/// pair picked at random each visit so the page does not read the same
/// every time. `{name}` is replaced with the student's display name.
const kHomeGreetings = [
  ('Hey, {name}', 'Pick up where you left off.'),
  ('Welcome back, {name}', 'Ready when you are.'),
  ('Good to see you, {name}', "Here's where you got to."),
  ('Hi, {name}', 'A little practice goes a long way.'),
  ("Let's go, {name}", 'Your next step is below.'),
];

/// Picked once per app session, not per build: a greeting that changed
/// every time the page redrew would flicker.
final greetingIndexProvider = Provider<int>(
  (ref) => Random().nextInt(kHomeGreetings.length),
);

/// The greeting at [index] (wrapped into range) for [name].
(String, String) homeGreeting(String name, int index) {
  final (title, subtitle) = kHomeGreetings[index % kHomeGreetings.length];
  return (title.replaceAll('{name}', name), subtitle);
}

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userDataAsync = ref.watch(userDataProvider);
    final isGuest = ref.watch(isGuestProvider);

    return Scaffold(
      appBar: const ParagonAppBar(
        title: Text('Home'),
        // On a wide screen the top bar names the page and carries search
        // and the account menu; the greeting below leads instead.
        collapseWhenWide: true,
        actions: [SearchAction()],
      ),
      body: userDataAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => LoadError(
          error: e,
          onRetry: () => ref.invalidate(userDataProvider),
        ),
        data: (userData) {
          // UserRepository stores `displayName: user.displayName ?? ''`, so
          // an anonymous user — and an email sign-up that never set a name
          // — has an empty string here, not null. A null-only fallback
          // therefore greeted them as "Hey,  👋". Treat blank as missing.
          final storedName = (userData?['displayName'] as String?)?.trim();
          final displayName = (storedName == null || storedName.isEmpty)
              ? 'Student'
              : storedName;

          return PageBody(
            maxWidth: 1040,
            children: [
              Builder(
                builder: (context) {
                  final (title, subtitle) = homeGreeting(
                    displayName,
                    ref.watch(greetingIndexProvider),
                  );
                  return PageIntro(title: title, subtitle: subtitle);
                },
              ),
              // The counters below are real, written to a real uid — and
              // that uid is easily lost. A guest watching them climb
              // deserves to know that before they find out by losing them.
              if (isGuest) ...[const GuestNotice(), const SizedBox(height: 20)],
              LayoutBuilder(
                builder: (context, box) {
                  // Two columns once there is room: what to do next on the
                  // left, how it is going and where else to go on the right.
                  if (box.maxWidth >= 820) {
                    return const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [_ContinueLearning(), YourSubjects()],
                          ),
                        ),
                        SizedBox(width: 24),
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _Stats(),
                              SizedBox(height: kSectionGap),
                              _QuickLinks(),
                            ],
                          ),
                        ),
                      ],
                    );
                  }
                  return const Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _ContinueLearning(),
                      _Stats(),
                      SizedBox(height: kSectionGap),
                      YourSubjects(),
                      _QuickLinks(),
                    ],
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

/// The subjects the student chose during onboarding, with what they have
/// done in each.
///
/// This section is the reason the subjects step exists. Until it was
/// built, `selectedSubjects` had exactly one reader in the whole app — the
/// catalog grid's sort order — so onboarding asked a question, wrote the
/// answer down, and never used it for anything the student could see.
///
/// **The ring's denominator comes from `subjects.topicCount`**, written by
/// the seeders and kept true nightly by `tools/admin/jobs.js --job=counts`.
/// That field exists so this page does not have to load every unit and
/// every unit's topics, per subject, to draw a circle: `subjectsProvider`
/// is one query the app already makes, and the numerator comes free from
/// the student's own progress document.
///
/// A subject whose `topicCount` is not known yet — seeded before the field
/// existed, or added between nightly runs — shows counts and no ring,
/// rather than a ring against a denominator of zero.
///
/// Also shown on `/me`, which is why it is public.
class YourSubjects extends ConsumerWidget {
  const YourSubjects({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedSubjectSlugsProvider);
    final catalogAsync = ref.watch(courseCatalogProvider);
    final progress =
        ref.watch(userProgressProvider).asData?.value ?? UserProgress.empty;

    // A guest, or anyone who has not been through onboarding, expressed no
    // preference. Showing an empty "Your subjects" card to them would be a
    // prompt to fix something that is not broken.
    if (selected.isEmpty) return const SizedBox.shrink();

    final courses = catalogAsync.asData?.value ?? const <CourseSummary>[];
    final mine = courses.where((c) => selected.contains(c.slug)).toList();
    if (mine.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          'Your subjects',
          action: TextButton(
            onPressed: () => context.push('/settings/subjects'),
            child: const Text('Edit'),
          ),
        ),
        for (var i = 0; i < mine.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          _SubjectProgressCard(
            course: mine[i],
            progress: progress.forSubject(mine[i].key),
            levels: progress.levelsForSubject(
              mine[i].key,
              outOf: mine[i].topicCount,
            ),
          ),
        ],
        const SizedBox(height: kSectionGap),
      ],
    );
  }
}

class _SubjectProgressCard extends StatelessWidget {
  const _SubjectProgressCard({
    required this.course,
    required this.progress,
    required this.levels,
  });

  final CourseSummary course;
  final SubjectProgress progress;

  /// One level per topic in the subject, untouched topics included —
  /// empty when the topic count is unknown, which is what suppresses the
  /// ring rather than drawing an empty one.
  final List<MasteryLevel> levels;

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.forSubject(course.name);

    final String detail;
    if (!course.isLive) {
      detail = 'Coming soon';
    } else if (progress.isEmpty) {
      detail = 'Not started yet';
    } else if (course.hasTopicCount) {
      detail =
          '${progress.startedTopics} of ${course.topicCount} topics  ·  '
          '${progress.completedTopics} proficient';
    } else {
      final started = progress.startedTopics;
      detail =
          '$started ${started == 1 ? 'topic' : 'topics'} started  ·  '
          '${progress.completedTopics} proficient';
    }

    return SurfaceCard(
      onTap: () => context.go('/subject/${course.key}/course'),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 36,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  course.name,
                  style: TextStyle(
                    color: context.palette.textStrong,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  detail,
                  style: TextStyle(
                    color: progress.isEmpty || !course.isLive
                        ? context.palette.onLow
                        : accent,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (levels.isNotEmpty) ...[
            MasteryRing(
              fraction: masteryFraction(levels),
              accent: accent,
              size: 40,
            ),
            const SizedBox(width: 6),
          ],
          Icon(Icons.chevron_right_rounded, color: context.palette.onLow),
        ],
      ),
    );
  }
}

/// "Continue learning": the lesson the student was last in, how far
/// through its topic they are, and one button back in. Absent until a
/// student has completed at least one lesson item.
class _ContinueLearning extends ConsumerWidget {
  const _ContinueLearning();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(continueLearningProvider);
    if (c == null) return const SizedBox.shrink();
    final next = c.next;
    final fraction = c.total == 0 ? 0.0 : c.done / c.total;

    return Padding(
      padding: const EdgeInsets.only(bottom: kSectionGap),
      child: SurfaceCard(
        key: const ValueKey('dashboard.continue'),
        borderColor: AppColors.primary.withAlpha(110),
        padding: const EdgeInsets.all(20),
        onTap: () => context.push(c.path),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconTile(
                  icon: next == null
                      ? Icons.task_alt_rounded
                      : Icons.play_lesson_rounded,
                  color: AppColors.primary,
                  size: 44,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        next == null ? 'LESSON FINISHED' : 'CONTINUE LEARNING',
                        style: AppTheme.caption.copyWith(
                          color: AppColors.primary,
                          letterSpacing: 0.9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        c.topic.name,
                        style: AppTheme.heading3.copyWith(
                          color: context.palette.textStrong,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              next == null
                  ? 'Take the topic test to unlock practice drills.'
                  : 'Up next: ${next.title}',
              style: AppTheme.bodyMd.copyWith(
                color: context.palette.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: fraction,
                      minHeight: 6,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${c.done} of ${c.total}',
                  style: AppTheme.label.copyWith(
                    color: context.palette.textSecondary,
                  ),
                ),
                const SizedBox(width: 16),
                FilledButton.icon(
                  onPressed: () => context.push(c.path),
                  icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                  iconAlignment: IconAlignment.end,
                  label: Text(next == null ? 'Take the test' : 'Resume'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 40),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Two numbers about the student's practice. Both come from documents
/// already being streamed (`progress/{uid}` and the week's attempt
/// count), and both are recomputable from `attempts` — unlike the day
/// streak they replaced, which came from the device clock.
class _Stats extends ConsumerWidget {
  const _Stats();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress =
        ref.watch(userProgressProvider).asData?.value ?? UserProgress.empty;
    final weekly = ref.watch(weeklyAttemptsCountProvider);
    final week = weekly.when(
      loading: () => '—',
      error: (_, _) => '0',
      data: (n) => '$n',
    );

    // Stretched to the taller tile, so the two cards' edges line up
    // whichever one has the longer caption.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _StatTile(
              icon: Icons.donut_large_rounded,
              color: AppColors.primary,
              value: '${progress.startedTopicCount}',
              label: 'Topics practised',
              detail: progress.completedTopicCount == 0
                  ? 'Start one today'
                  : '${progress.completedTopicCount} at proficient',
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _StatTile(
              icon: Icons.check_circle_outline_rounded,
              color: AppColors.accentBlue,
              value: week,
              label: 'Questions this week',
              detail: 'Practice, tests and exams',
            ),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
    required this.detail,
  });

  final IconData icon;
  final Color color;
  final String value;
  final String label;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconTile(icon: icon, color: color, size: 36),
          const SizedBox(height: 14),
          Text(
            value,
            style: AppTheme.displayLg.copyWith(
              color: context.palette.textStrong,
              height: 1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: AppTheme.label.copyWith(color: context.palette.textPrimary),
          ),
          Text(
            detail,
            style: AppTheme.caption.copyWith(
              color: context.palette.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Where else to go from home, as one tidy list.
class _QuickLinks extends StatelessWidget {
  const _QuickLinks();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader('Keep going'),
        RowGroup(
          children: [
            ListRow(
              icon: Icons.auto_stories_rounded,
              iconColor: AppColors.primary,
              title: 'Browse courses',
              subtitle: 'Pick a topic and keep learning',
              onTap: () => context.go('/courses'),
            ),
            // No count here on purpose: counting means reading the
            // student's recent attempts, and home opens far more often
            // than the notebook.
            ListRow(
              icon: Icons.replay_rounded,
              iconColor: AppColors.wrong,
              title: 'Mistakes notebook',
              subtitle: 'Go back over questions you got wrong',
              onTap: () => context.push('/mistakes'),
            ),
            ListRow(
              icon: Icons.style_rounded,
              iconColor: AppColors.secondary,
              title: 'Review',
              subtitle: 'Revision cards, saved lessons and notes',
              onTap: () => context.go('/review'),
            ),
            ListRow(
              icon: Icons.assignment_rounded,
              iconColor: AppColors.accentBlue,
              title: 'WAEC exam mode',
              subtitle: 'Timed past-paper practice',
              onTap: () => context.go('/waec'),
            ),
          ],
        ),
      ],
    );
  }
}
