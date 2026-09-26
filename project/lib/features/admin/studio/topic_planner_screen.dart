import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/learn_resource.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/repositories/admin_resource_repository.dart';
import '../../../core/repositories/learn_repository.dart';
import '../../../core/repositories/learning_repository.dart';
import '../../../core/repositories/subject_index_repository.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../lesson/article_pane.dart';
import '../../lesson/exercise_pane.dart';
import '../../lesson/video_pane.dart';
import '../admin_home_screen.dart' show ResourceRow, StatusBadge;
import '../admin_resource_editor_screen.dart';

String topicPlannerPath(String topicId) => '/admin/topic/$topicId';

/// `/admin/topic/:topicId` — one topic's lesson: every item in order, any
/// status, with "Add" for each type and a student's-eye preview.
///
/// Reviewers can drag to reorder. Writers cannot: reordering rewrites the
/// `order` of published items too, which the rules reserve for reviewers.
class TopicPlannerScreen extends ConsumerStatefulWidget {
  const TopicPlannerScreen({super.key, required this.topicId});

  final String topicId;

  @override
  ConsumerState<TopicPlannerScreen> createState() => _TopicPlannerScreenState();
}

class _TopicPlannerScreenState extends ConsumerState<TopicPlannerScreen> {
  /// The order being shown while a reorder saves, so the list doesn't jump
  /// back before Firestore answers.
  List<LearnResource>? _pending;
  bool _saving = false;

