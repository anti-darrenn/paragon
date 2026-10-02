import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/exam/exam_result.dart';
import '../core/learn/challenge.dart';
import '../core/learn/topic_test.dart';
import '../core/models/question.dart';
import '../core/providers/auth_provider.dart';
import '../core/repositories/attempt_repository.dart';
import '../core/repositories/course_repository.dart';
import '../core/repositories/learn_progress_repository.dart';
import '../core/repositories/learn_repository.dart';
import '../core/repositories/progress_repository.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_palette.dart';
import '../core/theme/app_theme.dart';
import '../core/widgets/answer_option.dart';
import '../core/widgets/full_latex_view.dart';
import '../core/widgets/load_error.dart';
import '../core/widgets/question_image.dart';
import 'exam_review_screen.dart' show ExamReviewCard;
import '../core/widgets/nav/back_navigation.dart';

/// A unit test (`/subject/:s/course/unit/:moduleId/test`) or the course
/// challenge (`/subject/:s/course/challenge`). The rules are in
/// `lib/core/learn/challenge.dart`; this screen sits the questions, with
/// no feedback until the end, then marks them, records them and shows
/// what moved.
class ChallengeScreen extends ConsumerWidget {
  const ChallengeScreen({super.key, required this.subjectKey, this.moduleId});

  final String subjectKey;

  /// The module for a unit test; null for the course challenge.
  final String? moduleId;

  ChallengeKind get kind =>
      moduleId == null ? ChallengeKind.courseChallenge : ChallengeKind.unitTest;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final title = kind == ChallengeKind.unitTest
        ? 'Unit test'
        : 'Course challenge';
    final Widget body;
    final user = ref.watch(currentUserProvider);
    if (user == null || ref.watch(isGuestProvider)) {
      body = _Note(
        text:
            'Unit tests and course challenges need an account, because '
            'what they unlock is saved to it.',
        action: 'Make an account',
        onAction: () => context.go('/account/upgrade'),
      );
    } else {
      body = ref
          .watch(courseProvider(subjectKey))
          .when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => LoadError(
              error: e,
              onRetry: () => ref.invalidate(courseProvider(subjectKey)),
            ),
            data: (course) {
              final topics = [
                for (final m in course.modules)
                  if (moduleId == null || m.id == moduleId)
                    for (final t in m.topics)
                      if (!t.isPlaceholder && t.questionCount > 0) t,
              ];
              if (!course.isLive || topics.isEmpty) {
                return _Note(
                  text: 'There is nothing to test here yet.',
                  action: 'Back to the course',
                  onAction: () => context.popOrGo(),
                );
              }
              return _Sitting(
                kind: kind,
                course: course,
                topics: topics,
                uid: user.uid,
              );
            },
          );
    }
    return Scaffold(
      backgroundColor: context.palette.background,
      appBar: ParagonAppBar(title: Text(title)),
      body: body,
    );
  }
}

class _Sitting extends ConsumerStatefulWidget {
  const _Sitting({
    required this.kind,
    required this.course,
    required this.topics,
    required this.uid,
  });

  final ChallengeKind kind;
  final Course course;
  final List<CourseTopic> topics;
  final String uid;

  @override
  ConsumerState<_Sitting> createState() => _SittingState();
}

class _SittingState extends ConsumerState<_Sitting> {
  /// Fixed when the screen opens, so a progress update mid-sitting cannot
  /// redraw the questions.
  late final String _planKey;

  /// Taken on submit, not on open: the gate's streams may not have
  /// delivered yet when the screen opens, and an open topic read as
  /// locked would lose its mastery counts. [build] keeps both streams
  /// subscribed so they are current by then. Taken before any write, so
  /// this challenge's own unlocks are not mistaken for earlier ones.
  Set<String> _openBefore = const {};
  TopicTestProgress _testsBefore = TopicTestProgress.empty;

  int _index = 0;
  final _answers = <int, int>{};
  bool _submitted = false;

  // what the save got through; a retry repeats only what failed
  bool _attemptsSaved = false;
  bool _unlocksSaved = false;
  bool _masterySaved = false;
  bool _saving = false;
  bool _saveFailed = false;

  List<Question> _questions = const [];
  Map<String, TopicTally> _tallies = const {};
  Set<String> _unlocked = const {};

