import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/providers/auth_provider.dart';
import '../core/repositories/course_repository.dart';
import '../core/repositories/progress_repository.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userDataAsync = ref.watch(userDataProvider);
    final weeklyAsync = ref.watch(weeklyAttemptsCountProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        // No hardcoded leading: this screen is the app's home ('/'), where
        // a back arrow pointing at '/' would be a no-op. When it is reached
        // by a push instead, Material's automaticallyImplyLeading supplies
        // a real back button on its own.
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined, size: 22),
            tooltip: 'Settings',
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: userDataAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (userData) {
          final rawStreak = userData?['currentStreak'];
          final streak = rawStreak is int
              ? rawStreak
              : (rawStreak is num ? rawStreak.toInt() : 0);
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
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Keep the streak going.',
                  style: TextStyle(color: Colors.white38, fontSize: 14),
                ),
                const SizedBox(height: 24),

                // ── Stats row ──────────────────────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        icon: Icons.local_fire_department_rounded,
                        iconColor: AppColors.primary,
                        value: '$streak',
                        label: 'Day streak',
                        sublabel: streak == 0
                            ? 'Start today'
                            : streak == 1
                            ? '1 day'
                            : '$streak days',
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
                const _YourSubjects(),
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
/// **Counts, not percentages, and not rings.** A ring needs to know how
/// many topics the subject contains, which is not on the subject document;
/// working it out means loading every unit and every unit's topics, per
/// subject, on the app's landing page. The course page already pays that
/// cost for one subject and shows a real ring there. Inventing a
/// denominator here to get a ring on the dashboard would be a worse answer
/// than a smaller true one.
class _YourSubjects extends ConsumerWidget {
  const _YourSubjects();

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
          ),
        ],
      ],
    );
  }
}

class _SubjectProgressCard extends StatelessWidget {
  const _SubjectProgressCard({required this.course, required this.progress});

  final CourseSummary course;
  final SubjectProgress progress;

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.forSubject(course.name);

    final String detail;
    if (!course.isLive) {
      detail = 'Coming soon';
    } else if (progress.isEmpty) {
      detail = 'Not started yet';
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
          color: AppColors.surfaceDark,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderDark),
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
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    detail,
                    style: TextStyle(
                      color: progress.isEmpty || !course.isLive
                          ? Colors.white38
                          : accent,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.white38),
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
      style: const TextStyle(
        color: Colors.white,
        fontSize: 15,
        fontWeight: FontWeight.w600,
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
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 22),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(color: Colors.white54, fontSize: 12),
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
          color: AppColors.surfaceDark,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderDark),
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
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.white38),
          ],
        ),
      ),
    );
  }
}
