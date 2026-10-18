import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/question.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/rooms/room.dart';
import '../../core/rooms/room_repository.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_theme.dart';
import '../../core/web/browser.dart';
import '../../core/widgets/full_latex_view.dart';
import '../../core/widgets/math_text.dart';
import '../../core/widgets/nav/back_navigation.dart';
import '../../core/widgets/share_link_button.dart';
import '../../core/widgets/ui/ui.dart';
import '../../core/models/avatar.dart';
import '../../core/repositories/flag_repository.dart';
import '../../core/widgets/user_avatar.dart';

/// `/rooms/:code/host`: the screen on the projector. Lobby with the big
/// code, then each question with a live count of answers, the reveal with
/// how the room split, and the podium.
class HostRoomScreen extends ConsumerStatefulWidget {
  const HostRoomScreen({super.key, required this.code});

  final String code;

  @override
  ConsumerState<HostRoomScreen> createState() => _HostRoomScreenState();
}

class _HostRoomScreenState extends ConsumerState<HostRoomScreen> {
  bool _busy = false;

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

  @override
  Widget build(BuildContext context) {
    final room = ref.watch(roomProvider(widget.code)).asData?.value;
    final uid = ref.watch(currentUserProvider)?.uid;
    if (room == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
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
        ref
            .watch(roomQuestionsProvider(room.questionIds.join(',')))
            .asData
            ?.value ??
        const <Question>[];
    final repo = ref.read(roomRepositoryProvider);
    final q = room.index < questions.length ? questions[room.index] : null;

    Widget body;
    switch (room.state) {
      case RoomState.lobby:
        body = _Lobby(
          code: room.code,
          topic: room.topicName,
          players: players,
          onStart: players.isEmpty || questions.isEmpty || _busy
              ? null
              : () => _do(() => repo.showQuestion(room.code, 0)),
        );
      case RoomState.question:
        final answered = answers.where((a) => a.index == room.index).length;
        body = _QuestionView(
          question: q,
          number: room.index + 1,
          total: room.questionIds.length,
          footer: '$answered of ${players.length} answered',
          action: ElevatedButton(
            onPressed: _busy ? null : () => _do(() => repo.reveal(room.code)),
            child: const Text('Show the answer'),
          ),
        );
      case RoomState.reveal:
        final counts = q == null
            ? const <int>[]
            : optionCounts(answers, room.index, q.options.length);
        body = _QuestionView(
          question: q,
          number: room.index + 1,
          total: room.questionIds.length,
          counts: counts,
          action: ElevatedButton(
            onPressed: _busy
                ? null
                : () => _do(() async {
                    if (room.isLast) {
                      await repo.podium(
                        room.code,
                        roomScores(
                          players: players.keys,
                          answers: answers,
                          correctIndexes: [
                            for (final x in questions) x.correctIndex,
                          ],
                        ),
                      );
                    } else {
                      await repo.showQuestion(room.code, room.index + 1);
                    }
                  }),
            child: Text(room.isLast ? 'See the scores' : 'Next question'),
          ),
        );
      case RoomState.podium:
      case RoomState.closed:
        body = _Podium(
          results: room.results,
          players: players,
          total: room.questionIds.length,
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

    return Scaffold(
      appBar: ParagonAppBar(
        title: Text('Room ${room.code} · ${room.topicName}'),
      ),
      body: PageBody(maxWidth: 1000, children: [body]),
    );
  }
}

class _Lobby extends StatelessWidget {
  const _Lobby({
    required this.code,
    required this.topic,
    required this.players,
    required this.onStart,
  });

  final String code;
  final String topic;
  final Map<String, RoomPlayer> players;
  final VoidCallback? onStart;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      children: [
        const SizedBox(height: 24),
        Text(
          'Go to ${appOrigin.replaceFirst(RegExp(r'^https?://'), '')}/join',
          style: AppTheme.heading3.copyWith(color: palette.textSecondary),
        ),
        const SizedBox(height: 8),
        Semantics(
          label: 'Room code ${code.split('').join(' ')}',
          excludeSemantics: true,
          child: SelectableText(
            code,
            style: AppTheme.displayLg.copyWith(
              fontSize: 72,
              letterSpacing: 12,
              color: AppColors.primary,
            ),
          ),
        ),
        ShareLinkButton.labelled(
          title: 'Join my Paragon quiz',
          path: roomJoinPath(code),
          label: 'Share join link',
        ),
        const SizedBox(height: 8),
        Text(
          topic,
          style: AppTheme.heading3.copyWith(color: palette.textPrimary),
        ),
        const SizedBox(height: 24),
        Text(
          '${players.length} ${players.length == 1 ? 'player' : 'players'} '
          '(up to $kMaxRoomPlayers)',
          style: AppTheme.bodyMd.copyWith(color: palette.textSecondary),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            for (final e in players.entries)
              PlayerChip(uid: e.key, player: e.value),
          ],
        ),
        const SizedBox(height: 24),
        SizedBox(
          height: 52,
          width: 260,
          child: ElevatedButton(
            onPressed: onStart,
            child: const Text('Start the quiz'),
          ),
        ),
      ],
    );
  }
}

