import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/plan/planner.dart';
import '../core/plan/study_plan.dart' show weeksUntil;
import '../core/providers/auth_provider.dart';
import '../core/repositories/plan_repository.dart';
import 'lesson/continue_learning.dart';
import '../core/repositories/course_repository.dart';
import '../core/repositories/progress_repository.dart';
import '../core/progress/mastery.dart';
import '../core/theme/app_colors.dart';
import '../core/widgets/guest_notice.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/tokens.dart';
import '../core/widgets/mastery_indicator.dart';
import '../core/widgets/page_layout.dart';
import '../core/widgets/ui/ui.dart';
import '../core/widgets/load_error.dart';
import '../core/theme/app_palette.dart';
import '../core/widgets/nav/back_navigation.dart';
import 'study/hub/study_paths.dart';
import 'study/planner/planner_store.dart';

/// The part of the day a greeting is for, by the device's clock.
enum DayPart { morning, afternoon, evening, late }

DayPart dayPartAt(int hour) => switch (hour) {
  >= 5 && < 12 => DayPart.morning,
  >= 12 && < 17 => DayPart.afternoon,
  >= 17 && < 22 => DayPart.evening,
  _ => DayPart.late,
};

/// What home says to the student: a greeting and a line under it, for the
/// time of day, one pair picked at random each visit so the page does not
/// read the same every time. `{name}` is replaced with the student's
/// display name. Warm, a little cheeky, never an emoji.
const kHomeGreetingsByPart = <DayPart, List<(String, String)>>{
  DayPart.morning: [
    ('Good morning, {name}', 'Fresh brain, fresh start. What are we learning?'),
    ('Morning, {name}', 'Twenty minutes before the day gets busy?'),
    ('Rise and shine, {name}', 'Early study sticks. Let us make it count.'),
  ],
  DayPart.afternoon: [
    ('Good afternoon, {name}', 'A short session now beats a long one never.'),
    ('Afternoon, {name}', 'Pick up where you left off.'),
    (
      'Hey, {name}',
      'Halfway through the day. One topic before the next thing?',
    ),
  ],
  DayPart.evening: [
    ('Good evening, {name}', 'One topic tonight, and tomorrow is easier.'),
    ('Evening, {name}', "Let's make today count."),
    ('Welcome back, {name}', 'Settle in. Your next step is below.'),
  ],
  DayPart.late: [
    (
      'Still up, {name}?',
      'Keep it short, then sleep: memory sets while you rest.',
    ),
    ('Night owl mode, {name}', 'Ten questions, then bed. Deal?'),
    ('Burning the midnight oil, {name}?', 'Respect. Small steps, then rest.'),
  ],
};

/// Every greeting, in one list.
final kHomeGreetings = [
  for (final lines in kHomeGreetingsByPart.values) ...lines,
];

/// Picked once per app session, not per build: a greeting that changed
/// every time the page redrew would flicker.
final greetingIndexProvider = Provider<int>((ref) => Random().nextInt(1000));

/// The greeting at [index] (wrapped into range) for [name]: from the
/// lines for [part] when given, otherwise from all of them.
(String, String) homeGreeting(String name, int index, {DayPart? part}) {
  final lines = part == null ? kHomeGreetings : kHomeGreetingsByPart[part]!;
  final (title, subtitle) = lines[index % lines.length];
  return (title.replaceAll('{name}', name), subtitle);
}

/// Paragon's tip of the day: one a day, the same all day.
const kStudyTips = [
  'Little and often wins. Three 20-minute sessions beat one long cram.',
  'Got one wrong? Good. The mistakes notebook turns it into one you get '
      'right.',
  'Read the question twice. Examiners love a "NOT" in the stem.',
  'Teach it to a friend. If you can explain it, you know it.',
  'Sleep is study too: your brain files away the day while you rest.',
  'Start with the topic you have been avoiding. It is usually smaller '
      'than it looks.',
  'In an objective question, rule out the two silly options first.',
  'Show your working, even to yourself. That is where Paper 2 marks hide.',
  'Past questions repeat their ideas. Sit a paper and you will see which.',
  'Take a break before you need one. Five minutes away, then back.',
  'Say a formula out loud as you write it. It sticks twice as well.',
  'Plan tomorrow tonight. Waking up to a plan is half the battle.',
];

