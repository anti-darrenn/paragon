import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../lessons/lesson_doc.dart';
import '../../models/question.dart';
import '../../repositories/learn_repository.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../answer_option.dart';
import '../full_latex_view.dart';
import 'lesson_block_view.dart';

/// A labelled frame shared by the interactive blocks, so a worked example,
/// a problem and a quick check are recognisable at a glance.
class _Frame extends StatelessWidget {
  const _Frame({
    required this.label,
    required this.icon,
    required this.colour,
    required this.child,
    this.title = '',
    this.base,
  });

  final String label;
  final IconData icon;
  final Color colour;
  final String title;
  final TextStyle? base;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        border: Border.all(color: AppColors.borderDark),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: colour),
              const SizedBox(width: 8),
              Text(
                label.toUpperCase(),
                style: AppTheme.label.copyWith(color: colour),
              ),
            ],
          ),
          if (title.isNotEmpty) ...[
            const SizedBox(height: 6),
            FullLatexView(
              latex: title,
              textStyle: AppTheme.heading3.copyWith(
                color: AppColors.textPrimaryDark,
                fontSize: ((base?.fontSize) ?? 16) + 1,
              ),
            ),
          ],
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _RevealButton extends StatelessWidget {
  const _RevealButton({
    required this.label,
    required this.onPressed,
    this.icon,
  });
  final String label;
  final IconData? icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon ?? Icons.visibility_outlined, size: 18),
        label: Text(label),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.label, required this.child, this.colour});
  final String label;
  final Color? colour;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            label,
            style: AppTheme.label.copyWith(
              color: colour ?? AppColors.textSecondaryDark,
            ),
          ),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }
}

// ─── Worked example ───────────────────────────────────────────────────

/// A problem whose solution is revealed one step at a time, so the student
/// can try each step before seeing it.
class WorkedExampleView extends StatefulWidget {
  const WorkedExampleView({
    super.key,
    required this.block,
    required this.base,
    this.authorPreview = false,
  });

  final ExampleBlock block;
  final TextStyle base;

  /// The editor shows every step at once, so the author can proofread.
  final bool authorPreview;

  @override
  State<WorkedExampleView> createState() => _WorkedExampleViewState();
}

class _WorkedExampleViewState extends State<WorkedExampleView> {
  int _shown = 0;

