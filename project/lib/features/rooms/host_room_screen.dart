import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/avatar.dart';
import '../../core/models/question.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/repositories/flag_repository.dart';
import '../../core/rooms/quiz_history.dart';
import '../../core/rooms/room.dart';
import '../../core/rooms/room_repository.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_theme.dart';
import '../../core/web/browser.dart';
import '../../core/widgets/full_latex_view.dart';
import '../../core/widgets/nav/back_navigation.dart';
import '../../core/widgets/question_image.dart';
import '../../core/widgets/share_link_button.dart';
import '../../core/widgets/ui/ui.dart';
import '../../core/widgets/user_avatar.dart';
import 'room_ui.dart';

/// `/rooms/:code/host`: the screen on the projector.
///
/// Lobby with the big code and players popping in → 3-2-1 → each question
/// with a countdown ring (in a timed room) that reveals by itself at zero
/// or once everyone has answered → the reveal, with how the room split and
/// the leaderboard → the podium, with confetti.
///
/// **Scoring happens here.** At each reveal the host's client works out the
/// question's points (`scoreQuestion`: speed from the server's timestamps
/// on the question and each answer) and writes the running `scores` and
/// `streaks` into the room, so every phone can show its total and place.
class HostRoomScreen extends ConsumerStatefulWidget {
  const HostRoomScreen({super.key, required this.code});

  final String code;

  @override
  ConsumerState<HostRoomScreen> createState() => _HostRoomScreenState();
}

class _HostRoomScreenState extends ConsumerState<HostRoomScreen> {
  bool _busy = false;
  bool _countingIn = false;
  bool _recorded = false;

  /// The question last scored, so the clock, "everyone answered" and the
  /// button can never score the same question twice.
  int _revealed = -1;

  /// Scores before the last reveal, for the "+points" on the leaderboard.
  Map<String, int> _before = const {};

  @override
  void initState() {
    super.initState();
    setLeaveGuard(true);
  }

  @override
  void dispose() {
    setLeaveGuard(false);
    super.dispose();
  }

  Future<void> _do(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("That didn't go through. Try again.")),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// The reveal: score this question, then show the answer.
  Future<void> _reveal(
    Room room,
    Map<String, RoomPlayer> players,
    List<TimedAnswer> answers,
    Question q,
  ) => _do(() async {
    if (room.state != RoomState.question || _revealed == room.index) return;
    _revealed = room.index;
    final next = scoreQuestion(
      scores: room.scores,
      streaks: room.streaks,
      players: players.keys,
      answers: answers,
      index: room.index,
      correctIndex: q.correctIndex,
      mode: room.mode,
      timeLimit: room.timeLimit,
      startedAt: room.questionStartedAt,
    );
    _before = room.scores;
    try {
      await ref
          .read(roomRepositoryProvider)
          .reveal(room.code, scores: next.scores, streaks: next.streaks);
    } catch (_) {
      _revealed = -1; // let the host try again
      rethrow;
    }
  });

