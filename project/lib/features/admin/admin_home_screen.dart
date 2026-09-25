import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/learn_resource.dart';
import '../../core/repositories/admin_resource_repository.dart';
import '../../core/repositories/learning_repository.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import 'admin_resource_editor_screen.dart';

/// `/admin` — pick a topic, see every resource in it (drafts included),
/// open one to edit or start a new article.
///
/// Reachable only with the `admin` claim; the router enforces that, and
/// the rules enforce it again for every read and write made from here.
class AdminHomeScreen extends ConsumerStatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  ConsumerState<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends ConsumerState<AdminHomeScreen> {
  String? _subjectId;
  String? _unitId;
  String? _topicId;

  @override
  Widget build(BuildContext context) {
    final subjects = ref.watch(subjectsProvider);
    final units = _subjectId == null
        ? null
        : ref.watch(unitsProvider(_subjectId!));
    final topics = _unitId == null ? null : ref.watch(topicsProvider(_unitId!));

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(title: const Text('Content editor')),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 60),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Articles saved here are drafts until published. '
                      'Students see nothing until you press Publish.',
                      style: AppTheme.bodyMd.copyWith(
                        color: AppColors.textSecondaryDark,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const _AwaitingReview(),
                    const SizedBox(height: 28),
                    Text(
                      'Browse by topic',
                      style: AppTheme.heading3.copyWith(
                        color: AppColors.textPrimaryDark,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _Picker(
                      label: 'SUBJECT',
                      value: _subjectId,
                      items: subjects.asData?.value
                          .map((s) => (s.id, s.name))
                          .toList(),
                      onChanged: (id) => setState(() {
                        _subjectId = id;
                        _unitId = null;
                        _topicId = null;
                      }),
                    ),
                    if (units != null) ...[
                      const SizedBox(height: 16),
                      _Picker(
                        key: ValueKey('unit-$_subjectId'),
                        label: 'UNIT',
                        value: _unitId,
                        items: units.asData?.value
                            .map((u) => (u.id, u.name))
                            .toList(),
                        onChanged: (id) => setState(() {
                          _unitId = id;
                          _topicId = null;
                        }),
                      ),
                    ],
                    if (topics != null) ...[
                      const SizedBox(height: 16),
                      _Picker(
                        key: ValueKey('topic-$_unitId'),
                        label: 'TOPIC',
                        value: _topicId,
                        items: topics.asData?.value
                            .map((t) => (t.id, t.name))
                            .toList(),
                        onChanged: (id) => setState(() => _topicId = id),
                      ),
                    ],
                    if (_topicId != null) ...[
                      const SizedBox(height: 28),
                      _TopicResources(topicId: _topicId!),
                    ],
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

class _Picker extends StatelessWidget {
  const _Picker({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final String? value;

  /// `(id, name)` pairs; null while loading.
  final List<(String, String)>? items;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTheme.label.copyWith(color: AppColors.textSecondaryDark),
        ),
        const SizedBox(height: 8),
        if (items == null)
          const LinearProgressIndicator(minHeight: 2)
        else
          DropdownButtonFormField<String>(
            initialValue: value,
            isExpanded: true,
            dropdownColor: AppColors.surfaceDark,
            style: AppTheme.bodyMd.copyWith(color: AppColors.textPrimaryDark),
            decoration: InputDecoration(
              filled: true,
              fillColor: AppColors.surfaceDark,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.borderDark),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.borderDark),
              ),
            ),
            items: [
              for (final (id, name) in items!)
                DropdownMenuItem(value: id, child: Text(name)),
            ],
            onChanged: onChanged,
          ),
      ],
    );
  }
}

class _TopicResources extends ConsumerWidget {
  const _TopicResources({required this.topicId});

  final String topicId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resources = ref.watch(adminTopicResourcesProvider(topicId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Resources',
          style: AppTheme.heading3.copyWith(color: AppColors.textPrimaryDark),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final (type, icon) in const [
              (LearnResourceType.article, Icons.article_outlined),
              (LearnResourceType.video, Icons.play_circle_outline_rounded),
              (LearnResourceType.exercise, Icons.edit_note_rounded),
            ])
              ElevatedButton.icon(
                onPressed: () =>
                    context.push(adminNewResourcePath(topicId, type)),
                icon: Icon(icon, size: 18),
                label: Text('New ${type.label.toLowerCase()}'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        resources.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Text(
            "Couldn't load this topic's resources.\n$e",
            style: AppTheme.bodyMd.copyWith(color: AppColors.wrong),
          ),
          data: (list) => list.isEmpty
              ? Text(
                  'No resources in this topic yet.',
                  style: AppTheme.bodyMd.copyWith(
                    color: AppColors.textSecondaryDark,
                  ),
                )
              : _ResourceList(resources: list),
        ),
      ],
    );
  }
}

/// Every draft in the app, across topics — where the review email sends
/// you.
class _AwaitingReview extends ConsumerWidget {
  const _AwaitingReview();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final drafts = ref.watch(adminDraftsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Awaiting review',
          style: AppTheme.heading3.copyWith(color: AppColors.textPrimaryDark),
        ),
        const SizedBox(height: 12),
        drafts.when(
          loading: () => const LinearProgressIndicator(minHeight: 2),
          error: (e, _) => Text(
            "Couldn't load drafts.\n$e",
            style: AppTheme.bodyMd.copyWith(color: AppColors.wrong),
          ),
          data: (list) => list.isEmpty
              ? Text(
                  'No drafts waiting.',
                  style: AppTheme.bodyMd.copyWith(
                    color: AppColors.textSecondaryDark,
                  ),
                )
              : _ResourceList(resources: list),
        ),
      ],
    );
  }
}

class _ResourceList extends StatelessWidget {
  const _ResourceList({required this.resources});

  final List<LearnResource> resources;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        border: Border.all(color: AppColors.borderDark),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          for (var i = 0; i < resources.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: AppColors.borderDark),
            _ResourceRow(resource: resources[i]),
          ],
        ],
      ),
    );
  }
}

class _ResourceRow extends StatelessWidget {
  const _ResourceRow({required this.resource});

  final LearnResource resource;

  @override
  Widget build(BuildContext context) {
    final editable = resource.type != LearnResourceType.unknown;
    final isDraft = resource.status == ResourceStatus.draft;
    // A seeded video with no id yet is the usual reason to open one.
    final needsWork = !resource.isAvailable;

    return ListTile(
      enabled: editable,
      onTap: editable
          ? () => context.push(adminResourcePath(resource.topicId, resource.id))
          : null,
      leading: Text(
        '${resource.order}',
        style: AppTheme.bodyMd.copyWith(color: AppColors.textSecondaryDark),
      ),
      title: Text(
        resource.title.isEmpty ? '(untitled)' : resource.title,
        style: AppTheme.bodyMd.copyWith(color: AppColors.textPrimaryDark),
      ),
      subtitle: Text(
        needsWork
            ? '${resource.type.label} · not ready — '
                  '${resource.type == LearnResourceType.video ? 'no YouTube link' : 'no body'}'
            : resource.type.label,
        style: AppTheme.caption.copyWith(
          color: needsWork ? AppColors.warning : AppColors.textSecondaryDark,
        ),
      ),
      trailing: _StatusBadge(isDraft: isDraft),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.isDraft});

  final bool isDraft;

  @override
  Widget build(BuildContext context) {
    final color = isDraft ? AppColors.warning : AppColors.correct;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        isDraft ? 'Draft' : 'Published',
        style: AppTheme.caption.copyWith(color: color),
      ),
    );
  }
}
