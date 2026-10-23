import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/question.dart';
import '../../core/providers/analytics_provider.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/rooms/room.dart';
import '../../core/rooms/room_repository.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/full_latex_view.dart';
import '../../core/widgets/nav/back_navigation.dart';
import '../../core/widgets/question_image.dart';
import '../../core/widgets/ui/ui.dart';
import '../../core/rooms/quiz_history.dart';
import 'room_paths.dart';
import 'room_ui.dart';

/// `/rooms/:code`: a player's phone. Pick a nickname, wait, then answer
/// each question as the host shows it, see whether it was right at the
/// reveal, and your place at the end. Guests welcome.
///
/// A player listens to the room and their own answer only — never to the
/// whole room's players or answers — so thirty phones cost thirty
/// listeners, not nine hundred.
class PlayerRoomScreen extends ConsumerStatefulWidget {
  const PlayerRoomScreen({super.key, required this.code});

  final String code;

  @override
  ConsumerState<PlayerRoomScreen> createState() => _PlayerRoomScreenState();
}

class _PlayerRoomScreenState extends ConsumerState<PlayerRoomScreen> {
  final _nickname = TextEditingController();
  bool _joined = false;
  bool _busy = false;
  String? _error;

  /// What this player chose, by question index — written once each, so
  /// it can be remembered here rather than listened for.
  final Map<int, int> _mine = {};

  /// Scores when this question was shown, for "+points" at the reveal.
  final Map<int, int> _scoreAtQuestion = {};
  bool _recorded = false;

  @override
  void initState() {
    super.initState();
    _rejoin();
  }

  /// After a reload: already in the room? Then skip the nickname, and
  /// recall the answer to the live question.
  Future<void> _rejoin() async {
    final uid = ref.read(currentUserProvider)?.uid;
    if (uid == null) return;
    final repo = ref.read(roomRepositoryProvider);
    try {
      final name = await repo.myNickname(widget.code, uid);
      if (name == null || !mounted) return;
      _nickname.text = name;
      setState(() => _joined = true);
      final room = await ref.read(roomProvider(widget.code).future);
      if (room == null) return;
      final mine = await repo.myAnswer(widget.code, uid, room.index);
      if (mine != null && mounted) setState(() => _mine[room.index] = mine);
    } catch (_) {}
  }

