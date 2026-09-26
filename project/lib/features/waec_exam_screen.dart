import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/models/question.dart';
import '../core/providers/auth_provider.dart';
import '../core/providers/analytics_provider.dart';
import '../core/repositories/attempt_repository.dart';
import '../core/theme/app_colors.dart';
import '../core/widgets/full_latex_view.dart';
import '../core/widgets/math_text.dart';
import '../core/widgets/report_problem_button.dart';
import 'study/notes/notes_widgets.dart' show QuestionBookmarkButton;
import '../core/study/study_dock.dart';
import '../core/study/study_tool.dart';
import '../core/theme/app_palette.dart';

/// Data handed from WaecExamSetupScreen via route `extra`. The exam screen
/// never queries Firestore itself — per spec §2.3.3, setup fetches once
/// and passes the result as route state.
class WaecExamSessionData {
  const WaecExamSessionData({
    required this.questions,
    required this.timerEnabled,
    required this.timerDurationMinutes,
  });

  final List<Question> questions;
  final bool timerEnabled;
  final int timerDurationMinutes;
}

class WaecExamScreen extends ConsumerStatefulWidget {
  final String subjectId;
  final WaecExamSessionData? session;

  const WaecExamScreen({super.key, required this.subjectId, this.session});

  @override
  ConsumerState<WaecExamScreen> createState() => _WaecExamScreenState();
}

class _WaecExamScreenState extends ConsumerState<WaecExamScreen> {
  int _currentIndex = 0;
  // Stores selected answer index per question index
  final Map<int, int> _answers = {};
  bool _examSubmitted = false;
  int _score = 0;

  // Attempt-write state, separate from exam scoring — the score above is
  // shown the instant the exam is submitted and never waits on this.
  bool _saving = false;
  bool _saveFailed = false;
  // "Review Answers" drops back into the live exam, so submit can run twice.
  // attempts are recorded once per exam — the retry button still works, since
  // this only flips on a successful write
  bool _attemptsSaved = false;
  // set when the student taps "Review Answers", which drops back into the
  // exam view. only used to offer the report affordance there
  bool _reviewMode = false;

  Timer? _ticker;
  int _remainingSeconds = 0;
  bool _vibratedFiveMin = false;
  bool _vibratedOneMin = false;