  @override
  Widget build(BuildContext context) {
    final b = widget.block;
    Widget body(List<LessonBlock> blocks) => LessonBlocksColumn(
      blocks: blocks,
      base: widget.base,
      authorPreview: widget.authorPreview,
    );

    // The answer counts as one more thing to reveal after the last step.
    final total = b.steps.length + (b.answer == null ? 0 : 1);
    final shown = widget.authorPreview ? total : _shown;
    final nextIsAnswer = shown == b.steps.length && b.answer != null;

    return _Frame(
      label: 'Worked example',
      icon: Icons.edit_note_rounded,
      colour: AppColors.primary,
      title: b.title,
      base: widget.base,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          body(b.problem),
          for (var i = 0; i < math.min(shown, b.steps.length); i++)
            _Section(
              label: b.steps[i].title.isEmpty
                  ? 'STEP ${i + 1}'
                  : 'STEP ${i + 1} · ${b.steps[i].title.toUpperCase()}',
              child: body(b.steps[i].body),
            ),
          if (b.answer != null && shown == total)
            _Section(
              label: 'ANSWER',
              colour: AppColors.correct,
              child: body(b.answer!),
            ),
          if (shown < total) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                _RevealButton(
                  label: nextIsAnswer
                      ? 'Show the answer'
                      : shown == 0
                      ? 'Show the first step'
                      : 'Show next step',
                  icon: Icons.arrow_downward_rounded,
                  onPressed: () => setState(() => _shown++),
                ),
                if (total - shown > 1)
                  TextButton(
                    onPressed: () => setState(() => _shown = total),
                    child: const Text('Show all'),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Try it yourself ──────────────────────────────────────────────────

class TryItView extends StatefulWidget {
  const TryItView({
    super.key,
    required this.block,
    required this.base,
    this.authorPreview = false,
  });

  final TryItBlock block;
  final TextStyle base;
  final bool authorPreview;

  @override
  State<TryItView> createState() => _TryItViewState();
}

class _TryItViewState extends State<TryItView> {
  bool _hint = false;
  bool _answer = false;

  @override
  Widget build(BuildContext context) {
    final b = widget.block;
    final showHint = widget.authorPreview || _hint;
    final showAnswer = widget.authorPreview || _answer;
    Widget body(List<LessonBlock> blocks) => LessonBlocksColumn(
      blocks: blocks,
      base: widget.base,
      authorPreview: widget.authorPreview,
    );

    return _Frame(
      label: 'Try it yourself',
      icon: Icons.psychology_alt_outlined,
      colour: AppColors.secondary,
      title: b.title,
      base: widget.base,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          body(b.problem),
          if (b.hint != null && showHint)
            _Section(label: 'HINT', child: body(b.hint!)),
          if (b.answer != null && showAnswer)
            _Section(
              label: 'ANSWER',
              colour: AppColors.correct,
              child: body(b.answer!),
            ),
          if ((b.hint != null && !showHint) ||
              (b.answer != null && !showAnswer)) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                if (b.hint != null && !showHint)
                  _RevealButton(
                    label: 'Show a hint',
                    icon: Icons.lightbulb_outline_rounded,
                    onPressed: () => setState(() => _hint = true),
                  ),
                if (b.answer != null && !showAnswer)
                  _RevealButton(
                    label: 'Show the answer',
                    onPressed: () => setState(() => _answer = true),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Quick checks ─────────────────────────────────────────────────────

/// The shared multiple-choice interaction for written checks and bank
/// questions: pick once, see right or wrong and the explanation, try again.
///
/// **Nothing is recorded.** Quick checks are formative; answers never reach
/// `attempts` or the mastery counters (only drill feeds those — CLAUDE.md).
class _ChoiceQuestion extends StatefulWidget {
  const _ChoiceQuestion({
    required this.question,
    required this.options,
    required this.correctIndex,
    required this.why,
  });

  final Widget question;
  final List<String> options;

  /// -1 when no single right answer is known: the options are shown but
  /// nothing is judged.
  final int correctIndex;
  final Widget? why;

  @override
  State<_ChoiceQuestion> createState() => _ChoiceQuestionState();
}

class _ChoiceQuestionState extends State<_ChoiceQuestion> {
  int? _picked;

  @override
  Widget build(BuildContext context) {
    final judged = widget.correctIndex >= 0;
    final picked = _picked;
    final answered = picked != null;
    final right = answered && picked == widget.correctIndex;

    AnswerOptionState stateFor(int i) {
      if (!answered) return AnswerOptionState.idle;
      if (i == widget.correctIndex) return AnswerOptionState.correct;
      if (i == picked) return AnswerOptionState.wrong;
      return AnswerOptionState.ruledOut;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        widget.question,
        const SizedBox(height: 12),
        for (var i = 0; i < widget.options.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: AnswerOption(
              index: i,
              text: widget.options[i],
              state: stateFor(i),
              onTap: judged && !answered
                  ? () => setState(() => _picked = i)
                  : null,
            ),
          ),
        if (answered) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(
                right ? Icons.check_circle_rounded : Icons.cancel_rounded,
                size: 18,
                color: right ? AppColors.correct : AppColors.wrong,
              ),
              const SizedBox(width: 8),
              Text(
                right
                    ? 'Correct'
                    : 'Not quite. The answer is ${AnswerOption.letter(widget.correctIndex)}.',
                style: AppTheme.bodyMd.copyWith(
                  color: right ? AppColors.correct : AppColors.wrong,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => setState(() => _picked = null),
                child: const Text('Try again'),
              ),
            ],
          ),
          if (widget.why != null) _Section(label: 'WHY', child: widget.why!),
        ],
      ],
    );
  }
}

class QuickCheckView extends StatelessWidget {
  const QuickCheckView({
    super.key,
    required this.block,
    required this.base,
    this.authorPreview = false,
  });

  final CheckBlock block;
  final TextStyle base;
  final bool authorPreview;

  @override
  Widget build(BuildContext context) {
    Widget body(List<LessonBlock> blocks) => LessonBlocksColumn(
      blocks: blocks,
      base: base,
      authorPreview: authorPreview,
    );
    return _Frame(
      label: 'Quick check',
      icon: Icons.task_alt_rounded,
      colour: AppColors.correct,
      child: _ChoiceQuestion(
        question: body(block.question),
        options: [for (final o in block.options) o.text],
        correctIndex: block.correctIndex,
        why: block.why == null ? null : body(block.why!),
      ),
    );
  }
}

/// A question from the bank, by id. `::: waec` labels it as a real past
/// question with its year.
class BankQuestionView extends ConsumerWidget {
  const BankQuestionView({super.key, required this.block, required this.base});

  final BankQuestionBlock block;
  final TextStyle base;

  String _label(Question q) {
    if (!block.isPastQuestion) return 'Quick check';
    return q.year == null ? 'Seen in WAEC' : 'Seen in WAEC ${q.year}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(pinnedQuestionsProvider(block.questionId));
    final q = async.asData?.value.firstOrNull;
    final loading = async.isLoading;

    return _Frame(
      label: q == null
          ? (block.isPastQuestion ? 'Seen in WAEC' : 'Quick check')
          : _label(q),
      icon: block.isPastQuestion
          ? Icons.history_edu_rounded
          : Icons.task_alt_rounded,
      colour: block.isPastQuestion ? AppColors.primary : AppColors.correct,
      child: q == null
          ? (loading
                ? const LinearProgressIndicator(minHeight: 2)
                : Text(
                    'This question is no longer available.',
                    style: base.copyWith(color: AppColors.textSecondaryDark),
                  ))
          : _ChoiceQuestion(
              question: FullLatexView(latex: q.text, textStyle: base),
              options: q.options,
              correctIndex: q.correctIndex,
              why: q.explanation.trim().isEmpty
                  ? null
                  : FullLatexView(latex: q.explanation, textStyle: base),
            ),
    );
  }
}

// ─── Revision card ────────────────────────────────────────────────────

class FlipCardView extends StatefulWidget {
  const FlipCardView({
    super.key,
    required this.front,
    required this.back,
    required this.base,
  });

  final String front;
  final String back;
  final TextStyle base;

  @override
  State<FlipCardView> createState() => _FlipCardViewState();
}

class _FlipCardViewState extends State<FlipCardView> {
  bool _flipped = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: _flipped
          ? 'Revision card, answer side'
          : 'Revision card, tap to see the answer',
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() => _flipped = !_flipped),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Container(
            key: ValueKey(_flipped),
            constraints: const BoxConstraints(minHeight: 96),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _flipped
                  ? AppColors.secondary.withAlpha(28)
                  : AppColors.surfaceDark,
              border: Border.all(
                color: _flipped ? AppColors.secondary : AppColors.borderDark,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.style_outlined,
                      size: 16,
                      color: AppColors.secondary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _flipped ? 'ANSWER' : 'REVISION CARD',
                      style: AppTheme.label.copyWith(
                        color: AppColors.secondary,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _flipped ? 'Tap to flip back' : 'Tap to flip',
                      style: AppTheme.caption.copyWith(
                        color: AppColors.textSecondaryDark,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                FullLatexView(
                  latex: _flipped ? widget.back : widget.front,
                  textStyle: widget.base,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