  @override
  void initState() {
    super.initState();
    final progress =
        ref.read(userProgressProvider).asData?.value ?? UserProgress.empty;
    final topics = [
      for (final t in widget.topics)
        (id: t.id, points: progress.levelFor(t.id).points),
    ];
    _planKey = challengePlanKey(
      widget.kind == ChallengeKind.unitTest
          ? planUnitTest(topics)
          : planCourseChallenge(topics),
    );
  }

  String get _subjectId => widget.course.subjectId ?? '';

  void _submit(List<Question> questions) {
    _openBefore = {
      for (final t in widget.topics)
        if (ref.read(drillAccessProvider(t.id)).isAllowed) t.id,
    };
    _testsBefore =
        ref.read(topicTestProgressProvider).asData?.value ??
        TopicTestProgress.empty;
    final answers = [
      for (var i = 0; i < questions.length; i++)
        (
          topicId: questions[i].topicId,
          isCorrect: _answers[i] == questions[i].correctIndex,
        ),
    ];
    final tallies = tallyByTopic(answers);
    setState(() {
      _submitted = true;
      _questions = questions;
      _tallies = tallies;
      _unlocked = topicsUnlockedBy(
        widget.kind,
        tallies,
      ).where((id) => !_openBefore.contains(id)).toSet();
    });
    _save();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _saveFailed = false;
    });
    try {
      if (!_attemptsSaved) {
        await ref
            .read(attemptRepositoryProvider)
            .recordBatch(
              userId: widget.uid,
              // its own source: drill queries filter on it, and only drill
              // feeds mastery directly
              source: 'challenge',
              attempts: [
                for (var i = 0; i < _questions.length; i++)
                  if (_answers[i] case final picked?)
                    AttemptDraft(
                      questionId: _questions[i].id,
                      topicId: _questions[i].topicId,
                      subjectId: _questions[i].subjectId,
                      selectedIndex: picked,
                      isCorrect: picked == _questions[i].correctIndex,
                    ),
              ],
            );
        _attemptsSaved = true;
      }
      if (!_unlocksSaved) {
        final learn = ref.read(learnProgressRepositoryProvider);
        for (final id in _unlocked) {
          final t = _tallies[id]!;
          await learn.recordChallengePass(
            uid: widget.uid,
            topicId: id,
            subjectId: _subjectId,
            correct: t.correct,
            total: t.total,
            previous: _testsBefore.forTopic(id),
          );
        }
        _unlocksSaved = true;
      }
      if (!_masterySaved) {
        final progress = ref.read(progressRepositoryProvider);
        final feeding = topicsFeedingMastery(
          _tallies,
          openBefore: _openBefore,
          unlocked: _unlocked,
        );
        for (final id in feeding) {
          final t = _tallies[id]!;
          await progress.addSession(
            uid: widget.uid,
            topicId: id,
            subjectId: _subjectId,
            answered: t.total,
            correct: t.correct,
          );
        }
        _masterySaved = true;
      }
    } catch (_) {
      if (mounted) setState(() => _saveFailed = true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // subscribed for [_submit]; see [_openBefore]
    ref.watch(topicTestProgressProvider);
    ref.watch(userProgressProvider);
    if (_submitted) return _results(context);
    return ref
        .watch(challengeQuestionsProvider(_planKey))
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => LoadError(
            error: e,
            onRetry: () => ref.invalidate(challengeQuestionsProvider(_planKey)),
          ),
          data: (questions) => questions.isEmpty
              ? _Note(
                  text: 'No questions could be found for this test.',
                  action: 'Back to the course',
                  onAction: () => context.popOrGo(),
                )
              : _sitting(context, questions),
        );
  }

  Widget _sitting(BuildContext context, List<Question> questions) {
    final q = questions[_index];
    final last = _index == questions.length - 1;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
          children: [
            LinearProgressIndicator(
              value: (_index + 1) / questions.length,
              backgroundColor: context.palette.track,
              valueColor: const AlwaysStoppedAnimation(AppColors.primary),
              minHeight: 3,
            ),
            const SizedBox(height: 12),
            Text(
              'Question ${_index + 1} of ${questions.length} · marked at the end',
              style: AppTheme.caption.copyWith(
                color: context.palette.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            FullLatexView(
              latex: q.text,
              textStyle: AppTheme.bodyLg.copyWith(
                color: context.palette.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            QuestionImage(assetId: q.imageId),
            const SizedBox(height: 20),
            // No right/wrong colouring: like the topic test and the WAEC
            // exam, this is marked at the end.
            for (var i = 0; i < q.options.length; i++)
              AnswerOption(
                index: i,
                text: q.options[i],
                state: _answers[_index] == i
                    ? AnswerOptionState.selected
                    : AnswerOptionState.idle,
                onTap: () => setState(() => _answers[_index] = i),
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (_index > 0)
                  TextButton(
                    onPressed: () => setState(() => _index--),
                    child: const Text('Back'),
                  ),
                const Spacer(),
                ElevatedButton(
                  onPressed: _answers[_index] == null
                      ? null
                      : () => last
                            ? _submit(questions)
                            : setState(() => _index++),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 14,
                    ),
                  ),
                  child: Text(
                    last ? 'Finish' : 'Next',
                    style: AppTheme.btnLabel.copyWith(color: Colors.white),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _results(BuildContext context) {
    final right = _tallies.values.fold(0, (s, t) => s + t.correct);
    final total = _questions.length;
    final names = {for (final t in widget.topics) t.id: t.name};
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 40),
          children: [
            Text(
              '$right / $total',
              textAlign: TextAlign.center,
              style: AppTheme.heading1.copyWith(
                color: context.palette.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${topicTestScore(correct: right, total: total)}% correct',
              textAlign: TextAlign.center,
              style: AppTheme.bodyMd.copyWith(
                color: context.palette.textSecondary,
              ),
            ),
            if (_unlocked.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                _unlocked.length == 1
                    ? 'You unlocked practice for 1 topic.'
                    : 'You unlocked practice for ${_unlocked.length} topics.',
                textAlign: TextAlign.center,
                style: AppTheme.bodyMd.copyWith(
                  color: AppColors.correct,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            if (widget.kind == ChallengeKind.courseChallenge) ...[
              const SizedBox(height: 12),
              Text(
                'A course challenge has too few questions per topic to '
                'unlock practice. A unit test can.',
                textAlign: TextAlign.center,
                style: AppTheme.caption.copyWith(
                  color: context.palette.textSecondary,
                ),
              ),
            ],
            if (_saving)
              const Padding(
                padding: EdgeInsets.only(top: 16),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_saveFailed)
              _Note(
                text: "Your results couldn't be saved. Check your connection.",
                action: 'Try again',
                onAction: _save,
              ),
            const SizedBox(height: 20),
            Text(
              'By topic',
              style: AppTheme.heading3.copyWith(
                color: context.palette.textPrimary,
              ),
            ),
            for (final e in _tallies.entries)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  names[e.key] ?? 'A topic',
                  style: AppTheme.bodyMd.copyWith(
                    color: context.palette.textPrimary,
                  ),
                ),
                subtitle: Text(
                  '${e.value.correct} of ${e.value.total} right',
                  style: AppTheme.caption.copyWith(
                    color: context.palette.textSecondary,
                  ),
                ),
                trailing: _unlocked.contains(e.key)
                    ? const Icon(
                        Icons.lock_open_rounded,
                        color: AppColors.correct,
                      )
                    : null,
                onTap: () => context.push(
                  '/subject/${widget.course.key}/course/topic/${e.key}',
                ),
              ),
            const SizedBox(height: 20),
            Text(
              'Your answers',
              style: AppTheme.heading3.copyWith(
                color: context.palette.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            for (var i = 0; i < _questions.length; i++)
              ExamReviewCard(
                number: i + 1,
                item: ExamItem(
                  questionId: _questions[i].id,
                  topicId: _questions[i].topicId,
                  selected: _answers[i] ?? -1,
                ),
                question: _questions[i],
              ),
          ],
        ),
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({
    required this.text,
    required this.action,
    required this.onAction,
  });

  final String text;
  final String action;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            text,
            textAlign: TextAlign.center,
            style: AppTheme.bodyMd.copyWith(
              color: context.palette.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          TextButton(onPressed: onAction, child: Text(action)),
        ],
      ),
    );
  }
}
