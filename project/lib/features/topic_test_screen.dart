import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/learn/topic_test.dart';
import '../core/web/browser.dart';
import '../core/models/question.dart';
import '../core/providers/analytics_provider.dart';
import '../core/providers/auth_provider.dart';
import '../core/repositories/attempt_repository.dart';
import '../core/repositories/learn_progress_repository.dart';
import '../core/repositories/learn_repository.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';
import '../core/widgets/full_latex_view.dart';
import '../core/widgets/session/session_frame.dart';
import '../core/widgets/session/session_summary.dart';
import '../core/widgets/ui/ui.dart';
import '../core/widgets/guest_notice.dart';
import '../core/widgets/answer_option.dart';
import '../core/widgets/report_problem_button.dart';
import '../core/widgets/load_error.dart';
import '../core/study/study_dock.dart';
import '../core/study/study_tool.dart';
import 'lesson/lesson_nudge.dart';
import '../core/theme/app_palette.dart';
import '../core/widgets/question_image.dart';
import '../core/widgets/nav/back_navigation.dart';
import '../core/widgets/session_title.dart';

/// The topic test — the gate that opens drill for one topic.
///
/// **Not a drill, and deliberately shaped to feel different.** Drill gives
/// feedback after every answer; this gives none until the end. That is not
/// a stylistic choice: a test that told you the answer as you went would
/// be a drill with a score attached, and CLAUDE.md is emphatic that the
/// product's modes must not quietly merge into one another. It is closer
/// to WAEC mode in shape, and scoped to a single topic.
///
/// Answers can be changed while the test is in progress, and the student
/// can move backwards through it. Unlimited retakes make that generous
/// rather than exploitable, and a locked-forward test on a ten-question
/// gate only punishes misclicks.
class TopicTestScreen extends ConsumerStatefulWidget {
  const TopicTestScreen({
    super.key,
    required this.subjectId,
    required this.unitId,
    required this.topicId,
  });

  final String subjectId;
  final String unitId;
  final String topicId;

  @override
  ConsumerState<TopicTestScreen> createState() => _TopicTestScreenState();
}

class _TopicTestScreenState extends ConsumerState<TopicTestScreen> {
  int _index = 0;

  /// Selected option per question index. Sparse — an unanswered question
  /// is simply absent, which is what [_answeredCount] counts.
  final Map<int, int> _answers = {};

  bool _submitted = false;

  /// Looking back through a marked test (`_Review`). In memory only.
  bool _reviewing = false;
  bool _saving = false;
  bool _saveFailed = false;

  /// The record as it stood *before* this attempt.
  ///
  /// Captured on the way in rather than read at submit time, because
  /// `recordAttempt` writes to the same document the stream is watching:
  /// reading it afterwards would race the update and could roll `passed`
  /// or `bestScore` backwards.
  TopicTestRecord? _priorRecord;

  int _correct = 0;
  int _total = 0;

  int get _answeredCount => _answers.length;

  void _select(int optionIndex) {
    if (_submitted) return;
    setState(() => _answers[_index] = optionIndex);
    // From the first answer on, closing the tab asks first — the same
    // moment the back button starts asking (web only).
    setLeaveGuard(true);
  }

  @override
  void dispose() {
    setLeaveGuard(false);
    super.dispose();
  }

