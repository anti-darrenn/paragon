import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/content/quiz_mix.dart';
import '../../../core/learn/topic_test.dart' show DrillAccess;
import '../../../core/models/question.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/questions/difficulty.dart';
import '../../../core/repositories/attempt_repository.dart';
import '../../../core/repositories/course_repository.dart';
import '../../../core/repositories/difficulty_vote_repository.dart';
import '../../../core/repositories/learn_progress_repository.dart';
import '../../../core/repositories/learning_repository.dart';
import '../../../core/repositories/progress_repository.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/nav/back_navigation.dart';
import '../../../core/widgets/question_runner.dart';
import '../../../core/widgets/ui/ui.dart';

/// The most topics one quiz mixes; each is one drill-pool read.
const kMaxQuizTopics = 10;

/// What a finished quiz adds to mastery: one session per topic, **only
/// for topics whose drill is already open** ([isOpen], `drillAccessFor`).
/// A quiz must never be a way around a topic test. Pure.
List<({String topicId, String subjectId, int answered, int correct})>
quizMasterySessions(
  List<({Question question, int selected, bool correct})> results, {
  required bool Function(String topicId) isOpen,
}) {
  final by = <String, ({String subjectId, int answered, int correct})>{};
  for (final r in results) {
    final t = r.question.topicId;
    if (t.isEmpty || !isOpen(t)) continue;
    final prev = by[t];
    by[t] = (
      subjectId: r.question.subjectId,
      answered: (prev?.answered ?? 0) + 1,
      correct: (prev?.correct ?? 0) + (r.correct ? 1 : 0),
    );
  }
  return [
    for (final e in by.entries)
      (
        topicId: e.key,
        subjectId: e.value.subjectId,
        answered: e.value.answered,
        correct: e.value.correct,
      ),
  ];
}

/// `/review/quiz`: a quiz from any mix of topics (owner's request,
/// 2026-10-17). Pick a subject, up to ten topics, a length and, if wanted,
/// a difficulty; instant feedback on each answer.
///
/// **What it records.** Answers are attempts with `source: 'quiz'`, and they
/// count towards mastery **only for topics whose drill is already open**
/// (`drillAccessFor`), the same rule the unit test follows. A quiz must not
/// be a way around a topic test.
class CustomQuizScreen extends ConsumerStatefulWidget {
  const CustomQuizScreen({super.key});

  @override
  ConsumerState<CustomQuizScreen> createState() => _CustomQuizScreenState();
}

class _CustomQuizScreenState extends ConsumerState<CustomQuizScreen> {
  String? _subjectId;
  final _topics = <String>{};
  int _length = 10;
  DifficultyTier? _tier;
  List<Question>? _questions;
  bool _loading = false;
  ({int correct, int total})? _result;
  final Map<String, int> _ratings = {};

