import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/learn/lesson_progress.dart';
import '../core/models/learn_resource.dart';
import '../core/repositories/learn_progress_repository.dart';
import '../core/repositories/course_repository.dart';
import '../core/repositories/learn_repository.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';
import '../core/widgets/app_top_nav.dart';
import 'lesson/lesson_screen.dart';
import 'lesson/video_pane.dart';
import 'study/offline/save_offline_button.dart';

/// Topic overview — `/subject/:subjectKey/course/topic/:topicKey`.
///
/// The lesson dashboard a topic link opens: everything that belongs to one
/// topic, listed in teaching order — watch, read, then practise — rather
/// than dropping the student straight into questions.
///
/// **What is real here and what is not.** The Learn section lists the
/// topic's *published* resources (`topicResourcesProvider`) in author
/// order, with checks for what the student has finished and a Start /
/// Continue button; every available item opens `LessonScreen`. A topic
/// with no published resources shows the old placeholder rows instead. The
/// practice row runs `DrillScreen`; the module quiz does not exist yet.
class TopicOverviewScreen extends ConsumerWidget {
  const TopicOverviewScreen({
    super.key,
    required this.subjectKey,
    required this.topicKey,
  });

  final String subjectKey;
  final String topicKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final courseAsync = ref.watch(courseProvider(subjectKey));

    return ParagonPage(
      child: courseAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: 120),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (error, _) => _NotFound(
          message: error is CourseNotFoundException
              ? '$error'
              : "That topic couldn't be loaded.",
        ),
        data: (course) {
          final found = course.findTopic(topicKey);
          if (found == null) {
            return const _NotFound(
              message: 'That topic is not part of this course.',
            );
          }
          final (module, topic) = found;
          return _TopicBody(course: course, module: module, topic: topic);
        },
      ),
    );
  }
}

class _TopicBody extends StatelessWidget {
  const _TopicBody({
    required this.course,
    required this.module,
    required this.topic,
  });

  final Course course;
  final CourseModule module;
  final CourseTopic topic;

  /// Drill route — only valid for a live topic, where both ids exist.
  String get _drillPath =>
      '/subject/${course.subjectId}/unit/${module.id}/topic/${topic.id}';

  bool get _canPractise =>
      !topic.isPlaceholder &&
      course.subjectId != null &&
      topic.questionCount > 0;

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.forSubject(course.name);
    final isCompact = MediaQuery.sizeOf(context).width < kCompactBreakpoint;

    final lessonList = _LessonList(
      course: course,
      module: module,
      topic: topic,
      accent: accent,
      drillPath: _drillPath,
      canPractise: _canPractise,
    );

    final rail = _PracticeRail(
      topic: topic,
      accent: accent,
      canPractise: _canPractise,
      onPractise: () => context.push(_drillPath),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: isCompact ? 24 : 40),

        _Breadcrumb(
          crumbs: [
            const _Crumb('Courses', '/courses'),
            _Crumb(course.name, '/subject/${course.key}/course'),
            _Crumb(module.name, null),
          ],
        ),
        const SizedBox(height: 16),

        Text(
          topic.name,
          style: AppTheme.displayLg.copyWith(
            color: AppColors.textPrimaryDark,
            fontSize: isCompact ? 26 : 36,
          ),
        ),
        const SizedBox(height: 10),
        Row(
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
                module.name,
                style: AppTheme.bodyMd.copyWith(
                  color: AppColors.textSecondaryDark,
                ),
              ),
            ),
          ],
        ),

        SizedBox(height: isCompact ? 28 : 40),

        if (isCompact)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [rail, const SizedBox(height: 24), lessonList],
          )
        else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: lessonList),
              const SizedBox(width: 28),
              SizedBox(width: 300, child: rail),
            ],
          ),

        const SizedBox(height: 64),
      ],
    );
  }
}

class _LessonList extends ConsumerWidget {
  const _LessonList({
    required this.course,
    required this.module,
    required this.topic,
    required this.accent,
    required this.drillPath,
    required this.canPractise,
  });

  final Course course;
  final CourseModule module;
  final CourseTopic topic;
  final Color accent;
  final String drillPath;
  final bool canPractise;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasNotes = topic.hasNotes && course.subjectId != null;

    // A catalog-only placeholder topic has no Firestore document, so it
    // cannot have resources and is not queried.
    final resourcesAsync = topic.isPlaceholder
        ? const AsyncData(<LearnResource>[])
        : ref.watch(topicResourcesProvider(topic.id));
    final resources = resourcesAsync.asData?.value ?? const <LearnResource>[];
    final completed = ref
        .watch(lessonProgressProvider)
        .forTopic(topic.id)
        .completed;