  @override
  void initState() {
    super.initState();
    final session = widget.session;
    if (session == null) {
      // Direct URL / bad deep link with no route extra — GoRouter passes
      // null silently rather than erroring. Redirect in initState (the
      // router's own redirect config only runs on route resolution, not
      // on `extra` validation) via addPostFrameCallback, since calling
      // context.go() during the current build would throw.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/waec/${widget.subjectId}/setup');
      });
      return;
    }
    if (session.timerEnabled) {
      _remainingSeconds = session.timerDurationMinutes * 60;
      _ticker = Timer.periodic(const Duration(seconds: 1), _onTick);
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _onTick(Timer timer) {
    if (!mounted || _examSubmitted) {
      timer.cancel();
      return;
    }
    setState(() {
      if (_remainingSeconds > 0) _remainingSeconds--;
    });
    if (_remainingSeconds == 300 && !_vibratedFiveMin) {
      _vibratedFiveMin = true;
      HapticFeedback.heavyImpact();
    }
    if (_remainingSeconds == 60 && !_vibratedOneMin) {
      _vibratedOneMin = true;
      HapticFeedback.heavyImpact();
      Future.delayed(
        const Duration(milliseconds: 200),
        HapticFeedback.heavyImpact,
      );
    }
    if (_remainingSeconds <= 0) {
      timer.cancel();
      _autoSubmit();
    }
  }

  void _autoSubmit() {
    final session = widget.session;
    if (session == null || _examSubmitted) return;
    _submitExam(session.questions);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Time's up — your exam has been submitted."),
        ),
      );
    }
  }

  void _selectOption(int optionIndex) {
    if (_examSubmitted) return;
    setState(() => _answers[_currentIndex] = optionIndex);
  }

  void _goToQuestion(int index) {
    setState(() => _currentIndex = index);
  }

  void _submitExam(List<Question> questions) {
    int correct = 0;
    for (int i = 0; i < questions.length; i++) {
      if (_answers[i] == questions[i].correctIndex) correct++;
    }
    setState(() {
      _examSubmitted = true;
      _score = correct;
    });
    if (!_attemptsSaved) _saveAttempts(questions);
  }

  /// Records one attempt per *answered* question via the same
  /// AttemptRepository the drill flow uses, tagged source: 'waec'.
  /// Unanswered questions are skipped, not recorded as wrong — an
  /// attempt document means "the student answered," matching drill's
  /// own semantics (record() there is only ever called with a selection).
  Future<void> _saveAttempts(List<Question> questions) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    final answered = <AttemptDraft>[];
    for (int i = 0; i < questions.length; i++) {
      final selected = _answers[i];
      if (selected == null) continue;
      final q = questions[i];
      answered.add(
        AttemptDraft(
          questionId: q.id,
          topicId: q.topicId,
          subjectId: q.subjectId,
          selectedIndex: selected,
          isCorrect: selected == q.correctIndex,
        ),
      );
    }
    if (answered.isEmpty) return;

    setState(() {
      _saving = true;
      _saveFailed = false;
    });
    try {
      await ref
          .read(attemptRepositoryProvider)
          .recordBatch(userId: user.uid, source: 'waec', attempts: answered);
      _attemptsSaved = true;

      // Counts and a subject id only — never question text or answers.
      await ref
          .read(analyticsProvider)
          .examCompleted(
            subjectId: widget.subjectId,
            answered: answered.length,
            correct: answered.where((a) => a.isCorrect).length,
          );

      if (mounted) setState(() => _saving = false);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _saveFailed = true;
        });
      }
    }
  }

  void _confirmExit() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: context.palette.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Exit exam?',
          style: TextStyle(color: context.palette.textStrong),
        ),
        content: Text(
          "Your progress will be lost and this exam won't be saved.",
          style: TextStyle(color: context.palette.onHigh),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Keep Going',
              style: TextStyle(color: context.palette.onMedium),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              context.go('/waec/${widget.subjectId}/setup');
            },
            child: const Text(
              'Exit Exam',
              style: TextStyle(
                color: AppColors.wrong,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmSubmit(List<Question> questions) {
    final unanswered = questions.length - _answers.length;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: context.palette.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Submit Exam?',
          style: TextStyle(color: context.palette.textStrong),
        ),
        content: Text(
          unanswered > 0
              ? 'You have $unanswered unanswered question${unanswered > 1 ? 's' : ''}. Are you sure?'
              : 'Submit your answers now?',
          style: TextStyle(color: context.palette.onHigh),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Cancel',
              style: TextStyle(color: context.palette.onMedium),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _submitExam(questions);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Submit', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _timerDisplay(WaecExamSessionData session) {
    if (!session.timerEnabled) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer_outlined, size: 16, color: context.palette.onLow),
          SizedBox(width: 4),
          Text(
            'Untimed',
            style: TextStyle(color: context.palette.onLow, fontSize: 13),
          ),
        ],
      );
    }
    final minutes = _remainingSeconds ~/ 60;
    final seconds = _remainingSeconds % 60;
    final display =
        '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    final color = _remainingSeconds <= 300
        ? AppColors.wrong
        : AppColors.primary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.timer_outlined, size: 16, color: color),
        const SizedBox(width: 4),
        Text(
          display,
          style: TextStyle(
            color: color,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    if (session == null) {
      // Redirecting in initState — render nothing while that happens.
      return const Scaffold(body: SizedBox.shrink());
    }
    final questions = session.questions;

    final scaffold = Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close, size: 20),
          onPressed: _examSubmitted ? () => context.go('/waec') : _confirmExit,
          tooltip: 'Exit exam',
        ),
        title: _examSubmitted
            ? const Text('Results')
            : Text(
                '${_currentIndex + 1} / ${questions.length}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _timerDisplay(session),
          ),
        ],
      ),
      body: questions.isEmpty
          ? Center(
              child: Text(
                'No WAEC questions available for this subject.',
                style: TextStyle(color: context.palette.onMedium),
              ),
            )
          : _examSubmitted
          ? _ResultsView(
              score: _score,
              total: questions.length,
              answers: _answers,
              questions: questions,
              saving: _saving,
              saveFailed: _saveFailed,
              onRetry: () => _saveAttempts(questions),
              onReview: () => setState(() {
                _examSubmitted = false;
                _reviewMode = true;
              }),
              onExit: () => context.go('/waec'),
            )
          : _buildActiveExam(questions),
    );

    // Android back and the back gesture would otherwise drop a timed exam
    // without a word; only the close button asked. Route them to the same
    // dialog. (Browser back and closing the tab cannot be intercepted this
    // way; resuming an exam is still deferred work.)
    return PopScope(
      canPop: _examSubmitted,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmExit();
      },
      child: StudyDock(
        subjectId: widget.subjectId,
        studyContext: StudyContext.waecExam,
        child: scaffold,
      ),
    );
  }

  Widget _buildActiveExam(List<Question> questions) {
    final q = questions[_currentIndex];
    final selectedOption = _answers[_currentIndex];

    return Column(
      children: [
        // Progress bar
        LinearProgressIndicator(
          value: (_currentIndex + 1) / questions.length,
          backgroundColor: context.palette.track,
          valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
          minHeight: 3,
        ),

        // Question navigator strip
        SizedBox(
          height: 44,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            itemCount: questions.length,
            itemBuilder: (_, i) {
              final isActive = i == _currentIndex;
              final isAnswered = _answers.containsKey(i);
              return GestureDetector(
                onTap: () => _goToQuestion(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 28,
                  height: 28,
                  margin: const EdgeInsets.only(right: 6),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isActive
                        ? AppColors.primary
                        : isAnswered
                        ? AppColors.primary.withAlpha((0.25 * 255).round())
                        : context.palette.track,
                    border: isActive
                        ? null
                        : Border.all(
                            color: isAnswered
                                ? AppColors.primary.withAlpha(
                                    (0.5 * 255).round(),
                                  )
                                : context.palette.border,
                          ),
                  ),
                  child: Text(
                    '${i + 1}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isActive
                          ? Colors.white
                          : isAnswered
                          ? context.palette.textStrong
                          : context.palette.onLow,
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        // Question + options
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: context.palette.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: context.palette.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (q.year != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            'WAEC ${q.year}',
                            style: TextStyle(
                              color: context.palette.onLow,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      FullLatexView(
                        latex: q.text,
                        textStyle: TextStyle(
                          color: context.palette.textStrong,
                          fontSize: 16,
                          height: 1.6,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                ...List.generate(q.options.length, (i) {
                  final isSelected = selectedOption == i;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: GestureDetector(
                      onTap: () => _selectOption(i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 13,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary.withAlpha((0.1 * 255).round())
                              : context.palette.surface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.primary
                                : context.palette.border,
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 160),
                              width: 28,
                              height: 28,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isSelected
                                    ? AppColors.primary
                                    : context.palette.track,
                              ),
                              child: Text(
                                String.fromCharCode(65 + i),
                                style: TextStyle(
                                  color: isSelected
                                      ? Colors.white
                                      : context.palette.onMedium,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: MathText(
                                text: q.options[i],
                                useLightRenderer: true,
                                style: TextStyle(
                                  color: isSelected
                                      ? context.palette.textStrong
                                      : context.palette.onHigh,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
                if (_reviewMode)
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
              ],
            ),
          ),
        ),

        // Navigation + submit
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Row(
              children: [
                if (_currentIndex > 0)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _goToQuestion(_currentIndex - 1),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: context.palette.border),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        '← Prev',
                        style: TextStyle(color: context.palette.onHigh),
                      ),
                    ),
                  ),
                if (_currentIndex > 0) const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _currentIndex < questions.length - 1
                        ? () => _goToQuestion(_currentIndex + 1)
                        : () => _confirmSubmit(questions),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _currentIndex < questions.length - 1
                          ? AppColors.primary
                          : AppColors.submitGreen,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      _currentIndex < questions.length - 1
                          ? 'Next →'
                          : 'Submit Exam',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Results view
// ─────────────────────────────────────────────────────────────────────────────

class _ResultsView extends StatelessWidget {
  final int score;
  final int total;
  final Map<int, int> answers;
  final List<Question> questions;
  final bool saving;
  final bool saveFailed;
  final VoidCallback onRetry;
  final VoidCallback onReview;
  final VoidCallback onExit;

  const _ResultsView({
    required this.score,
    required this.total,
    required this.answers,
    required this.questions,
    required this.saving,
    required this.saveFailed,
    required this.onRetry,
    required this.onReview,
    required this.onExit,
  });

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? ((score / total) * 100).round() : 0;
    final Color scoreColor = pct >= 50 ? AppColors.correct : AppColors.wrong;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 24),
          Text(
            'Exam Complete',
            style: TextStyle(
              color: context.palette.textStrong,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$score / $total  ($pct%)',
            style: TextStyle(
              color: scoreColor,
              fontSize: 36,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            pct >= 50 ? 'Pass' : 'Below pass mark',
            style: TextStyle(color: scoreColor, fontSize: 14),
          ),
          if (saveFailed) ...[
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.wrong.withAlpha((0.12 * 255).round()),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.wrong.withAlpha((0.4 * 255).round()),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: AppColors.wrong,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "Couldn't save your results.",
                      style: TextStyle(
                        color: context.palette.onHigh,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: saving ? null : onRetry,
                    child: Text(
                      saving ? 'Retrying…' : 'Retry',
                      style: const TextStyle(
                        color: AppColors.wrong,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: onReview,
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: context.palette.border),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                'Review Answers',
                style: TextStyle(color: context.palette.onHigh),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onExit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'Back to Subjects',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
