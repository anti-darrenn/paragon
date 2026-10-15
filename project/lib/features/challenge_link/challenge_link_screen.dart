import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/guest_limits.dart';
import '../../core/challenge/challenge_link.dart';
import '../../core/models/question.dart';
import '../../core/providers/analytics_provider.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/repositories/attempt_repository.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/guest_notice.dart';
import '../../core/widgets/nav/back_navigation.dart';
import '../../core/widgets/question_runner.dart';
import '../../core/widgets/ui/ui.dart';
import 'challenge_share.dart';

/// `/c/:id`: a friend's challenge. Read the score to beat, answer the same
/// questions with instant feedback, compare, and — the point of it for
/// Paragon — find the topic and an account one tap away.
///
/// Reached from a WhatsApp link, usually by someone with no session: the
/// router sends them to `/welcome?next=/c/<id>`, "Browse as guest" brings
/// them straight back (Wave B), and they play as a guest.
class ChallengeLinkScreen extends ConsumerStatefulWidget {
  const ChallengeLinkScreen({super.key, required this.id});

  final String id;

  @override
  ConsumerState<ChallengeLinkScreen> createState() =>
      _ChallengeLinkScreenState();
}

enum _Stage { intro, playing, done }

class _ChallengeLinkScreenState extends ConsumerState<ChallengeLinkScreen> {
  _Stage _stage = _Stage.intro;
  List<Question>? _questions;
  bool _loading = false;
  String? _error;
  int _mine = 0;
  List<({String questionId, bool correct})> _answers = const [];

  Future<void> _start(ChallengeLink c) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final qs = await ref.read(challengeRepositoryProvider).questions(c);
      if (!mounted) return;
      if (qs.isEmpty) {
        setState(() => _error = "This challenge's questions aren't available.");
        return;
      }
      setState(() {
        _questions = qs;
        _stage = _Stage.playing;
      });
    } catch (_) {
      if (mounted) setState(() => _error = "Couldn't load the questions.");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _finished(
    ChallengeLink c,
    List<({Question question, int selected, bool correct})> results,
  ) {
    setState(() {
      _mine = results.where((r) => r.correct).length;
      _answers = [
        for (final r in results)
          (questionId: r.question.id, correct: r.correct),
      ];
      _stage = _Stage.done;
    });
    ref
        .read(analyticsProvider)
        .challengePlayed(topicId: c.topicId, beat: _mine > c.score);
    final uid = ref.read(currentUserProvider)?.uid;
    if (uid == null) return;
    // Recorded like any practice, for the mistakes notebook; never fed to
    // `progress` (source: challenge_link), so it opens nothing.
    ref
        .read(attemptRepositoryProvider)
        .recordBatch(
          userId: uid,
          source: 'challenge_link',
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
        )
        .catchError((_) {});
  }

  Future<void> _challengeBack(ChallengeLink c) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    final back = challengeFrom(_answers);
    try {
      final id = await ref
          .read(challengeRepositoryProvider)
          .create(
            uid: user.uid,
            name: challengerName(user.displayName),
            subjectId: c.subjectId,
            topicId: c.topicId,
            topicName: c.topicName,
            questionIds: back.ids,
            score: back.score,
          );
      if (!mounted) return;
      await showChallengeShareSheet(
        context,
        id: id,
        message: challengeMessage(
          score: back.score,
          total: back.ids.length,
          topicName: c.topicName,
          id: id,
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Couldn't create the challenge.")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(challengeLinkProvider(widget.id));
    return Scaffold(
      appBar: const ParagonAppBar(title: Text('Challenge')),
      body: async.when(
        loading: () => const PageBody(children: [SkeletonPage(count: 3)]),
        error: (_, _) => _missing(context),
        data: (c) => c == null ? _missing(context) : _body(context, c),
      ),
    );
  }

  Widget _missing(BuildContext context) => EmptyState(
    icon: Icons.link_off_rounded,
    title: 'This challenge has ended',
    message: 'Challenges last 30 days. There is plenty more to practise.',
    action: ElevatedButton(
      onPressed: () => context.go('/courses'),
      child: const Text('Browse courses'),
    ),
  );

  Widget _body(BuildContext context, ChallengeLink c) {
    final palette = context.palette;
    final isGuest = ref.watch(isGuestProvider);
    final mineToShare = ref.watch(currentUserProvider)?.uid == c.userId;
    return PageBody(
      children: [
        switch (_stage) {
          _Stage.intro => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PageIntro(
                title: mineToShare
                    ? 'Your challenge'
                    : '${c.name} challenges you',
                subtitle:
                    '${c.name} scored ${c.score}/${c.total} on ${c.topicName}. '
                    '${mineToShare ? 'Send it to a friend.' : 'Can you beat that?'}',
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(_error!, style: AppTheme.bodyMd),
                ),
              if (mineToShare)
                ElevatedButton.icon(
                  icon: const Icon(Icons.send_rounded),
                  label: const Text('Send it'),
                  onPressed: () => showChallengeShareSheet(
                    context,
                    id: c.id,
                    message: challengeMessage(
                      score: c.score,
                      total: c.total,
                      topicName: c.topicName,
                      id: c.id,
                    ),
                  ),
                )
              else
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _loading ? null : () => _start(c),
                    child: Text(
                      _loading ? 'Loading…' : 'Answer ${c.total} questions',
                    ),
                  ),
                ),
            ],
          ),
          _Stage.playing => QuestionRunner(
            questions: _questions!,
            onFinished: (r) => _finished(c, r),
          ),
          _Stage.done => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PageIntro(
                title: '$_mine/${_answers.length}',
                subtitle: scoreLine(
                  mine: _mine,
                  theirs: c.score,
                  total: c.total,
                  name: c.name,
                ),
              ),
              if (isGuest) ...[
                GuestNotice(
                  message: GuestLimits.saveResultMessage(
                    'your $_mine/${_answers.length}',
                  ),
                ),
                const SizedBox(height: 16),
              ],
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: () => context.go(
                    '/subject/${c.subjectId}/course/topic/${c.topicId}',
                  ),
                  child: Text('Learn ${c.topicName}'),
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                icon: const Icon(Icons.replay_rounded),
                label: Text('Challenge ${c.name} back'),
                onPressed: () => _challengeBack(c),
              ),
              const SizedBox(height: 16),
              Text(
                'Answers here count toward your mistakes notebook, not '
                'toward topic mastery.',
                style: AppTheme.caption.copyWith(color: palette.textSecondary),
              ),
            ],
          ),
        },
      ],
    );
  }
}