  @override
  Widget build(BuildContext context) {
    final roomAsync = ref.watch(roomProvider(widget.code));
    final room = roomAsync.asData?.value;
    final uid = ref.watch(currentUserProvider)?.uid;
    if (room == null) {
      // Loading, or gone: a room that failed to load, or no longer exists,
      // used to spin here for ever.
      return Scaffold(
        appBar: const ParagonAppBar(title: Text('Live quiz')),
        body: roomAsync.isLoading
            ? const LoadingView(label: 'Opening the room')
            : Center(
                child: SingleChildScrollView(
                  child: EmptyState(
                    illustration: IllustrationAsset.notFound,
                    title: roomAsync.hasError
                        ? "Couldn't open this room"
                        : 'This room no longer exists',
                    message: roomAsync.hasError
                        ? 'Check your connection and try again.'
                        : 'Rooms last a day. Start a new one for your class.',
                    action: roomAsync.hasError
                        ? AppButton(
                            label: 'Try again',
                            onPressed: () =>
                                ref.invalidate(roomProvider(widget.code)),
                          )
                        : AppButton(
                            label: 'Start a new room',
                            onPressed: () => context.go('/rooms/new'),
                          ),
                  ),
                ),
              ),
      );
    }
    if (room.hostUid != uid) {
      return Scaffold(
        appBar: const ParagonAppBar(title: Text('Live quiz')),
        body: EmptyState(
          icon: Icons.lock_outline,
          title: 'Only the host can run this room',
          action: TextButton(
            onPressed: () => context.go('/rooms/${room.code}'),
            child: const Text('Join it instead'),
          ),
        ),
      );
    }
    final players =
        ref.watch(roomPlayersProvider(widget.code)).asData?.value ?? const {};
    final answers =
        ref.watch(roomAnswersProvider(widget.code)).asData?.value ?? const [];
    final questions =
        ref.watch(roomItemsProvider(roomItemsKey(room))).asData?.value ??
        const <Question>[];
    final repo = ref.read(roomRepositoryProvider);
    final q = room.index < questions.length ? questions[room.index] : null;
    final names = {for (final e in players.entries) e.key: e.value.nickname};

    // The room's record in the host's history, once.
    if (room.state == RoomState.podium && !_recorded && uid != null) {
      _recorded = true;
      ref
          .read(quizHistoryRepositoryProvider)
          .record(uid: uid, room: room, players: players.length)
          .ignore();
    }

    Widget body;
    if (_countingIn) {
      body = SizedBox(
        height: 420,
        child: GetReady(
          title: room.topicName,
          onDone: () {
            setState(() => _countingIn = false);
            _do(() => repo.showQuestion(room.code, 0));
          },
        ),
      );
    } else {
      switch (room.state) {
        case RoomState.lobby:
          body = _Lobby(
            room: room,
            players: players,
            questions: questions.length,
            onStart: players.isEmpty || questions.isEmpty || _busy
                ? null
                : () => setState(() => _countingIn = true),
          );
        case RoomState.question:
          final answered = answers.where((a) => a.index == room.index).length;
          final everyone = players.isNotEmpty && answered >= players.length;
          if (everyone && q != null && !_busy) {
            // Everyone is in: no need to wait for the clock.
            scheduleMicrotask(() => _reveal(room, players, answers, q));
          }
          body = _QuestionStage(
            room: room,
            question: q,
            answered: answered,
            players: players.length,
            onTimeUp: q == null
                ? null
                : () => _reveal(room, players, answers, q),
            action: FilledButton(
              onPressed: _busy || q == null
                  ? null
                  : () => _reveal(room, players, answers, q),
              child: const Text('Show the answer'),
            ),
          );
        case RoomState.reveal:
          final counts = q == null
              ? const <int>[]
              : optionCounts(
                  [
                    for (final a in answers)
                      (uid: a.uid, index: a.index, selected: a.selected),
                  ],
                  room.index,
                  q.options.length,
                );
          body = _RevealStage(
            room: room,
            question: q,
            counts: counts,
            names: names,
            before: _before,
            action: FilledButton(
              onPressed: _busy
                  ? null
                  : () => _do(() async {
                      if (room.isLast) {
                        await repo.podium(room.code, {
                          for (final p in players.keys) p: room.scores[p] ?? 0,
                        });
                      } else {
                        await repo.showQuestion(room.code, room.index + 1);
                      }
                    }),
              child: Text(room.isLast ? 'See the podium' : 'Next question'),
            ),
          );
        case RoomState.podium:
        case RoomState.closed:
          body = _PodiumStage(
            room: room,
            names: names,
            players: players,
            action: room.state == RoomState.closed
                ? null
                : TextButton(
                    onPressed: () async {
                      await repo.close(room.code);
                      setLeaveGuard(false);
                      if (context.mounted) context.go('/');
                    },
                    child: const Text('Close the room'),
                  ),
          );
      }
    }

    return Scaffold(
      appBar: ParagonAppBar(
        title: Text('Room ${room.code} · ${room.topicName}'),
      ),
      body: PageBody(maxWidth: 1100, children: [body]),
    );
  }
}

class _Lobby extends StatelessWidget {
  const _Lobby({
    required this.room,
    required this.players,
    required this.questions,
    required this.onStart,
  });