  Future<void> _submit(List<Question> questions) async {
    if (_submitted || _saving) return;

    var correct = 0;
    final drafts = <AttemptDraft>[];
    for (var i = 0; i < questions.length; i++) {
      final q = questions[i];
      final selected = _answers[i];
      if (selected == null) continue;
      final isCorrect = selected == q.correctIndex;
      if (isCorrect) correct++;
      drafts.add(
        AttemptDraft(
          questionId: q.id,
          topicId: q.topicId,
          subjectId: q.subjectId,
          selectedIndex: selected,
          isCorrect: isCorrect,
        ),
      );
    }

    // Scored out of the whole test, not out of what was attempted. A
    // student who answers two questions correctly and leaves eight blank
    // has scored 20%, not 100% — otherwise the gate opens for anyone
    // willing to skip everything they are unsure of.
    setLeaveGuard(false);
    setState(() {
      _submitted = true;
      _saving = true;
      _saveFailed = false;
      _correct = correct;
      _total = questions.length;
    });

    final user = ref.read(currentUserProvider);
    if (user == null) {
      setState(() => _saving = false);
      return;
    }

    final subjectId = questions.isEmpty ? '' : questions.first.subjectId;
    try {
      await ref
          .read(attemptRepositoryProvider)
          .recordBatch(
            userId: user.uid,
            // Its own source value. Drill queries filter on `source`, and
            // a test answer must never be mistaken for drill practice —
            // nor feed the mastery counters that grandfather the gate,
            // which would let passing a test raise the very mastery level
            // that is an alternative way through it.
            source: 'test',
            attempts: drafts,
          );

      await ref
          .read(learnProgressRepositoryProvider)
          .recordAttempt(
            uid: user.uid,
            topicId: widget.topicId,
            subjectId: subjectId,
            correct: correct,
            total: questions.length,
            previous: _priorRecord ?? TopicTestRecord.none,
          );

      ref
          .read(analyticsProvider)
          .topicTestCompleted(
            subjectId: subjectId,
            topicId: widget.topicId,
            score: topicTestScore(correct: correct, total: questions.length),
            passed: topicTestPassed(correct: correct, total: questions.length),
          );
    } catch (_) {
      // The score is still shown — it is correct, it just did not persist.
      // Saying "you passed" and silently not unlocking anything would be
      // the worse failure.
      if (mounted) setState(() => _saveFailed = true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _confirmLeave() async {
    final leave = await showDialog<bool>(
      context: context,
      // The dialog's own context: when "Leave" closes the test, the
      // screen's context is deactivated while this dialog is still fading
      // out, and reading the theme through it throws.
      builder: (dialogContext) => AlertDialog(
        backgroundColor: dialogContext.palette.surface,
        title: const Text('Leave the test?'),
        content: const Text("Your answers so far won't be saved."),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep going'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              'Leave',
              style: TextStyle(color: dialogContext.palette.dangerFg),
            ),
          ),
        ],
      ),
    );
    if (leave == true && mounted) context.popOrGo();
  }

  void _retake() {
    // A fresh subset, not the same ten again — retakes are unlimited, so a
    // fixed set would make the gate a memory test.
    ref.invalidate(topicTestQuestionsProvider(widget.topicId));
    setState(() {
      _index = 0;
      _answers.clear();
      _submitted = false;
      _reviewing = false;
      _saveFailed = false;
      _correct = 0;
      _total = 0;
      _priorRecord = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final questionsAsync = ref.watch(
      topicTestQuestionsProvider(widget.topicId),
    );
    final isGuest = ref.watch(isGuestProvider);

    // Pinned before the first submit; see the field doc.
    final stored = ref.watch(topicTestProgressProvider).asData?.value;
    if (!_submitted && stored != null) {
      _priorRecord = stored.forTopic(widget.topicId);
    }

    final scaffold = Scaffold(
      appBar: ParagonAppBar(
        title: SessionTitle(kind: 'Topic test', topicId: widget.topicId),
      ),
      body: questionsAsync.when(
        loading: () => const LoadingView(label: 'Loading your test'),
        error: (e, _) => LoadError(
          error: e,
          onRetry: () =>
              ref.invalidate(topicTestQuestionsProvider(widget.topicId)),
          message:
              "This test couldn't be loaded. Check your connection and try again.",
        ),
        data: (questions) {
          if (questions.isEmpty) {
            return _EmptyBank(onBack: () => context.popOrGo());
          }
          if (_submitted && _reviewing) {
            return _Review(
              questions: questions,
              answers: _answers,
              onBack: () => setState(() => _reviewing = false),
            );
          }
          if (_submitted) {
            return _Result(
              correct: _correct,
              total: _total,
              saving: _saving,
              saveFailed: _saveFailed,
              isGuest: isGuest,
              onReview: () => setState(() => _reviewing = true),
              onRetake: _retake,
              onDone: () => context.popOrGo(),
            );
          }
          return Column(
            children: [
              // A nudge towards the lesson, never a gate.
              if (_answers.isEmpty) LessonNudge(topicId: widget.topicId),
              Expanded(
                child: _Questions(
                  questions: questions,
                  index: _index,
                  answers: _answers,
                  answeredCount: _answeredCount,
                  onSelect: _select,
                  onIndex: (i) => setState(() => _index = i),
                  onSubmit: () => _submit(questions),
                ),
              ),
            ],
          );
        },
      ),
    );

    // Once a question is answered, back asks first: leaving throws the
    // attempt away, and the pass mark gates drill.
    return PopScope(
      canPop: (_submitted && !_reviewing) || _answers.isEmpty,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        // Back from the review returns to the result, not out of the test.
        if (_reviewing) {
          setState(() => _reviewing = false);
        } else {
          _confirmLeave();
        }
      },
      child: StudyDock(
        subjectId: widget.subjectId,
        studyContext: StudyContext.topicTest,
        // Above the Back/Next bar while the test is open.
        bottomInset: _submitted ? 0 : kSessionBarHeight,
        child: scaffold,
      ),
    );
  }
}

// ─── In progress ──────────────────────────────────────────────────────

class _Questions extends StatelessWidget {
  const _Questions({
    required this.questions,
    required this.index,
    required this.answers,
    required this.answeredCount,
    required this.onSelect,
    required this.onIndex,
    required this.onSubmit,
  });

