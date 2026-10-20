import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/plan/planner.dart';
import '../../../core/plan/study_plan.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/repositories/course_repository.dart';
import '../../../core/repositories/progress_repository.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/nav/back_navigation.dart';
import '../../../core/widgets/page_layout.dart';
import '../../../core/widgets/ui/ui.dart';
import '../../plan/plan_widgets.dart' show planTopicsFor;
import 'planner_store.dart';

/// `/review/planner`: the student's week, a day at a time, with what they
/// mean to study and a tick for each thing done (owner's request,
/// 2026-10-19). Kept on the device; reads nothing of its own except, on
/// "Plan my week", the course outlines (cached, shared with the course
/// pages and `/plan`).
class PlannerScreen extends ConsumerStatefulWidget {
  const PlannerScreen({super.key});

  @override
  ConsumerState<PlannerScreen> createState() => _PlannerScreenState();
}

class _PlannerScreenState extends ConsumerState<PlannerScreen> {
  /// Weeks from this one: 0 is this week, -1 last week.
  int _weekOffset = 0;
  bool _planning = false;

  DateTime get _today {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  List<DateTime> get _week {
    final t = _today;
    return weekOf(DateTime(t.year, t.month, t.day + 7 * _weekOffset));
  }

  PlannerNotifier get _planner => ref.read(plannerProvider.notifier);

  Future<void> _addTo(String day) async {
    final task = await showDialog<PlannerTask>(
      context: context,
      builder: (_) => _AddTaskDialog(
        day: day,
        subjects: _subjectNames(),
        newId: _planner.newId,
      ),
    );
    if (task != null) await _planner.add(task);
  }

  /// The names of the student's subjects, from the catalog the app has
  /// already loaded.
  List<String> _subjectNames() {
    final slugs = ref.read(selectedSubjectSlugsProvider);
    final catalog = ref.read(courseCatalogProvider).asData?.value ?? const [];
    return [
      for (final c in catalog)
        if (slugs.contains(c.slug) && c.isLive) c.name,
    ];
  }

  /// Fills the rest of the week from each subject's shortest path: the
  /// topics worth the most marks that the student has not mastered.
  Future<void> _planWeek() async {
    final messenger = ScaffoldMessenger.of(context);
    final slugs = ref.read(selectedSubjectSlugsProvider).toList()..sort();
    if (slugs.isEmpty) {
      messenger.showSnackBar(
        SnackBar(
          content: const Text('Choose your subjects first.'),
          action: SnackBarAction(
            label: 'Choose',
            onPressed: () => context.push('/settings/subjects'),
          ),
        ),
      );
      return;
    }
    setState(() => _planning = true);
    try {
      final progress =
          ref.read(userProgressProvider).asData?.value ?? UserProgress.empty;
      final perSubject = <List<PlanIdea>>[];
      for (final slug in slugs) {
        final Course course;
        try {
          course = await ref.read(courseProvider(slug).future);
        } catch (_) {
          continue;
        }
        if (!course.isLive) continue;
        final next = shortestPath(planTopicsFor(course, progress), take: 4);
        perSubject.add([
          for (final t in next)
            (
              title: t.name,
              subject: course.name,
              path: course.pathForTopicId(t.id),
            ),
        ]);
      }
      // One subject after another, so a week mixes them.
      final ideas = <PlanIdea>[
        for (var i = 0; i < 4; i++)
          for (final list in perSubject)
            if (i < list.length) list[i],
      ];
      final today = dayKey(_today);
      final days = [
        for (final d in _week)
          if (dayKey(d).compareTo(today) >= 0) dayKey(d),
      ];
      final tasks = spreadOverWeek(
        planner: ref.read(plannerProvider),
        ideas: ideas,
        days: days,
        newId: _planner.newId,
      );
      await _planner.addAll(tasks);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            tasks.isEmpty
                ? 'Your week is already full. Nice.'
                : 'Added ${tasks.length} '
                      '${tasks.length == 1 ? 'topic' : 'topics'}, '
                      'the ones worth the most marks first.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _planning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final planner = ref.watch(plannerProvider);
    final palette = context.palette;
    final week = _week;
    final keys = [for (final d in week) dayKey(d)];
    final today = dayKey(_today);
    final tally = planner.tally(keys);
    final behind = _weekOffset == 0 ? planner.leftBehind(today) : 0;
    final canPlan = keys.last.compareTo(today) >= 0;

    return Scaffold(
      backgroundColor: palette.background,
      appBar: const ParagonAppBar(title: Text('Planner')),
      body: PageBody(
        maxWidth: kContentMaxWidth,
        children: [
          PageIntro(
            title: 'Your week',
            subtitle: _mood(tally.done, tally.total),
          ),
          SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    IconButton(
                      tooltip: 'Previous week',
                      onPressed: () => setState(() => _weekOffset--),
                      icon: const Icon(Icons.chevron_left_rounded),
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            switch (_weekOffset) {
                              0 => 'This week',
                              1 => 'Next week',
                              -1 => 'Last week',
                              _ => 'Week of ${_short(week.first)}',
                            },
                            style: AppTheme.heading3.copyWith(
                              color: palette.textPrimary,
                            ),
                          ),
                          Text(
                            '${_short(week.first)} to ${_short(week.last)}',
                            style: AppTheme.caption.copyWith(
                              color: palette.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Next week',
                      onPressed: _weekOffset >= 8
                          ? null
                          : () => setState(() => _weekOffset++),
                      icon: const Icon(Icons.chevron_right_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Semantics(
                  label: '${tally.done} of ${tally.total} done this week',
                  excludeSemantics: true,
                  child: Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: tally.total == 0
                                ? 0
                                : tally.done / tally.total,
                            minHeight: 8,
                            backgroundColor: palette.track,
                            color: tally.total > 0 && tally.done == tally.total
                                ? AppColors.correct
                                : AppColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '${tally.done} of ${tally.total} done',
                        style: AppTheme.label.copyWith(
                          color: palette.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (canPlan) ...[
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    children: [
                      FilledButton.icon(
                        key: const ValueKey('planner.planWeek'),
                        onPressed: _planning ? null : _planWeek,
                        icon: _planning
                            ? const SizedBox.square(
                                dimension: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.auto_awesome_rounded, size: 18),
                        label: const Text('Plan my week for me'),
                      ),
                      if (_weekOffset != 0)
                        TextButton(
                          onPressed: () => setState(() => _weekOffset = 0),
                          child: const Text('Back to this week'),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (behind > 0) ...[
            const SizedBox(height: 12),
            SurfaceCard(
              key: const ValueKey('planner.behind'),
              borderColor: AppColors.warning.withAlpha(120),
              child: Row(
                children: [
                  const Icon(Icons.history_rounded, color: AppColors.warning),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '$behind ${behind == 1 ? 'thing' : 'things'} from '
                      'earlier days still to do. No stress: bring '
                      '${behind == 1 ? 'it' : 'them'} to today?',
                      style: AppTheme.bodyMd.copyWith(
                        color: palette.textPrimary,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => _planner.carryOver(today),
                    child: const Text('Move to today'),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: kSectionGap),
          LayoutBuilder(
            builder: (context, box) {
              final twoUp = box.maxWidth >= 720;
              final width = twoUp ? (box.maxWidth - 14) / 2 : box.maxWidth;
              return Wrap(
                spacing: 14,
                runSpacing: 14,
                children: [
                  for (final d in week)
                    SizedBox(
                      width: width,
                      child: _DayCard(
                        date: d,
                        isToday: dayKey(d) == today,
                        isPast: dayKey(d).compareTo(today) < 0,
                        tasks: planner.on(dayKey(d)),
                        canAdd: planner.canAddOn(dayKey(d)),
                        onAdd: () => _addTo(dayKey(d)),
                        tomorrow: dayKey(DateTime(d.year, d.month, d.day + 1)),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          Text(
            'Your planner is kept on this device, for this account.',
            textAlign: TextAlign.center,
            style: AppTheme.caption.copyWith(color: palette.textSecondary),
          ),
        ],
      ),
    );
  }

  /// A line about the week, in Paragon's voice.
  static String _mood(int done, int total) {
    if (total == 0) {
      return 'Nothing planned yet. Pick a day and add a topic, or let '
          'Paragon fill the week with the topics worth the most marks.';
    }
    if (done == total) return 'All $total done. Look at you go.';
    if (done == 0) return '$total planned. The first tick is the hardest.';
    if (done * 2 >= total) {
      return 'Past halfway: $done of $total. Keep rolling.';
    }
    return '$done of $total done. One topic at a time.';
  }
}

const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _months = [
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

String _short(DateTime d) => '${d.day} ${_months[d.month - 1]}';

class _DayCard extends ConsumerWidget {
  const _DayCard({
    required this.date,
    required this.isToday,
    required this.isPast,
    required this.tasks,
    required this.canAdd,
    required this.onAdd,
    required this.tomorrow,
  });

  final DateTime date;
  final bool isToday;
  final bool isPast;
  final List<PlannerTask> tasks;
  final bool canAdd;
  final VoidCallback onAdd;
  final String tomorrow;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final allDone = tasks.isNotEmpty && tasks.every((t) => t.done);
    return SurfaceCard(
      key: ValueKey('planner.day.${dayKey(date)}'),
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
      borderColor: isToday ? AppColors.primary.withAlpha(140) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                '${_weekdays[date.weekday - 1]} ${_short(date)}',
                style: AppTheme.bodyLg.copyWith(
                  color: isPast ? palette.textSecondary : palette.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (isToday) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha(36),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'Today',
                    style: AppTheme.caption.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
              if (allDone) ...[
                const SizedBox(width: 8),
                const Icon(
                  Icons.celebration_rounded,
                  size: 18,
                  color: AppColors.correct,
                  semanticLabel: 'All done',
                ),
              ],
              const Spacer(),
              IconButton(
                tooltip: 'Add to ${_weekdays[date.weekday - 1]}',
                onPressed: canAdd ? onAdd : null,
                icon: const Icon(Icons.add_rounded),
              ),
            ],
          ),
          if (tasks.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8, right: 8),
              child: Text(
                isPast ? 'Nothing planned.' : _restLine(date),
                style: AppTheme.label.copyWith(color: palette.textSecondary),
              ),
            ),
          for (final t in tasks) _TaskRow(task: t, tomorrow: tomorrow),
        ],
      ),
    );
  }

  /// An empty day, said kindly; one line per weekday so it varies.
  static String _restLine(DateTime d) => const [
    'Free. Add a topic, or keep it for rest.',
    'Open day. Twenty minutes counts.',
    'Nothing yet. Midweek is a good day for past questions.',
    'Clear. A short drill keeps things warm.',
    'Free. Friday revision is underrated.',
    'Weekend: a longer session, or a well-earned rest.',
    'Sunday: look back at the week, or plan the next.',
  ][d.weekday - 1];
}

class _TaskRow extends ConsumerWidget {
  const _TaskRow({required this.task, required this.tomorrow});
  final PlannerTask task;
  final String tomorrow;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final planner = ref.read(plannerProvider.notifier);
    final accent = task.subject.isEmpty
        ? AppColors.neutral
        : AppColors.forSubject(task.subject);
    final detail = [
      if (task.subject.isNotEmpty) task.subject,
      if (task.minutes > 0) '${task.minutes} min',
    ].join(' · ');

    return Row(
      children: [
        Semantics(
          checked: task.done,
          label: task.title,
          excludeSemantics: true,
          onTap: () => planner.toggle(task.id),
          child: Checkbox(
            key: ValueKey('planner.task.${task.id}'),
            value: task.done,
            activeColor: AppColors.correct,
            onChanged: (_) => planner.toggle(task.id),
          ),
        ),
        Container(
          width: 3,
          height: 28,
          decoration: BoxDecoration(
            color: accent,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: InkWell(
            onTap: task.path.isEmpty ? null : () => context.push(task.path),
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    style: AppTheme.bodyMd.copyWith(
                      color: task.done
                          ? palette.textSecondary
                          : palette.textPrimary,
                      decoration: task.done
                          ? TextDecoration.lineThrough
                          : TextDecoration.none,
                    ),
                  ),
                  if (detail.isNotEmpty)
                    Text(
                      detail,
                      style: AppTheme.caption.copyWith(
                        color: palette.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        PopupMenuButton<String>(
          tooltip: 'More for ${task.title}',
          icon: Icon(Icons.more_vert_rounded, color: palette.textSecondary),
          onSelected: (v) => switch (v) {
            'open' => context.push(task.path),
            'tomorrow' => planner.move(task.id, tomorrow),
            _ => planner.remove(task.id),
          },
          itemBuilder: (_) => [
            if (task.path.isNotEmpty)
              const PopupMenuItem(value: 'open', child: Text('Open the topic')),
            if (!task.done)
              const PopupMenuItem(
                value: 'tomorrow',
                child: Text('Move to the next day'),
              ),
            const PopupMenuItem(value: 'delete', child: Text('Remove')),
          ],
        ),
      ],
    );
  }
}

/// What to add to a day: what, which subject, and for how long.
class _AddTaskDialog extends StatefulWidget {
  const _AddTaskDialog({
    required this.day,
    required this.subjects,
    required this.newId,
  });

  final String day;
  final List<String> subjects;
  final String Function() newId;

  @override
  State<_AddTaskDialog> createState() => _AddTaskDialogState();
}

class _AddTaskDialogState extends State<_AddTaskDialog> {
  final _title = TextEditingController();
  String _subject = '';
  int _minutes = 30;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  void _done() {
    final title = _title.text.trim();
    if (title.isEmpty) return;
    Navigator.of(context).pop(
      PlannerTask(
        id: widget.newId(),
        day: widget.day,
        title: title.length > 120 ? title.substring(0, 120) : title,
        subject: _subject,
        minutes: _minutes,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = parseDayKey(widget.day)!;
    return AlertDialog(
      title: Text('Add to ${_weekdays[d.weekday - 1]} ${_short(d)}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              key: const ValueKey('planner.addTitle'),
              controller: _title,
              autofocus: true,
              maxLength: 120,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: 'What will you study?',
                hintText: 'e.g. Indices, or 20 past questions',
              ),
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _done(),
            ),
            if (widget.subjects.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final s in ['', ...widget.subjects])
                    ChoiceChip(
                      label: Text(s.isEmpty ? 'Any' : s),
                      selected: _subject == s,
                      onSelected: (_) => setState(() => _subject = s),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final m in const [15, 30, 45, 60, 0])
                  ChoiceChip(
                    label: Text(m == 0 ? 'No time' : '$m min'),
                    selected: _minutes == m,
                    onSelected: (_) => setState(() => _minutes = m),
                  ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _title.text.trim().isEmpty ? null : _done,
          child: const Text('Add'),
        ),
      ],
    );
  }
}
