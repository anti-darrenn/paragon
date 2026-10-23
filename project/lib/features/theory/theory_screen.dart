import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    return Scaffold(
      appBar: ParagonAppBar(
        title: Text(
          open == null
              ? 'Theory practice'
              : 'WAEC ${open.examYear} · Q${open.number}',
        ),
      ),
      body: async.when(
        loading: () => const PageBody(children: [SkeletonPage()]),
        error: (_, _) => const EmptyState(
          icon: Icons.error_outline,
          title: "Couldn't load the theory questions",
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
                    title: 'Theory practice',
                    subtitle:
                        'Work each question on paper, then mark yourself '
                        'against the scheme, one step at a time.',
                  ),
                  RowGroup(
                    children: [
                      for (final q in list)
                        ListRow(
                          title: 'WAEC ${q.examYear} · Question ${q.number}',
                          subtitle: '${q.totalMarks} marks',
                          onTap: () => setState(() => _open = q),
                        ),
                    ],
                  ),
                ],
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
                  OutlinedButton(
                    onPressed: () => setState(() => _revealed.add(pi)),
                    child: const Text('I have answered it: show the scheme'),
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
        if (done)
          Text(
            'You gave yourself ${selfMarked(q, _ticked)}/${q.totalMarks}.',
            textAlign: TextAlign.center,
            style: AppTheme.heading3.copyWith(color: context.palette.primaryFg),
          ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: widget.onBack,
          child: const Text('All questions'),
        ),
      ],
    );
  }
}