  Future<void> _start() async {
    setState(() => _loading = true);
    try {
      final pools = await Future.wait([
        for (final t in _topics) ref.read(drillQuestionsProvider(t).future),
      ]);
      final qs = buildCustomQuiz(pools, length: _length, tier: _tier);
      if (!mounted) return;
      if (qs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No questions match. Try more topics or any difficulty.',
            ),
          ),
        );
        return;
      }
      setState(() => _questions = qs);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Couldn't load questions: $e")));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _finish(
    List<({Question question, int selected, bool correct})> results,
  ) async {
    setState(() {
      _result = (
        correct: results.where((r) => r.correct).length,
        total: results.length,
      );
    });
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    if (_ratings.isNotEmpty) {
      ref
          .read(difficultyVoteRepositoryProvider)
          .submit(uid: user.uid, votes: Map.of(_ratings))
          .ignore();
    }
    try {
      await ref
          .read(attemptRepositoryProvider)
          .recordBatch(
            userId: user.uid,
            source: 'quiz',
            attempts: [
              for (final r in results)
                AttemptDraft(
                  questionId: r.question.id,
                  topicId: r.question.topicId,
                  subjectId: r.question.subjectId,
                  selectedIndex: r.selected,
                  isCorrect: r.correct,
                ),
            ],
          );
      final sessions = quizMasterySessions(
        results,
        isOpen: (t) => ref.read(drillAccessProvider(t)) == DrillAccess.allowed,
      );
      for (final m in sessions) {
        await ref
            .read(progressRepositoryProvider)
            .addSession(
              uid: user.uid,
              topicId: m.topicId,
              subjectId: m.subjectId,
              answered: m.answered,
              correct: m.correct,
            );
      }
    } catch (_) {
      // Practice history is not worth interrupting the result over.
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Scaffold(
      backgroundColor: palette.background,
      appBar: const ParagonAppBar(title: Text('Custom quiz')),
      body: PageBody(
        children: [
          if (_result case final r?)
            Column(
              children: [
                EmptyState(
                  icon: Icons.emoji_events_outlined,
                  title: '${r.correct} of ${r.total}',
                  message: r.correct == r.total
                      ? 'Every one. Try a harder difficulty next.'
                      : 'Your wrong answers are in the mistakes notebook.',
                ),
                FilledButton(
                  onPressed: () => setState(() {
                    _result = null;
                    _questions = null;
                    _ratings.clear();
                  }),
                  child: const Text('New quiz'),
                ),
              ],
            )
          else if (_questions case final qs?)
            QuestionRunner(questions: qs, ratings: _ratings, onFinished: _finish)
          else
            _setup(palette),
        ],
      ),
    );
  }

  Widget _setup(AppPalette palette) {
    final subjects = ref.watch(subjectsProvider).asData?.value ?? const [];
    final subjectId = _subjectId ?? (subjects.isEmpty ? null : subjects.first.id);
    final course = subjectId == null
        ? null
        : ref.watch(courseProvider(subjectId)).asData?.value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Mix topics into one quiz. Instant feedback on every answer.',
          style: AppTheme.bodyMd.copyWith(color: palette.textSecondary),
        ),
        const SizedBox(height: 16),
        const SectionHeader('Subject'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final s in subjects)
              ChoiceChip(
                label: Text(s.name),
                selected: s.id == subjectId,
                onSelected: (_) => setState(() {
                  _subjectId = s.id;
                  _topics.clear();
                }),
              ),
          ],
        ),
        const SizedBox(height: 20),
        SectionHeader(
          'Topics',
          subtitle: '${_topics.length} of up to $kMaxQuizTopics chosen',
        ),
        if (course == null)
          const Padding(
            padding: EdgeInsets.all(12),
            child: Center(child: CircularProgressIndicator()),
          )
        else
          for (final m in course.modules)
            if (m.topics.any((t) => !t.isPlaceholder && t.counts.servable > 0))
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: SurfaceCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              m.name,
                              style: AppTheme.label.copyWith(
                                color: palette.textPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () => setState(() {
                              for (final t in m.topics) {
                                if (t.isPlaceholder || t.counts.servable == 0) {
                                  continue;
                                }
                                if (_topics.length >= kMaxQuizTopics) break;
                                _topics.add(t.id);
                              }
                            }),
                            child: const Text('All'),
                          ),
                        ],
                      ),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final t in m.topics)
                            if (!t.isPlaceholder && t.counts.servable > 0)
                              FilterChip(
                                label: Text(t.name),
                                selected: _topics.contains(t.id),
                                onSelected: (on) => setState(() {
                                  if (!on) {
                                    _topics.remove(t.id);
                                  } else if (_topics.length < kMaxQuizTopics) {
                                    _topics.add(t.id);
                                  }
                                }),
                              ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
        const SizedBox(height: 8),
        const SectionHeader('Length'),
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 10, label: Text('10')),
            ButtonSegment(value: 20, label: Text('20')),
            ButtonSegment(value: 30, label: Text('30')),
          ],
          selected: {_length},
          onSelectionChanged: (s) => setState(() => _length = s.first),
        ),
        const SizedBox(height: 20),
        const SectionHeader('Difficulty'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              label: const Text('Any'),
              selected: _tier == null,
              onSelected: (_) => setState(() => _tier = null),
            ),
            for (final t in DifficultyTier.values)
              ChoiceChip(
                label: Text(t.label),
                selected: _tier == t,
                onSelected: (_) => setState(() => _tier = t),
              ),
          ],
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: _topics.isEmpty || _loading ? null : _start,
          child: Text(_loading ? 'Getting questions…' : 'Start the quiz'),
        ),
        if (_topics.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Choose at least one topic.',
              style: AppTheme.caption.copyWith(color: context.palette.warningFg),
            ),
          ),
      ],
    );
  }
}
