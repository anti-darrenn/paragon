import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/learn/exercise_session.dart';
import '../../core/models/learn_resource.dart';
import '../../core/models/question.dart';
import '../../core/providers/analytics_provider.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/repositories/attempt_repository.dart';
import '../../core/repositories/learn_repository.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/answer_option.dart';
import '../../core/widgets/full_latex_view.dart';
import '../../core/widgets/report_problem_button.dart';
import '../study/notes/notes_widgets.dart' show QuestionBookmarkButton;
import '../../core/theme/app_palette.dart';

/// An in-lesson exercise: a short set of questions with immediate
/// feedback, Khan-style. The rules live in [ExerciseSession].
///
/// **What this writes, and what it must never write.** A signed-in
/// student's first tries are recorded once, when the set ends, as attempts
/// with `source: 'exercise'`. Nothing here may call
/// `ProgressRepository.addSession`: mastery at proficient opens drill on
/// its own (`drillAccessFor`), so exercise answers feeding it would be a
/// way around the topic test. Guests record nothing. A set abandoned
/// halfway records nothing either — only finished sets are evidence.
class ExercisePane extends ConsumerStatefulWidget {
  const ExercisePane({
    super.key,
    required this.resource,
    this.onFinished,
    this.recordAttempts = true,
  });

  final LearnResource resource;

  /// Called once per finished set — the lesson marks the item complete.
  final VoidCallback? onFinished;

  /// False in the editor's preview.
  final bool recordAttempts;

  @override
  ConsumerState<ExercisePane> createState() => _ExercisePaneState();
}

class _ExercisePaneState extends ConsumerState<ExercisePane> {
  ExerciseSession? _session;
  List<Question>? _sessionFor;
  final _focus = FocusNode();

  LearnResource get r => widget.resource;

  bool get _pinned => r.questionIds.isNotEmpty;

  ExerciseQuery get _query => ExerciseQuery(
    topicId: r.topicId,
    resourceId: r.id,
    questionCount: r.questionCount,
  );

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  void _newSet() {
    setState(() {
      _session = null;
      _sessionFor = null;
    });
    if (!_pinned) ref.invalidate(exerciseQuestionsProvider(_query));
  }

