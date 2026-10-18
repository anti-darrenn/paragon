import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/feature_access.dart';
import '../../core/content/quiz_mix.dart';
import '../../core/providers/analytics_provider.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/questions/difficulty.dart';
import '../../core/repositories/course_repository.dart';
import '../../core/repositories/learning_repository.dart';
import '../../core/rooms/room.dart';
import '../../core/rooms/room_repository.dart';
import '../../core/rooms/teacher_quiz.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/nav/back_navigation.dart';
import '../../core/widgets/ui/ui.dart';
import 'room_paths.dart';

/// The most bank topics one room mixes; each is one drill-pool read.
const kMaxRoomTopics = 10;

/// The most questions in a room; the rules hold the same cap.
const kMaxRoomQuestions = 30;

enum _Source { bank, mine, both }

/// The room's order from what the host chose (pure): bank questions as
/// `b:<id>`, then the quiz's as `q:<i>`, mixed when both. At most
/// [kMaxRoomQuestions].
List<String> roomOrder({
  required List<String> bankIds,
  required int quizCount,
  bool shuffle = true,
  Random? random,
}) {
  final items = [
    for (final id in bankIds) 'b:$id',
    for (var i = 0; i < quizCount; i++) 'q:$i',
  ];
  if (shuffle && bankIds.isNotEmpty && quizCount > 0) {
    items.shuffle(random ?? Random());
  }
  return items.take(kMaxRoomQuestions).toList();
}

/// `/rooms/new`: what to ask, how to score it, and how long each question
/// lasts. Accounts only.
///
/// - **Questions:** Paragon's, from any mix of up to ten topics (one topic
///   gives the old single-topic room), the host's own quiz, or both.
/// - **Mode:** speed (Kahoot-style points for a fast right answer) or
///   classic (one point a right answer).
/// - **Timer:** 10 to 90 seconds a question, or none in a classic room.
class NewRoomScreen extends ConsumerStatefulWidget {
  const NewRoomScreen({super.key});

  @override
  ConsumerState<NewRoomScreen> createState() => _NewRoomScreenState();
}

class _NewRoomScreenState extends ConsumerState<NewRoomScreen> {
  _Source _source = _Source.bank;
  String? _subjectId;
  final _topics = <String>{};
  final _topicNames = <String, String>{};
  int _count = 10;
  DifficultyTier? _tier;
  String? _quizId;
  RoomMode _mode = RoomMode.speed;
  int _timeLimit = 20;
  bool _busy = false;
  String? _error;

  bool get _usesBank => _source != _Source.mine;
  bool get _usesQuiz => _source != _Source.bank;

