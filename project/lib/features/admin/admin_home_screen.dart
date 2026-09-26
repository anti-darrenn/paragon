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
import 'admin_flag_screen.dart';
import 'admin_resource_editor_screen.dart';
import 'studio/review_panels.dart';
import 'studio/staff_profile.dart';
import 'studio/topic_planner_screen.dart';
import '../../core/theme/app_palette.dart';

/// `/admin` — the content studio's home.
///
/// Top to bottom: what needs you now (items waiting for review for a
/// reviewer, items sent back to their writer, problem reports), then the
/// course map — every topic of a subject with the state of its lesson,
/// one tap from its planner.
///
/// Reachable by any content-team role; the router gates it, and the rules
/// check every read and write again. See docs/CONTENT_ROLES.md.
class AdminHomeScreen extends ConsumerStatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  ConsumerState<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends ConsumerState<AdminHomeScreen> {
  String? _subjectId;

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(staffRoleProvider);
    final access = ref.watch(staffAccessProvider);
    // Publishes this member's name and avatar for the rest of the team.
    ref.watch(staffProfileSyncProvider);
    // The subjects this account works on come first, and the map opens
    // on the first of them; the rest stay browsable, read-only.
    final subjects = [...?ref.watch(subjectsProvider).asData?.value]
      ..sort(
        (a, b) => (access.covers(a.id) ? 0 : 1).compareTo(
          access.covers(b.id) ? 0 : 1,
        ),
      );
    final subjectId = _subjectId ?? subjects.firstOrNull?.id;

    return Scaffold(
      backgroundColor: context.palette.background,
      appBar: AppBar(
        title: const Text('Content studio'),
        actions: [
          if (role == StaffRole.admin)
            TextButton.icon(
              onPressed: () => context.push('/admin/team'),
              icon: const Icon(Icons.group_outlined, size: 18),
              label: const Text('Team'),
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 960),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 60),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      role.canReview
                          ? 'You can review and publish. Writers submit items to you; nothing reaches students until it is published.'
                          : 'Write and submit items for review. A reviewer publishes them; students see nothing before that.',
                      style: AppTheme.bodyMd.copyWith(
                        color: context.palette.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (role.canReview) ...[
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
                    const SizedBox(height: 28),
                    if (role.canReview) ...[
                      const _FlagQueue(),
                      const SizedBox(height: 28),
                      const _LessonReports(),
                      const SizedBox(height: 28),
                    ],
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Course map',
                            style: AppTheme.heading3.copyWith(
                              color: context.palette.textPrimary,
                            ),
                          ),
                        ),
                        if (subjects.isNotEmpty)
                          DropdownButton<String>(
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
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (subjectId != null) _CourseMap(subjectId: subjectId),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
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
    TopicState.empty => AppColors.textSecondaryDark,
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

  Future<void> _rebuild() async {
    setState(() => _rebuilding = true);
    try {
      final units = await ref.read(unitsProvider(widget.subjectId).future);
      final names = <String, String>{};
      for (final u in units) {
        for (final Topic t in await ref.read(topicsProvider(u.id).future)) {
          names[t.id] = t.name;
        }
      }
      await ref
          .read(subjectIndexRepositoryProvider)
          .rebuildSubject(subjectId: widget.subjectId, topicNames: names);
      ref.invalidate(subjectIndexProvider(widget.subjectId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Glossary, formulas and cards rebuilt.'),
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
        if (widget.canRebuild)
          TextButton.icon(
            onPressed: _rebuilding ? null : _rebuild,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: Text(
              _rebuilding ? 'Rebuilding…' : 'Rebuild glossary & cards',
            ),
          ),
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

/// Student problem reports, grouped by question, open ones first.
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
    final secondary = AppTheme.bodyMd.copyWith(
      color: context.palette.textSecondary,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Problem reports',
                style: AppTheme.heading3.copyWith(
                  color: context.palette.textPrimary,
                ),
              ),
            ),
            TextButton(
              onPressed: () => setState(() => _showResolved = !_showResolved),
              child: Text(_showResolved ? 'Hide resolved' : 'Show resolved'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        queue.when(
          loading: () => const LinearProgressIndicator(minHeight: 2),
          error: (e, _) => Text(
            "Couldn't load reports.\n$e",
            style: AppTheme.bodyMd.copyWith(color: AppColors.wrong),
          ),
          data: (rows) {
            final shown = _showResolved
                ? rows
                : rows.where((r) => r.isOpen).toList();
            if (shown.isEmpty) {
              return Text(
                _showResolved ? 'No reports yet.' : 'No open reports.',
                style: secondary,
              );
            }
            return Container(
              decoration: BoxDecoration(
                color: context.palette.surface,
                border: Border.all(color: context.palette.border),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  for (var i = 0; i < shown.length; i++) ...[
                    if (i > 0)
                      Divider(height: 1, color: context.palette.border),
                    _FlagRow(row: shown[i]),
                  ],
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class _FlagRow extends StatelessWidget {
  const _FlagRow({required this.row});

  final FlaggedQuestion row;

  @override
  Widget build(BuildContext context) {
    final q = row.question;
    final open = row.openReports.length;
    final reasons = row.openReasonCounts
        .map((e) => '${e.$2} × ${e.$1.label}')
        .join(' · ');
    final stem = q == null
        ? '(question no longer exists)'
        : q.question.text.replaceAll(RegExp(r'\s+'), ' ');

    return ListTile(
      onTap: () => context.push(adminFlagPath(row.questionId)),
      leading: Text(
        open > 0 ? '$open' : '✓',
        style: AppTheme.heading3.copyWith(
          color: open > 0 ? AppColors.warning : AppColors.correct,
        ),
      ),
      title: Text(
        stem,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: AppTheme.bodyMd.copyWith(color: context.palette.textPrimary),
      ),
      subtitle: Text(
        [
          if (reasons.isNotEmpty) reasons else 'Resolved',
          if (q?.isGenerated ?? false) 'generated',
        ].join(' · '),
        style: AppTheme.caption.copyWith(color: context.palette.textSecondary),
      ),
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
        Text(
          'Lesson reports',
          style: AppTheme.heading3.copyWith(color: context.palette.textPrimary),
        ),
        const SizedBox(height: 12),
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