  Future<void> _finish(ExerciseSession s) async {
    widget.onFinished?.call();
    if (!widget.recordAttempts) return;

    ref
        .read(analyticsProvider)
        .exerciseCompleted(
          topicId: r.topicId,
          correct: s.firstTryCorrect,
          total: s.firstTries.length,
        );

    final user = ref.read(currentUserProvider);
    if (user == null || user.isAnonymous || s.firstTries.isEmpty) return;
    try {
      await ref
          .read(attemptRepositoryProvider)
          .recordBatch(
            userId: user.uid,
            source: 'exercise',
            attempts: [
              for (final t in s.firstTries)
                AttemptDraft(
                  questionId: t.questionId,
                  topicId: r.topicId,
                  subjectId: r.subjectId,
                  selectedIndex: t.selectedIndex,
                  isCorrect: t.isCorrect,
                ),
            ],
          );
    } catch (_) {
      // Practice history is not worth interrupting a lesson over.
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = _pinned
        ? ref.watch(pinnedQuestionsProvider(r.questionIds.join(',')))
        : ref.watch(exerciseQuestionsProvider(_query));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'EXERCISE',
          style: AppTheme.caption.copyWith(
            color: context.palette.textSecondary,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          r.title,
          style: AppTheme.heading2.copyWith(color: context.palette.textPrimary),
        ),
        const SizedBox(height: 20),
        async.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(40),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, _) => _Note(
            "These questions couldn't be loaded. Check your connection and "
            'try again.',
            action: TextButton(onPressed: _newSet, child: const Text('Retry')),
          ),
          data: (questions) {
            if (questions.isEmpty) {
              return const _Note(
                'No practice questions for this topic yet. Carry on with the '
                'next lesson.',
              );
            }
            if (!identical(_sessionFor, questions)) {
              _sessionFor = questions;
              _session = ExerciseSession(questions);
            }
            return _body(_session!);
          },
        ),
      ],
    );
  }

  Widget _body(ExerciseSession s) {
    if (s.isFinished) return _summary(s);
    final q = s.current!;

    void act(VoidCallback change) {
      setState(change);
      if (s.isFinished) _finish(s);
    }

    final resolved =
        s.step == ExerciseStep.correct || s.step == ExerciseStep.revealed;

    AnswerOptionState stateFor(int i) {
      if (resolved && i == q.correctIndex) return AnswerOptionState.correct;
      if (s.step == ExerciseStep.revealed && i == s.selected) {
        return AnswerOptionState.wrong;
      }
      if (s.wrongOptions.contains(i)) return AnswerOptionState.ruledOut;
      if (i == s.selected) return AnswerOptionState.selected;
      return AnswerOptionState.idle;
    }

    final primary = resolved
        ? (
            label: s.index == s.questions.length - 1
                ? 'Finish'
                : 'Next question',
            onPressed: () => act(s.next),
          )
        : (label: 'Check', onPressed: s.canCheck ? () => act(s.check) : null);

    return Focus(
      focusNode: _focus,
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        final digit = int.tryParse(event.logicalKey.keyLabel);
        if (digit != null && digit >= 1 && digit <= q.options.length) {
          act(() => s.select(digit - 1));
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.enter &&
            primary.onPressed != null) {
          primary.onPressed!();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Dots(session: s),
          const SizedBox(height: 20),
          FullLatexView(
            latex: q.text,
            textStyle: AppTheme.bodyLg.copyWith(
              color: context.palette.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 20),
          for (var i = 0; i < q.options.length; i++)
            AnswerOption(
              index: i,
              text: q.options[i],
              state: stateFor(i),
              onTap: resolved || s.wrongOptions.contains(i)
                  ? null
                  : () => act(() => s.select(i)),
            ),
          _Feedback(session: s, question: q),
          const SizedBox(height: 8),
          // On its own line: beside the button it overflowed a phone.
          if (resolved)
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  ReportProblemButton(questionId: q.id),
                  QuestionBookmarkButton(question: q),
                ],
              ),
            ),
          Row(
            children: [
              const Spacer(),
              ElevatedButton(
                onPressed: primary.onPressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(140, 44),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(primary.label),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Keys 1–${q.options.length} choose an answer, Enter checks it.',
            style: AppTheme.caption.copyWith(
              color: context.palette.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _summary(ExerciseSession s) {
    final total = s.firstTries.length;
    final isGuest = ref.watch(isGuestProvider);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: context.palette.surface,
        border: Border.all(color: context.palette.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${s.firstTryCorrect} of $total right first time',
            style: AppTheme.heading2.copyWith(
              color: context.palette.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isGuest
                ? 'Practice only — guest answers are not saved.'
                : 'Practice only — this does not affect your mastery or the '
                      'topic test.',
            style: AppTheme.bodyMd.copyWith(
              color: context.palette.textSecondary,
            ),
          ),
          const SizedBox(height: 20),
          OutlinedButton(
            onPressed: _newSet,
            child: const Text('Try another set'),
          ),
        ],
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.session});

  final ExerciseSession session;

  @override
  Widget build(BuildContext context) {
    final tries = session.firstTries;
    return Semantics(
      label: 'Question ${session.index + 1} of ${session.questions.length}',
      child: Row(
        children: [
          for (var i = 0; i < session.questions.length; i++)
            Container(
              width: 28,
              height: 6,
              margin: const EdgeInsets.only(right: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(3),
                color: i < tries.length
                    ? (tries[i].isCorrect ? AppColors.correct : AppColors.wrong)
                    : i == session.index
                    ? AppColors.primary
                    : context.palette.track,
              ),
            ),
        ],
      ),
    );
  }
}

class _Feedback extends StatelessWidget {
  const _Feedback({required this.session, required this.question});

  final ExerciseSession session;
  final Question question;

  @override
  Widget build(BuildContext context) {
    final (String? headline, Color color) = switch (session.step) {
      ExerciseStep.correct => ('Correct!', AppColors.correct),
      ExerciseStep.retrying => ('Not quite — try again.', AppColors.warning),
      ExerciseStep.revealed => (
        'The right answer is ${AnswerOption.letter(question.correctIndex.clamp(0, 25))}.',
        AppColors.wrong,
      ),
      _ => (null, context.palette.textSecondary),
    };
    if (headline == null) return const SizedBox.shrink();

    final showExplanation =
        (session.step == ExerciseStep.correct ||
            session.step == ExerciseStep.revealed) &&
        question.explanation.trim().isNotEmpty;

    return Semantics(
      liveRegion: true,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withAlpha(26),
          border: Border.all(color: color.withAlpha(102)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              headline,
              style: AppTheme.bodyMd.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (showExplanation) ...[
              const SizedBox(height: 8),
              FullLatexView(
                latex: question.explanation,
                textStyle: AppTheme.bodyMd.copyWith(
                  color: context.palette.onHigh,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note(this.text, {this.action});

  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            text,
            style: AppTheme.bodyMd.copyWith(
              color: context.palette.textSecondary,
            ),
          ),
          ?action,
        ],
      ),
    );
  }
}
