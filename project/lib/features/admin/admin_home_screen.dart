import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/staff_role.dart';
import '../../core/lessons/lesson_doc.dart';
import '../../core/models/learn_resource.dart';
import '../../core/models/topic.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/repositories/admin_flag_repository.dart';
import '../../core/repositories/admin_resource_repository.dart';
import '../../core/repositories/learning_repository.dart';
import '../../core/repositories/subject_index_repository.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/ui/ui.dart';
import 'admin_paths.dart';
import 'admin_resource_editor_screen.dart';
import 'studio/launch_panels.dart';
import 'studio/question_browser.dart';
import 'studio/question_widgets.dart';
import 'studio/review_panels.dart';
import 'studio/staff_profile.dart';
import 'studio/topic_planner_screen.dart';
import 'studio/question_bank.dart';
import '../../core/theme/app_palette.dart';
import '../../core/widgets/nav/back_navigation.dart';

/// The studio's sections, in the rail's order. [name] is the `?s=` value
/// (`adminSectionPath`), so every section has its own address.
enum StudioSection {
  overview('Overview', Icons.space_dashboard_outlined, 'What needs you now.'),
  lessons(
    'Lessons',
    Icons.menu_book_outlined,
    'Items waiting for review, items sent back, and every topic of a subject.',
  ),
  questions(
    'Questions',
    Icons.quiz_outlined,
    'Find any question by its words, its paper or its topic, and fix it.',
  ),
  reports(
    'Reports',
    Icons.flag_outlined,
    'What students reported on questions and lessons, and their feedback.',
  ),
  quality(
    'Quality',
    Icons.fact_check_outlined,
    'What the content rules found in the past-question bank. Open a rule '
        'to see its questions.',
  ),
  site(
    'Site',
    Icons.insights_outlined,
    'The day\'s Firestore quota, waiting lists and traction.',
  ),
  bank(
    'Question bank',
    Icons.inventory_2_outlined,
    'Vet questions before students see them, and write new ones. Only '
        'vetted questions are used anywhere on Paragon.',
  );

  const StudioSection(this.label, this.icon, this.summary);
  final String label;
  final IconData icon;
  final String summary;

  /// Writers draft lessons and browse questions; the rest is review work.
  /// The question bank is the founder's alone.
  bool visibleTo(StaffRole role, {bool founder = false}) => switch (this) {
    overview || lessons || questions => true,
    bank => founder,
    _ => role.canReview,
  };

  static StudioSection parse(String? name) => StudioSection.values.firstWhere(
    (s) => s.name == name,
    orElse: () => StudioSection.overview,
  );
}

/// `/admin`: the content studio.
///
/// A rail of sections on a wide screen (chips across the top on a phone),
/// each with its own address (`/admin?s=questions`). Overview counts what
/// needs doing and links straight to it.
///
/// Reachable by any content-team role; the router gates it, and the rules
/// check every read and write again. See docs/CONTENT_ROLES.md.
class AdminHomeScreen extends ConsumerWidget {
  const AdminHomeScreen({super.key, this.section});

  /// The `?s=` value; unknown or missing is the overview.
  final String? section;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(staffRoleProvider);
    final founder = ref.watch(staffAccessProvider).isFounder;
    // Publishes this member's name and avatar for the rest of the team.
    ref.watch(staffProfileSyncProvider);
    final sections = [
      for (final s in StudioSection.values)
        if (s.visibleTo(role, founder: founder)) s,
    ];
    var current = StudioSection.parse(section);
    if (!sections.contains(current)) current = StudioSection.overview;
    void open(StudioSection s) => context.go(adminSectionPath(s.name));

    final body = _SectionBody(section: current, role: role, open: open);

