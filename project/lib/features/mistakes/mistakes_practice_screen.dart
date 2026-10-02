import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/question.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/repositories/attempt_repository.dart';
import '../../core/repositories/mistakes_repository.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/answer_option.dart';
import '../../core/widgets/full_latex_view.dart';
import '../../core/widgets/question_image.dart';
import '../../core/widgets/report_problem_button.dart';
import '../../core/widgets/nav/back_navigation.dart';

/// `/mistakes/practice`: the notebook's questions again, one at a time,
/// with immediate feedback, as in drill.
///
/// Answers are recorded once, at the end, as `source: 'review'`. They
/// **never** reach `ProgressRepository`: mastery at proficient opens drill
/// by itself, so practising old mistakes must not count toward it, for
/// the same reason the topic test and exercises do not. A right answer
/// still clears the question from the notebook, because it is now the
/// latest attempt.
class MistakesPracticeScreen extends ConsumerStatefulWidget {
  const MistakesPracticeScreen({super.key, required this.questions});

  /// Null when the page was opened without the notebook (a reload or a
  /// typed URL): there is then nothing to practise.
  final List<Question>? questions;

  @override
  ConsumerState<MistakesPracticeScreen> createState() =>
      _MistakesPracticeScreenState();
}

class _MistakesPracticeScreenState
    extends ConsumerState<MistakesPracticeScreen> {
  int _index = 0;
  int? _selected;
  bool _checked = false;
  final _answers = <AttemptDraft>[];

  bool _saving = false;
  bool _saved = false;
  bool _saveFailed = false;

  List<Question> get _questions => widget.questions ?? const [];

  void _check() {
    final q = _questions[_index];
    setState(() {
      _checked = true;
      _answers.add(
        AttemptDraft(
          questionId: q.id,
          topicId: q.topicId,
          subjectId: q.subjectId,
          selectedIndex: _selected!,
          isCorrect: _selected == q.correctIndex,
        ),
      );
    });
  }

  void _next() {
    setState(() {
      _index++;
      _selected = null;
      _checked = false;
    });
    if (_index == _questions.length) _save();
  }

  Future<void> _save() async {
    final user = ref.read(currentUserProvider);
    if (user == null || _answers.isEmpty) return;
    setState(() {
      _saving = true;
      _saveFailed = false;
    });
    try {
      await ref
          .read(attemptRepositoryProvider)
          .recordBatch(userId: user.uid, source: 'review', attempts: _answers);
      if (!mounted) return;
      setState(() => _saved = true);
      // the notebook re-reads, so questions answered right here leave it
      ref.invalidate(mistakesProvider);
    } catch (_) {
      if (mounted) setState(() => _saveFailed = true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.palette.background,
      appBar: ParagonAppBar(title: const Text('Practise mistakes')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: _questions.isEmpty
              ? _Message(
                  text:
                      'Open your mistakes notebook to choose what to practise.',
                  action: 'Go to the notebook',
                  onAction: () => context.go('/mistakes'),
                )
              : _index >= _questions.length
              ? _summary(context)
              : _question(context),
        ),
      ),
    );
  }

  Widget _question(BuildContext context) {
    final q = _questions[_index];
    final right = _checked && _selected == q.correctIndex;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
      children: [
        Text(
          'Question ${_index + 1} of ${_questions.length}',
          style: AppTheme.caption.copyWith(
            color: context.palette.textSecondary,
          ),
        ),
        const SizedBox(height: 12),
        FullLatexView(
          latex: q.text,
          textStyle: AppTheme.bodyLg.copyWith(
            color: context.palette.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        QuestionImage(assetId: q.imageId),
        const SizedBox(height: 20),
        for (var i = 0; i < q.options.length; i++)
          AnswerOption(
            index: i,
            text: q.options[i],
            state: !_checked
                ? (_selected == i
                      ? AnswerOptionState.selected
                      : AnswerOptionState.idle)
                : i == q.correctIndex
                ? AnswerOptionState.correct
                : i == _selected
                ? AnswerOptionState.wrong
                : AnswerOptionState.idle,
            onTap: _checked ? null : () => setState(() => _selected = i),
          ),
        if (_checked) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: (right ? AppColors.correct : AppColors.wrong).withAlpha(
                26,
              ),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: (right ? AppColors.correct : AppColors.wrong).withAlpha(
                  102,
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  right ? 'Right this time.' : 'Not yet.',
                  style: AppTheme.bodyMd.copyWith(
                    color: right ? AppColors.correct : AppColors.wrong,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (q.explanation.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  FullLatexView(
                    latex: q.explanation,
                    textStyle: AppTheme.bodyMd.copyWith(
                      color: context.palette.onHigh,
                    ),
                  ),
                ],
                QuestionImage(assetId: q.explanationImageId),
              ],
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: ReportProblemButton(questionId: q.id),
          ),
        ],
        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: _checked ? _next : (_selected == null ? null : _check),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: Text(
            !_checked
                ? 'Check'
                : _index + 1 == _questions.length
                ? 'Finish'
                : 'Next',
            style: AppTheme.btnLabel.copyWith(color: Colors.white),
          ),
        ),
      ],
    );
  }

  Widget _summary(BuildContext context) {
    final right = _answers.where((a) => a.isCorrect).length;
    final total = _answers.length;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 40, 16, 40),
      children: [
        Text(
          '$right of $total right',
          textAlign: TextAlign.center,
          style: AppTheme.heading1.copyWith(color: context.palette.textPrimary),
        ),
        const SizedBox(height: 8),
        Text(
          right == 0
              ? 'These stay in your notebook for next time.'
              : right == total
              ? 'All $total have left your notebook.'
              : '$right ${right == 1 ? 'has' : 'have'} left your notebook. '
                    'The rest stay for next time.',
          textAlign: TextAlign.center,
          style: AppTheme.bodyMd.copyWith(color: context.palette.textSecondary),
        ),
        const SizedBox(height: 24),
        if (_saving)
          const Center(child: CircularProgressIndicator())
        else if (_saveFailed)
          _Message(
            text:
                "Your answers couldn't be saved, so the notebook hasn't "
                'changed. Check your connection.',
            action: 'Try again',
            onAction: _save,
          )
        else if (_saved)
          OutlinedButton(
            onPressed: () => context.popOrGo(),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: const Text('Back to the notebook'),
          ),
      ],
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.text,
    required this.action,
    required this.onAction,
  });

  final String text;
  final String action;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            text,
            textAlign: TextAlign.center,
            style: AppTheme.bodyMd.copyWith(
              color: context.palette.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          TextButton(onPressed: onAction, child: Text(action)),
        ],
      ),
    );
  }
}