  final Room room;
  final Map<String, RoomPlayer> players;
  final int questions;
  final VoidCallback? onStart;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final code = room.code;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Go to ${appOrigin.replaceFirst(RegExp(r'^https?://'), '')}/join',
          textAlign: TextAlign.center,
          style: AppTheme.heading3.copyWith(color: palette.textSecondary),
        ),
        const SizedBox(height: 8),
        Semantics(
          label: 'Room code ${code.split('').join(' ')}',
          child: SelectableText(
            code,
            textAlign: TextAlign.center,
            style: AppTheme.heading1.copyWith(
              fontSize: 76,
              letterSpacing: 14,
              color: AppColors.primary,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        Center(
          child: ShareLinkButton.labelled(
            title: 'Join my Paragon quiz',
            path: roomJoinPath(code),
            label: 'Share join link',
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            Chip(
              avatar: Icon(
                room.mode == RoomMode.speed ? Icons.bolt_rounded : Icons.check,
                size: 18,
              ),
              label: Text(
                room.mode == RoomMode.speed
                    ? 'Speed: faster right answers score more'
                    : 'Classic: one point a right answer',
              ),
            ),
            Chip(
              avatar: const Icon(Icons.timer_outlined, size: 18),
              label: Text(
                room.timeLimit > 0
                    ? '${room.timeLimit} s a question'
                    : 'No timer',
              ),
            ),
            Chip(label: Text('$questions questions')),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          '${players.length} ${players.length == 1 ? 'player' : 'players'} '
          '(up to $kMaxRoomPlayers)',
          textAlign: TextAlign.center,
          style: AppTheme.bodyLg.copyWith(color: palette.textPrimary),
        ),
        // An empty lobby says what to do, rather than "0 players" over
        // nothing.
        if (players.isEmpty) ...[
          const SizedBox(height: 8),
          const LoadingView(
            label: 'Waiting for players to join with the code above',
            showLabel: true,
            delay: Duration.zero,
            padding: EdgeInsets.symmetric(vertical: 24),
          ),
        ],
        const SizedBox(height: 12),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final e in players.entries)
              _PopIn(
                key: ValueKey(e.key),
                child: PlayerChip(uid: e.key, player: e.value),
              ),
          ],
        ),
        const SizedBox(height: 28),
        Center(
          child: SizedBox(
            width: 280,
            height: 56,
            child: FilledButton.icon(
              onPressed: onStart,
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Start the quiz'),
            ),
          ),
        ),
      ],
    );
  }
}

/// A player's chip arrives with a small bounce.
class _PopIn extends StatelessWidget {
  const _PopIn({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (reduceMotion(context)) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.4, end: 1),
      duration: const Duration(milliseconds: 420),
      curve: Curves.elasticOut,
      builder: (context, s, child) => Transform.scale(scale: s, child: child),
      child: child,
    );
  }
}

class _QuestionStage extends StatelessWidget {
  const _QuestionStage({
    required this.room,
    required this.question,
    required this.answered,
    required this.players,
    required this.action,
    this.onTimeUp,
  });

  final Room room;
  final Question? question;
  final int answered;
  final int players;
  final Widget action;
  final VoidCallback? onTimeUp;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final q = question;
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
                style: AppTheme.bodyLg.copyWith(color: palette.textSecondary),
              ),
            ),
            if (room.timeLimit > 0 && started != null)
              CountdownRing(
                key: ValueKey('${room.index}-$started'),
                startedAt: started,
                seconds: room.timeLimit,
                onDone: onTimeUp,
              ),
          ],
        ),
        const SizedBox(height: 12),
        FullLatexView(
          latex: q.text,
          textStyle: AppTheme.heading2.copyWith(color: palette.textPrimary),
        ),
        QuestionImage(assetId: q.imageId),
        const SizedBox(height: 20),
        ShapeGrid(
          count: q.options.length,
          tile: (i) => ShapeTile(index: i, text: q.options[i]),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Icon(Icons.how_to_vote_outlined, color: palette.textSecondary),
            const SizedBox(width: 8),
            AnimatedSwitcher(
              duration: reduceMotion(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 250),
              transitionBuilder: (child, a) =>
                  ScaleTransition(scale: a, child: child),
              child: Text(
                '$answered',
                key: ValueKey(answered),
                style: AppTheme.heading2.copyWith(
                  color: context.palette.primaryFg,
                ),
              ),
            ),
            Text(
              ' of $players answered',
              style: AppTheme.bodyLg.copyWith(color: palette.textPrimary),
            ),
            const Spacer(),
            action,
          ],
        ),
      ],
    );
  }
}

class _RevealStage extends StatelessWidget {
  const _RevealStage({
    required this.room,
    required this.question,
    required this.counts,
    required this.names,
    required this.before,
    required this.action,
  });

