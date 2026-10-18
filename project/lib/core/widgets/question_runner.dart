import 'package:flutter/material.dart';

import '../models/question.dart';
import '../theme/app_colors.dart';
import '../theme/app_palette.dart';
import '../theme/app_theme.dart';
import 'answer_option.dart';
import 'difficulty_rating.dart';
import 'full_latex_view.dart';
import 'question_image.dart';
import 'question_source_badge.dart';

/// A short run of questions with instant feedback: pick, see right or
/// wrong and the worked answer, go on. For the guest taster and a
/// friend's challenge link — places that should feel like Paragon in a
/// minute, without drill's gate, hints or mastery.
///
/// Records nothing itself; [onFinished] gets each question's choice and
/// whether it was right, and the caller decides what to store.
class QuestionRunner extends StatefulWidget {
  const QuestionRunner({
    super.key,
    required this.questions,
    required this.onFinished,
    this.showDifficulty = true,
    this.ratings,
  });

  /// Off for questions made from a student's own flashcards.
  final bool showDifficulty;

  /// When given, "How hard was this?" is offered under each answer and the
  /// choices land here, for the caller to send once (practice only).
  final Map<String, int>? ratings;

  final List<Question> questions;
  final void Function(List<({Question question, int selected, bool correct})>)
  onFinished;

  @override
  State<QuestionRunner> createState() => _QuestionRunnerState();
}

class _QuestionRunnerState extends State<QuestionRunner> {
  int _index = 0;
  int? _selected;
  final _results = <({Question question, int selected, bool correct})>[];

  Question get _q => widget.questions[_index];
  bool get _answered => _selected != null;

  void _pick(int i) {
    if (_answered) return;
    setState(() {
      _selected = i;
      _results.add((question: _q, selected: i, correct: i == _q.correctIndex));
    });
  }

  void _next() {
    if (_index == widget.questions.length - 1) {
      widget.onFinished(List.unmodifiable(_results));
      return;
    }
    setState(() {
      _index++;
      _selected = null;
    });
  }

  AnswerOptionState _stateOf(int i) {
    if (!_answered) return AnswerOptionState.idle;
    if (i == _q.correctIndex) return AnswerOptionState.correct;
    if (i == _selected) return AnswerOptionState.wrong;
    return AnswerOptionState.ruledOut;
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final q = _q;
    final right = _answered && _selected == q.correctIndex;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Question ${_index + 1} of ${widget.questions.length}',
          style: AppTheme.caption.copyWith(color: palette.textSecondary),
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: (_index + (_answered ? 1 : 0)) / widget.questions.length,
          minHeight: 3,
          backgroundColor: palette.track,
          color: AppColors.primary,
        ),
        const SizedBox(height: 16),
        QuestionSourceBadge(question: q, showDifficulty: widget.showDifficulty),
        FullLatexView(
          latex: q.text,
          textStyle: AppTheme.bodyLg.copyWith(
            color: palette.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        QuestionImage(assetId: q.imageId),
        const SizedBox(height: 16),
        for (var i = 0; i < q.options.length; i++)
          AnswerOption(
            index: i,
            text: q.options[i],
            state: _stateOf(i),
            onTap: _answered ? null : () => _pick(i),
          ),
        if (_answered) ...[
          const SizedBox(height: 4),
          AnswerVerdict(right: right, correctIndex: q.correctIndex),
          if (q.explanation.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            FullLatexView(
              latex: q.explanation,
              textStyle: AppTheme.bodyMd.copyWith(color: palette.textPrimary),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            height: 48,
            child: ElevatedButton(
              autofocus: true,
              onPressed: _next,
              child: Text(
                _index == widget.questions.length - 1
                    ? 'See how you did'
                    : 'Next',
              ),
            ),
          ),
          if (widget.ratings case final ratings?)
            Align(
              alignment: Alignment.centerLeft,
              child: DifficultyRating(
                selected: ratings[q.id],
                onRate: (level) => setState(() => ratings[q.id] = level),
              ),
            ),
        ],
      ],
    );
  }
}
