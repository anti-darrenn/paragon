import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/learn_resource.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/repositories/admin_resource_repository.dart';
import '../../../core/repositories/lesson_workflow.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import 'staff_profile.dart';
import '../../../core/theme/app_palette.dart';

String _when(DateTime? t) {
  if (t == null) return 'just now';
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return 'just now';
  if (d.inHours < 1) return '${d.inMinutes} min ago';
  if (d.inDays < 1) return '${d.inHours} h ago';
  if (d.inDays < 30) return '${d.inDays} d ago';
  return '${t.day}/${t.month}/${t.year}';
}

/// The version history of one item, with restore. Opened from the editor.
///
/// Restoring on a published item is a reviewer's action (the rules refuse
/// a writer's write to anything published), so the button is shown only
/// when this account may do it.
Future<void> showHistorySheet(
  BuildContext context, {
  required LearnResource resource,
  required VoidCallback onRestored,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.palette.surface,
    builder: (sheet) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      builder: (context, scroll) => _HistoryList(
        resource: resource,
        scroll: scroll,
        onRestored: () {
          Navigator.of(sheet).pop();
          onRestored();
        },
      ),
    ),
  );
}

class _HistoryList extends ConsumerWidget {
  const _HistoryList({
    required this.resource,
    required this.scroll,
    required this.onRestored,
  });

  final LearnResource resource;
  final ScrollController scroll;
  final VoidCallback onRestored;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = (topicId: resource.topicId, resourceId: resource.id);
    final versions = ref.watch(resourceVersionsProvider(key));
    final role = ref.watch(staffAccessProvider).roleIn(resource.subjectId);
    final canRestore = resource.status.isLive ? role.canReview : role.canWrite;

    return versions.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(20),
        child: Text(
          "Couldn't load history.\n$e",
          style: AppTheme.bodyMd.copyWith(color: AppColors.wrong),
        ),
      ),
      data: (list) => ListView(
        controller: scroll,
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'History',
            style: AppTheme.heading3.copyWith(
              color: context.palette.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Every save keeps what was there before. Restoring puts an older '
            'version back and keeps the current one here too.',
            style: AppTheme.caption.copyWith(
              color: context.palette.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          if (list.isEmpty)
            Text(
              'No earlier versions yet.',
              style: AppTheme.bodyMd.copyWith(
                color: context.palette.textSecondary,
              ),
            ),
          for (final v in list)
            Card(
              color: context.palette.background,
              child: ExpansionTile(
                title: Text(
                  v.title.isEmpty ? '(untitled)' : v.title,
                  style: AppTheme.bodyMd.copyWith(
                    color: context.palette.textPrimary,
                  ),
                ),
                subtitle: Text(
                  '${_when(v.savedAt)}${v.status == null ? '' : ' · was ${v.status!.label.toLowerCase()}'}',
                  style: AppTheme.caption.copyWith(
                    color: context.palette.textSecondary,
                  ),
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          constraints: const BoxConstraints(maxHeight: 220),
                          padding: const EdgeInsets.all(10),
                          color: context.palette.surface,
                          child: SingleChildScrollView(
                            child: SelectableText(
                              v.body.isEmpty ? '(no article body)' : v.body,
                              style: AppTheme.caption.copyWith(
                                color: context.palette.textPrimary,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                        ),
                        if (canRestore)
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              icon: const Icon(Icons.restore_rounded, size: 18),
                              label: const Text('Restore this version'),
                              onPressed: () async {
                                final uid = ref.read(currentUserProvider)?.uid;
                                if (uid == null) return;
                                await ref
                                    .read(lessonWorkflowProvider)
                                    .restoreVersion(resource, v, uid: uid);
                                ref.invalidate(resourceVersionsProvider(key));
                                ref.invalidate(adminResourceProvider(key));
                                onRestored();
                              },
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

/// The review thread beside the editor: comments from writers and
/// reviewers, newest last, with resolve and a box to add one.
class CommentsPanel extends ConsumerStatefulWidget {
  const CommentsPanel({super.key, required this.resource});

  final LearnResource resource;

  @override
  ConsumerState<CommentsPanel> createState() => _CommentsPanelState();
}

class _CommentsPanelState extends ConsumerState<CommentsPanel> {
  final _text = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final user = ref.read(currentUserProvider);
    if (user == null || _text.text.trim().isEmpty) return;
    setState(() => _sending = true);
    try {
      await ref
          .read(lessonWorkflowProvider)
          .addComment(
            widget.resource,
            uid: user.uid,
            authorName: authorNameFor(user.displayName, user.email),
            text: _text.text,
          );
      _text.clear();
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final key = (
      topicId: widget.resource.topicId,
      resourceId: widget.resource.id,
    );
    final comments =
        ref.watch(resourceCommentsProvider(key)).asData?.value ?? const [];
    final me = ref.watch(currentUserProvider)?.uid;
    final role = ref
        .watch(staffAccessProvider)
        .roleIn(widget.resource.subjectId);
    final open = comments.where((c) => !c.resolved).length;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: context.palette.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            comments.isEmpty
                ? 'REVIEW COMMENTS'
                : 'REVIEW COMMENTS · $open OPEN',
            style: AppTheme.label.copyWith(
              color: context.palette.textSecondary,
            ),
          ),
          for (final c in comments)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  StaffAvatar(uid: c.authorUid, fallbackName: c.authorName),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${c.authorName} · ${_when(c.createdAt)}',
                          style: AppTheme.caption.copyWith(
                            color: context.palette.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          c.text,
                          style: AppTheme.bodyMd.copyWith(
                            color: c.resolved
                                ? context.palette.textSecondary
                                : context.palette.textPrimary,
                            decoration: c.resolved
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (c.authorUid == me || role.canReview)
                    IconButton(
                      tooltip: c.resolved ? 'Reopen' : 'Resolve',
                      icon: Icon(
                        c.resolved ? Icons.undo_rounded : Icons.check_rounded,
                        size: 18,
                      ),
                      onPressed: () => ref
                          .read(lessonWorkflowProvider)
                          .setCommentResolved(
                            widget.resource,
                            c.id,
                            resolved: !c.resolved,
                          ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _text,
                  minLines: 1,
                  maxLines: 4,
                  style: AppTheme.bodyMd.copyWith(
                    color: context.palette.textPrimary,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Add a comment',
                    isDense: true,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Send',
                icon: const Icon(Icons.send_rounded, size: 18),
                onPressed: _sending ? null : _send,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The name shown on a comment: the account's display name, else the
/// part of the email before the @, else "Someone".
String authorNameFor(String? displayName, String? email) {
  final name = (displayName ?? '').trim();
  if (name.isNotEmpty) return name;
  final at = (email ?? '').indexOf('@');
  if (at > 0) return email!.substring(0, at);
  return 'Someone';
}

/// Short, human status line for the editor header.
String statusLine(ResourceStatus s, {required bool isRevision}) => switch (s) {
  ResourceStatus.draft =>
    isRevision
        ? 'REVISION DRAFT — replaces the published version once approved.'
        : 'DRAFT — students cannot see this yet.',
  ResourceStatus.inReview => 'IN REVIEW — waiting for a reviewer.',
  ResourceStatus.changesRequested =>
    'CHANGES REQUESTED — see the comments, then resubmit.',
  ResourceStatus.published => 'PUBLISHED — students can see this now.',
};

Color statusColour(ResourceStatus s) => switch (s) {
  ResourceStatus.draft => AppColors.warning,
  ResourceStatus.inReview => AppColors.accentBlue,
  ResourceStatus.changesRequested => AppColors.wrong,
  ResourceStatus.published => AppColors.correct,
};
