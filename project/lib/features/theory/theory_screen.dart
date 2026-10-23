import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/motion/score_ring.dart';
import '../../core/widgets/load_error.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theory/theory_question.dart';
import '../../core/widgets/full_latex_view.dart';
import '../../core/widgets/nav/back_navigation.dart';
import '../../core/widgets/ui/ui.dart';

/// `/waec/:subjectId/theory`: Paper 2 questions to work on paper and mark
/// against the scheme. Reached only from a subject tile that appears once
/// there are [kTheoryMinQuestions] published.
class TheoryScreen extends ConsumerStatefulWidget {
  const TheoryScreen({super.key, required this.subjectId});

  final String subjectId;

  @override
  ConsumerState<TheoryScreen> createState() => _TheoryScreenState();
}

class _TheoryScreenState extends ConsumerState<TheoryScreen> {
  TheoryQuestion? _open;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(theoryQuestionsProvider(widget.subjectId));
    final open = _open;
    // Back from a question returns to the list, not out of theory.
    return PopScope(
      canPop: open == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _open = null);
      },
      child: Scaffold(
        appBar: ParagonAppBar(
          title: Text(
            open == null
                ? 'Theory practice'
                : 'WAEC ${open.examYear} · Q${open.number}',
          ),
        ),
        body: async.when(
          loading: () => const PageBody(children: [SkeletonPage()]),
          error: (e, _) => LoadError(
            error: e,
            message: "Couldn't load the theory questions.",
            onRetry: () =>
                ref.invalidate(theoryQuestionsProvider(widget.subjectId)),
          ),
          data: (list) => open != null
              ? _SelfMark(
                  key: ValueKey(open.id),
                  question: open,
                  onBack: () => setState(() => _open = null),
                )
              : PageBody(
                  children: [
                    const PageIntro(
                      // The app bar names the page on a phone.
                      wideOnly: true,
                      title: 'Theory practice',
                      subtitle:
                          'Work each question on paper, then mark yourself '
                          'against the scheme, one step at a time.',
                    ),
                    if (list.isEmpty)
                      const EmptyState(
                        illustration: IllustrationAsset.empty,
                        title: 'No theory questions yet',
                        message:
                            'Paper 2 questions appear here once there are '
                            'enough to practise.',
                      )
                    else
                      RowGroup(
                        children: [
                          for (final q in list)
                            ListRow(
                              icon: Icons.edit_note_rounded,
                              iconColor: AppColors.secondary,
                              title:
                                  'WAEC ${q.examYear} · Question ${q.number}',
                              subtitle: '${q.totalMarks} marks',
                              onTap: () => setState(() => _open = q),
                            ),
                        ],
                      ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _SelfMark extends StatefulWidget {
  const _SelfMark({super.key, required this.question, required this.onBack});

  final TheoryQuestion question;
  final VoidCallback onBack;

  @override
  State<_SelfMark> createState() => _SelfMarkState();
}

class _SelfMarkState extends State<_SelfMark> {
  /// Parts whose scheme is showing.
  final Set<int> _revealed = {};
  final Set<(int, int)> _ticked = {};

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final q = widget.question;
    final done = _revealed.length == q.parts.length;
    return PageBody(
      children: [
        for (final (pi, part) in q.parts.indexed) ...[
          SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '(${part.label}) · ${part.marks} marks',
                  style: AppTheme.caption.copyWith(
                    color: palette.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                FullLatexView(
                  latex: part.prompt,
                  textStyle: AppTheme.bodyLg.copyWith(
                    color: palette.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                if (!_revealed.contains(pi))
                  AppButton(
                    label: 'I have answered it: show the scheme',
                    tone: ButtonTone.secondary,
                    icon: Icons.visibility_outlined,
                    onPressed: () => setState(() => _revealed.add(pi)),
                  )
                else
                  for (final (si, step) in part.scheme.indexed)
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _ticked.contains((pi, si)),
                      onChanged: (v) => setState(
                        () => v == true
                            ? _ticked.add((pi, si))
                            : _ticked.remove((pi, si)),
                      ),
                      title: FullLatexView(latex: step.description),
                      secondary: Text('${step.marks}'),
                    ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (done) ...[
          const SizedBox(height: 8),
          Center(
            child: ScoreRing(
              fraction: q.totalMarks == 0
                  ? 0
                  : selfMarked(q, _ticked) / q.totalMarks,
              label: '${selfMarked(q, _ticked)}/${q.totalMarks}',
              caption: 'marks',
              size: 128,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'You gave yourself ${selfMarked(q, _ticked)}/${q.totalMarks}.',
            textAlign: TextAlign.center,
            style: AppTheme.bodyMd.copyWith(color: palette.textSecondary),
          ),
        ],
        const SizedBox(height: 16),
        Center(
          child: AppButton(
            label: 'All questions',
            tone: ButtonTone.secondary,
            icon: Icons.arrow_back_rounded,
            onPressed: widget.onBack,
          ),
        ),
      ],
    );
  }
}
