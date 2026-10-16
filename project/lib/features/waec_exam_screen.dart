import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/a11y/speech_text.dart';
import '../core/exam/exam_result.dart';
import '../core/exam/saved_exam.dart';
import '../core/models/question.dart';
import '../core/repositories/exam_result_repository.dart';
import 'exam_review_screen.dart' show GradeEstimateCard;
import '../core/auth/guest_limits.dart';
import '../core/providers/auth_provider.dart';
import '../core/widgets/guest_notice.dart';
import '../core/web/browser.dart';
import '../core/providers/analytics_provider.dart';
import '../core/repositories/attempt_repository.dart';
import '../core/theme/app_colors.dart';
import '../core/widgets/full_latex_view.dart';
import '../core/widgets/question_source_badge.dart';
import '../core/widgets/math_text.dart';
import '../core/study/study_dock.dart';
import '../core/study/study_tool.dart';
import '../core/theme/app_palette.dart';
import '../core/widgets/question_image.dart';
import '../core/widgets/nav/back_navigation.dart';
import 'plan/plan_widgets.dart';

/// Data handed from WaecExamSetupScreen via route `extra`. The exam screen
/// never queries Firestore itself — per spec §2.3.3, setup fetches once
/// and passes the result as route state.
class WaecExamSessionData {
  const WaecExamSessionData({
    required this.questions,
    required this.timerEnabled,
    required this.timerDurationMinutes,
    this.resume,
  });

  /// Picks up an exam kept on the device (`SavedExam`): its questions,
  /// answers, flags, place and remaining time.
  factory WaecExamSessionData.resuming(SavedExam saved) => WaecExamSessionData(
    questions: saved.questions,
    timerEnabled: saved.timerEnabled,
    timerDurationMinutes: saved.timerMinutes,
    resume: saved,
  );

  final List<Question> questions;
  final bool timerEnabled;
  final int timerDurationMinutes;
  final SavedExam? resume;
}

/// The `/waec/:subjectId/exam` route's screen. Here rather than in the
/// router because this library is deferred there, and a deferred type
/// cannot be used in the router's `is` check.
Widget waecExamRoute(String subjectId, Object? extra, {String? routeKey}) =>
    WaecExamScreen(
  subjectId: subjectId,
  routeKey: routeKey,
  // Direct URL / bad deep link with no route extra is handled inside
  // WaecExamScreen itself (redirects back to setup) rather than crashing
  // on a bad cast — see its initState.
  session: extra is WaecExamSessionData ? extra : null,
);

class WaecExamScreen extends ConsumerStatefulWidget {
  final String subjectId;
  final WaecExamSessionData? session;

  /// The subject as the URL named it, for the way back to setup.
  final String? routeKey;

  const WaecExamScreen({
    super.key,
    required this.subjectId,
    this.session,
    this.routeKey,
  });

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

  /// The exam as sat, built on submit and saved to `examResults` so it can
  /// be reviewed after a reload and listed in the subject's history. Its
  /// id is chosen up front, so a retried save writes the same document.
  ExamResult? _result;
  bool _resultSaved = false;
  DateTime _startedAt = DateTime.now();

  /// Questions the student marked to come back to. Shown on the strip and
  /// counted before submitting; never scored.
  final Set<int> _flagged = {};