  Future<void> _create() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      var bankIds = <String>[];
      if (_usesBank && _topics.isNotEmpty) {
        final pools = await Future.wait([
          for (final t in _topics) ref.read(drillQuestionsProvider(t).future),
        ]);
        bankIds = [
          for (final q in buildCustomQuiz(pools, length: _count, tier: _tier))
            q.id,
        ];
      }
      TeacherQuiz? quiz;
      if (_usesQuiz && _quizId != null) {
        quiz = await ref.read(teacherQuizProvider(_quizId!).future);
      }
      final quizCount = quiz == null ? 0 : quiz.questions.length;
      final playable = quiz == null
          ? const <int>[]
          : [
              for (var i = 0; i < quiz.questions.length; i++)
                if (quiz.questions[i].isComplete) i,
            ];
      final items = [
        for (final i in roomOrder(bankIds: bankIds, quizCount: quizCount))
          if (i.startsWith('b:') ||
              playable.contains(int.parse(i.substring(2))))
            i,
      ];
      if (items.isEmpty) {
        setState(() => _error = 'Choose topics or a quiz with questions in it.');
        return;
      }
      final title = quiz != null && bankIds.isEmpty
          ? quiz.title
          : _topics.length == 1
          ? _topicNames[_topics.first] ?? 'Live quiz'
          : quiz != null
          ? '${quiz.title} and more'
          : '${_topics.length} topics';
      final code = await ref
          .read(roomRepositoryProvider)
          .create(
            hostUid: user.uid,
            subjectId: _subjectId ?? quiz?.subjectId ?? '',
            topicId: _topics.length == 1 && bankIds.isNotEmpty
                ? _topics.first
                : '',
            topicName: title,
            questionIds: bankIds,
            items: items,
            quizId: quiz?.id,
            mode: _mode,
            timeLimit: _timeLimit,
          );
      ref.read(analyticsProvider).roomHosted(questions: items.length);
      if (mounted) context.go('/rooms/$code/host');
    } catch (_) {
      if (mounted) {
        setState(() => _error = "Couldn't make the room. Try again.");
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    if (!canUse(Feature.hostRoom, isGuest: ref.watch(isGuestProvider))) {
      return Scaffold(
        appBar: const ParagonAppBar(title: Text('Host a quiz')),
        body: EmptyState(
          icon: Icons.groups_outlined,
          title: 'Hosting needs an account',
          message:
              'Anyone can join a quiz as a guest; making one needs a '
              'free account.',
          action: ElevatedButton(
            onPressed: () => context.push('/account/upgrade'),
            child: const Text('Make an account'),
          ),
        ),
      );
    }
    final ready =
        (_usesBank && _topics.isNotEmpty) || (_usesQuiz && _quizId != null);
    return Scaffold(
      appBar: const ParagonAppBar(title: Text('Host a quiz')),
      body: PageBody(
        children: [
          const PageIntro(
            title: 'Host a live quiz',
            subtitle:
                'Everyone answers the same question at once on their own '
                'phone. Rooms close after a day.',
          ),
          const SectionHeader('Questions'),
          SegmentedButton<_Source>(
            segments: const [
              ButtonSegment(
                value: _Source.bank,
                label: Text('Paragon\'s'),
                icon: Icon(Icons.inventory_2_outlined),
              ),
              ButtonSegment(
                value: _Source.mine,
                label: Text('My quiz'),
                icon: Icon(Icons.edit_note_rounded),
              ),
              ButtonSegment(
                value: _Source.both,
                label: Text('Both'),
                icon: Icon(Icons.merge_rounded),
              ),
            ],
            selected: {_source},
            onSelectionChanged: (s) => setState(() => _source = s.first),
          ),
          if (_usesQuiz) ...[
            const SizedBox(height: kSectionGap),
            _MyQuizPicker(
              selected: _quizId,
              onChanged: (id) => setState(() => _quizId = id),
            ),
          ],
          if (_usesBank) ...[
            const SizedBox(height: kSectionGap),
            _BankPicker(
              subjectId: _subjectId,
              topics: _topics,
              onSubject: (id) => setState(() {
                _subjectId = id;
                _topics.clear();
              }),
              onTopic: (id, name, on) => setState(() {
                if (!on) {
                  _topics.remove(id);
                } else if (_topics.length < kMaxRoomTopics) {
                  _topics.add(id);
                  _topicNames[id] = name;
                }
              }),
            ),
            const SizedBox(height: kSectionGap),
            const SectionHeader('How many from Paragon'),
            Wrap(
              spacing: 8,
              children: [
                for (final n in const [5, 10, 15, 20, 30])
                  ChoiceChip(
                    label: Text('$n'),
                    selected: _count == n,
                    onSelected: (_) => setState(() => _count = n),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Any difficulty'),
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
          ],
          const SizedBox(height: kSectionGap),
          const SectionHeader('Scoring'),
          SegmentedButton<RoomMode>(
            segments: const [
              ButtonSegment(
                value: RoomMode.speed,
                label: Text('Speed'),
                icon: Icon(Icons.bolt_rounded),
              ),
              ButtonSegment(
                value: RoomMode.classic,
                label: Text('Classic'),
                icon: Icon(Icons.check_rounded),
              ),
            ],
            selected: {_mode},
            onSelectionChanged: (s) => setState(() {
              _mode = s.first;
              if (_mode == RoomMode.speed && _timeLimit == 0) _timeLimit = 20;
            }),
          ),
          const SizedBox(height: 6),
          Text(
            _mode == RoomMode.speed
                ? 'A right answer scores up to $kSpeedMaxPoints, falling to '
                      '$kSpeedMinPoints at the time limit, plus a bonus for a '
                      'run of right answers.'
                : 'One point a right answer, however long it takes.',
            style: AppTheme.caption.copyWith(color: palette.textSecondary),
          ),
          const SizedBox(height: kSectionGap),
          const SectionHeader(
            'Time a question',
            subtitle: 'A question also ends as soon as everyone has answered.',
          ),
          Wrap(
            spacing: 8,
            children: [
              for (final s in kRoomTimeLimits)
                ChoiceChip(
                  label: Text('$s s'),
                  selected: _timeLimit == s,
                  onSelected: (_) => setState(() => _timeLimit = s),
                ),
              if (_mode == RoomMode.classic)
                ChoiceChip(
                  label: const Text('No timer'),
                  selected: _timeLimit == 0,
                  onSelected: (_) => setState(() => _timeLimit = 0),
                ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: AppTheme.bodyMd.copyWith(color: AppColors.wrong),
            ),
          ],
          const SizedBox(height: kSectionGap),
          SizedBox(
            height: 52,
            child: FilledButton.icon(
              onPressed: !ready || _busy ? null : _create,
              icon: const Icon(Icons.rocket_launch_outlined),
              label: Text(_busy ? 'Making the room…' : 'Make the room'),
            ),
          ),
        ],
      ),
    );
  }
}

class _MyQuizPicker extends ConsumerWidget {
  const _MyQuizPicker({required this.selected, required this.onChanged});
  final String? selected;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final quizzes = ref.watch(myQuizzesProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          'My quizzes',
          subtitle: 'Questions you wrote, with your own diagrams.',
          action: TextButton.icon(
            onPressed: () => context.push(quizEditPath('new')),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Write a quiz'),
          ),
        ),
        quizzes.when(
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => const Text("Couldn't load your quizzes."),
          data: (list) => list.isEmpty
              ? Text(
                  'No quizzes yet. Write one, then come back here.',
                  style: AppTheme.bodyMd.copyWith(color: palette.textSecondary),
                )
              : RadioGroup<String>(
                  groupValue: selected,
                  onChanged: onChanged,
                  child: Column(
                    children: [
                      for (final q in list)
                        RadioListTile<String>(
                          value: q.id,
                          title: Text(q.title),
                          subtitle: Text(
                            '${q.playable.length} of ${q.questions.length} '
                            'questions ready',
                          ),
                          enabled: q.playable.isNotEmpty,
                        ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}

class _BankPicker extends ConsumerWidget {
  const _BankPicker({
    required this.subjectId,
    required this.topics,
    required this.onSubject,
    required this.onTopic,
  });

  final String? subjectId;
  final Set<String> topics;
  final ValueChanged<String> onSubject;
  final void Function(String id, String name, bool on) onTopic;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final subjects = ref.watch(subjectsProvider).asData?.value ?? const [];
    final id = subjectId;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader('Subject'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final s in subjects)
              ChoiceChip(
                label: Text(s.name),
                selected: id == s.id,
                onSelected: (_) => onSubject(s.id),
              ),
          ],
        ),
        if (id != null) ...[
          const SizedBox(height: kSectionGap),
          SectionHeader(
            'Topics',
            subtitle:
                '${topics.length} of up to $kMaxRoomTopics. One topic, or a mix.',
          ),
          ref
              .watch(courseProvider(id))
              .when(
                loading: () => const SkeletonPage(
                  title: false,
                  count: 4,
                  cardHeight: 48,
                ),
                error: (_, _) => const Text("Couldn't load the topics."),
                data: (course) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final m in course.modules)
                      if (m.topics.any(
                        (t) => !t.isPlaceholder && t.counts.servable >= 5,
                      ))
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                m.name,
                                style: AppTheme.label.copyWith(
                                  color: palette.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  for (final t in m.topics)
                                    if (!t.isPlaceholder &&
                                        t.counts.servable >= 5)
                                      FilterChip(
                                        label: Text(t.name),
                                        selected: topics.contains(t.id),
                                        onSelected: (on) =>
                                            onTopic(t.id, t.name, on),
                                      ),
                                ],
                              ),
                            ],
                          ),
                        ),
                  ],
                ),
              ),
        ],
      ],
    );
  }
}
