import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/question.dart';
import '../../../core/repositories/learning_repository.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/answer_option.dart';
import '../../../core/widgets/math_text.dart';
import '../../lesson/lesson_screen.dart' show lessonPath;
import 'notes_widgets.dart';
import 'study_models.dart';
import 'study_providers.dart';

/// `/saved` — bookmarked lessons, bookmarked questions, and every note.
class SavedScreen extends ConsumerWidget {
  const SavedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: AppColors.backgroundDark,
        appBar: AppBar(
          backgroundColor: AppColors.backgroundDark,
          title: const Text('Saved'),
          bottom: const TabBar(
            indicatorColor: AppColors.primary,
            labelColor: AppColors.textPrimaryDark,
            unselectedLabelColor: AppColors.textSecondaryDark,
            tabs: [
              Tab(text: 'Lessons'),
              Tab(text: 'Questions'),
              Tab(text: 'Notes'),
            ],
          ),
        ),
        body: const Column(
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: GuestNotesPrompt(),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _BookmarkList(kind: BookmarkKind.lesson),
                  _BookmarkList(kind: BookmarkKind.question),
                  _NotesList(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _empty(String text) => Center(
  child: Padding(
    padding: const EdgeInsets.all(32),
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: AppTheme.bodyMd.copyWith(color: AppColors.textSecondaryDark),
    ),
  ),
);

Widget _loadFailed() => _empty("Couldn't load these. Check your connection and try again.");

class _BookmarkList extends ConsumerWidget {
  const _BookmarkList({required this.kind});

  final BookmarkKind kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(bookmarksProvider).when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => _loadFailed(),
      data: (all) {
        final items = all.values.where((b) => b.kind == kind).toList()
          ..sort(
            (a, b) =>
                (b.savedAt ?? DateTime(0)).compareTo(a.savedAt ?? DateTime(0)),
          );
        if (items.isEmpty) {
          return _empty(
            kind == BookmarkKind.lesson
                ? 'No saved lessons yet. Tap the bookmark on a lesson to keep it here.'
                : 'No saved questions yet. Tap the bookmark beside a question to keep it here.',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: items.length,
          separatorBuilder: (_, _) => const Divider(height: 1, color: AppColors.borderDark),
          itemBuilder: (context, i) {
            final b = items[i];
            return ListTile(
              leading: Icon(
                kind == BookmarkKind.lesson ? Icons.menu_book : Icons.help_outline,
                color: AppColors.textSecondaryDark,
              ),
              title: Text(
                b.title.isEmpty ? 'Untitled' : b.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.textPrimaryDark),
              ),
              trailing: IconButton(
                tooltip: 'Remove from saved',
                icon: const Icon(Icons.bookmark, color: AppColors.primary),
                onPressed: () => ref.read(bookmarksProvider.notifier).remove(b.key),
              ),
              onTap: () {
                if (kind == BookmarkKind.lesson) {
                  context.push(lessonPath(b.topicId, b.resourceId!));
                } else {
                  showSavedQuestion(context, b.questionId!);
                }
              },
            );
          },
        );
      },
    );
  }
}

/// A saved question with its answer, read-only. Nothing here records an
/// attempt.
Future<void> showSavedQuestion(BuildContext context, String questionId) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surfaceDark,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      builder: (context, controller) => SavedQuestionView(
        questionId: questionId,
        controller: controller,
      ),
    ),
  );
}

class SavedQuestionView extends ConsumerWidget {
  const SavedQuestionView({super.key, required this.questionId, this.controller});

  final String questionId;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(savedQuestionProvider(questionId)).when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => _loadFailed(),
      data: (q) => q == null
          ? _empty('This question is no longer available.')
          : _body(q),
    );
  }

  Widget _body(Question q) {
    final answered = q.correctIndex >= 0 && q.correctIndex < q.options.length;
    return ListView(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        MathText(
          text: q.text,
          style: AppTheme.bodyLg.copyWith(color: AppColors.textPrimaryDark),
        ),
        const SizedBox(height: 16),
        for (var i = 0; i < q.options.length; i++)
          AnswerOption(
            index: i,
            text: q.options[i],
            state: answered && i == q.correctIndex
                ? AnswerOptionState.correct
                : AnswerOptionState.idle,
          ),
        const SizedBox(height: 12),
        if (!answered)
          Text(
            'This question has no verified answer yet.',
            style: AppTheme.caption.copyWith(color: AppColors.warning),
          ),
        if (q.explanation.trim().isNotEmpty) ...[
          const SizedBox(height: 8),
          MathText(
            text: q.explanation,
            style: AppTheme.bodyMd.copyWith(color: AppColors.textSecondaryDark),
          ),
        ],
      ],
    );
  }
}

class _NotesList extends ConsumerWidget {
  const _NotesList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(allNotesProvider).when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => _loadFailed(),
      data: (notes) {
        if (notes.isEmpty) {
          return _empty(
            'No notes yet. Long-press a paragraph in any lesson to highlight it or add a note.',
          );
        }
        // Grouped by topic, topics in order of their most recent note.
        final byTopic = <String, List<LessonNote>>{};
        for (final n in notes) {
          byTopic.putIfAbsent(n.topicId, () => []).add(n);
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            for (final e in byTopic.entries) ...[
              const SizedBox(height: 12),
              _TopicHeading(topicId: e.key),
              for (final n in e.value)
                NoteTile(
                  note: n,
                  onTap: () => context.push(lessonPath(n.topicId, n.resourceId)),
                ),
            ],
          ],
        );
      },
    );
  }
}

class _TopicHeading extends ConsumerWidget {
  const _TopicHeading({required this.topicId});

  final String topicId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topic = ref.watch(topicByIdProvider(topicId)).asData?.value;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        topic?.name ?? 'Topic',
        style: AppTheme.label.copyWith(color: AppColors.textSecondaryDark),
      ),
    );
  }
}
