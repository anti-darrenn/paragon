import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/exam/exam_result.dart';
import '../core/learn/challenge.dart';
import '../core/learn/topic_test.dart';
import '../core/models/question.dart';
import '../core/auth/feature_access.dart';
import '../core/providers/auth_provider.dart';
import '../core/repositories/attempt_repository.dart';
import '../core/repositories/course_repository.dart';
import '../core/repositories/learn_progress_repository.dart';
import '../core/repositories/learn_repository.dart';
import '../core/repositories/progress_repository.dart';
import '../core/theme/app_palette.dart';
import '../core/widgets/answer_option.dart';
import '../core/widgets/load_error.dart';
import 'exam_review_screen.dart' show ExamReviewCard;
import '../core/widgets/nav/back_navigation.dart';
import '../core/widgets/session/session_frame.dart';
import '../core/widgets/session/session_summary.dart';
import '../core/widgets/ui/ui.dart';

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
    if (user == null ||
        !canUse(Feature.challenges, isGuest: ref.watch(isGuestProvider))) {
      body = Center(
        child: SingleChildScrollView(
          child: EmptyState(
            icon: Icons.lock_outline_rounded,
            title: 'This needs an account',
            message:
                'Unit tests and course challenges need an account, because '
                'what they unlock is saved to it.',
            action: AppButton(
              label: 'Make an account',
              onPressed: () => context.go('/account/upgrade'),
            ),
          ),
        ),
      );
    } else {
      body = ref
          .watch(courseProvider(subjectKey))
          .when(
            loading: () => const LoadingView(label: 'Loading your test'),
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
                return Center(
                  child: SingleChildScrollView(
                    child: EmptyState(
                      illustration: IllustrationAsset.empty,
                      title: 'Nothing to test yet',
                      message: 'There is nothing to test here yet.',
                      action: AppButton(
                        label: 'Back to the course',
                        onPressed: () => context.popOrGo(),
                      ),
                    ),
                  ),
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
          loading: () => const LoadingView(label: 'Loading your test'),
          error: (e, _) => LoadError(
            error: e,
            onRetry: () => ref.invalidate(challengeQuestionsProvider(_planKey)),
          ),
          data: (questions) => questions.isEmpty
              ? Center(
                  child: SingleChildScrollView(
                    child: EmptyState(
                      illustration: IllustrationAsset.empty,
                      title: 'No questions for this test yet',
                      message: 'No questions could be found for this test.',
                      action: AppButton(
                        label: 'Back to the course',
                        onPressed: () => context.popOrGo(),
                      ),
                    ),
                  ),
                )
              : _sitting(context, questions),
        );
  }

  Widget _sitting(BuildContext context, List<Question> questions) {
    final q = questions[_index];
    final last = _index == questions.length - 1;
    final VoidCallback? next = _answers[_index] == null
        ? null
        : () => last ? _submit(questions) : setState(() => _index++);
    return SessionKeys(
      optionCount: q.options.length,
      onSelect: (i) => setState(() => _answers[_index] = i),
      onEnter: next,
      child: SessionLayout(
        header: SessionHeader(
          index: _index,
          total: questions.length,
          // Answered or not — never right or wrong: marked at the end.
          states: [
            for (var i = 0; i < questions.length; i++)
              _answers[i] != null
                  ? SegmentState.answered
                  : SegmentState.pending,
          ],
          note: 'marked at the end',
        ),
        bar: SessionNavBar(
          nextLabel: last ? 'Finish' : 'Next',
          onNext: next,
          onBack: _index > 0 ? () => setState(() => _index--) : null,
        ),
        children: [
          QuestionCard(question: q, showSource: false),
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
        ],
      ),
    );
  }

  Widget _results(BuildContext context) {
    final right = _tallies.values.fold(0, (s, t) => s + t.correct);
    final total = _questions.length;
    final names = {for (final t in widget.topics) t.id: t.name};
    final unit = widget.kind != ChallengeKind.courseChallenge;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 40),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: kPageMaxWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SessionSummary(
                title: unit ? 'Unit test done' : 'Course challenge done',
                correct: right,
                total: total,
                subtitle:
                    '${topicTestScore(correct: right, total: total)}% correct',
                celebrate:
                    _unlocked.isNotEmpty ||
                    SessionSummary.isWorthCelebrating(
                      correct: right,
                      total: total,
                    ),
                details: [
                  if (_unlocked.isNotEmpty)
                    InlineAlert(
                      tone: Tone.success,
                      icon: Icons.lock_open_rounded,
                      announce: true,
                      message: _unlocked.length == 1
                          ? 'You unlocked practice for 1 topic.'
                          : 'You unlocked practice for '
                                '${_unlocked.length} topics.',
                    ),
                  if (!unit)
                    const InlineAlert(
                      tone: Tone.neutral,
                      message:
                          'A course challenge has too few questions per topic '
                          'to unlock practice. A unit test can.',
                    ),
                  if (_saving)
                    const LoadingView(
                      label: 'Saving your results',
                      delay: Duration.zero,
                      padding: EdgeInsets.zero,
                    )
                  else if (_saveFailed)
                    InlineAlert(
                      tone: Tone.danger,
                      announce: true,
                      message:
                          "Your results couldn't be saved. Check your "
                          'connection.',
                      action: TextButton(
                        onPressed: _save,
                        child: const Text('Try again'),
                      ),
                    ),
                ],
                primary: AppButton(
                  label: 'Back to the course',
                  expand: true,
                  onPressed: () => context.popOrGo(),
                ),
              ),
              const SizedBox(height: 32),
              const SectionHeader('By topic'),
              RowGroup(
                children: [
                  for (final e in _tallies.entries)
                    ListRow(
                      title: names[e.key] ?? 'A topic',
                      subtitle: '${e.value.correct} of ${e.value.total} right',
                      trailing: _unlocked.contains(e.key)
                          ? const Tag(
                              'Unlocked',
                              tone: Tone.success,
                              icon: Icons.lock_open_rounded,
                            )
                          : null,
                      onTap: () =>
                          context.push(widget.course.pathForTopicId(e.key)),
                    ),
                ],
              ),
              const SizedBox(height: kSectionGap),
              const SectionHeader('Your answers'),
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
      ),
    );
  }
}