    // A failed load must not masquerade as "no lessons yet": the
    // placeholder rows below would hide it completely.
    if (resourcesAsync.hasError) {
      debugPrint(
        'topicResourcesProvider(${topic.id}) failed: '
        '${resourcesAsync.error}',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHeading(label: 'Learn', accent: accent),
        const SizedBox(height: 12),

        if (resourcesAsync.isLoading)
          const LinearProgressIndicator(minHeight: 2)
        else if (resourcesAsync.hasError)
          Text(
            "This topic's lessons couldn't be loaded. Try refreshing.",
            style: AppTheme.bodyMd.copyWith(color: AppColors.wrong),
          )
        else if (resources.isNotEmpty) ...[
          _lessonButton(context, resources, completed),
          for (var i = 0; i < resources.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            _resourceRow(
              context,
              resources[i],
              completed.contains(resources[i].id),
            ),
          ],
          SaveTopicOfflineButton(
            topicId: topic.id,
            topicName: topic.name,
            subjectId: course.subjectId ?? '',
            courseKey: course.key,
            resources: resources,
          ),
        ] else
          ..._placeholderRows(context, hasNotes),

        const SizedBox(height: 28),
        _SectionHeading(label: 'Practice', accent: accent),
        const SizedBox(height: 12),

        _LessonRow(
          icon: Icons.fitness_center_rounded,
          kind: 'Exercise',
          title: 'Practise ${topic.name}',
          subtitle: canPractise
              ? '${topic.questionCount} questions · instant feedback'
              : topic.isPlaceholder
              ? 'No questions yet'
              : 'No questions with a verified answer yet',
          accent: accent,
          onTap: canPractise ? () => context.push(drillPath) : null,
          disabledReason:
              'This topic has no practisable questions in Paragon yet.',
          isPrimary: true,
        ),
        const SizedBox(height: 10),

        // A scored, no-feedback quiz over one topic doesn't exist — WAEC
        // Prep is the exam-style surface and is subject-wide, not per
        // topic, so this is a genuine gap rather than a rename of drill.
        _LessonRow(
          icon: Icons.task_alt_rounded,
          kind: 'Quiz',
          title: '${module.name} quiz',
          subtitle: 'Not available yet',
          accent: accent,
          onTap: null,
          disabledReason: 'Module quizzes are not part of Paragon yet.',
        ),
      ],
    );
  }

  /// One published resource; every available one opens the lesson page.
  /// An unavailable one (a video not yet recorded, an article not yet
  /// written) stays listed and disabled, so the lesson's shape is honest.
  Widget _resourceRow(BuildContext context, LearnResource r, bool done) {
    final (icon, available, waiting) = switch (r.type) {
      LearnResourceType.video => (
        Icons.play_circle_outline_rounded,
        (r.durationSeconds ?? 0) > 0 ? 'Watch · ${formatDuration(r.durationSeconds!)}' : 'Watch',
        'Not recorded yet',
      ),
      LearnResourceType.article => (Icons.article_outlined, 'Read', 'Not written yet'),
      _ => (Icons.edit_note_rounded, 'Practise', 'Not available yet'),
    };
    return _LessonRow(
      icon: done ? Icons.check_circle : icon,
      kind: r.type.label,
      title: r.title,
      subtitle: !r.isAvailable ? waiting : (done ? 'Completed' : available),
      accent: done ? AppColors.correct : accent,
      onTap: r.isAvailable
          ? () => context.push(lessonPath(topic.id, r.id))
          : null,
      disabledReason: 'This ${r.type.label.toLowerCase()} is not ready yet.',
    );
  }

  /// "Start lesson" before anything is done, "Continue" part-way, "Review"
  /// once everything is — pointing at the first incomplete item.
  Widget _lessonButton(
    BuildContext context,
    List<LearnResource> resources,
    Set<String> completed,
  ) {
    final target = continueTarget(resources, completed);
    final first = resources.where((r) => r.isAvailable).firstOrNull;
    final open = target ?? first;
    if (open == null) return const SizedBox.shrink();

    final done = completedCount(resources, completed);
    final total = availableCount(resources);
    final label = target == null
        ? 'Review lesson'
        : done == 0
        ? 'Start lesson'
        : 'Continue: ${target.title}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '$done of $total done',
              style: AppTheme.bodyMd.copyWith(
                color: AppColors.textSecondaryDark,
              ),
            ),
          ),
          Flexible(
            child: ElevatedButton(
              onPressed: () => context.push(lessonPath(topic.id, open.id)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(label, overflow: TextOverflow.ellipsis),
            ),
          ),
        ],
      ),
    );
  }

  /// The lesson shape shown for a topic with no published resources.
  List<Widget> _placeholderRows(BuildContext context, bool hasNotes) {
    return [
      // Videos have no content model yet — no collection, no field, no
      // seeded data. Two rows are shown so the lesson shape is visible,
      // both explicitly disabled.
      _LessonRow(
        icon: Icons.play_circle_outline_rounded,
        kind: 'Video',
        title: 'Introduction to ${topic.name}',
        subtitle: 'Not recorded yet',
        accent: accent,
        onTap: null,
        disabledReason: 'Video lessons are not part of Paragon yet.',
      ),
      const SizedBox(height: 10),
      _LessonRow(
        icon: Icons.play_circle_outline_rounded,
        kind: 'Video',
        title: '${topic.name}: worked examples',
        subtitle: 'Not recorded yet',
        accent: accent,
        onTap: null,
        disabledReason: 'Video lessons are not part of Paragon yet.',
      ),
      const SizedBox(height: 10),

      // The one Learn row that can become real without a schema change:
      // `Topic.hasNotes` / `notesMarkdown` already exist and LearnScreen
      // already renders them. No seeded topic sets them today.
      _LessonRow(
        icon: Icons.article_outlined,
        kind: 'Article',
        title: '${topic.name} — key ideas',
        subtitle: hasNotes ? 'Read the notes' : 'Not written yet',
        accent: accent,
        onTap: hasNotes ? () => context.push('$drillPath/learn') : null,
        disabledReason: 'Notes for this topic have not been written yet.',
      ),
    ];
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.label, required this.accent});

  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: AppTheme.heading3.copyWith(
            color: AppColors.textPrimaryDark,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            height: 1,
            color: AppColors.borderDark.withAlpha((0.6 * 255).round()),
          ),
        ),
      ],
    );
  }
}

