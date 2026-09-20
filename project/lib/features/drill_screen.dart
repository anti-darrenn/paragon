import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/repositories/learning_repository.dart';
import '../core/repositories/attempt_repository.dart';
import '../core/providers/auth_provider.dart';
import '../core/models/question.dart';
import '../core/theme/app_colors.dart';
import '../core/widgets/full_latex_view.dart';
import '../core/widgets/math_text.dart';
import '../core/widgets/report_problem_button.dart';
import '../core/providers/analytics_provider.dart';
import '../core/repositories/progress_repository.dart';
import '../core/repositories/user_repository.dart';

class DrillScreen extends ConsumerStatefulWidget {
  final String topicId;
  const DrillScreen({super.key, required this.topicId});

  @override
  ConsumerState<DrillScreen> createState() => _DrillScreenState();
}

class _DrillScreenState extends ConsumerState<DrillScreen> {
  int _index = 0;
  int? _selected;
  bool _submitted = false;

  // ── Session tally ─────────────────────────────────────────────────────
  // Counted here rather than derived at the end because a student can
  // leave part-way through, and an abandoned session is exactly the one
  // worth knowing about.
  int _answered = 0;
  int _correct = 0;
  String? _sessionSubjectId;
  String? _uid;

  /// One flush per session, whichever way the student leaves.
  bool _sessionFlushed = false;

  /// The streak is a property of the day, not of the question.
  ///
  /// `updateStreak` used to run on every single submit. Each call is a
  /// Firestore transaction with a read inside it, so a 20-question drill
  /// cost 20 reads and 19 of them existed only to re-confirm that today
  /// was already recorded. On the Spark plan's 50k daily reads that is the
  /// same shape of defect as the unbounded queries in `docs/audit/NEXT.md`
  /// — cost that scales with exactly the engagement the product wants.
  /// `WaecExamScreen` already did this correctly, once per exam.
  bool _streakRecorded = false;

  /// Held rather than read from `ref` on the way out: Riverpod 3 forbids
  /// touching `ref` inside `dispose()`. Safe to hold because [Analytics]
  /// reads the opt-out flag at call time, so this instance cannot outlive
  /// a student's decision to turn collection off mid-session.
  Analytics? _analytics;
  ProgressRepository? _progress;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _analytics ??= ref.read(analyticsProvider);
    _progress ??= ref.read(progressRepositoryProvider);
  }

  @override
  void dispose() {
    // Catches the back arrow, and anything else that takes the screen away
    // without passing through Done. A no-op if Done already flushed.
    _flushSession();
    super.dispose();
  }

  /// Ends the session: one analytics event, one progress write.
  ///
  /// Deliberately not awaited by its callers. Both fire-and-forget calls
  /// are safe on their own terms — `Analytics` swallows its own failures,
  /// and the Firestore SDK applies a write locally and retries it — and
  /// awaiting would put a network round trip between tapping Done and the
  /// screen closing.
  ///
  /// The write is per session rather than per question on purpose; see
  /// `progress_repository.dart`. A session where nothing was answered is
  /// not a session, and writes nothing at all.
  void _flushSession() {
    if (_sessionFlushed || _answered == 0) return;
    _sessionFlushed = true;

    _analytics?.drillCompleted(
      subjectId: _sessionSubjectId ?? '',
      topicId: widget.topicId,
      answered: _answered,
      correct: _correct,
    );

    final uid = _uid;
    if (uid != null) {
      _progress?.addSession(
        uid: uid,
        topicId: widget.topicId,
        subjectId: _sessionSubjectId ?? '',
        answered: _answered,
        correct: _correct,
      );
    }
  }

  Future<void> _submit(List<Question> questions) async {
    if (_selected == null) return;

    final q = questions[_index];
    final user = ref.read(currentUserProvider);
    final isCorrect = _selected == q.correctIndex;

    setState(() {
      _submitted = true;
      _answered++;
      if (isCorrect) _correct++;
    });
    _sessionSubjectId ??= q.subjectId;

    if (user != null) {
      _uid = user.uid;
      await ref
          .read(attemptRepositoryProvider)
          .record(
            userId: user.uid,
            questionId: q.id,
            topicId: q.topicId,
            subjectId: q.subjectId,
            selectedIndex: _selected!,
            isCorrect: isCorrect,
            source: 'drill',
          );
      if (!_streakRecorded) {
        _streakRecorded = true;
        await ref.read(userRepositoryProvider).updateStreak(user.uid);
      }
    }
  }

  void _next(List<Question> questions) {
    if (_index < questions.length - 1) {
      setState(() {
        _index++;
        _selected = null;
        _submitted = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final questionsAsync = ref.watch(drillQuestionsProvider(widget.topicId));

    return Scaffold(
      appBar: AppBar(title: const Text('Drill')),
      body: questionsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (questions) {
          if (questions.isEmpty) {
            return const Center(
              child: Text('No questions for this topic yet.'),
            );
          }
          final q = questions[_index];
          final isLast = _index == questions.length - 1;

          final progressValue =
              (_index + (_submitted ? 1 : 0)) / questions.length;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top progress bar
                LinearProgressIndicator(
                  value: progressValue,
                  backgroundColor: AppColors.trackDark,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                  minHeight: 3,
                ),
                const SizedBox(height: 12),
                Text(
                  'Question ${_index + 1} of ${questions.length}',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.white54),
                ),
                const SizedBox(height: 12),
                FullLatexView(
                  latex: q.text,
                  textStyle: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 24),
                ...List.generate(q.options.length, (i) {
                  Color borderColor = Colors.white24;
                  if (_submitted) {
                    if (i == q.correctIndex) {
                      borderColor = AppColors.correct;
                    } else if (i == _selected) {
                      borderColor = AppColors.wrong;
                    }
                  } else if (_selected == i) {
                    borderColor = AppColors.primary;
                  }
                  final optionColor = _submitted
                      ? (i == q.correctIndex
                            ? AppColors.correct
                            : (i == _selected
                                  ? AppColors.wrong
                                  : Colors.white70))
                      : (_selected == i ? Colors.white : Colors.white70);

                  return GestureDetector(
                    onTap: _submitted
                        ? null
                        : () => setState(() => _selected = i),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        border: Border.all(color: borderColor, width: 1.5),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: MathText(
                        text: q.options[i],
                        useLightRenderer: true,
                        style: TextStyle(color: optionColor, fontSize: 15),
                      ),
                    ),
                  );
                }),
                // only render once there's a worked solution to show — an empty
                // box reads as a rendering failure next to a marked answer
                if (_submitted && q.explanation.trim().isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.correct.withAlpha((0.1 * 255).round()),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppColors.correct.withAlpha((0.4 * 255).round()),
                      ),
                    ),
                    child: FullLatexView(
                      latex: q.explanation,
                      textStyle: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                // outside the explanation block on purpose — most questions
                // have no worked solution, and those are the ones most worth
                // reporting
                if (_submitted)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: ReportProblemButton(questionId: q.id),
                  ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _submitted
                        ? (isLast
                              ? () {
                                  _flushSession();
                                  Navigator.of(context).pop();
                                }
                              : () => _next(questions))
                        : (_selected != null ? () => _submit(questions) : null),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: Text(
                      _submitted
                          ? (isLast ? 'Done' : 'Next Question')
                          : 'Submit Answer',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