/// The tip for [day]: by day of the year, so it changes at midnight.
String tipFor(DateTime day) {
  final n = day.difference(DateTime(day.year)).inDays;
  return kStudyTips[n % kStudyTips.length];
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
        loading: () => const PageBody(
          maxWidth: kContentMaxWidth,
          children: [SkeletonPage(count: 4, cardHeight: 96)],
        ),
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
            maxWidth: kContentMaxWidth,
            children: [
              _HomeHero(name: displayName),
              const SizedBox(height: kSectionGap),
              // What the student does here is real, written to a real uid,
              // and that uid is easily lost. A guest deserves to know that
              // before they find out by losing it.
              if (isGuest) ...[const GuestNotice(), const SizedBox(height: 20)],
              LayoutBuilder(
                builder: (context, box) {
                  // Two columns once there is room: what to do next on the
                  // left, where else to go on the right.
                  if (box.maxWidth >= 820) {
                    return const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _ContinueLearning(),
                              _TodayCard(),
                              YourSubjects(),
                            ],
                          ),
                        ),
                        SizedBox(width: 24),
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [_QuickStart(columns: 2), _SupportLine()],
                          ),
                        ),
                      ],
                    );
                  }
                  return const Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _ContinueLearning(),
                      _TodayCard(),
                      _QuickStart(columns: 2),
                      YourSubjects(),
                      _SupportLine(),
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

const _weekdayNames = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];
const _monthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

/// The top of Home: the date, a greeting for the time of day, the exam
/// countdown when the student has set one, and the tip of the day. Brand
/// colours washed over the surface, so it reads in light and dark alike.
class _HomeHero extends ConsumerWidget {
  const _HomeHero({required this.name});
  final String name;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final now = DateTime.now();
    final (title, subtitle) = homeGreeting(
      name,
      ref.watch(greetingIndexProvider),
      part: dayPartAt(now.hour),
    );
    // Accounts only; a guest's settings are always `none`.
    final exam = ref.watch(planSettingsProvider).asData?.value.examDate;
    final days = exam == null
        ? null
        : DateTime(
            exam.year,
            exam.month,
            exam.day,
          ).difference(DateTime(now.year, now.month, now.day)).inDays;

