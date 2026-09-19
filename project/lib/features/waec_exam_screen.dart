import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/models/question.dart';
import '../core/providers/auth_provider.dart';
import '../core/repositories/attempt_repository.dart';
import '../core/theme/app_colors.dart';
import '../core/widgets/full_latex_view.dart';
import '../core/widgets/math_text.dart';
import '../core/widgets/report_problem_button.dart';

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
        backgroundColor: AppColors.surfaceDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Exit exam?', style: TextStyle(color: Colors.white)),
        content: const Text(
          "Your progress will be lost and this exam won't be saved.",
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Keep Going',
              style: TextStyle(color: Colors.white54),
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
        backgroundColor: AppColors.surfaceDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Submit Exam?',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          unanswered > 0
              ? 'You have $unanswered unanswered question${unanswered > 1 ? 's' : ''}. Are you sure?'
              : 'Submit your answers now?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white54),
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
      return const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer_outlined, size: 16, color: Colors.white38),
          SizedBox(width: 4),
          Text(
            'Untimed',
            style: TextStyle(color: Colors.white38, fontSize: 13),
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

    return Scaffold(
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
          ? const Center(
              child: Text(
                'No WAEC questions available for this subject.',
                style: TextStyle(color: Colors.white54),
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
  }

  Widget _buildActiveExam(List<Question> questions) {
    final q = questions[_currentIndex];
    final selectedOption = _answers[_currentIndex];

    return Column(
      children: [
        // Progress bar
        LinearProgressIndicator(
          value: (_currentIndex + 1) / questions.length,
          backgroundColor: AppColors.trackDark,
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
                        : AppColors.trackDark,
                    border: isActive
                        ? null
                        : Border.all(
                            color: isAnswered
                                ? AppColors.primary.withAlpha(
                                    (0.5 * 255).round(),
                                  )
                                : AppColors.borderDark,
                          ),
                  ),
                  child: Text(
                    '${i + 1}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isActive || isAnswered
                          ? Colors.white
                          : Colors.white38,
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
                    color: AppColors.surfaceDark,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.borderDark),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (q.year != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            'WAEC ${q.year}',
                            style: const TextStyle(
                              color: Colors.white38,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      FullLatexView(
                        latex: q.text,
                        textStyle: const TextStyle(
                          color: Colors.white,
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
                              : AppColors.surfaceDark,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.borderDark,
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
                                    : AppColors.trackDark,
                              ),
                              child: Text(
                                String.fromCharCode(65 + i),
                                style: TextStyle(
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.white54,
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
                                      ? Colors.white
                                      : Colors.white70,
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
                    child: ReportProblemButton(questionId: q.id),
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
                        side: const BorderSide(color: AppColors.borderDark),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        '← Prev',
                        style: TextStyle(color: Colors.white70),
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
              color: Colors.white,
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
                  const Expanded(
                    child: Text(
                      "Couldn't save your results.",
                      style: TextStyle(color: Colors.white70, fontSize: 13),
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
                side: const BorderSide(color: AppColors.borderDark),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'Review Answers',
                style: TextStyle(color: Colors.white70),
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
