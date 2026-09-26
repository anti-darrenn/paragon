import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/learn/lesson_progress.dart';
import '../core/providers/auth_provider.dart';
import '../core/repositories/learn_progress_repository.dart';
import '../core/repositories/learn_repository.dart';
import '../core/repositories/learning_repository.dart';
import 'lesson/lesson_screen.dart';
import '../core/repositories/course_repository.dart';
import '../core/repositories/progress_repository.dart';
import '../core/progress/mastery.dart';
import '../core/theme/app_colors.dart';
import '../core/widgets/guest_notice.dart';
import '../core/theme/app_theme.dart';
import '../core/widgets/mastery_indicator.dart';
import '../core/widgets/user_avatar.dart';
import '../core/widgets/load_error.dart';
import '../core/theme/app_palette.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userDataAsync = ref.watch(userDataProvider);
    final weeklyAsync = ref.watch(weeklyAttemptsCountProvider);
    final isGuest = ref.watch(isGuestProvider);
    // Already streamed by `YourSubjects` below — Riverpod shares the one
    // listener, so reading it here costs nothing extra.
    final progress =
        ref.watch(userProgressProvider).asData?.value ?? UserProgress.empty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        // No hardcoded leading: this screen is the app's home ('/'), where
        // a back arrow pointing at '/' would be a no-op. When it is reached
        // by a push instead, Material's automaticallyImplyLeading supplies
        // a real back button on its own.
        // Your profile, which links on to settings. The avatar replaced a
        // settings gear here, so settings stays one tap further than it
        // was — a fair trade for a profile nobody could otherwise find.
        actions: [
          IconButton(
            icon: const UserAvatar(size: 32),
            tooltip: 'Your profile',
            onPressed: () => context.push('/me'),
          ),
          const SizedBox(width: 4),
        ],
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

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Greeting ───────────────────────────────────────────
                Text(
                  'Hey, $displayName 👋',
                  style: TextStyle(
                    color: context.palette.textStrong,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Pick up where you left off.',
                  style: TextStyle(color: context.palette.onLow, fontSize: 14),
                ),
                const SizedBox(height: 16),

                // The counters below are real, written to a real uid — and
                // that uid dies with the session. A guest watching them
                // climb deserves to know that before they find out by
                // losing them.
                if (isGuest) ...[
                  const GuestNotice(),
                  const SizedBox(height: 16),
                ],

                const _ContinueLearning(),

                // ── Stats row ──────────────────────────────────────────
                Row(
                  children: [
                    Expanded(
                      // Replaces the day-streak card. Both numbers come
                      // from the `progress/{uid}` document already being
                      // streamed for the subject rings, so this is a
                      // relabelling of data in hand, not a new read — and
                      // unlike the streak it is recomputable from
                      // `attempts` rather than from the device clock.
                      child: _StatCard(
                        icon: Icons.donut_large_rounded,
                        iconColor: AppColors.primary,
                        value: '${progress.startedTopicCount}',
                        label: 'Topics practised',
                        sublabel: progress.completedTopicCount == 0
                            ? 'Start one today'
                            : '${progress.completedTopicCount} at proficient',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: weeklyAsync.when(
                        loading: () => const _StatCard(
                          icon: Icons.check_circle_outline_rounded,
                          iconColor: AppColors.accentBlue,
                          value: '—',
                          label: 'This week',
                          sublabel: 'Questions',
                        ),
                        error: (e, st) => const _StatCard(
                          icon: Icons.check_circle_outline_rounded,
                          iconColor: AppColors.accentBlue,
                          value: '0',
                          label: 'This week',
                          sublabel: 'Questions',
                        ),
                        data: (count) => _StatCard(
                          icon: Icons.check_circle_outline_rounded,
                          iconColor: AppColors.accentBlue,
                          value: '$count',
                          label: 'This week',
                          sublabel: 'Questions',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // ── Your subjects ──────────────────────────────────────
                const YourSubjects(),
                const SizedBox(height: 28),

                // ── Continue practising ────────────────────────────────
                _SectionHeader('Continue Practising'),
                const SizedBox(height: 10),
                _ActionCard(
                  icon: Icons.play_circle_filled_rounded,
                  iconColor: AppColors.primary,
                  title: 'Back to Subjects',
                  subtitle: 'Pick a topic and keep drilling',
                  onTap: () => context.go('/subjects'),
                ),
                const SizedBox(height: 10),
                _ActionCard(
                  icon: Icons.assignment_outlined,
                  iconColor: AppColors.accentBlue,
                  title: 'WAEC Exam Mode',
                  subtitle: 'Timed past-paper practice',
                  onTap: () => context.go('/waec'),
                ),
                const SizedBox(height: 32),
              ],
            ),
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: _SectionHeader('Your Subjects')),
            TextButton(
              onPressed: () => context.push('/settings/subjects'),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'Edit',
                style: AppTheme.caption.copyWith(color: AppColors.primary),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
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

    return GestureDetector(
      onTap: () => context.push('/subject/${course.key}/course'),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.palette.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.palette.border),
        ),
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
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Reusable sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: context.palette.textStrong,
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

/// "Continue learning" — the Learn topic the student most recently
/// finished something in, and the next thing to open there.
///
/// Absent until a student has completed at least one lesson item. Costs
/// the topic document and that topic's resource list (two reads), both
/// cached for the lesson page it links to.
class _ContinueLearning extends ConsumerWidget {
  const _ContinueLearning();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recent = ref.watch(lessonProgressProvider).mostRecent;
    if (recent == null) return const SizedBox.shrink();

    final topic = ref.watch(topicByIdProvider(recent.topicId)).asData?.value;
    final resources = ref
        .watch(topicResourcesProvider(recent.topicId))
        .asData
        ?.value;
    if (topic == null || resources == null) return const SizedBox.shrink();

    final next = continueTarget(resources, recent.progress.completed);
    final done = completedCount(resources, recent.progress.completed);
    final total = availableCount(resources);
    final (title, subtitle, path) = next != null
        ? (
            'Continue learning: ${topic.name}',
            'Up next: ${next.title} · $done of $total done',
            lessonPath(topic.id, next.id),
          )
        : (
            'You finished the ${topic.name} lesson',
            'Take the topic test to unlock practice drills.',
            '/subject/${topic.subjectId}/unit/${topic.unitId}/topic/${topic.id}/test',
          );

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: context.palette.surface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => context.push(path),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primary.withAlpha(90)),
            ),
            child: Row(
              children: [
                Icon(
                  next == null
                      ? Icons.task_alt_rounded
                      : Icons.play_lesson_outlined,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppTheme.bodyLg.copyWith(
                          color: context.palette.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: AppTheme.bodyMd.copyWith(
                          color: context.palette.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.primary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;
  final String sublabel;

  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
    required this.sublabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.palette.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 22),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              color: context.palette.textStrong,
              fontSize: 32,
              fontWeight: FontWeight.bold,
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(color: context.palette.onMedium, fontSize: 12),
          ),
          Text(
            sublabel,
            style: TextStyle(
              color: iconColor.withAlpha((0.8 * 255).round()),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.palette.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.palette.border),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: iconColor.withAlpha((0.12 * 255).round()),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: context.palette.textStrong,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: context.palette.onLow,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: context.palette.onLow),
          ],
        ),
      ),
    );
  }
}