    return Scaffold(
      backgroundColor: context.palette.background,
      appBar: ParagonAppBar(
        title: const Text('Content studio'),
        actions: [
          if (role == StaffRole.admin)
            TextButton.icon(
              onPressed: () => context.push('/admin/team'),
              icon: const Icon(Icons.group_outlined, size: 18),
              label: const Text('Team'),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, box) {
            if (box.maxWidth >= 900) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Rail(sections: sections, current: current, onOpen: open),
                  VerticalDivider(width: 1, color: context.palette.border),
                  Expanded(child: body),
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ChipBar(sections: sections, current: current, onOpen: open),
                Divider(height: 1, color: context.palette.border),
                Expanded(child: body),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// How many things each section is waiting on, for the rail's badges and
/// the overview's cards. Every count comes from a list the studio loads
/// anyway, so it costs no extra reads.
class _Counts {
  _Counts(WidgetRef ref)
    : inReview = ref
          .watch(adminStatusQueueProvider(ResourceStatus.inReview))
          .asData
          ?.value
          .length,
      sentBack = ref
          .watch(adminStatusQueueProvider(ResourceStatus.changesRequested))
          .asData
          ?.value
          .length,
      questionReports = ref
          .watch(adminFlagQueueProvider)
          .asData
          ?.value
          .where((r) => r.isOpen)
          .length,
      lessonReports = ref
          .watch(adminLessonReportsProvider)
          .asData
          ?.value
          .length,
      audit = ref.watch(contentAuditProvider).asData?.value;

  final int? inReview;
  final int? sentBack;
  final int? questionReports;
  final int? lessonReports;
  final ContentAudit? audit;

  int? _rule(bool Function(AuditRule) test) =>
      audit?.rules.where(test).fold<int>(0, (n, r) => n + r.count);

  int? get suspects => _rule((r) => r.level == 'S');
  int? get meaning => _rule((r) => r.level == 'A');
  int? get missingExplanations => _rule((r) => r.rule == 'missing-explanation');

  int? badge(StudioSection s, StaffRole role) => switch (s) {
    StudioSection.lessons => role.canReview ? inReview : sentBack,
    StudioSection.reports =>
      (questionReports == null && lessonReports == null)
          ? null
          : (questionReports ?? 0) + (lessonReports ?? 0),
    StudioSection.quality => suspects,
    _ => null,
  };
}

class _Rail extends ConsumerWidget {
  const _Rail({
    required this.sections,
    required this.current,
    required this.onOpen,
  });

  final List<StudioSection> sections;
  final StudioSection current;
  final void Function(StudioSection) onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(staffRoleProvider);
    final counts = _Counts(ref);
    final palette = context.palette;
    return SizedBox(
      width: 236,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 20, 12, 20),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
            child: Text(
              switch (role) {
                StaffRole.admin => 'Admin',
                StaffRole.reviewer => 'Reviewer',
                _ => 'Writer',
              },
              style: AppTheme.caption.copyWith(
                color: palette.textSecondary,
                letterSpacing: 0.9,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          for (final s in sections)
            _RailItem(
              section: s,
              selected: s == current,
              badge: counts.badge(s, role),
              onTap: () => onOpen(s),
            ),
        ],
      ),
    );
  }
}

class _RailItem extends StatelessWidget {
  const _RailItem({
    required this.section,
    required this.selected,
    required this.badge,
    required this.onTap,
  });

  final StudioSection section;
  final bool selected;
  final int? badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final fg = selected ? AppColors.primary : palette.textPrimary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Semantics(
        selected: selected,
        button: true,
        child: Material(
          color: selected
              ? AppColors.primary.withAlpha(28)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              child: Row(
                children: [
                  Icon(section.icon, size: 20, color: fg),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      section.label,
                      style: AppTheme.bodyMd.copyWith(
                        color: fg,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                  if (badge != null && badge! > 0) _Badge(count: badge!),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(
      color: AppColors.warning.withAlpha(40),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      count > 99 ? '99+' : '$count',
      style: AppTheme.caption.copyWith(
        color: AppColors.warning,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _ChipBar extends ConsumerWidget {
  const _ChipBar({
    required this.sections,
    required this.current,
    required this.onOpen,
  });

  final List<StudioSection> sections;
  final StudioSection current;
  final void Function(StudioSection) onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(staffRoleProvider);
    final counts = _Counts(ref);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          for (final s in sections)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                avatar: Icon(s.icon, size: 18),
                label: Text(switch (counts.badge(s, role)) {
                  final n? when n > 0 => '${s.label} · $n',
                  _ => s.label,
                }),
                selected: s == current,
                onSelected: (_) => onOpen(s),
              ),
            ),
        ],
      ),
    );
  }
}

class _SectionBody extends StatelessWidget {
  const _SectionBody({
    required this.section,
    required this.role,
    required this.open,
  });

  final StudioSection section;
  final StaffRole role;
  final void Function(StudioSection) open;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final content = switch (section) {
      StudioSection.overview => _Overview(role: role, open: open),
      StudioSection.lessons => _LessonsSection(role: role),
      StudioSection.questions => const QuestionBrowser(),
      StudioSection.reports => const Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _FlagQueue(),
          SizedBox(height: 32),
          _LessonReports(),
          SizedBox(height: 32),
          FeedbackPanel(),
        ],
      ),
      StudioSection.quality => const ContentQualityPanel(),
      StudioSection.bank => const QuestionBankPanel(),
      StudioSection.site => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const UsagePanel(),
          const SizedBox(height: 32),
          const WaitlistPanel(),
          if (role == StaffRole.admin) ...[
            const SizedBox(height: 32),
            const TractionPanel(),
          ],
        ],
      ),
    };
    return SingleChildScrollView(
      // A new section starts at the top, not where the last one was left.
      key: PageStorageKey(section.name),
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 64),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1040),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                section.label,
                style: AppTheme.heading2.copyWith(color: palette.textStrong),
              ),
              const SizedBox(height: 4),
              Text(
                section.summary,
                style: AppTheme.bodyMd.copyWith(color: palette.textSecondary),
              ),
              const SizedBox(height: 24),
              content,
            ],
          ),
        ),
      ),
    );
  }
}