  @override
  void dispose() {
    _nickname.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    final uid = ref.read(currentUserProvider)?.uid;
    final name = _nickname.text.trim();
    if (uid == null) return;
    if (name.isEmpty || name.length > 20) {
      setState(() => _error = 'A nickname of up to 20 characters.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      // The avatar goes with the nickname, so a photo shows on the host's
      // screen. Anything the rules would refuse is left out.
      final avatar = ref.read(userDataProvider).asData?.value?['avatar'];
      await ref
          .read(roomRepositoryProvider)
          .join(
            widget.code,
            uid,
            name,
            avatar:
                avatar is String &&
                    RegExp(
                      r'^((preset|initials):[a-z_]{2,20}|photo:[0-9]{1,13})$',
                    ).hasMatch(avatar)
                ? avatar
                : null,
          );
      ref.read(analyticsProvider).roomJoined();
      if (mounted) setState(() => _joined = true);
    } catch (_) {
      if (mounted) {
        setState(() => _error = "Couldn't join. The room may have closed.");
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _answer(Room room, int option) async {
    final uid = ref.read(currentUserProvider)?.uid;
    if (uid == null || _mine.containsKey(room.index)) return;
    setState(() => _mine[room.index] = option);
    try {
      await ref
          .read(roomRepositoryProvider)
          .answer(room.code, uid, room.index, option);
    } catch (_) {
      // Too late (the host had moved on) or already answered: the rules
      // refused it, so it does not count.
      if (mounted) {
        setState(() => _mine.remove(room.index));
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Too late for that one.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(roomProvider(widget.code));
    final room = async.asData?.value;
    final palette = context.palette;
    return Scaffold(
      appBar: ParagonAppBar(title: Text('Room ${widget.code}')),
      body: async.isLoading
          ? const Center(child: CircularProgressIndicator())
          : room == null
          ? EmptyState(
              icon: Icons.meeting_room_outlined,
              title: 'No room has that code',
              action: TextButton(
                onPressed: () => context.go('/join'),
                child: const Text('Try another code'),
              ),
            )
          : PageBody(children: [_stage(context, room, palette)]),
    );
  }

  Widget _stage(BuildContext context, Room room, AppPalette palette) {
    if (!_joined) {
      if (room.state == RoomState.closed || room.state == RoomState.podium) {
        return const EmptyState(
          icon: Icons.flag_outlined,
          title: 'This quiz has finished',
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageIntro(
            title: room.topicName,
            subtitle: 'Choose a nickname to join.',
          ),
          TextField(
            controller: _nickname,
            maxLength: 20,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Your nickname',
              helperText: 'Everyone in the room sees it. No surnames needed.',
              errorText: _error,
            ),
            onSubmitted: (_) => _busy ? null : _join(),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: _busy ? null : _join,
              child: const Text('Join'),
            ),
          ),
        ],
      );
    }

    final questions =
        ref.watch(roomItemsProvider(roomItemsKey(room))).asData?.value ??
        const <Question>[];
    final q = room.index < questions.length ? questions[room.index] : null;
    final mine = _mine[room.index];
    final uid = ref.watch(currentUserProvider)?.uid ?? '';

    switch (room.state) {
      case RoomState.lobby:
        return EmptyState(
          icon: Icons.hourglass_top_rounded,
          title: "You're in, ${_nickname.text.trim()}",
          message: room.mode == RoomMode.speed
              ? 'Speed round: the faster a right answer, the more it scores. '
                    'Waiting for the host to start.'
              : 'Waiting for the host to start.',
        );
      case RoomState.question:
        _scoreAtQuestion.putIfAbsent(room.index, () => room.scores[uid] ?? 0);
        if (q == null) return const Center(child: CircularProgressIndicator());
        final started = room.questionStartedAt;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Question ${room.index + 1} of ${room.questionCount}',
                    style: AppTheme.caption.copyWith(
                      color: palette.textSecondary,
                    ),
                  ),
                ),
                if (room.timeLimit > 0 && started != null && mine == null)
                  CountdownRing(
                    key: ValueKey('${room.index}-$started'),
                    startedAt: started,
                    seconds: room.timeLimit,
                    size: 56,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            FullLatexView(
              latex: q.text,
              textStyle: AppTheme.bodyLg.copyWith(
                color: palette.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            QuestionImage(assetId: q.imageId),
            const SizedBox(height: 16),
            ShapeGrid(
              count: q.options.length,
              tile: (i) => ShapeTile(
                index: i,
                text: q.options[i],
                state: mine == null
                    ? TileState.idle
                    : mine == i
                    ? TileState.selected
                    : TileState.faded,
                onTap: mine != null ? null : () => _answer(room, i),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              mine == null ? 'Pick an answer.' : 'Locked in. Wait for the reveal.',
              textAlign: TextAlign.center,
              style: AppTheme.bodyLg.copyWith(
                color: palette.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        );
      case RoomState.reveal:
        if (q == null) return const Center(child: CircularProgressIndicator());
        final right = mine != null && mine == q.correctIndex;
        // Exact when this phone saw the question; unknown after a reload.
        final before = _scoreAtQuestion[room.index];
        final gained = before == null
            ? 0
            : (room.scores[uid] ?? 0) - before;
        final rows = standings(room.scores);
        final me = rows.where((r) => r.uid == uid).firstOrNull;
        final run = room.streaks[uid] ?? 0;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Verdict(
              right: right,
              answered: mine != null,
              gained: gained,
              speed: room.mode == RoomMode.speed,
              run: run,
            ),
            const SizedBox(height: 16),
            if (me != null)
              Text(
                'You are ${_ordinal(me.place)} of ${rows.length} with '
                '${me.score} ${room.mode == RoomMode.speed ? 'points' : 'right'}.',
                textAlign: TextAlign.center,
                style: AppTheme.bodyLg.copyWith(color: palette.textPrimary),
              ),
            const SizedBox(height: 16),
            ShapeGrid(
              count: q.options.length,
              tile: (i) => ShapeTile(
                index: i,
                text: q.options[i],
                state: i == q.correctIndex
                    ? TileState.correct
                    : i == mine
                    ? TileState.wrong
                    : TileState.faded,
              ),
            ),
          ],
        );
      case RoomState.podium:
      case RoomState.closed:
        final rows = standings(room.results);
        final me = rows.where((r) => r.uid == uid).firstOrNull;
        if (room.state == RoomState.podium && !_recorded && uid.isNotEmpty) {
          _recorded = true;
          ref
              .read(quizHistoryRepositoryProvider)
              .record(uid: uid, room: room, players: rows.length)
              .ignore();
        }
        final top = me != null && me.place <= 3;
        return Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                EmptyState(
                  icon: me?.place == 1
                      ? Icons.emoji_events_rounded
                      : Icons.emoji_events_outlined,
                  title: me == null
                      ? 'The quiz has finished'
                      : me.place == 1
                      ? 'You won!'
                      : '${_ordinal(me.place)} of ${rows.length}',
                  message: me == null
                      ? null
                      : room.mode == RoomMode.speed
                      ? '${me.score} points'
                      : '${me.score} of ${room.questionCount} right',
                ),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => context.go(kQuizHistoryPath),
                      icon: const Icon(Icons.history_rounded),
                      label: const Text('Your quiz history'),
                    ),
                    if (room.topicId.isNotEmpty && room.subjectId.isNotEmpty)
                      FilledButton(
                        onPressed: () => context.go(
                          '/subject/${room.subjectId}/course/topic/${room.topicId}',
                        ),
                        child: const Text('Practise this topic'),
                      ),
                  ],
                ),
              ],
            ),
            if (top) Positioned.fill(
                child: Confetti(pieces: 60, colours: kRoomConfettiColours),
              ),
          ],
        );
    }
  }
}