  final List<Question> questions;
  final int index;
  final Map<int, int> answers;
  final int answeredCount;
  final void Function(int) onSelect;
  final void Function(int) onIndex;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final q = questions[index];
    final selected = answers[index];
    final isLast = index == questions.length - 1;
    final unanswered = questions.length - answeredCount;
    final VoidCallback next = isLast ? onSubmit : () => onIndex(index + 1);

    return SessionKeys(
      optionCount: q.options.length,
      onSelect: onSelect,
      onEnter: next,
      child: SessionLayout(
        header: SessionHeader(
          index: index,
          total: questions.length,
          // Answered or not — never right or wrong: marked at the end.
          states: [
            for (var i = 0; i < questions.length; i++)
              answers.containsKey(i)
                  ? SegmentState.answered
                  : SegmentState.pending,
          ],
          note: '$answeredCount answered · marked at the end',
        ),
        bar: SessionNavBar(
          nextLabel: isLast ? 'Submit test' : 'Next',
          onNext: next,
          onBack: index > 0 ? () => onIndex(index - 1) : null,
        ),
        children: [
          // Said up front, not on the results screen: a student is
          // entitled to know the pass mark before they sit the thing. Once,
          // before the first answer, rather than above all ten questions.
          if (answeredCount == 0 && index == 0) ...[
            const InlineAlert(
              tone: Tone.info,
              title: 'Marked at the end',
              message:
                  'Score $kTopicTestPassPercent% or more to unlock drill '
                  'practice. No feedback until the end. Unlimited retakes.',
            ),
            const SizedBox(height: 16),
          ],
          // No source badge: a test shows the question and nothing else.
          QuestionCard(question: q, showSource: false),

          // No correct/incorrect colouring anywhere here — that is the
          // whole difference between this and a drill. Selected or not.
          for (var i = 0; i < q.options.length; i++)
            AnswerOption(
              index: i,
              text: q.options[i],
              state: selected == i
                  ? AnswerOptionState.selected
                  : AnswerOptionState.idle,
              onTap: () => onSelect(i),
            ),

          // Warned, not blocked. Unanswered questions count as wrong, so a
          // student is free to submit an incomplete test — they should
          // just not be surprised by the result.
          if (isLast && unanswered > 0) ...[
            const SizedBox(height: 4),
            InlineAlert(
              tone: Tone.warning,
              message:
                  '$unanswered unanswered. Blank answers count as wrong.',
            ),
          ],
          const SizedBox(height: 8),
          // No bookmark here: a question saved mid-test shows its answer
          // on the Saved page, which would turn the gate into a lookup.
          // Drill and exercises offer the same questions to bookmark.
          Align(
            alignment: Alignment.centerLeft,
            child: ReportProblemButton(
              questionId: q.id,
              isGenerated: q.isGenerated,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Result ───────────────────────────────────────────────────────────

class _Result extends StatelessWidget {
  const _Result({
    required this.correct,
    required this.total,
    required this.saving,
    required this.saveFailed,
    required this.isGuest,
    required this.onReview,
    required this.onRetake,
    required this.onDone,
  });

  final int correct;
  final int total;
  final bool saving;
  final bool saveFailed;
  final bool isGuest;
  final VoidCallback onReview;
  final VoidCallback onRetake;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final score = topicTestScore(correct: correct, total: total);
    final passed = topicTestPassed(correct: correct, total: total);
    final p = context.palette;

    final done = AppButton(
      label: 'Done',
      tone: passed ? ButtonTone.primary : ButtonTone.ghost,
      expand: true,
      onPressed: onDone,
    );
    final retake = AppButton(
      label: passed ? 'Take it again' : 'Retake the test',
      tone: passed ? ButtonTone.ghost : ButtonTone.primary,
      icon: Icons.refresh_rounded,
      expand: true,
      onPressed: onRetake,
    );
    // Which ones were wrong, and why: the score alone left a student to
    // guess what to go back over (audit C2).
    final review = AppButton(
      label: 'Review answers',
      tone: ButtonTone.secondary,
      expand: true,
      onPressed: onReview,
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 32),
      child: SessionSummary(
        title: passed ? 'Passed — drill unlocked' : 'Not passed yet',
        correct: correct,
        total: total,
        scoreLabel: '$score%',
        subtitle: '$correct of $total correct',
        celebrate: passed,
        details: [
          Text(
            passed
                ? 'You can now drill this topic as much as you like. Your '
                      'best score is kept.'
                // Never "you failed". The retake is free and immediate,
                // and the number needed is stated rather than implied.
                : 'You need $kTopicTestPassPercent% to unlock drill. Go back '
                      'through the lesson and try again — retakes are '
                      'unlimited and a new set of questions is drawn each '
                      'time.',
            textAlign: TextAlign.center,
            style: AppTheme.bodyMd.copyWith(color: p.textSecondary),
          ),
          if (saving)
            const LoadingView(
              label: 'Saving your result',
              delay: Duration.zero,
              padding: EdgeInsets.zero,
            ),
          if (saveFailed)
            const InlineAlert(
              tone: Tone.danger,
              announce: true,
              message:
                  'Your score above is right, but it could not be saved — so '
                  'this attempt has not unlocked anything yet. Check your '
                  'connection and take the test again.',
            ),
          if (isGuest) const GuestNotice(),
        ],
        // A pass is done; a fail's next step is the retake.
        primary: passed ? done : retake,
        secondary: review,
        tertiary: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            passed ? retake : done,
            if (correct < total)
              AppButton(
                label: 'Practise what you got wrong',
                tone: ButtonTone.ghost,
                expand: true,
                onPressed: () => context.push('/mistakes'),
              ),
          ],
        ),
      ),
    );
  }
}

/// The marked test, question by question: the student's answer, the right
/// one and the worked explanation. Held in memory; nothing is stored or
/// read. Only after submitting, so it never gives an answer to a test in
/// progress.
class _Review extends StatelessWidget {
  const _Review({
    required this.questions,
    required this.answers,
    required this.onBack,
  });

  final List<Question> questions;
  final Map<int, int> answers;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back, size: 18),
            label: const Text('Back to your result'),
          ),
        ),
        for (var n = 0; n < questions.length; n++) ...[
          const SizedBox(height: 16),
          Text(
            answers[n] == null
                ? 'Question ${n + 1} · not answered'
                : answers[n] == questions[n].correctIndex
                ? 'Question ${n + 1} · right'
                : 'Question ${n + 1} · wrong',
            style: AppTheme.caption.copyWith(color: palette.textSecondary),
          ),
          const SizedBox(height: 8),
          FullLatexView(
            latex: questions[n].text,
            textStyle: AppTheme.bodyLg.copyWith(
              color: palette.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          QuestionImage(assetId: questions[n].imageId),
          const SizedBox(height: 12),
          for (var i = 0; i < questions[n].options.length; i++)
            AnswerOption(
              index: i,
              text: questions[n].options[i],
              state: i == questions[n].correctIndex
                  ? AnswerOptionState.correct
                  : i == answers[n]
                  ? AnswerOptionState.wrong
                  : AnswerOptionState.idle,
            ),
          if (questions[n].explanation.trim().isNotEmpty ||
              questions[n].explanationImageId != null)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: palette.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: palette.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (questions[n].explanation.trim().isNotEmpty)
                    FullLatexView(
                      latex: questions[n].explanation,
                      textStyle: AppTheme.bodyMd.copyWith(
                        color: palette.textPrimary,
                      ),
                    ),
                  QuestionImage.workedAnswer(
                    assetId: questions[n].explanationImageId,
                  ),
                ],
              ),
            )
          else
            Text(
              'No worked answer yet for this question.',
              style: AppTheme.bodyMd.copyWith(color: palette.textSecondary),
            ),
          ReportProblemButton(
            questionId: questions[n].id,
            isGenerated: questions[n].isGenerated,
          ),
          Divider(color: palette.border, height: 24),
        ],
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: onBack,
          child: const Text('Back to your result'),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _EmptyBank extends StatelessWidget {
  const _EmptyBank({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 40,
            color: context.palette.textSecondary,
          ),
          const SizedBox(height: 14),
          Text(
            'This topic\x27s questions are still being checked by our team, '
            'so there is no test to take yet. Check back soon.',
            textAlign: TextAlign.center,
            style: AppTheme.bodyLg.copyWith(
              color: context.palette.textSecondary,
            ),
          ),
          const SizedBox(height: 20),
          OutlinedButton(
            onPressed: onBack,
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.primary),
            ),
            child: Text(
              'Back',
              style: AppTheme.btnLabel.copyWith(
                color: context.palette.primaryFg,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