/// What needs doing, as cards that go straight to it.
class _Overview extends ConsumerWidget {
  const _Overview({required this.role, required this.open});

  final StaffRole role;
  final void Function(StudioSection) open;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = _Counts(ref);
    final palette = context.palette;
    final cards = <Widget>[
      if (role.canReview)
        _CountCard(
          icon: Icons.rate_review_outlined,
          colour: AppColors.accentBlue,
          count: c.inReview,
          title: 'Waiting for your review',
          action: 'Review lessons',
          onTap: () => open(StudioSection.lessons),
        ),
      _CountCard(
        icon: Icons.undo_rounded,
        colour: AppColors.warning,
        count: c.sentBack,
        title: 'Sent back for changes',
        action: 'See what to change',
        onTap: () => open(StudioSection.lessons),
      ),
      if (role.canReview) ...[
        _CountCard(
          icon: Icons.flag_outlined,
          colour: AppColors.warning,
          count: c.questionReports,
          title: 'Questions students reported',
          action: 'Work through them',
          onTap: () => open(StudioSection.reports),
        ),
        _CountCard(
          icon: Icons.priority_high_rounded,
          colour: AppColors.wrong,
          count: c.suspects,
          title: 'Answers that may be wrong',
          action: 'Check against the paper',
          onTap: () => open(StudioSection.quality),
        ),
        _CountCard(
          icon: Icons.rule_rounded,
          colour: AppColors.wrong,
          count: c.meaning,
          title: 'Questions that read wrong',
          action: 'Fix them',
          onTap: () => open(StudioSection.quality),
        ),
        _CountCard(
          icon: Icons.notes_rounded,
          colour: palette.textSecondary,
          count: c.missingExplanations,
          title: 'Past questions with no worked answer',
          action: 'Write some',
          onTap: () => open(StudioSection.quality),
        ),
      ],
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SurfaceCard(
          onTap: () => open(StudioSection.questions),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Row(
            children: [
              Icon(Icons.search_rounded, color: palette.textSecondary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Find a question by its words, paper or topic',
                  style: AppTheme.bodyMd.copyWith(color: palette.textSecondary),
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: palette.textSecondary),
            ],
          ),
        ),
        const SizedBox(height: 20),
        LayoutBuilder(
          builder: (context, box) {
            final columns = box.maxWidth >= 720
                ? 3
                : (box.maxWidth >= 460 ? 2 : 1);
            final width = (box.maxWidth - 14 * (columns - 1)) / columns;
            return Wrap(
              spacing: 14,
              runSpacing: 14,
              children: [
                for (final card in cards) SizedBox(width: width, child: card),
              ],
            );
          },
        ),
        const SizedBox(height: 28),
        Text(
          role.canReview
              ? 'You review and publish. Nothing reaches students until it is '
                    'published, and every question edit is kept in its history.'
              : 'Write lessons and submit them for review; a reviewer publishes '
                    'them. Questions are read-only for writers.',
          style: AppTheme.caption.copyWith(color: palette.textSecondary),
        ),
      ],
    );
  }
}

