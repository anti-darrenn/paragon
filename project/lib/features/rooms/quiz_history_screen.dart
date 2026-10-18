import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/rooms/quiz_history.dart';
import '../../core/rooms/room.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/nav/back_navigation.dart';
import '../../core/widgets/ui/ui.dart';
import 'room_paths.dart';

/// `/me/history`: every live quiz played or hosted, newest first, with
/// games, wins and rooms hosted at the top (owner's request, 2026-10-17).
/// One query, the student's own entries only.
class QuizHistoryScreen extends ConsumerWidget {
  const QuizHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final history = ref.watch(myQuizHistoryProvider);
    return Scaffold(
      backgroundColor: palette.background,
      appBar: const ParagonAppBar(title: Text('Quiz history')),
      body: PageBody(
        children: [
          history.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text("Couldn't load your history.\n$e"),
            data: (list) {
              if (list.isEmpty) {
                return EmptyState(
                  icon: Icons.emoji_events_outlined,
                  title: 'No live quizzes yet',
                  message:
                      'Join one with a code from your teacher, or host your '
                      'own.',
                  action: Wrap(
                    spacing: 8,
                    children: [
                      FilledButton(
                        onPressed: () => context.push('/join'),
                        child: const Text('Join a quiz'),
                      ),
                      OutlinedButton(
                        onPressed: () => context.push('/rooms/new'),
                        child: const Text('Host one'),
                      ),
                    ],
                  ),
                );
              }
              final t = historyTotals(list);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      _Stat(label: 'Played', value: t.games),
                      _Stat(label: 'Won', value: t.wins, accent: true),
                      _Stat(label: 'Hosted', value: t.hosted),
                    ],
                  ),
                  const SizedBox(height: 20),
                  RowGroup(
                    children: [
                      for (final e in list)
                        ListRow(
                          leading: Icon(
                            e.isHost
                                ? Icons.co_present_outlined
                                : e.won
                                ? Icons.emoji_events_rounded
                                : Icons.sports_esports_outlined,
                            color: e.won ? AppColors.medalGold : null,
                          ),
                          title: e.title,
                          subtitle: [
                            if (e.at != null) _day(e.at!),
                            e.isHost
                                ? 'Hosted for ${e.players}'
                                : '${_place(e.place)} of ${e.players}',
                            e.mode == RoomMode.speed ? 'Speed' : 'Classic',
                          ].join(' · '),
                          trailing: e.isHost
                              ? null
                              : Text(
                                  e.mode == RoomMode.speed
                                      ? '${e.score}'
                                      : '${e.score}/${e.total}',
                                  style: AppTheme.heading3,
                                ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => context.push(kMyQuizzesPath),
                      icon: const Icon(Icons.edit_note_rounded),
                      label: const Text('My quizzes'),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  static String _place(int n) {
    final teen = n % 100 >= 11 && n % 100 <= 13;
    final s = teen
        ? 'th'
        : switch (n % 10) {
            1 => 'st',
            2 => 'nd',
            3 => 'rd',
            _ => 'th',
          };
    return '$n$s';
  }

  static String _day(DateTime d) =>
      '${d.day} ${const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][d.month - 1]}';
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, this.accent = false});
  final String label;
  final int value;
  final bool accent;

  @override
  Widget build(BuildContext context) => Expanded(
    child: SurfaceCard(
      child: Column(
        children: [
          Text(
            '$value',
            style: AppTheme.heading1.copyWith(
              color: accent ? AppColors.primary : context.palette.textPrimary,
            ),
          ),
          Text(
            label,
            style: AppTheme.caption.copyWith(
              color: context.palette.textSecondary,
            ),
          ),
        ],
      ),
    ),
  );
}