  Future<void> _reorder(List<LearnResource> items, int from, int to) async {
    final list = [...items];
    if (to > from) to -= 1;
    list.insert(to, list.removeAt(from));
    setState(() {
      _pending = list;
      _saving = true;
    });
    try {
      final db = FirebaseFirestore.instance;
      final batch = db.batch();
      for (var i = 0; i < list.length; i++) {
        final order = (i + 1) * 10;
        if (list[i].order != order) {
          batch.update(
            db
                .collection('topics')
                .doc(widget.topicId)
                .collection('resources')
                .doc(list[i].id),
            {'order': order, 'updatedAt': FieldValue.serverTimestamp()},
          );
        }
      }
      await batch.commit();
      ref.invalidate(adminTopicResourcesProvider(widget.topicId));
      ref.invalidate(topicResourcesProvider(widget.topicId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Couldn't reorder: $e")));
      }
    } finally {
      if (mounted) {
        setState(() {
          _pending = null;
          _saving = false;
        });
      }
    }
  }

  /// Deletes one item after confirming. Deleting a published item also
  /// refreshes what depends on it: the topic's lesson count and the
  /// subject's glossary/formula/card index.
  Future<void> _delete(LearnResource r) async {
    final live = r.status.isLive;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        title: Text('Delete "${r.title.isEmpty ? 'untitled' : r.title}"?'),
        content: Text(
          live
              ? 'Students lose it immediately. This cannot be undone. To take '
                    'it down but keep it, open it and use Unpublish instead.'
              : 'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(true),
            child: const Text(
              'Delete',
              style: TextStyle(color: AppColors.wrong),
            ),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _saving = true);
    try {
      final repo = ref.read(adminResourceRepositoryProvider);
      await repo.delete(topicId: widget.topicId, resourceId: r.id);
      if (live) {
        await repo.refreshLessonCount(widget.topicId).catchError((_) {});
        final topic = await ref.read(topicByIdProvider(widget.topicId).future);
        if (topic != null) {
          await ref
              .read(subjectIndexRepositoryProvider)
              .rebuildTopic(
                subjectId: topic.subjectId,
                topicId: topic.id,
                topicName: topic.name,
              )
              .catchError((_) {});
          ref.invalidate(subjectIndexProvider(topic.subjectId));
        }
      }
      ref.invalidate(adminTopicResourcesProvider(widget.topicId));
      ref.invalidate(topicResourcesProvider(widget.topicId));
      ref.invalidate(adminSubjectResourcesProvider);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Deleted.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Couldn't delete: $e")));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final topic = ref.watch(topicByIdProvider(widget.topicId)).asData?.value;
    final itemsAsync = ref.watch(adminTopicResourcesProvider(widget.topicId));
    final canReorder = ref
        .watch(staffAccessProvider)
        .roleIn(topic?.subjectId ?? '')
        .canReview;

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        title: Text(topic?.name ?? 'Topic', overflow: TextOverflow.ellipsis),
        actions: [
          TextButton.icon(
            onPressed: () {
              final items = itemsAsync.asData?.value;
              if (items == null) return;
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => _StudentPreview(
                    title: topic?.name ?? 'Preview',
                    items: items,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.visibility_outlined, size: 18),
            label: const Text('Preview as student'),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: itemsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  "Couldn't load this topic.\n$e",
                  style: AppTheme.bodyMd.copyWith(color: AppColors.wrong),
                ),
              ),
              data: (loaded) {
                final items = _pending ?? loaded;
                return ListView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 60),
                  children: [
                    Text(
                      canReorder
                          ? 'The lesson, in the order students see it. Drag to reorder; it ends with the topic test.'
                          : 'The lesson, in the order students see it. It ends with the topic test.',
                      style: AppTheme.bodyMd.copyWith(
                        color: AppColors.textSecondaryDark,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (final (type, icon) in const [
                          (LearnResourceType.article, Icons.article_outlined),
                          (
                            LearnResourceType.video,
                            Icons.play_circle_outline_rounded,
                          ),
                          (LearnResourceType.exercise, Icons.edit_note_rounded),
                        ])
                          ElevatedButton.icon(
                            onPressed: () => context.push(
                              adminNewResourcePath(widget.topicId, type),
                            ),
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
                    const SizedBox(height: 16),
                    if (_saving) const LinearProgressIndicator(minHeight: 2),
                    if (items.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Text(
                          'No lesson items yet. Start with an article.',
                          style: AppTheme.bodyMd.copyWith(
                            color: AppColors.textSecondaryDark,
                          ),
                        ),
                      )
                    else if (canReorder)
                      ReorderableListView(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        buildDefaultDragHandles: false,
                        onReorder: _saving
                            ? (_, _) {}
                            : (from, to) => _reorder(items, from, to),
                        children: [
                          for (var i = 0; i < items.length; i++)
                            Material(
                              key: ValueKey(items[i].id),
                              color: AppColors.surfaceDark,
                              child: ResourceRow(
                                resource: items[i],
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    StatusBadge(status: items[i].status),
                                    _ItemMenu(
                                      resource: items[i],
                                      onDelete: _delete,
                                    ),
                                    ReorderableDragStartListener(
                                      index: i,
                                      child: const Padding(
                                        padding: EdgeInsets.only(left: 8),
                                        child: Icon(
                                          Icons.drag_indicator_rounded,
                                          color: AppColors.textSecondaryDark,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      )
                    else
                      Column(
                        children: [
                          for (final r in items)
                            Material(
                              color: AppColors.surfaceDark,
                              child: ResourceRow(
                                resource: r,
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    StatusBadge(status: r.status),
                                    _ItemMenu(resource: r, onDelete: _delete),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// Every item as a student would see it, drafts included, one after
/// another. Exercises run with recording off.
class _StudentPreview extends StatelessWidget {
  const _StudentPreview({required this.title, required this.items});

  final String title;
  final List<LearnResource> items;

  @override
  Widget build(BuildContext context) {
    final shown = items.where((r) => !r.isRevision).toList();
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        title: Text('Preview: $title', overflow: TextOverflow.ellipsis),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 60),
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.warning.withAlpha(30),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Preview including drafts. Students see only published items. Revisions are not shown; they replace their original when approved.',
                  style: AppTheme.caption.copyWith(color: AppColors.warning),
                ),
              ),
              for (final r in shown) ...[
                const SizedBox(height: 28),
                Row(children: [StatusBadge(status: r.status)]),
                const SizedBox(height: 12),
                switch (r.type) {
                  LearnResourceType.video => VideoPane(
                    resource: r,
                    isOffline: false,
                  ),
                  LearnResourceType.exercise => ExercisePane(
                    resource: r,
                    recordAttempts: false,
                  ),
                  _ => ArticlePane(resource: r),
                },
                const SizedBox(height: 12),
                const Divider(color: AppColors.borderDark),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Open or delete one item. Delete is offered only where the rules allow
/// it: reviewers on anything, a writer on their own draft.
class _ItemMenu extends ConsumerWidget {
  const _ItemMenu({required this.resource, required this.onDelete});

  final LearnResource resource;
  final Future<void> Function(LearnResource) onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(staffAccessProvider).roleIn(resource.subjectId);
    final uid = ref.watch(currentUserProvider)?.uid;
    final canDelete =
        role.canReview ||
        (resource.status == ResourceStatus.draft &&
            resource.createdBy != null &&
            resource.createdBy == uid);
    return PopupMenuButton<String>(
      tooltip: 'More',
      color: AppColors.surfaceDark,
      icon: const Icon(Icons.more_vert, color: AppColors.textSecondaryDark),
      onSelected: (choice) {
        if (choice == 'open') {
          context.push(adminResourcePath(resource.topicId, resource.id));
        } else if (choice == 'delete') {
          onDelete(resource);
        }
      },
      itemBuilder: (_) => [
        const PopupMenuItem(value: 'open', child: Text('Open')),
        if (canDelete)
          const PopupMenuItem(
            value: 'delete',
            child: Text('Delete', style: TextStyle(color: AppColors.wrong)),
          ),
      ],
    );
  }
}