class _CountCard extends StatelessWidget {
  const _CountCard({
    required this.icon,
    required this.colour,
    required this.count,
    required this.title,
    required this.action,
    required this.onTap,
  });

  final IconData icon;
  final Color colour;
  final int? count;
  final String title;
  final String action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final done = count == 0;
    return SurfaceCard(
      onTap: onTap,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconTile(
                icon: icon,
                color: done ? AppColors.correct : colour,
                size: 36,
              ),
              const Spacer(),
              if (count == null)
                const SkeletonBox(width: 40, height: 28)
              else
                Text(
                  '$count',
                  style: AppTheme.displayLg.copyWith(
                    fontSize: 30,
                    color: done ? AppColors.correct : palette.textStrong,
                    height: 1,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: AppTheme.bodyMd.copyWith(
              color: palette.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            done ? 'All clear' : action,
            style: AppTheme.caption.copyWith(
              color: done ? AppColors.correct : AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Review queues, then the course map of one subject.
class _LessonsSection extends ConsumerStatefulWidget {
  const _LessonsSection({required this.role});
  final StaffRole role;

  @override
  ConsumerState<_LessonsSection> createState() => _LessonsSectionState();
}

class _LessonsSectionState extends ConsumerState<_LessonsSection> {
  String? _subjectId;

  @override
  Widget build(BuildContext context) {
    final access = ref.watch(staffAccessProvider);
    // The subjects this account works on come first, and the map opens
    // on the first of them; the rest stay browsable, read-only.
    final subjects = [...?ref.watch(subjectsProvider).asData?.value]
      ..sort(
        (a, b) => (access.covers(a.id) ? 0 : 1).compareTo(
          access.covers(b.id) ? 0 : 1,
        ),
      );
    final subjectId = _subjectId ?? subjects.firstOrNull?.id;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.role.canReview) ...[
          const _StatusQueue(
            status: ResourceStatus.inReview,
            title: 'Waiting for your review',
            empty: 'Nothing waiting for review.',
          ),
          const SizedBox(height: 28),
        ],
        const _StatusQueue(
          status: ResourceStatus.changesRequested,
          title: 'Sent back for changes',
          empty: 'Nothing sent back.',
        ),
        const SizedBox(height: 32),
        SectionHeader(
          'Course map',
          subtitle:
              'Every topic and the state of its lesson. Open one to plan it.',
          action: subjects.isEmpty
              ? null
              : DropdownButton<String>(
                  value: subjectId,
                  dropdownColor: context.palette.surface,
                  underline: const SizedBox.shrink(),
                  items: [
                    for (final s in subjects)
                      DropdownMenuItem(
                        value: s.id,
                        child: Text(
                          access.covers(s.id)
                              ? s.name
                              : '${s.name} (read-only)',
                        ),
                      ),
                  ],
                  onChanged: (id) => setState(() => _subjectId = id),
                ),
        ),
        if (subjectId != null) _CourseMap(subjectId: subjectId),
      ],
    );
  }
}

/// Items in one workflow state across every topic, linking to the editor.
class _StatusQueue extends ConsumerWidget {
  const _StatusQueue({
    required this.status,
    required this.title,
    required this.empty,
  });

  final ResourceStatus status;
  final String title;
  final String empty;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(adminStatusQueueProvider(status));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: AppTheme.heading3.copyWith(color: context.palette.textPrimary),
        ),
        const SizedBox(height: 12),
        items.when(
          loading: () => const LinearProgressIndicator(minHeight: 2),
          error: (e, _) => Text(
            "Couldn't load this list.\n$e",
            style: AppTheme.bodyMd.copyWith(color: AppColors.wrong),
          ),
          data: (list) => list.isEmpty
              ? Text(
                  empty,
                  style: AppTheme.bodyMd.copyWith(
                    color: context.palette.textSecondary,
                  ),
                )
              : ResourceList(resources: list, showAuthor: true),
        ),
      ],
    );
  }
}