  final Room room;
  final Question? question;
  final List<int> counts;
  final Map<String, String> names;
  final Map<String, int> before;
  final Widget action;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final q = question;
    if (q == null) return const Center(child: CircularProgressIndicator());
    final most = counts.isEmpty ? 1 : counts.reduce((a, b) => a > b ? a : b);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Question ${room.index + 1} of ${room.questionCount}',
          style: AppTheme.bodyLg.copyWith(color: palette.textSecondary),
        ),
        const SizedBox(height: 8),
        FullLatexView(
          latex: q.text,
          textStyle: AppTheme.heading3.copyWith(color: palette.textPrimary),
        ),
        const SizedBox(height: 16),
        ShapeGrid(
          count: q.options.length,
          tile: (i) => ShapeTile(
            index: i,
            text: q.options[i],
            state: i == q.correctIndex ? TileState.correct : TileState.faded,
            count: i < counts.length ? counts[i] : 0,
            countMax: most,
          ),
        ),
        if (q.explanation.trim().isNotEmpty) ...[
          const SizedBox(height: 12),
          SurfaceCard(
            child: FullLatexView(
              latex: q.explanation,
              textStyle: AppTheme.bodyMd.copyWith(color: palette.textPrimary),
            ),
          ),
        ],
        const SizedBox(height: 24),
        const SectionHeader('Leaderboard'),
        Leaderboard(scores: room.scores, names: names, before: before),
        const SizedBox(height: 16),
        Align(alignment: Alignment.centerRight, child: action),
      ],
    );
  }
}

class _PodiumStage extends StatelessWidget {
  const _PodiumStage({
    required this.room,
    required this.names,
    required this.players,
    required this.action,
  });

  final Room room;
  final Map<String, String> names;
  final Map<String, RoomPlayer> players;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final rows = standings(room.results);
    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const PageIntro(title: 'The podium'),
            PodiumSteps(
              scores: room.results,
              names: names,
              avatar: (uid, size) => AvatarDisc(
                avatar: Avatar.parse(players[uid]?.avatar, seed: uid),
                initials: initialsFor(names[uid]),
                size: size,
                uid: uid,
              ),
            ),
            const SizedBox(height: 20),
            RowGroup(
              children: [
                for (final r in rows)
                  ListRow(
                    leading: CircleAvatar(child: Text('${r.place}')),
                    title: names[r.uid] ?? 'Player',
                    trailing: Text(
                      room.mode == RoomMode.speed
                          ? '${r.score}'
                          : '${r.score}/${room.questionCount}',
                      style: AppTheme.heading3,
                    ),
                  ),
              ],
            ),
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
        Positioned.fill(child: Confetti(colours: kRoomConfettiColours)),
      ],
    );
  }
}

/// A player in the lobby: their avatar (a photo too, 2026-10-17) and
/// nickname. The host can hide a photo on this screen at once, and anyone
/// can report one; a report goes to the studio's Pictures queue.
class PlayerChip extends ConsumerStatefulWidget {
  const PlayerChip({super.key, required this.uid, required this.player});

  final String uid;
  final RoomPlayer player;

  @override
  ConsumerState<PlayerChip> createState() => _PlayerChipState();
}

class _PlayerChipState extends ConsumerState<PlayerChip> {
  bool _hidden = false;

  Future<void> _report() async {
    final me = ref.read(currentUserProvider)?.uid;
    if (me == null) return;
    try {
      await ref
          .read(flagRepositoryProvider)
          .reportAvatar(userId: me, avatarUid: widget.uid);
      if (!mounted) return;
      setState(() => _hidden = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Reported. The Paragon team will look at it.'),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't send the report.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final avatar = Avatar.parse(widget.player.avatar, seed: widget.uid);
    final shown = _hidden && avatar.isPhoto
        ? Avatar.parse(null, seed: widget.uid)
        : avatar;
    final chip = Chip(
      avatar: AvatarDisc(
        avatar: shown,
        initials: initialsFor(widget.player.nickname),
        size: 24,
        uid: widget.uid,
      ),
      label: Text(widget.player.nickname),
    );
    if (!avatar.isPhoto) return chip;
    return PopupMenuButton<String>(
      tooltip: 'Photo options for ${widget.player.nickname}',
      onSelected: (v) =>
          v == 'hide' ? setState(() => _hidden = !_hidden) : _report(),
      itemBuilder: (_) => [
        PopupMenuItem(
          value: 'hide',
          child: Text(_hidden ? 'Show photo' : 'Hide photo'),
        ),
        const PopupMenuItem(value: 'report', child: Text('Report picture')),
      ],
      child: chip,
    );
  }
}