class _QuestionView extends StatelessWidget {
  const _QuestionView({
    required this.question,
    required this.number,
    required this.total,
    required this.action,
    this.footer,
    this.counts,
  });

  final Question? question;
  final int number;
  final int total;
  final Widget action;
  final String? footer;

  /// Set at the reveal: how many chose each option.
  final List<int>? counts;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final q = question;
    if (q == null) return const Center(child: CircularProgressIndicator());
    final most = counts == null || counts!.isEmpty
        ? 1
        : counts!.reduce((a, b) => a > b ? a : b).clamp(1, 1 << 30);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Question $number of $total',
          style: AppTheme.bodyMd.copyWith(color: palette.textSecondary),
        ),
        const SizedBox(height: 12),
        FullLatexView(
          latex: q.text,
          textStyle: AppTheme.heading2.copyWith(color: palette.textPrimary),
        ),
        const SizedBox(height: 20),
        for (var i = 0; i < q.options.length; i++)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: counts != null && i == q.correctIndex
                  ? AppColors.correct.withAlpha(40)
                  : palette.surface,
              border: Border.all(
                color: counts != null && i == q.correctIndex
                    ? AppColors.correct
                    : palette.border,
                width: 1.5,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Text(
                  String.fromCharCode(65 + i),
                  style: AppTheme.heading3.copyWith(color: AppColors.primary),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: MathText(
                    text: q.options[i],
                    useLightRenderer: true,
                    style: AppTheme.bodyLg.copyWith(color: palette.textPrimary),
                  ),
                ),
                if (counts != null) ...[
                  SizedBox(
                    width: 120,
                    child: LinearProgressIndicator(
                      value: counts![i] / most,
                      minHeight: 10,
                      backgroundColor: palette.track,
                      color: i == q.correctIndex
                          ? AppColors.correct
                          : palette.onLow,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text('${counts![i]}', style: AppTheme.bodyLg),
                ],
              ],
            ),
          ),
        if (footer != null)
          Text(
            footer!,
            textAlign: TextAlign.center,
            style: AppTheme.bodyLg.copyWith(color: palette.textSecondary),
          ),
        const SizedBox(height: 16),
        Center(child: SizedBox(height: 52, width: 260, child: action)),
      ],
    );
  }
}

class _Podium extends StatelessWidget {
  const _Podium({
    required this.results,
    required this.players,
    required this.total,
    required this.action,
  });

  final Map<String, int> results;
  final Map<String, RoomPlayer> players;
  final int total;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final rows = standings(results);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const PageIntro(title: 'Scores'),
        RowGroup(
          children: [
            for (final r in rows)
              ListRow(
                leading: CircleAvatar(child: Text('${r.place}')),
                title: players[r.uid]?.nickname ?? 'Player',
                trailing: Text('${r.score}/$total', style: AppTheme.heading3),
              ),
          ],
        ),
        if (action != null) ...[const SizedBox(height: 16), action!],
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
      onSelected: (v) => v == 'hide'
          ? setState(() => _hidden = !_hidden)
          : _report(),
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
