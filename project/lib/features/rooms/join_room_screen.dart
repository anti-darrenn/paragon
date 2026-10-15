import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/feature_access.dart';
import '../../core/data/read_meter.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/rooms/room.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/nav/back_navigation.dart';
import '../../core/widgets/ui/ui.dart';

/// `/join`: type the code on the board. Also where an account starts a
/// room of its own.
class JoinRoomScreen extends ConsumerStatefulWidget {
  const JoinRoomScreen({super.key});

  @override
  ConsumerState<JoinRoomScreen> createState() => _JoinRoomScreenState();
}

class _JoinRoomScreenState extends ConsumerState<JoinRoomScreen> {
  final _code = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    final code = normaliseRoomCode(_code.text);
    if (code == null) {
      setState(() => _error = 'A room code is six letters and numbers.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final db = FirebaseFirestore.instance;
      final snap = await db.collection('rooms').doc(code).get().metered();
      final room = snap.exists ? Room.fromFirestore(snap) : null;
      if (room == null || room.state == RoomState.closed) {
        setState(() => _error = 'No open room has that code.');
        return;
      }
      final players = await db
          .collection('rooms')
          .doc(code)
          .collection('players')
          .count()
          .get()
          .metered();
      if ((players.count ?? 0) >= kMaxRoomPlayers) {
        setState(() => _error = 'That room is full.');
        return;
      }
      if (mounted) context.go('/rooms/$code');
    } catch (_) {
      if (mounted) {
        setState(() => _error = "Couldn't reach the room. Try again.");
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canHost = canUse(
      Feature.hostRoom,
      isGuest: ref.watch(isGuestProvider),
    );
    return Scaffold(
      appBar: const ParagonAppBar(title: Text('Live quiz')),
      body: PageBody(
        children: [
          const PageIntro(
            title: 'Join a live quiz',
            subtitle:
                'Type the code your teacher or friend is showing. You answer '
                'on your phone; the scores go up on their screen.',
          ),
          TextField(
            controller: _code,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            style: AppTheme.heading2.copyWith(letterSpacing: 6),
            decoration: InputDecoration(hintText: 'ABC234', errorText: _error),
            onSubmitted: (_) => _busy ? null : _join(),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: _busy ? null : _join,
              child: Text(_busy ? 'Checking…' : 'Join'),
            ),
          ),
          const SizedBox(height: kSectionGap),
          SurfaceCard(
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    canHost
                        ? 'Running a class or a study group? Host a quiz on '
                              'any topic.'
                        : 'Make a free account to host a quiz of your own.',
                    style: AppTheme.bodyMd.copyWith(
                      color: context.palette.textSecondary,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () =>
                      context.push(canHost ? '/rooms/new' : '/account/upgrade'),
                  child: Text(canHost ? 'Host a quiz' : 'Make an account'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