/// How far along a topic's lesson is, from its items.
enum TopicState {
  empty('Empty'),
  draft('Draft'),
  changesRequested('Changes requested'),
  inReview('In review'),
  published('Published');

  const TopicState(this.label);
  final String label;

  Color get colour => switch (this) {
    TopicState.empty => AppColors.neutral,
    TopicState.draft => AppColors.warning,
    TopicState.changesRequested => AppColors.wrong,
    TopicState.inReview => AppColors.accentBlue,
    TopicState.published => AppColors.correct,
  };

  /// The most pressing state among a topic's items: anything needing
  /// action outranks "published", so a live lesson with a revision in
  /// review shows as in review.
  static TopicState of(List<LearnResource> items) {
    if (items.isEmpty) return TopicState.empty;
    final statuses = items.map((r) => r.status).toSet();
    if (statuses.contains(ResourceStatus.changesRequested)) {
      return TopicState.changesRequested;
    }
    if (statuses.contains(ResourceStatus.inReview)) return TopicState.inReview;
    if (statuses.contains(ResourceStatus.draft)) {
      return statuses.contains(ResourceStatus.published)
          ? TopicState.published
          : TopicState.draft;
    }
    return TopicState.published;
  }
}

/// Every unit and topic of a subject, each topic a chip showing its
/// lesson's state, item count and outstanding to-dos.
class _CourseMap extends ConsumerWidget {
  const _CourseMap({required this.subjectId});

  final String subjectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final units = ref.watch(unitsProvider(subjectId)).asData?.value;
    final resources = ref.watch(adminSubjectResourcesProvider(subjectId));
    final byTopic = <String, List<LearnResource>>{};
    for (final r in resources.asData?.value ?? const <LearnResource>[]) {
      byTopic.putIfAbsent(r.topicId, () => []).add(r);
    }
    final role = ref.watch(staffAccessProvider).roleIn(subjectId);

    if (units == null || resources.isLoading) {
      return const LinearProgressIndicator(minHeight: 2);
    }
    if (resources.hasError) {
      return Text(
        "Couldn't load this subject's lessons.\n${resources.error}",
        style: AppTheme.bodyMd.copyWith(color: AppColors.wrong),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _MapSummary(
          subjectId: subjectId,
          byTopic: byTopic,
          canRebuild: role.canReview,
        ),
        for (final unit in units) ...[
          const SizedBox(height: 20),
          Text(
            unit.name.toUpperCase(),
            style: AppTheme.label.copyWith(
              color: context.palette.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          _UnitTopics(unitId: unit.id, byTopic: byTopic),
        ],
      ],
    );
  }
}

class _MapSummary extends ConsumerStatefulWidget {
  const _MapSummary({
    required this.subjectId,
    required this.byTopic,
    required this.canRebuild,
  });

