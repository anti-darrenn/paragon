import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/content/question_counts.dart' show groupThousands;
import '../../../core/models/topic.dart';
import '../../../core/repositories/admin_flag_repository.dart';
import '../../../core/repositories/admin_question_repository.dart';
import '../../../core/repositories/learning_repository.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/ui/ui.dart';
import '../admin_paths.dart';
import 'question_widgets.dart';
import 'studio_error.dart';
import 'subject_picker.dart';

/// The founder's question bank (owner's decision, 2026-10-17).
///
/// Only **vetted** questions are used anywhere on Paragon. Everything else
/// is **pending**. Here the founder picks a subject, sees each topic's
/// pending and vetted counts (`topics.pendingCount` / `questionCount`, from
/// the nightly counts job), and either starts vetting a topic's pending
/// questions in the workbench, one after another ("Approve & next"), or
/// looks through what is already vetted. "Write a question" adds a new one
/// from a textbook, which starts pending too.
class QuestionBankPanel extends ConsumerStatefulWidget {
  const QuestionBankPanel({super.key});

  @override
  ConsumerState<QuestionBankPanel> createState() => _QuestionBankPanelState();
}

class _QuestionBankPanelState extends ConsumerState<QuestionBankPanel> {
  String? _subjectId;

  /// The topic whose vetted questions are open below it.
  String? _openTopic;
  String? _loadingTopic;

  Future<void> _vet(Topic t) async {
    setState(() => _loadingTopic = t.id);
    try {
      final page = await ref
          .read(adminQuestionRepositoryProvider)
          .pendingPage(t.id);
      if (!mounted) return;
      if (page.questions.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Nothing pending in ${t.name}.')),
        );
        return;
      }
      final ids = [for (final q in page.questions) q.question.id];
      await openQuestion(context, ref, ids.first, list: ids);
    } catch (e) {
      if (mounted) {
        showStudioFailure(context, "Couldn't load the pending questions.", e);
      }
    } finally {
      if (mounted) setState(() => _loadingTopic = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final subjects = ref.watch(subjectsProvider);
    return subjects.when(
      loading: () => const StudioListSkeleton(),
      error: (e, _) =>
          StudioError(message: "Couldn't load the subjects.", error: e),
      data: (list) {
        final subjectId = _subjectId ?? (list.isEmpty ? null : list.first.id);
        final topics = subjectId == null
            ? null
            : ref.watch(subjectTopicsProvider(subjectId));
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            StudioSubjectPicker(
              subjects: list,
              selected: subjectId,
              onSelected: (id) => setState(() {
                _subjectId = id;
                _openTopic = null;
              }),
            ),
            const SizedBox(height: 16),
            if (subjectId != null)
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.icon(
                  onPressed: () =>
                      context.push(adminNewQuestionPath(subjectId: subjectId)),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Write a question'),
                ),
              ),
            const SizedBox(height: 20),
            if (topics != null)
              topics.when(
                loading: () => const StudioListSkeleton(),
                error: (e, _) =>
                    StudioError(message: "Couldn't load the topics.", error: e),
                data: (ts) {
                  final pending = ts.fold<int>(0, (n, t) => n + t.pendingCount);
                  final vetted = ts.fold<int>(0, (n, t) => n + t.questionCount);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '${groupThousands(pending)} pending · '
                        '${groupThousands(vetted)} vetted. Counts refresh '
                        'nightly.',
                        style: AppTheme.bodyMd.copyWith(
                          color: palette.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SurfaceCard(
                        padding: EdgeInsets.zero,
                        child: Column(
                          children: [
                            for (final t in ts) ...[
                              _TopicRow(
                                topic: t,
                                loading: _loadingTopic == t.id,
                                open: _openTopic == t.id,
                                onVet: () => _vet(t),
                                onWrite: () => context.push(
                                  adminNewQuestionPath(
                                    subjectId: subjectId!,
                                    topicId: t.id,
                                  ),
                                ),
                                onToggleVetted: () => setState(
                                  () => _openTopic = _openTopic == t.id
                                      ? null
                                      : t.id,
                                ),
                              ),
                              if (_openTopic == t.id)
                                _VettedList(topicId: t.id),
                              Divider(
                                height: 1,
                                color: palette.border.withAlpha(150),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
          ],
        );
      },
    );
  }
}

class _TopicRow extends StatelessWidget {
  const _TopicRow({
    required this.topic,
    required this.loading,
    required this.open,
    required this.onVet,
    required this.onWrite,
    required this.onToggleVetted,
  });

  final Topic topic;
  final bool loading;
  final bool open;
  final VoidCallback onVet;
  final VoidCallback onWrite;
  final VoidCallback onToggleVetted;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final t = topic;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Wrap(
        spacing: 10,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 220, maxWidth: 420),
            child: Text(
              t.name,
              style: AppTheme.bodyMd.copyWith(
                color: palette.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          StudioTag(
            '${groupThousands(t.pendingCount)} pending',
            color: t.pendingCount > 0 ? AppColors.warning : null,
          ),
          StudioTag(
            '${groupThousands(t.questionCount)} vetted',
            color: t.questionCount > 0 ? AppColors.correct : null,
          ),
          if (loading)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            FilledButton.tonal(onPressed: onVet, child: const Text('Vet')),
          TextButton(
            onPressed: onToggleVetted,
            child: Text(open ? 'Hide vetted' : 'Vetted'),
          ),
          IconButton(
            tooltip: 'Write a question for this topic',
            onPressed: onWrite,
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
    );
  }
}

/// A topic's vetted questions, a page at a time.
class _VettedList extends ConsumerStatefulWidget {
  const _VettedList({required this.topicId});
  final String topicId;

  @override
  ConsumerState<_VettedList> createState() => _VettedListState();
}

class _VettedListState extends ConsumerState<_VettedList> {
  final _rows = <ReviewedQuestion>[];
  DocumentSnapshot? _last;
  bool _hasMore = false;
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await ref
          .read(adminQuestionRepositoryProvider)
          .vettedPage(widget.topicId, after: _last);
      if (!mounted) return;
      setState(() {
        _rows.addAll(page.questions);
        _last = page.last;
        _hasMore = page.hasMore;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ids = [for (final q in _rows) q.question.id];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_error != null)
            Text(
              "Couldn't load the vetted questions.\n$_error",
              style: AppTheme.caption.copyWith(color: context.palette.dangerFg),
            ),
          if (!_loading && _rows.isEmpty && _error == null)
            Text(
              'Nothing vetted in this topic yet.',
              style: AppTheme.caption.copyWith(
                color: context.palette.textSecondary,
              ),
            ),
          for (final q in _rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: QuestionListCard(
                question: q,
                onTap: () =>
                    openQuestion(context, ref, q.question.id, list: ids),
              ),
            ),
          if (_loading) const StudioListSkeleton(count: 2),
          if (_hasMore && !_loading)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: _fetch,
                child: const Text('Show more'),
              ),
            ),
        ],
      ),
    );
  }
}
