import 'package:flutter/material.dart';

import '../models/question.dart';
import '../sound/sfx.dart';
import '../theme/tokens.dart';
import 'answer_option.dart';
import 'difficulty_rating.dart';
import 'session/session_frame.dart';
import 'ui/ui.dart';

/// A short run of questions with instant feedback: pick, check, see right
/// or wrong and the worked answer, go on. For the guest taster and a
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
  bool _checked = false;
  final _results = <({Question question, int selected, bool correct})>[];
  final _scroll = ScrollController();
  final _feedbackKey = GlobalKey();

  Question get _q => widget.questions[_index];
  bool get _isLast => _index == widget.questions.length - 1;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _pick(int i) {
    if (_checked) return;
    // Browsers only start audio inside a gesture: wake it on the tap.
    Sfx.unlock();
    setState(() => _selected = i);
  }

  void _check() {
    final selected = _selected;
    if (selected == null || _checked) return;
    final right = selected == _q.correctIndex;
    Sfx.play(right ? SfxCue.correct : SfxCue.wrong);
    setState(() {
      _checked = true;
      _results.add((question: _q, selected: selected, correct: right));
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _feedbackKey.currentContext;
      if (target == null || !mounted) return;
      Scrollable.ensureVisible(
        target,
        alignment: 0.1,
        alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
        duration: Motion.of(context, Motion.medium),
        curve: Motion.curve,
      );
    });
  }

  void _next() {
    if (_isLast) {
      widget.onFinished(List.unmodifiable(_results));
      return;
    }
    setState(() {
      _index++;
      _selected = null;
      _checked = false;
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  AnswerOptionState _stateOf(int i) {
    if (!_checked) {
      return i == _selected
          ? AnswerOptionState.selected
          : AnswerOptionState.idle;
    }
    if (i == _q.correctIndex) return AnswerOptionState.correct;
    if (i == _selected) return AnswerOptionState.wrong;
    return AnswerOptionState.ruledOut;
  }

  @override
  Widget build(BuildContext context) {
    final q = _q;
    final right = _checked && _selected == q.correctIndex;
    final VoidCallback? primary = _checked
        ? _next
        : (_selected == null ? null : _check);
    return SessionKeys(
      optionCount: q.options.length,
      onSelect: _checked ? null : _pick,
      onEnter: primary,
      child: SessionLayout(
        controller: _scroll,
        header: SessionHeader(
          index: _index,
          total: widget.questions.length,
          states: [
            for (var i = 0; i < widget.questions.length; i++)
              i < _results.length
                  ? (_results[i].correct
                        ? SegmentState.right
                        : SegmentState.wrong)
                  : SegmentState.pending,
          ],
        ),
        bar: SessionActionBar(
          verdict: !_checked
              ? SessionVerdict.none
              : (right ? SessionVerdict.right : SessionVerdict.wrong),
          label: !_checked ? 'Check' : (_isLast ? 'See results' : 'Continue'),
          onPressed: primary,
          optionCount: q.options.length,
          message: _checked
              ? AnswerVerdict(
                  right: right,
                  correctIndex: q.correctIndex,
                  padding: EdgeInsets.zero,
                )
              : null,
        ),
        children: [
          QuestionCard(question: q, showDifficulty: widget.showDifficulty),
          for (var i = 0; i < q.options.length; i++)
            AnswerOption(
              index: i,
              text: q.options[i],
              state: _stateOf(i),
              onTap: _checked ? null : () => _pick(i),
            ),
          if (_checked) ...[
            FeedbackPanel(
              key: _feedbackKey,
              question: q,
              right: right,
              missingNote: null,
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
      ),
    );
  }
}