  final String subjectId;
  final Map<String, List<LearnResource>> byTopic;
  final bool canRebuild;

  @override
  ConsumerState<_MapSummary> createState() => _MapSummaryState();
}

class _MapSummaryState extends ConsumerState<_MapSummary> {
  bool _rebuilding = false;

  Future<void> _rebuild({required bool all}) async {
    setState(() => _rebuilding = true);
    try {
      final access = ref.read(staffAccessProvider);
      final subjectIds = all
          ? [
              for (final s in await ref.read(subjectsProvider.future))
                if (access.roleIn(s.id).canReview) s.id,
            ]
          : [widget.subjectId];
      for (final id in subjectIds) {
        await _rebuildSubject(id);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              all
                  ? 'Rebuilt ${subjectIds.length} subjects: search, glossary '
                        'and cards.'
                  : 'Search, glossary, formulas and cards rebuilt.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Couldn't rebuild: $e")));
      }
    } finally {
      if (mounted) setState(() => _rebuilding = false);
    }
  }

  /// Every topic of the subject is named, so each gets an index entry and
  /// search can find it even before it has a lesson.
  Future<void> _rebuildSubject(String subjectId) async {
    final units = await ref.read(unitsProvider(subjectId).future);
    final names = <String, String>{};
    for (final u in units) {
      for (final Topic t in await ref.read(topicsProvider(u.id).future)) {
        names[t.id] = t.name;
      }
    }
    await ref
        .read(subjectIndexRepositoryProvider)
        .rebuildSubject(subjectId: subjectId, topicNames: names);
    ref.invalidate(subjectIndexProvider(subjectId));
  }

  @override
  Widget build(BuildContext context) {
    final states = widget.byTopic.values.map(TopicState.of).toList();
    final published = states.where((s) => s == TopicState.published).length;
    final started = widget.byTopic.length;

    return Wrap(
      spacing: 16,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          '$published published · $started with any content',
          style: AppTheme.bodyMd.copyWith(color: context.palette.textPrimary),
        ),
        if (widget.canRebuild) ...[
          TextButton.icon(
            onPressed: _rebuilding ? null : () => _rebuild(all: false),
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: Text(
              _rebuilding ? 'Rebuilding…' : 'Rebuild search, glossary & cards',
            ),
          ),
          // Once after the search index gained topics and lessons, and
          // whenever topics are renamed or added outside the studio.
          TextButton.icon(
            onPressed: _rebuilding ? null : () => _rebuild(all: true),
            icon: const Icon(Icons.sync_rounded, size: 18),
            label: const Text('Rebuild all subjects'),
          ),
        ],
      ],
    );
  }
}

class _UnitTopics extends ConsumerWidget {
  const _UnitTopics({required this.unitId, required this.byTopic});

  final String unitId;
  final Map<String, List<LearnResource>> byTopic;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topics = ref.watch(topicsProvider(unitId)).asData?.value;
    if (topics == null) return const LinearProgressIndicator(minHeight: 2);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final t in topics)
          _TopicChip(topic: t, items: byTopic[t.id] ?? const []),
      ],
    );
  }
}

class _TopicChip extends StatelessWidget {
  const _TopicChip({required this.topic, required this.items});

  final Topic topic;
  final List<LearnResource> items;

  @override
  Widget build(BuildContext context) {
    final state = TopicState.of(items);
    final todos = items
        .where((r) => r.type == LearnResourceType.article)
        .expand((r) => parseLessonDoc(r.body).blocks)
        .whereType<TodoBlock>()
        .length;

    return InkWell(
      onTap: () => context.push(topicPlannerPath(topic.id)),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 210,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: context.palette.surface,
          border: Border.all(color: state.colour.withAlpha(140)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              topic.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.bodyMd.copyWith(
                color: context.palette.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              [
                state.label,
                if (items.isNotEmpty)
                  '${items.length} item${items.length == 1 ? '' : 's'}',
                if (todos > 0) '$todos to-do${todos == 1 ? '' : 's'}',
              ].join(' · '),
              style: AppTheme.caption.copyWith(color: state.colour),
            ),
          ],
        ),
      ),
    );
  }
}

