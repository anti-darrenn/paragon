import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/question.dart';
import '../../core/progress/mistakes.dart';
import '../../core/repositories/learning_repository.dart';
import '../../core/repositories/mistakes_repository.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/answer_option.dart';
import '../../core/widgets/full_latex_view.dart';
import '../../core/widgets/load_error.dart';
import '../../core/widgets/question_image.dart';

/// The most a practice round takes from the notebook at once.
const int kMistakesPracticeSize = 20;

/// `/mistakes`: every question whose latest answer was wrong, with the
/// right answer and the working, and a way to practise them.
///
/// Mistakes from every mode are listed, WAEC exams included. That does not
/// merge the modes: this reads history, and its practice records its own
/// `source: 'review'`, which never feeds drill or mastery.
class MistakesScreen extends ConsumerStatefulWidget {
  const MistakesScreen({super.key});

  @override
  ConsumerState<MistakesScreen> createState() => _MistakesScreenState();
}

class _MistakesScreenState extends ConsumerState<MistakesScreen> {
  /// Null shows every subject.
  String? _subjectId;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(mistakesProvider);
    return Scaffold(
      backgroundColor: context.palette.background,
      appBar: AppBar(title: const Text('Mistakes notebook')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => LoadError(
          error: e,
          onRetry: () => ref.invalidate(mistakesProvider),
        ),
        data: (all) {
          final subjectIds = {for (final e in all) e.subjectId};
          final subjectId = subjectIds.contains(_subjectId) ? _subjectId : null;
          final shown = subjectId == null
              ? all
              : [
                  for (final e in all)
                    if (e.subjectId == subjectId) e,
                ];
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: RefreshIndicator(
                onRefresh: () => ref.refresh(mistakesProvider.future),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
                  children: [
                    Text(
                      'Questions whose latest answer was wrong, from your last '
                      '$kMistakesWindow answers. Get one right, here or '
                      'anywhere else, and it leaves the notebook.',
                      style: AppTheme.bodyMd.copyWith(
                        color: context.palette.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (all.isEmpty)
                      const _Empty()
                    else ...[
                      if (subjectIds.length > 1)
                        _SubjectFilter(
                          subjectIds: subjectIds,
                          selected: subjectId,
                          onSelected: (id) => setState(() => _subjectId = id),
                        ),
                      _PractiseButton(
                        questions: [for (final e in shown) e.question],
                      ),
                      const SizedBox(height: 16),
                      for (final e in shown) _MistakeCard(entry: e),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Icon(
            Icons.check_circle_outline_rounded,
            size: 48,
            color: context.palette.textSecondary,
          ),
          const SizedBox(height: 12),
          Text(
            'Nothing to review',
            style: AppTheme.heading3.copyWith(
              color: context.palette.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Questions you get wrong in practice, tests and exams collect '
            'here, so you can come back to them.',
            textAlign: TextAlign.center,
            style: AppTheme.bodyMd.copyWith(
              color: context.palette.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _SubjectFilter extends ConsumerWidget {
  const _SubjectFilter({
    required this.subjectIds,
    required this.selected,
    required this.onSelected,
  });

  final Set<String> subjectIds;
  final String? selected;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final names = {
      for (final s in ref.watch(subjectsProvider).asData?.value ?? const [])
        s.id: s.name,
    };
    final ids = subjectIds.toList()
      ..sort((a, b) => (names[a] ?? a).compareTo(names[b] ?? b));
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          ChoiceChip(
            label: const Text('All'),
            selected: selected == null,
            onSelected: (_) => onSelected(null),
          ),
          for (final id in ids)
            ChoiceChip(
              label: Text(names[id] ?? 'Other'),
              selected: selected == id,
              onSelected: (_) => onSelected(id),
            ),
        ],
      ),
    );
  }
}

class _PractiseButton extends StatelessWidget {
  const _PractiseButton({required this.questions});
  final List<Question> questions;

  @override
  Widget build(BuildContext context) {
    final n = questions.length < kMistakesPracticeSize
        ? questions.length
        : kMistakesPracticeSize;
    return ElevatedButton.icon(
      onPressed: () => context.push(
        '/mistakes/practice',
        extra: questions.take(kMistakesPracticeSize).toList(),
      ),
      icon: const Icon(Icons.replay_rounded, color: Colors.white),
      label: Text(
        n == 1 ? 'Practise this question' : 'Practise $n questions',
        style: AppTheme.btnLabel.copyWith(color: Colors.white),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}

class _MistakeCard extends StatelessWidget {
  const _MistakeCard({required this.entry});
  final MistakeEntry entry;

  @override
  Widget build(BuildContext context) {
    final q = entry.question;
    final picked = entry.mistake.selectedIndex;
    final base = AppTheme.bodyMd.copyWith(color: context.palette.onHigh);
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.palette.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            mistakeSourceLabel(entry.mistake.latest.source),
            style: AppTheme.caption.copyWith(
              color: context.palette.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          FullLatexView(
            latex: q.text,
            textStyle: AppTheme.bodyLg.copyWith(
              color: context.palette.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          QuestionImage(assetId: q.imageId),
          const SizedBox(height: 12),
          for (var i = 0; i < q.options.length; i++)
            if (i == q.correctIndex || i == picked)
              AnswerOption(
                index: i,
                text: q.options[i],
                state: i == q.correctIndex
                    ? AnswerOptionState.correct
                    : AnswerOptionState.wrong,
              ),
          if (q.explanation.trim().isNotEmpty || q.explanationImageId != null)
            Theme(
              data: Theme.of(
                context,
              ).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text(
                  'Show the working',
                  style: AppTheme.bodyMd.copyWith(color: AppColors.primary),
                ),
                children: [
                  if (q.explanation.trim().isNotEmpty)
                    FullLatexView(latex: q.explanation, textStyle: base),
                  QuestionImage(assetId: q.explanationImageId),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