    return Container(
      key: const ValueKey('home.hero'),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.border),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.alphaBlend(AppColors.primary.withAlpha(34), palette.surface),
            palette.surface,
            Color.alphaBlend(
              AppColors.secondary.withAlpha(30),
              palette.surface,
            ),
          ],
          stops: const [0, 0.55, 1],
        ),
      ),
      child: Stack(
        children: [
          // A little sparkle in the corner, decoration only.
          Positioned(
            right: -18,
            top: -18,
            child: ExcludeSemantics(
              child: Icon(
                Icons.auto_awesome_rounded,
                size: 120,
                color: AppColors.primary.withAlpha(26),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_weekdayNames[now.weekday - 1]} ${now.day} '
                          '${_monthNames[now.month - 1]}'
                      .toUpperCase(),
                  style: AppTheme.caption.copyWith(
                    color: context.palette.primaryFg,
                    letterSpacing: 1.1,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Semantics(
                  header: true,
                  child: Text(
                    title,
                    style: AppTheme.displayLg.copyWith(
                      color: palette.textStrong,
                      height: 1.15,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: AppTheme.bodyLg.copyWith(color: palette.textSecondary),
                ),
                if (days != null && days >= 0) ...[
                  const SizedBox(height: 14),
                  _Pill(
                    icon: Icons.event_rounded,
                    color: AppColors.primary,
                    text: days == 0
                        ? 'Exam day. You have got this.'
                        : days < 14
                        ? '$days ${days == 1 ? 'day' : 'days'} to your exam'
                        : '${weeksUntil(exam!, now)} weeks to your exam',
                    onTap: () => context.push('/plan'),
                  ),
                ],
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: palette.background.withAlpha(150),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: palette.border),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.lightbulb_outline_rounded,
                        size: 18,
                        color: AppColors.warning,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: 'Tip of the day  ',
                                style: AppTheme.label.copyWith(
                                  color: palette.textPrimary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              TextSpan(
                                text: tipFor(now),
                                style: AppTheme.label.copyWith(
                                  color: palette.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
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

class _Pill extends StatelessWidget {
  const _Pill({
    required this.icon,
    required this.color,
    required this.text,
    this.onTap,
  });

  final IconData icon;
  final Color color;
  final String text;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withAlpha(30),
      shape: StadiumBorder(side: BorderSide(color: color.withAlpha(110))),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                text,
                style: AppTheme.label.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Today": what the planner says for today, ticked off right here. Kept
/// on the device, so it costs nothing to show.
class _TodayCard extends ConsumerWidget {
  const _TodayCard();

  static const _shown = 4;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final tasks = ref.watch(plannerProvider).on(dayKey(DateTime.now()));
    final done = tasks.where((t) => t.done).length;
    final allDone = tasks.isNotEmpty && done == tasks.length;

    return Padding(
      padding: const EdgeInsets.only(bottom: kSectionGap),
      child: SurfaceCard(
        key: const ValueKey('home.today'),
        padding: const EdgeInsets.fromLTRB(18, 14, 10, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const IconTile(
                  icon: Icons.event_note_rounded,
                  color: AppColors.accentBlue,
                  size: 36,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Today',
                        style: AppTheme.heading3.copyWith(
                          color: palette.textPrimary,
                        ),
                      ),
                      Text(
                        tasks.isEmpty
                            ? 'Nothing planned yet'
                            : allDone
                            ? 'All done. Brilliant.'
                            : '$done of ${tasks.length} done',
                        style: AppTheme.caption.copyWith(
                          color: allDone
                              ? AppColors.correct
                              : palette.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => context.push(kPlannerPath),
                  child: Text(tasks.isEmpty ? 'Plan my week' : 'Planner'),
                ),
              ],
            ),
            if (tasks.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8, right: 8),
                child: Text(
                  'Give today a plan and Paragon will keep score. Or let it '
                  'pick the topics worth the most marks.',
                  style: AppTheme.label.copyWith(color: palette.textSecondary),
                ),
              )
            else ...[
              const SizedBox(height: 4),
              for (final t in tasks.take(_shown))
                CheckboxListTile(
                  key: ValueKey('home.today.${t.id}'),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  activeColor: AppColors.correct,
                  value: t.done,
                  onChanged: (_) =>
                      ref.read(plannerProvider.notifier).toggle(t.id),
                  title: Text(
                    t.title,
                    style: AppTheme.bodyMd.copyWith(
                      color: t.done
                          ? palette.textSecondary
                          : palette.textPrimary,
                      decoration: t.done
                          ? TextDecoration.lineThrough
                          : TextDecoration.none,
                    ),
                  ),
                  subtitle: t.subject.isEmpty && t.minutes == 0
                      ? null
                      : Text(
                          [
                            if (t.subject.isNotEmpty) t.subject,
                            if (t.minutes > 0) '${t.minutes} min',
                          ].join(' · '),
                          style: AppTheme.caption.copyWith(
                            color: palette.textSecondary,
                          ),
                        ),
                ),
              if (tasks.length > _shown)
                Padding(
                  padding: const EdgeInsets.only(left: 4, top: 2),
                  child: Text(
                    'and ${tasks.length - _shown} more in the planner',
                    style: AppTheme.caption.copyWith(
                      color: palette.textSecondary,
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Where to go from home, as tiles: each one a thing to do, said plainly.
class _QuickStart extends StatelessWidget {
  const _QuickStart({required this.columns});
  final int columns;

  @override
  Widget build(BuildContext context) {
    final tiles = [
      _Tile(
        key: const ValueKey('home.quick.quiz'),
        icon: Icons.bolt_rounded,
        color: AppColors.primary,
        title: 'Quick quiz',
        line: 'Your topics, instant feedback',
        onTap: () => context.push(kCustomQuizPath),
      ),
      _Tile(
        key: const ValueKey('home.quick.waec'),
        icon: Icons.assignment_rounded,
        color: AppColors.accentBlue,
        title: 'Sit a past paper',
        line: 'The real thing, timed',
        onTap: () => context.go('/waec'),
      ),
      _Tile(
        key: const ValueKey('home.quick.mistakes'),
        icon: Icons.replay_rounded,
        color: AppColors.wrong,
        title: 'Mistakes',
        line: 'Turn wrongs into rights',
        onTap: () => context.push('/mistakes'),
      ),
      _Tile(
        key: const ValueKey('home.quick.planner'),
        icon: Icons.event_note_rounded,
        color: AppColors.correct,
        title: 'Planner',
        line: 'Plan the week, tick it off',
        onTap: () => context.push(kPlannerPath),
      ),
      _Tile(
        key: const ValueKey('home.quick.flashcards'),
        icon: Icons.style_rounded,
        color: AppColors.secondary,
        title: 'Flashcards',
        line: 'Make them, flip them',
        onTap: () => context.push(kDecksPath),
      ),
      _Tile(
        key: const ValueKey('home.quick.live'),
        icon: Icons.groups_rounded,
        color: AppColors.warning,
        title: 'Live quiz',
        line: 'Play with your class',
        onTap: () => context.push('/join'),
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader('Jump in'),
        // Rows of equal height: a tile whose line wraps no longer stands
        // taller than its neighbour.
        for (var r = 0; r < tiles.length; r += columns) ...[
          if (r > 0) const SizedBox(height: 10),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = r; i < r + columns; i++) ...[
                  if (i > r) const SizedBox(width: 10),
                  Expanded(
                    child: i < tiles.length ? tiles[i] : const SizedBox(),
                  ),
                ],
              ],
            ),
          ),
        ],
        const SizedBox(height: kSectionGap),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    required this.line,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String line;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return SurfaceCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          IconTile(icon: icon, color: color, size: 34),
          const SizedBox(height: 10),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTheme.bodyMd.copyWith(
              color: palette.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            line,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTheme.caption.copyWith(color: palette.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// One quiet line at the bottom: how Paragon stays free.
class _SupportLine extends StatelessWidget {
  const _SupportLine();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      child: TextButton.icon(
        style: TextButton.styleFrom(
          alignment: Alignment.centerLeft,
          foregroundColor: palette.textSecondary,
        ),
        onPressed: () => context.push('/support'),
        icon: const Icon(Icons.volunteer_activism_outlined, size: 18),
        label: const Text(
          'Paragon is free for every student. Here is how it stays that way.',
        ),
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

    if (catalogAsync.isLoading) return const _SubjectsSkeleton();
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

    final p = context.palette;
    return SurfaceCard(
      onTap: () => context.go('/subject/${course.slug}/course'),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: accent.withAlpha(30),
              borderRadius: BorderRadius.circular(Radii.md),
            ),
            child: Illustration(
              IllustrationAsset.forSubject(course.name),
              height: 38,
              accent: accent,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  course.name,
                  style: AppTheme.bodyMd.copyWith(
                    color: p.textStrong,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  detail,
                  style: AppTheme.label.copyWith(color: p.textSecondary),
                ),
              ],
            ),
          ),
          // A 0% ring says nothing to someone who has not started; the
          // ring arrives with the first practice.
          if (course.isLive && progress.isEmpty)
            Text(
              'Start',
              style: AppTheme.label.copyWith(
                color: p.primaryFg,
                fontWeight: FontWeight.w700,
              ),
            )
          else if (levels.isNotEmpty)
            MasteryRing(
              fraction: masteryFraction(levels),
              accent: accent,
              size: 40,
            ),
          const SizedBox(width: 6),
          Icon(Icons.chevron_right_rounded, color: p.onLow),
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
    if (c == null) {
      // Hold the card's place while progress loads, so the page does not
      // jump down when it arrives.
      if (ref.watch(continueLearningLoadingProvider)) {
        return const _ContinueSkeleton();
      }
      // Nothing to continue yet: say where to begin, instead of nothing.
      return const _StartHere();
    }
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
                          color: context.palette.primaryFg,
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

/// What a student with no progress sees where "Continue learning" will
/// be: their first subject's course, and five quick questions to warm up.
/// Brilliant and Khan both open on a single "start here"; Home used to open
/// on a page of equal tiles, none of which said where to begin.
///
/// Costs no reads: the catalog and progress are already loaded for "Your
/// subjects".
class _StartHere extends ConsumerWidget {
  const _StartHere();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(userProgressProvider).asData?.value;
    // Someone who has practised has places to go; this is for a first day.
    if (progress == null || !progress.isEmpty) {
      return const SizedBox.shrink();
    }
    final selected = ref.watch(selectedSubjectSlugsProvider);
    final courses =
        ref.watch(courseCatalogProvider).asData?.value ??
        const <CourseSummary>[];
    final first = courses
        .where((c) => c.isLive && (selected.isEmpty || selected.contains(c.slug)))
        .firstOrNull;
    final p = context.palette;
    final accent = first == null
        ? AppColors.primary
        : AppColors.forSubject(first.name);

    return Padding(
      padding: const EdgeInsets.only(bottom: kSectionGap),
      child: SurfaceCard(
        key: const ValueKey('dashboard.startHere'),
        borderColor: AppColors.primary.withAlpha(110),
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'START HERE',
                    style: AppTheme.caption.copyWith(
                      color: p.primaryFg,
                      letterSpacing: 0.9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    first == null
                        ? 'Pick a course to begin'
                        : 'Begin with ${first.name}',
                    style: AppTheme.heading3.copyWith(color: p.textStrong),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Each topic has a short test. Pass it to open unlimited '
                    'practice, with the working after every answer.',
                    style: AppTheme.bodyMd.copyWith(color: p.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      AppButton(
                        label: first == null
                            ? 'Browse courses'
                            : 'Open ${first.name}',
                        trailingIcon: Icons.arrow_forward_rounded,
                        onPressed: () => context.go(
                          first == null
                              ? '/courses'
                              : '/subject/${first.slug}/course',
                        ),
                      ),
                      AppButton(
                        label: 'Warm up: 5 questions',
                        tone: ButtonTone.ghost,
                        icon: Icons.bolt_rounded,
                        onPressed: () => context.push('/try'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (first != null && MediaQuery.sizeOf(context).width >= 480) ...[
              const SizedBox(width: 16),
              Illustration(
                IllustrationAsset.forSubject(first.name),
                height: 88,
                accent: accent,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The continue card's shape, pulsing, while it loads.
class _ContinueSkeleton extends StatelessWidget {
  const _ContinueSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(bottom: kSectionGap),
      child: SurfaceCard(
        key: ValueKey('dashboard.continueSkeleton'),
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SkeletonBox(width: 44, height: 44, radius: 12),
                SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonBox(width: 110, height: 10),
                    SizedBox(height: 8),
                    SkeletonBox(width: 220, height: 18),
                  ],
                ),
              ],
            ),
            SizedBox(height: 18),
            SkeletonBox(width: 260),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: SkeletonBox(height: 6)),
                SizedBox(width: 16),
                SkeletonBox(width: 110, height: 40, radius: 12),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// "Your subjects" while the catalog loads: the heading and three rows.
class _SubjectsSkeleton extends StatelessWidget {
  const _SubjectsSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader('Your subjects'),
        for (var i = 0; i < 3; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          const SurfaceCard(
            child: Row(
              children: [
                SkeletonBox(width: 4, height: 36, radius: 2),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonBox(width: 140),
                      SizedBox(height: 8),
                      SkeletonBox(width: 90, height: 10),
                    ],
                  ),
                ),
                SkeletonBox(width: 40, height: 40, radius: 20),
              ],
            ),
          ),
        ],
        const SizedBox(height: kSectionGap),
      ],
    );
  }
}