/// Items as rows linking to the editor. Shared with the topic planner.
class ResourceList extends StatelessWidget {
  const ResourceList({
    super.key,
    required this.resources,
    this.showAuthor = false,
  });

  final List<LearnResource> resources;

  /// Leads each row with its author's avatar — for the review queues,
  /// where who wrote it is the first thing a reviewer wants to know.
  final bool showAuthor;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.palette.surface,
        border: Border.all(color: context.palette.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          for (var i = 0; i < resources.length; i++) ...[
            if (i > 0) Divider(height: 1, color: context.palette.border),
            ResourceRow(resource: resources[i], showAuthor: showAuthor),
          ],
        ],
      ),
    );
  }
}

class ResourceRow extends StatelessWidget {
  const ResourceRow({
    super.key,
    required this.resource,
    this.trailing,
    this.showAuthor = false,
  });

  final LearnResource resource;
  final bool showAuthor;

  /// Replaces the status badge (the planner puts a drag handle here).
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final editable = resource.type != LearnResourceType.unknown;
    // A seeded video with no id yet is the usual reason to open one.
    final needsWork = !resource.isAvailable;

    return ListTile(
      enabled: editable,
      onTap: editable
          ? () => context.push(adminResourcePath(resource.topicId, resource.id))
          : null,
      leading: showAuthor && resource.createdBy != null
          ? StaffAvatar(uid: resource.createdBy!)
          : Icon(switch (resource.type) {
              LearnResourceType.video => Icons.play_circle_outline_rounded,
              LearnResourceType.exercise => Icons.edit_note_rounded,
              _ => Icons.article_outlined,
            }, color: context.palette.textSecondary),
      title: Text(
        resource.title.isEmpty ? '(untitled)' : resource.title,
        style: AppTheme.bodyMd.copyWith(color: context.palette.textPrimary),
      ),
      subtitle: Text(
        [
          resource.type.label,
          if (resource.isRevision) 'revision of a published item',
          if (needsWork)
            'not ready: ${resource.type == LearnResourceType.video ? 'no YouTube link' : 'no body'}',
        ].join(' · '),
        style: AppTheme.caption.copyWith(
          color: needsWork ? AppColors.warning : context.palette.textSecondary,
        ),
      ),
      trailing: trailing ?? StatusBadge(status: resource.status),
    );
  }
}

class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.status});

  final ResourceStatus status;

  @override
  Widget build(BuildContext context) {
    final colour = statusColour(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        border: Border.all(color: colour),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status.label,
        style: AppTheme.caption.copyWith(color: colour),
      ),
    );
  }
}

/// Student problem reports, grouped by question, open ones first. Each
/// shows the question itself and opens the workbench, which steps through
/// the rest of the list.
class _FlagQueue extends ConsumerStatefulWidget {
  const _FlagQueue();

  @override
  ConsumerState<_FlagQueue> createState() => _FlagQueueState();
}

class _FlagQueueState extends ConsumerState<_FlagQueue> {
  bool _showResolved = false;

