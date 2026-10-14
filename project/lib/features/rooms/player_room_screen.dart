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
import '../../core/widgets/answer_option.dart';
import '../../core/widgets/full_latex_view.dart';
import '../../core/widgets/nav/back_navigation.dart';
import '../../core/widgets/ui/ui.dart';

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
      await ref.read(roomRepositoryProvider).join(widget.code, uid, name);
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
        ref
            .watch(roomQuestionsProvider(room.questionIds.join(',')))
            .asData
            ?.value ??
        const <Question>[];
    final q = room.index < questions.length ? questions[room.index] : null;
    final mine = _mine[room.index];

    switch (room.state) {
      case RoomState.lobby:
        return EmptyState(
          icon: Icons.hourglass_top_rounded,
          title: "You're in, ${_nickname.text.trim()}",
          message: 'Waiting for the host to start.',
        );
      case RoomState.question:
      case RoomState.reveal:
        if (q == null) return const Center(child: CircularProgressIndicator());
        final reveal = room.state == RoomState.reveal;
        AnswerOptionState stateOf(int i) {
          if (!reveal) {
            return mine == i
                ? AnswerOptionState.selected
                : AnswerOptionState.idle;
          }
          if (i == q.correctIndex) return AnswerOptionState.correct;
          if (i == mine) return AnswerOptionState.wrong;
          return AnswerOptionState.ruledOut;
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Question ${room.index + 1} of ${room.questionIds.length}',
              style: AppTheme.caption.copyWith(color: palette.textSecondary),
            ),
            const SizedBox(height: 8),
            FullLatexView(
              latex: q.text,
              textStyle: AppTheme.bodyLg.copyWith(
                color: palette.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            for (var i = 0; i < q.options.length; i++)
              AnswerOption(
                index: i,
                text: q.options[i],
                state: stateOf(i),
                onTap: reveal || mine != null ? null : () => _answer(room, i),
              ),
            const SizedBox(height: 8),
            Text(
              reveal
                  ? mine == null
                        ? 'No answer this time.'
                        : mine == q.correctIndex
                        ? 'Right! One point.'
                        : 'Not this time.'
                  : mine == null
                  ? 'Pick an answer.'
                  : 'Locked in. Wait for the reveal.',
              textAlign: TextAlign.center,
              style: AppTheme.bodyLg.copyWith(
                color: reveal && mine == q.correctIndex
                    ? AppColors.correct
                    : palette.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        );
      case RoomState.podium:
      case RoomState.closed:
        final uid = ref.watch(currentUserProvider)?.uid;
        final rows = standings(room.results);
        final me = rows.where((r) => r.uid == uid).firstOrNull;
        return EmptyState(
          icon: Icons.emoji_events_outlined,
          title: me == null
              ? 'The quiz has finished'
              : '${me.score}/${room.questionIds.length} · place ${me.place} of ${rows.length}',
          message: 'Want more ${room.topicName}? Practise it any time.',
          action: ElevatedButton(
            onPressed: () => context.go(
              '/subject/${room.subjectId}/course/topic/${room.topicId}',
            ),
            child: Text('Learn ${room.topicName}'),
          ),
        );
    }
  }
}