  /// Debounces saving the exam to the device (`SavedExam`).
  Timer? _persistTimer;
  late final SavedExamStore _store = ref.read(savedExamStoreProvider);
  String? _uid;
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
        if (mounted) context.go('/waec/${widget.routeKey ?? widget.subjectId}/setup');
      });
      return;
    }
    // Closing or reloading the tab mid-exam asks first (web only).
    setLeaveGuard(true);
    _uid = ref.read(currentUserProvider)?.uid;
    final resume = session.resume;
    if (resume != null) {
      _answers.addAll(resume.answers);
      _flagged.addAll(resume.flagged);
      _currentIndex = resume.currentIndex;
      _startedAt = resume.startedAt;
    }
    if (session.timerEnabled) {
      _remainingSeconds =
          resume?.remainingSeconds ?? session.timerDurationMinutes * 60;
      _ticker = Timer.periodic(const Duration(seconds: 1), _onTick);
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    // A last save on the way out (a route change, not a submit): the
    // debounce may not have fired yet.
    if (_persistTimer?.isActive ?? false) {
      _persistTimer!.cancel();
      _persistNow();
    }
    setLeaveGuard(false);
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
    // The clock is part of what a resume restores.
    if (_remainingSeconds % 15 == 0) _persist();
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
    final q = widget.session?.questions[_currentIndex];
    if (q == null || optionIndex >= q.options.length) return;
    setState(() => _answers[_currentIndex] = optionIndex);
    _persist();
  }

  void _goToQuestion(int index) {
    final total = widget.session?.questions.length ?? 0;
    if (index < 0 || index >= total) return;
    setState(() => _currentIndex = index);
    _persist();
  }

  void _toggleFlag() {
    if (_examSubmitted) return;
    setState(() {
      if (!_flagged.remove(_currentIndex)) _flagged.add(_currentIndex);
    });
    _persist();
  }

  /// Keeps the exam on the device, half a second after the last change.
  void _persist() {
    if (_examSubmitted || _uid == null) return;
    _persistTimer?.cancel();
    _persistTimer = Timer(const Duration(milliseconds: 500), _persistNow);
  }

  void _persistNow() {
    final session = widget.session;
    final uid = _uid;
    if (session == null || uid == null || _examSubmitted) return;
    _store.save(
      uid,
      SavedExam(
        subjectId: widget.subjectId,
        questions: session.questions,
        answers: Map.of(_answers),
        flagged: Set.of(_flagged),
        currentIndex: _currentIndex,
        timerEnabled: session.timerEnabled,
        timerMinutes: session.timerDurationMinutes,
        remainingSeconds: _remainingSeconds,
        startedAt: _startedAt,
        savedAt: DateTime.now(),
      ),
    );
  }

  /// Submitted or abandoned: nothing left to resume.
  void _forgetSaved() {
    _persistTimer?.cancel();
    final uid = _uid;
    if (uid != null) _store.clear(uid, widget.subjectId);
  }

  void _submitExam(List<Question> questions) {
    int correct = 0;
    for (int i = 0; i < questions.length; i++) {
      if (_answers[i] == questions[i].correctIndex) correct++;
    }
    final session = widget.session;
    _result ??= ExamResult.fromSitting(
      id: ref.read(examResultRepositoryProvider).newId(),
      subjectId: widget.subjectId,
      questions: questions,
      answers: _answers,
      timed: session?.timerEnabled ?? false,
      durationSeconds: DateTime.now().difference(_startedAt).inSeconds,
    );
    setState(() {
      _examSubmitted = true;
      _score = correct;
    });
    setLeaveGuard(false);
    _forgetSaved();
    if (!_attemptsSaved || !_resultSaved) _saveAttempts(questions);
  }

  void _openReview(List<Question> questions) {
    final result = _result;
    if (result == null) return;
    context.push(
      '/waec/review/${result.id}',
      extra: ExamReview(result, {for (final q in questions) q.id: q}),
    );
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
    // An exam with nothing answered records nothing: no attempts, and no
    // result for the history to show as an empty 0%.
    if (answered.isEmpty) return;

    setState(() {
      _saving = true;
      _saveFailed = false;
    });
    try {
      // Two writes, each flagged on success, so a retry after a failure
      // repeats only what failed and never records the attempts twice.
      if (!_attemptsSaved) {
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
      }
      final result = _result;
      if (!_resultSaved && result != null) {
        await ref.read(examResultRepositoryProvider).save(user.uid, result);
        _resultSaved = true;
        ref.invalidate(examHistoryProvider(widget.subjectId));
      }

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
      builder: (dialogContext) => AlertDialog(
        backgroundColor: dialogContext.palette.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Exit exam?',
          style: TextStyle(color: dialogContext.palette.textStrong),
        ),
        content: Text(
          "Your progress will be lost and this exam won't be saved.",
          style: TextStyle(color: dialogContext.palette.onHigh),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Keep Going',
              style: TextStyle(color: dialogContext.palette.onMedium),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _forgetSaved();
              context.go('/waec/${widget.routeKey ?? widget.subjectId}/setup');
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

  /// Before submitting: how many are answered, unanswered and flagged,
  /// with a way back to each (PLAN.md P5.2.3). Enter submits.
  void _confirmSubmit(List<Question> questions) {
    final summary = examSummary(
      total: questions.length,
      answers: _answers,
      flagged: _flagged,
    );
    final firstUnanswered = nextMatching(
      questions.length,
      0,
      (i) => !_answers.containsKey(i),
    );
    final firstFlagged = nextMatching(
      questions.length,
      0,
      (i) => _flagged.contains(i),
    );

    Widget line(String label, int n, Color colour) => Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: colour, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(label)),
          Text('$n', style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: dialogContext.palette.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Submit exam?',
          style: TextStyle(color: dialogContext.palette.textStrong),
        ),
        content: DefaultTextStyle.merge(
          style: TextStyle(color: dialogContext.palette.onHigh),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              line('Answered', summary.answered, AppColors.primary),
              line(
                'Not answered',
                summary.unanswered,
                dialogContext.palette.onLow,
              ),
              line('Flagged for review', summary.flagged, AppColors.warning),
              const SizedBox(height: 8),
              Text(
                summary.unanswered > 0
                    ? 'Unanswered questions score nothing.'
                    : 'You can still go back and check.',
                style: TextStyle(
                  color: dialogContext.palette.onMedium,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        actions: [
          if (firstUnanswered != null)
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _goToQuestion(firstUnanswered);
              },
              child: const Text('Go to unanswered'),
            ),
          if (firstFlagged != null)
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _goToQuestion(firstFlagged);
              },
              child: const Text('Review flagged'),
            ),
          ElevatedButton(
            autofocus: true,
            onPressed: () {
              Navigator.of(dialogContext).pop();
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
      appBar: ParagonAppBar(
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
              isGuest: ref.watch(isGuestProvider),
              score: _score,
              total: questions.length,
              answers: _answers,
              questions: questions,
              saving: _saving,
              saveFailed: _saveFailed,
              onRetry: () => _saveAttempts(questions),
              onReview: () => _openReview(questions),
              onExit: () => context.go('/waec'),
            )
          : _buildActiveExam(questions),
    );

    // Android back and the back gesture would otherwise drop a timed exam
    // without a word; only the close button asked. Route them to the same
    // dialog. Closing or reloading the tab is guarded by `setLeaveGuard`;
    // resuming an exam is still deferred work.
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

  /// Keyboard: A-E answer, left/right move, F flags. Web students on a
  /// laptop sit the whole paper without the mouse (PLAN.md P5.2.2).
  Map<ShortcutActivator, VoidCallback> _shortcuts(List<Question> questions) => {
    for (final (i, key) in [
      LogicalKeyboardKey.keyA,
      LogicalKeyboardKey.keyB,
      LogicalKeyboardKey.keyC,
      LogicalKeyboardKey.keyD,
      LogicalKeyboardKey.keyE,
    ].indexed)
      SingleActivator(key): () => _selectOption(i),
    const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
        _goToQuestion(_currentIndex - 1),
    const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
        _currentIndex < questions.length - 1
        ? _goToQuestion(_currentIndex + 1)
        : _confirmSubmit(questions),
    const SingleActivator(LogicalKeyboardKey.keyF): _toggleFlag,
  };

  Widget _buildActiveExam(List<Question> questions) => CallbackShortcuts(
    bindings: _shortcuts(questions),
    child: Focus(autofocus: true, child: _activeExamBody(questions)),
  );

  Widget _activeExamBody(List<Question> questions) {
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

        // Question navigator strip. Each number is a 48px target with its
        // state spoken ("Question 3, answered, flagged"); state is shown
        // by colour *and* by a flag mark, never colour alone.
        SizedBox(
          height: 56,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            itemCount: questions.length,
            itemBuilder: (_, i) => _StripItem(
              number: i + 1,
              isActive: i == _currentIndex,
              isAnswered: _answers.containsKey(i),
              isFlagged: _flagged.contains(i),
              onTap: () => _goToQuestion(i),
            ),
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
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: QuestionSourceBadge(question: q)),
                          _FlagButton(
                            flagged: _flagged.contains(_currentIndex),
                            onPressed: _toggleFlag,
                          ),
                        ],
                      ),
                      FullLatexView(
                        latex: q.text,
                        textStyle: TextStyle(
                          color: context.palette.textStrong,
                          fontSize: 16,
                          height: 1.6,
                        ),
                      ),
                      QuestionImage(assetId: q.imageId),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                ...List.generate(q.options.length, (i) {
                  final isSelected = selectedOption == i;
                  final letter = String.fromCharCode(65 + i);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Semantics(
                      button: true,
                      selected: isSelected,
                      inMutuallyExclusiveGroup: true,
                      label: 'Option $letter: ${speakText(q.options[i])}',
                      // excludeSemantics drops the InkWell's own action, so
                      // the tap is given here — without it a screen reader
                      // could hear an option but never choose it.
                      onTap: () => _selectOption(i),
                      excludeSemantics: true,
                      child: InkWell(
                        onTap: () => _selectOption(i),
                        borderRadius: BorderRadius.circular(10),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 160),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 13,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primary.withAlpha(
                                    (0.1 * 255).round(),
                                  )
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
                                  letter,
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
                    ),
                  );
                }),
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
  final bool isGuest;
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
    required this.isGuest,
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
          const SizedBox(height: 16),
          GradeEstimateCard(percent: total > 0 ? score * 100 / total : 0),
          PracticeComparison(
            subjectId: questions.isEmpty ? '' : questions.first.subjectId,
            percent: total > 0 ? score * 100 / total : 0,
          ),
          if (isGuest) ...[
            const SizedBox(height: 16),
            GuestNotice(
              message: GuestLimits.saveResultMessage('this $score/$total'),
            ),
          ],
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

/// One number on the exam's question strip: a 48x48 target around a 36px
/// circle. Answered is a tinted fill, current a solid one, flagged a flag
/// mark, so state never rests on colour alone.
class _StripItem extends StatelessWidget {
  const _StripItem({
    required this.number,
    required this.isActive,
    required this.isAnswered,
    required this.isFlagged,
    required this.onTap,
  });

  final int number;
  final bool isActive;
  final bool isAnswered;
  final bool isFlagged;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final state = [
      isAnswered ? 'answered' : 'not answered',
      if (isFlagged) 'flagged',
      if (isActive) 'current',
    ].join(', ');
    return Semantics(
      button: true,
      selected: isActive,
      label: 'Question $number, $state',
      onTap: onTap,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 48,
          height: 48,
          child: Stack(
            alignment: Alignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 36,
                height: 36,
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
                          color: isFlagged
                              ? AppColors.warning
                              : isAnswered
                              ? AppColors.primary.withAlpha((0.5 * 255).round())
                              : context.palette.border,
                          width: isFlagged ? 2 : 1,
                        ),
                ),
                child: Text(
                  '$number',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isActive
                        ? Colors.white
                        : isAnswered
                        ? context.palette.textStrong
                        : context.palette.onMedium,
                  ),
                ),
              ),
              if (isFlagged)
                const Positioned(
                  top: 2,
                  right: 2,
                  child: Icon(Icons.flag, size: 14, color: AppColors.warning),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Flag for review" on the current question. Also the F key.
class _FlagButton extends StatelessWidget {
  const _FlagButton({required this.flagged, required this.onPressed});

  final bool flagged;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: flagged ? AppColors.warning : context.palette.onMedium,
        minimumSize: const Size(48, 40),
        padding: const EdgeInsets.symmetric(horizontal: 8),
      ),
      icon: Icon(flagged ? Icons.flag : Icons.outlined_flag, size: 18),
      label: Text(flagged ? 'Flagged' : 'Flag (F)'),
    );
  }
}
