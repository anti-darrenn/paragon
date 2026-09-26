import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/learn/topic_test.dart';
import '../core/models/question.dart';
import '../core/providers/analytics_provider.dart';
import '../core/providers/auth_provider.dart';
import '../core/repositories/attempt_repository.dart';
import '../core/repositories/learn_progress_repository.dart';
import '../core/repositories/learn_repository.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';
import '../core/widgets/full_latex_view.dart';
import '../core/widgets/guest_notice.dart';
import '../core/widgets/math_text.dart';
import '../core/widgets/report_problem_button.dart';
import 'study/notes/notes_widgets.dart' show QuestionBookmarkButton;
import '../core/widgets/load_error.dart';
import '../core/study/study_dock.dart';
import '../core/study/study_tool.dart';

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
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        title: const Text('Leave the test?'),
        content: const Text("Your answers so far won't be saved."),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep going'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(
              'Leave',
              style: TextStyle(color: AppColors.wrong),
            ),
          ),
        ],
      ),
    );
    if (leave == true && mounted) context.pop();
  }

  void _retake() {
    // A fresh subset, not the same ten again — retakes are unlimited, so a
    // fixed set would make the gate a memory test.
    ref.invalidate(topicTestQuestionsProvider(widget.topicId));
    setState(() {
      _index = 0;
      _answers.clear();
      _submitted = false;
      _saveFailed = false;
      _correct = 0;
      _total = 0;
      _priorRecord = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final questionsAsync = ref.watch(topicTestQuestionsProvider(widget.topicId));
    final isGuest = ref.watch(isGuestProvider);

    // Pinned before the first submit; see the field doc.
    final stored = ref.watch(topicTestProgressProvider).asData?.value;
    if (!_submitted && stored != null) {
      _priorRecord = stored.forTopic(widget.topicId);
    }

    final scaffold = Scaffold(
      appBar: AppBar(title: const Text('Topic test')),
      body: questionsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => LoadError(
          error: e,
          onRetry: () =>
              ref.invalidate(topicTestQuestionsProvider(widget.topicId)),
          message:
              "This test couldn't be loaded. Check your connection and try again.",
        ),
        data: (questions) {
          if (questions.isEmpty) {
            return _EmptyBank(
              onBack: () => context.pop(),
            );
          }
          if (_submitted) {
            return _Result(
              correct: _correct,
              total: _total,
              saving: _saving,
              saveFailed: _saveFailed,
              isGuest: isGuest,
              onRetake: _retake,
              onDone: () => context.pop(),
            );
          }
          return _Questions(
            questions: questions,
            index: _index,
            answers: _answers,
            answeredCount: _answeredCount,
            isGuest: isGuest,
            onSelect: _select,
            onIndex: (i) => setState(() => _index = i),
            onSubmit: () => _submit(questions),
          );
        },
      ),
    );

    // Once a question is answered, back asks first: leaving throws the
    // attempt away, and the pass mark gates drill.
    return PopScope(
      canPop: _submitted || _answers.isEmpty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmLeave();
      },
      child: StudyDock(
        subjectId: widget.subjectId,
        studyContext: StudyContext.topicTest,
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
    required this.isGuest,
    required this.onSelect,
    required this.onIndex,
    required this.onSubmit,
  });

  final List<Question> questions;
  final int index;
  final Map<int, int> answers;
  final int answeredCount;
  final bool isGuest;
  final void Function(int) onSelect;
  final void Function(int) onIndex;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final q = questions[index];
    final selected = answers[index];
    final isLast = index == questions.length - 1;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LinearProgressIndicator(
            value: answeredCount / questions.length,
            backgroundColor: AppColors.trackDark,
            valueColor: const AlwaysStoppedAnimation<Color>(
              AppColors.secondary,
            ),
            minHeight: 3,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                'Question ${index + 1} of ${questions.length}',
                style: AppTheme.caption.copyWith(
                  color: AppColors.textSecondaryDark,
                ),
              ),
              const Spacer(),
              Text(
                '$answeredCount answered',
                style: AppTheme.caption.copyWith(
                  color: AppColors.textSecondaryDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // Said up front, not on the results screen. A student is
          // entitled to know the pass mark before they sit the thing.
          Text(
            'Score $kTopicTestPassPercent% or more to unlock drill practice. '
            'No feedback until the end. Unlimited retakes.',
            style: AppTheme.caption.copyWith(color: AppColors.textSecondaryDark),
          ),
          if (isGuest) ...[
            const SizedBox(height: 12),
            const GuestNotice(),
          ],
          const SizedBox(height: 16),

          FullLatexView(
            latex: q.text,
            textStyle: AppTheme.bodyLg.copyWith(
              color: AppColors.textPrimaryDark,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 20),

          // No correct/incorrect colouring anywhere here — that is the
          // whole difference between this and a drill.
          ...List.generate(q.options.length, (i) {
            final isChosen = selected == i;
            return GestureDetector(
              onTap: () => onSelect(i),
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: isChosen ? AppColors.secondary : Colors.white24,
                    width: 1.5,
                  ),
                  borderRadius: BorderRadius.circular(10),
                  color: isChosen
                      ? AppColors.secondary.withAlpha((0.10 * 255).round())
                      : null,
                ),
                child: MathText(
                  text: q.options[i],
                  useLightRenderer: true,
                  style: TextStyle(
                    color: isChosen ? Colors.white : Colors.white70,
                    fontSize: 15,
                  ),
                ),
              ),
            );
          }),

          const SizedBox(height: 8),
          Row(
            children: [
              if (index > 0)
                OutlinedButton(
                  onPressed: () => onIndex(index - 1),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.borderDark),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
                  ),
                  child: Text(
                    'Back',
                    style: AppTheme.btnLabel.copyWith(
                      color: AppColors.textSecondaryDark,
                    ),
                  ),
                ),
              if (index > 0) const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: isLast ? onSubmit : () => onIndex(index + 1),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isLast
                        ? AppColors.secondary
                        : AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text(
                    isLast ? 'Submit test' : 'Next',
                    style: AppTheme.btnLabel.copyWith(color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
          if (isLast && answeredCount < questions.length) ...[
            const SizedBox(height: 10),
            // Warned, not blocked. Unanswered questions count as wrong, so
            // a student is free to submit an incomplete test — they should
            // just not be surprised by the result.
            Text(
              '${questions.length - answeredCount} unanswered. '
              'Blank answers count as wrong.',
              style: AppTheme.caption.copyWith(color: AppColors.wrong),
            ),
          ],
          const SizedBox(height: 16),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ReportProblemButton(questionId: q.id),
              QuestionBookmarkButton(question: q),
            ],
          ),
          const SizedBox(height: 24),
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
    required this.onRetake,
    required this.onDone,
  });

  final int correct;
  final int total;
  final bool saving;
  final bool saveFailed;
  final bool isGuest;
  final VoidCallback onRetake;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final score = topicTestScore(correct: correct, total: total);
    final passed = topicTestPassed(correct: correct, total: total);
    final accent = passed ? AppColors.correct : AppColors.primary;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 16),
          Icon(
            passed ? Icons.verified_rounded : Icons.refresh_rounded,
            size: 56,
            color: accent,
          ),
          const SizedBox(height: 16),
          Text(
            '$score%',
            textAlign: TextAlign.center,
            style: AppTheme.displayLg.copyWith(color: accent, fontSize: 48),
          ),
          const SizedBox(height: 4),
          Text(
            '$correct of $total correct',
            textAlign: TextAlign.center,
            style: AppTheme.bodyMd.copyWith(
              color: AppColors.textSecondaryDark,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            passed ? 'Passed — drill unlocked' : 'Not passed yet',
            textAlign: TextAlign.center,
            style: AppTheme.heading2.copyWith(color: AppColors.textPrimaryDark),
          ),
          const SizedBox(height: 8),
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
            style: AppTheme.bodyMd.copyWith(
              color: AppColors.textSecondaryDark,
            ),
          ),

          if (saving) ...[
            const SizedBox(height: 20),
            const Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ],
          if (saveFailed) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.wrong.withAlpha((0.12 * 255).round()),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.wrong),
              ),
              child: Text(
                'Your score above is right, but it could not be saved — so '
                'this attempt has not unlocked anything yet. Check your '
                'connection and take the test again.',
                style: AppTheme.bodyMd.copyWith(color: AppColors.wrong),
              ),
            ),
          ],
          if (isGuest) ...[
            const SizedBox(height: 20),
            const GuestNotice(),
          ],

          const SizedBox(height: 28),
          ElevatedButton(
            onPressed: onDone,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: Text(
              'Done',
              style: AppTheme.btnLabel.copyWith(color: Colors.white),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: onRetake,
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.secondary),
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: Text(
              passed ? 'Take it again' : 'Retake the test',
              style: AppTheme.btnLabel.copyWith(color: AppColors.secondary),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
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
          const Icon(
            Icons.inbox_outlined,
            size: 40,
            color: AppColors.textSecondaryDark,
          ),
          const SizedBox(height: 14),
          Text(
            'This topic has no questions with a verified answer yet, so '
            'there is no test to take.',
            textAlign: TextAlign.center,
            style: AppTheme.bodyLg.copyWith(
              color: AppColors.textSecondaryDark,
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
              style: AppTheme.btnLabel.copyWith(color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }
}
