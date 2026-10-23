import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/learn/exercise_session.dart';
import '../../core/models/learn_resource.dart';
import '../../core/models/question.dart';
import '../../core/providers/analytics_provider.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/repositories/attempt_repository.dart';
import '../../core/repositories/learn_repository.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/answer_option.dart';
import '../../core/widgets/report_problem_button.dart';
import '../study/notes/notes_widgets.dart' show QuestionBookmarkButton;
import '../../core/theme/app_palette.dart';
import '../../core/learn/hints.dart';
import '../../core/widgets/hint_panel.dart';
import '../../core/repositories/difficulty_vote_repository.dart';
import '../../core/widgets/difficulty_rating.dart';
import '../../core/sound/sfx.dart';
import '../../core/widgets/session/session_frame.dart';
import '../../core/widgets/session/session_summary.dart';
import '../../core/widgets/ui/ui.dart';

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

  /// "How hard was this?" answers for this set, sent once: when the set is
  /// finished, or when the student leaves part-way.
  final Map<String, int> _ratings = {};
  DifficultyVoteRepository? _votes;
  String? _uid;

  LearnResource get r => widget.resource;

  bool get _pinned => r.questionIds.isNotEmpty;

  ExerciseQuery get _query => ExerciseQuery(
    topicId: r.topicId,
    resourceId: r.id,
    questionCount: r.questionCount,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Held: Riverpod 3 forbids `ref` in dispose().
    _votes ??= ref.read(difficultyVoteRepositoryProvider);
    _uid = ref.read(currentUserProvider)?.uid;
  }

  @override
  void dispose() {
    _sendRatings();
    super.dispose();
  }

  void _sendRatings() {
    final uid = _uid;
    if (uid == null || _ratings.isEmpty) return;
    _votes?.submit(uid: uid, votes: Map.of(_ratings));
    _ratings.clear();
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
    _sendRatings();
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
                  hintsUsed: t.hintsUsed,
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
          loading: () => const LoadingView(label: 'Loading questions'),
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

    void pick(int i) {
      if (s.wrongOptions.contains(i)) return;
      Sfx.unlock();
      act(() => s.select(i));
    }

    void check() {
      act(s.check);
      Sfx.play(
        s.step == ExerciseStep.correct ? SfxCue.correct : SfxCue.wrong,
      );
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

    final VoidCallback? primary = resolved
        ? () => act(s.next)
        : (s.canCheck ? check : null);
    final tries = s.firstTries;

    return SessionKeys(
      optionCount: q.options.length,
      onSelect: resolved ? null : pick,
      onEnter: primary,
      // Inside the lesson's own scroll view, so the bar sits under the
      // question rather than pinned to the window.
      child: SessionLayout(
        header: SessionHeader(
          index: s.index,
          total: s.questions.length,
          states: [
            for (var i = 0; i < s.questions.length; i++)
              i < tries.length
                  ? (tries[i].isCorrect
                        ? SegmentState.right
                        : SegmentState.wrong)
                  : SegmentState.pending,
          ],
        ),
        bar: SessionActionBar(
          verdict: switch (s.step) {
            ExerciseStep.correct => SessionVerdict.right,
            ExerciseStep.revealed => SessionVerdict.wrong,
            ExerciseStep.retrying => SessionVerdict.retry,
            _ => SessionVerdict.none,
          },
          label: !resolved
              ? 'Check'
              : (s.index == s.questions.length - 1
                    ? 'See results'
                    : 'Continue'),
          onPressed: primary,
          optionCount: q.options.length,
          message: _Feedback(session: s, question: q),
        ),
        children: [
          QuestionCard(question: q),
          for (var i = 0; i < q.options.length; i++)
            AnswerOption(
              index: i,
              text: q.options[i],
              state: stateFor(i),
              onTap: resolved || s.wrongOptions.contains(i)
                  ? null
                  : () => pick(i),
            ),
          if (s.canHint)
            HintPanel(
              steps: hintSteps(q.explanation),
              shown: s.hintsShown,
              onShowNext: () => act(s.useHint),
            ),
          if (resolved) ...[
            FeedbackPanel(
              question: q,
              right: s.step == ExerciseStep.correct,
              missingNote: null,
            ),
            // On its own line: beside the button it overflowed a phone.
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  ReportProblemButton(
                    questionId: q.id,
                    isGenerated: q.isGenerated,
                  ),
                  QuestionBookmarkButton(question: q),
                ],
              ),
            ),
            // Optional, and never between the student and Continue.
            Align(
              alignment: Alignment.centerLeft,
              child: DifficultyRating(
                selected: _ratings[q.id],
                onRate: (level) => setState(() => _ratings[q.id] = level),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _summary(ExerciseSession s) {
    final total = s.firstTries.length;
    final isGuest = ref.watch(isGuestProvider);
    return SessionSummary(
      title: '${s.firstTryCorrect} of $total right first time',
      correct: s.firstTryCorrect,
      total: total,
      subtitle: isGuest
          ? 'Practice only — guest answers are not saved.'
          : 'Practice only — this does not affect your mastery or the '
                'topic test.',
      celebrate: SessionSummary.isWorthCelebrating(
        correct: s.firstTryCorrect,
        total: total,
      ),
      primary: AppButton(
        label: 'Try another set',
        tone: ButtonTone.secondary,
        icon: Icons.refresh_rounded,
        expand: true,
        onPressed: _newSet,
      ),
    );
  }
}

/// The verdict in the bar: "Correct!", "Not quite — try again." or the
/// right answer, in words and an icon, announced as it appears. The
/// worked answer itself is the page's [FeedbackPanel].
class _Feedback extends StatelessWidget {
  const _Feedback({required this.session, required this.question});

  final ExerciseSession session;
  final Question question;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final (String? headline, Color color, IconData icon) =
        switch (session.step) {
          ExerciseStep.correct => ('Correct!', p.successFg, Icons.check_circle),
          ExerciseStep.retrying => (
            'Not quite — try again.',
            p.warningFg,
            Icons.replay_rounded,
          ),
          ExerciseStep.revealed => (
            'The right answer is '
                '${AnswerOption.letter(question.correctIndex.clamp(0, 25))}.',
            p.dangerFg,
            Icons.cancel,
          ),
          _ => (null, p.textSecondary, Icons.circle),
        };
    if (headline == null) return const SizedBox.shrink();
    return Semantics(
      liveRegion: true,
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              headline,
              style: AppTheme.bodyLg.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
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