  @override
  Widget build(BuildContext context) {
    final queue = ref.watch(adminFlagQueueProvider);
    final palette = context.palette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          'Question reports',
          subtitle: 'Fix the question, or dismiss the reports if it is right.',
          action: TextButton(
            onPressed: () => setState(() => _showResolved = !_showResolved),
            child: Text(_showResolved ? 'Hide resolved' : 'Show resolved'),
          ),
        ),
        queue.when(
          loading: () => const StudioListSkeleton(),
          error: (e, _) => Text(
            "Couldn't load reports.\n$e",
            style: AppTheme.bodyMd.copyWith(color: AppColors.wrong),
          ),
          data: (rows) {
            final shown = _showResolved
                ? rows
                : rows.where((r) => r.isOpen).toList();
            if (shown.isEmpty) {
              return SurfaceCard(
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_circle_outline_rounded,
                      color: AppColors.correct,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _showResolved ? 'No reports yet.' : 'No open reports.',
                      style: AppTheme.bodyMd.copyWith(
                        color: palette.textPrimary,
                      ),
                    ),
                  ],
                ),
              );
            }
            final ids = [for (final r in shown) r.questionId];
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final row in shown)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: row.question == null
                        ? SurfaceCard(
                            padding: EdgeInsets.zero,
                            child: ListRow(
                              icon: Icons.help_outline_rounded,
                              title: 'A question that no longer exists',
                              subtitle:
                                  '${row.openReports.length} open reports',
                              onTap: () => openQuestion(
                                context,
                                ref,
                                row.questionId,
                                list: ids,
                              ),
                            ),
                          )
                        : _ReportedQuestion(
                            row: row,
                            onTap: () => openQuestion(
                              context,
                              ref,
                              row.questionId,
                              list: ids,
                            ),
                          ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

/// A reported question: why students reported it, above the question.
class _ReportedQuestion extends StatelessWidget {
  const _ReportedQuestion({required this.row, required this.onTap});
  final FlaggedQuestion row;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final reasons = row.openReasonCounts
        .map((e) => '${e.$2} × ${e.$1.label}')
        .join(' · ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (reasons.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 6),
            child: Text(
              reasons,
              style: AppTheme.caption.copyWith(
                color: AppColors.warning,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        QuestionListCard(
          question: row.question!,
          openReports: row.openReports.length,
          onTap: onTap,
        ),
      ],
    );
  }
}

/// Open reports on lesson items. Each opens the item in the editor, and
/// can be closed as fixed or dismissed from here.
class _LessonReports extends ConsumerWidget {
  const _LessonReports();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reports = ref.watch(adminLessonReportsProvider);

    Future<void> resolve(LessonItemReport r, FlagStatus status) async {
      final uid = ref.read(currentUserProvider)?.uid;
      if (uid == null) return;
      await ref
          .read(adminFlagRepositoryProvider)
          .resolveLessonReport(r, status: status, uid: uid);
      ref.invalidate(adminLessonReportsProvider);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(
          'Lesson reports',
          subtitle: 'Open the item to fix it, then close the report.',
        ),
        reports.when(
          loading: () => const LinearProgressIndicator(minHeight: 2),
          error: (e, _) => Text(
            "Couldn't load lesson reports.\n$e",
            style: AppTheme.bodyMd.copyWith(color: AppColors.wrong),
          ),
          data: (list) => list.isEmpty
              ? Text(
                  'No open lesson reports.',
                  style: AppTheme.bodyMd.copyWith(
                    color: context.palette.textSecondary,
                  ),
                )
              : Container(
                  decoration: BoxDecoration(
                    color: context.palette.surface,
                    border: Border.all(color: context.palette.border),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      for (final r in list)
                        ListTile(
                          onTap: () => context.push(
                            adminResourcePath(r.topicId, r.resourceId),
                          ),
                          leading: const Icon(
                            Icons.flag_outlined,
                            color: AppColors.warning,
                          ),
                          title: Text(
                            r.reason.label,
                            style: AppTheme.bodyMd.copyWith(
                              color: context.palette.textPrimary,
                            ),
                          ),
                          subtitle: Text(
                            r.resourceId,
                            style: AppTheme.caption.copyWith(
                              color: context.palette.textSecondary,
                            ),
                          ),
                          trailing: Wrap(
                            children: [
                              TextButton(
                                onPressed: () => resolve(r, FlagStatus.fixed),
                                child: const Text('Fixed'),
                              ),
                              TextButton(
                                onPressed: () =>
                                    resolve(r, FlagStatus.dismissed),
                                child: const Text('Dismiss'),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}
