import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/nav/back_navigation.dart';
import '../../../core/widgets/load_error.dart';
import '../../../core/widgets/ui/ui.dart';
import '../cards/card_providers.dart';
import '../hub/study_paths.dart';
import 'deck.dart';
import 'deck_store.dart';

/// `/review/flashcards`: the student's decks, each with how many cards are
/// due, and the ways into it: study, quiz, edit.
class DecksScreen extends ConsumerWidget {
  const DecksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final decks = ref.watch(decksProvider);
    final schedule = ref.watch(cardScheduleProvider).asData?.value ?? const {};
    final leitner = ref.watch(leitnerProvider);
    final isGuest = ref.watch(isGuestProvider);

    return Scaffold(
      backgroundColor: palette.background,
      appBar: const ParagonAppBar(title: Text('My flashcards')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(deckEditPath('new')),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New deck'),
      ),
      body: PageBody(
        children: [
          Text(
            'Make your own cards: a question or word on the front, the '
            'answer on the back, maths and all. Paragon brings each card '
            'back just before you would forget it.',
            style: AppTheme.bodyMd.copyWith(color: palette.textSecondary),
          ),
          if (isGuest) ...[
            const SizedBox(height: 8),
            const InlineAlert(
              tone: Tone.info,
              message:
                  'Your decks are kept on this device. Make an account to keep '
                  'them everywhere.',
            ),
          ],
          const SizedBox(height: 20),
          decks.when(
            loading: () => const SkeletonPage(title: false, count: 3),
            error: (e, _) => LoadError(
              error: e,
              message: "Couldn't load your decks.",
              onRetry: () => ref.invalidate(decksProvider),
            ),
            data: (list) {
              if (list.isEmpty) {
                return EmptyState(
                  illustration: IllustrationAsset.empty,
                  title: 'No decks yet',
                  message:
                      'Start one for a topic you keep forgetting: formulas, '
                      'definitions, symbols.',
                  action: AppButton(
                    label: 'New deck',
                    icon: Icons.add_rounded,
                    onPressed: () => context.push(deckEditPath('new')),
                  ),
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final d in list)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _DeckTile(
                        deck: d,
                        due: d.usable
                            .where(
                              (c) => leitner.isDue(
                                schedule[scheduleId(d.id, c.id)],
                              ),
                            )
                            .length,
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

class _DeckTile extends StatelessWidget {
  const _DeckTile({required this.deck, required this.due});
  final Deck deck;
  final int due;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final count = deck.usable.length;
    final canQuiz = quizFromDeck(deck, limit: 1).isNotEmpty;
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  deck.title,
                  style: AppTheme.bodyLg.copyWith(
                    color: palette.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                due > 0 ? '$due due' : '$count card${count == 1 ? '' : 's'}',
                style: AppTheme.label.copyWith(
                  color: due > 0 ? AppColors.primary : palette.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: count == 0
                    ? null
                    : () => context.push(deckStudyPath(deck.id)),
                icon: const Icon(Icons.flip_rounded, size: 18),
                label: const Text('Study'),
              ),
              OutlinedButton.icon(
                onPressed: canQuiz
                    ? () => context.push(deckQuizPath(deck.id))
                    : null,
                icon: const Icon(Icons.quiz_outlined, size: 18),
                label: const Text('Quiz me'),
              ),
              TextButton.icon(
                onPressed: () => context.push(deckEditPath(deck.id)),
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Edit'),
              ),
            ],
          ),
          if (!canQuiz && count > 0)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'A quiz needs four cards with different answers.',
                style: AppTheme.caption.copyWith(color: palette.textSecondary),
              ),
            ),
        ],
      ),
    );
  }
}