/// One row in the lesson list: type icon, kind label, title, status.
class _LessonRow extends StatefulWidget {
  const _LessonRow({
    required this.icon,
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.onTap,
    required this.disabledReason,
    this.isPrimary = false,
  });

  final IconData icon;
  final String kind;
  final String title;
  final String subtitle;
  final Color accent;
  final VoidCallback? onTap;

  /// Tooltip shown when [onTap] is null — says *why* the row is inert, so a
  /// disabled row never reads as a bug.
  final String disabledReason;

  /// The practice row: given the accent border, since it's the action the
  /// page exists to funnel students toward.
  final bool isPrimary;

  @override
  State<_LessonRow> createState() => _LessonRowState();
}

class _LessonRowState extends State<_LessonRow> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isEnabled = widget.onTap != null;
    final borderColor = !isEnabled
        ? AppColors.borderDark
        : widget.isPrimary || _isHovered
        ? widget.accent.withAlpha((_isHovered ? 0.85 * 255 : 0.5 * 255).round())
        : AppColors.borderDark;

    final row = AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isEnabled && _isHovered
            ? widget.accent.withAlpha((0.08 * 255).round())
            : AppColors.surfaceDark,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isEnabled
                  ? widget.accent.withAlpha((0.14 * 255).round())
                  : AppColors.trackDark,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              widget.icon,
              size: 19,
              color: isEnabled ? widget.accent : AppColors.textSecondaryDark,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.kind.toUpperCase(),
                  style: AppTheme.caption.copyWith(
                    color: isEnabled
                        ? widget.accent
                        : AppColors.textSecondaryDark,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  widget.title,
                  style: AppTheme.bodyLg.copyWith(
                    color: isEnabled
                        ? AppColors.textPrimaryDark
                        : AppColors.textSecondaryDark,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.subtitle,
                  style: AppTheme.bodyMd.copyWith(
                    color: AppColors.textSecondaryDark,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Icon(
            isEnabled
                ? Icons.chevron_right_rounded
                : Icons.lock_outline_rounded,
            size: isEnabled ? 22 : 16,
            color: isEnabled ? widget.accent : AppColors.borderDark,
          ),
        ],
      ),
    );

    if (!isEnabled) {
      return Tooltip(
        message: widget.disabledReason,
        child: Opacity(opacity: 0.7, child: row),
      );
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: row,
      ),
    );
  }
}

/// Side rail: the single call to action, plus the honest caveat about where
/// the question count comes from.
class _PracticeRail extends StatelessWidget {
  const _PracticeRail({
    required this.topic,
    required this.accent,
    required this.canPractise,
    required this.onPractise,
  });

  final CourseTopic topic;
  final Color accent;
  final bool canPractise;
  final VoidCallback onPractise;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: accent.withAlpha((0.08 * 255).round()),
        border: Border.all(color: accent.withAlpha((0.3 * 255).round())),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            canPractise ? 'Ready to practise?' : 'Nothing to practise yet',
            style: AppTheme.heading3.copyWith(
              color: AppColors.textPrimaryDark,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            canPractise
                // Drill caps a session at 20 questions and rotates which
                // ones you get — see `drillQuestionsProvider`. Saying "all
                // 103 questions" would be wrong for the larger topics.
                ? 'Up to 20 questions a session, drawn from past WAEC '
                      'papers, with feedback after every answer.'
                : 'Questions for this topic have not been added to Paragon '
                      'yet. Check back as content lands.',
            style: AppTheme.bodyMd.copyWith(color: AppColors.textSecondaryDark),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 44,
            child: ElevatedButton(
              onPressed: canPractise ? onPractise : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                disabledBackgroundColor: AppColors.trackDark,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                canPractise ? 'Start practising' : 'Coming soon',
                style: AppTheme.btnLabel.copyWith(
                  color: canPractise
                      ? Colors.white
                      : AppColors.textSecondaryDark,
                ),
              ),
            ),
          ),
        ],
      ),
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

class _NotFound extends StatelessWidget {
  const _NotFound({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 120),
      child: Center(
        child: Column(
          children: [
            const Icon(
              Icons.search_off_rounded,
              size: 32,
              color: AppColors.textSecondaryDark,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTheme.bodyLg.copyWith(
                color: AppColors.textSecondaryDark,
              ),
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
      ),
    );
  }
}