String _ordinal(int n) {
  final teen = n % 100 >= 11 && n % 100 <= 13;
  final suffix = teen
      ? 'th'
      : switch (n % 10) {
          1 => 'st',
          2 => 'nd',
          3 => 'rd',
          _ => 'th',
        };
  return '$n$suffix';
}

/// Right or wrong, big and coloured, with the points and the run.
class _Verdict extends StatelessWidget {
  const _Verdict({
    required this.right,
    required this.answered,
    required this.gained,
    required this.speed,
    required this.run,
  });

  final bool right;
  final bool answered;
  final int gained;
  final bool speed;
  final int run;

  @override
  Widget build(BuildContext context) {
    final colour = right ? AppColors.correct : AppColors.wrong;
    final still = reduceMotion(context);
    return Semantics(
      liveRegion: true,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: still ? 1 : 0.7, end: 1),
        duration: Duration(milliseconds: still ? 0 : 380),
        curve: Curves.easeOutBack,
        builder: (context, sc, child) =>
            Transform.scale(scale: sc, child: child),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
          decoration: BoxDecoration(
            color: colour,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            children: [
              Icon(
                right ? Icons.check_circle_rounded : Icons.cancel_rounded,
                color: Colors.white,
                size: 56,
              ),
              const SizedBox(height: 8),
              Text(
                !answered
                    ? 'No answer this time'
                    : right
                    ? 'Right!'
                    : 'Not this time',
                style: AppTheme.heading2.copyWith(color: Colors.white),
              ),
              if (right && gained > 0)
                Text(
                  '+$gained',
                  style: AppTheme.heading3.copyWith(color: Colors.white),
                ),
              if (right && speed && run > 1)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    '$run in a row (+${streakBonus(run)} bonus)',
                    style: AppTheme.bodyMd.copyWith(color: Colors.white),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

