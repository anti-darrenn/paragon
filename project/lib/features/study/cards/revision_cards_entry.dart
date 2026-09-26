import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/repositories/learning_repository.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import 'card_providers.dart';
import 'card_review_screen.dart' show cardsPath;

/// "Revision cards: 3 due" on a subject's course page. Nothing at all when
/// the subject has no cards, or while they are loading — the page must
/// not grow a line that then disappears.
///
/// Costs one read of `subjectIndex/{subjectId}` and, once per app session,
/// one of `study/{uid}`.
class RevisionCardsEntry extends ConsumerWidget {
  const RevisionCardsEntry({super.key, required this.subjectId});

  final String subjectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deck = ref.watch(cardDeckProvider(subjectId));
    if (deck == null || deck.cards.isEmpty) return const SizedBox.shrink();
    final due = deck.dueCount;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Align(
        alignment: Alignment.centerLeft,
        child: OutlinedButton.icon(
          key: const ValueKey('course.revisionCards'),
          onPressed: () => context.push(cardsPath(subjectId)),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.textPrimaryDark,
            side: const BorderSide(color: AppColors.borderDark),
          ),
          icon: const Icon(Icons.style_outlined, size: 18),
          label: Text(
            'Revision cards: $due due',
            style: AppTheme.label.copyWith(
              color: due > 0 ? AppColors.primary : AppColors.textSecondaryDark,
            ),
          ),
        ),
      ),
    );
  }
}

/// "Revision cards" in the Saved page's app bar: pick a subject, then
/// review its cards. The subject list is already cached by the rest of
/// the app, so this costs no extra read.
class RevisionCardsAction extends ConsumerWidget {
  const RevisionCardsAction({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      key: const ValueKey('saved.revisionCards'),
      tooltip: 'Revision cards',
      icon: const Icon(Icons.style_outlined),
      onPressed: () async {
        final subjects = await ref.read(subjectsProvider.future);
        if (!context.mounted) return;
        final picked = await showModalBottomSheet<String>(
          context: context,
          backgroundColor: AppColors.surfaceDark,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          builder: (sheet) => SafeArea(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 12),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 6, 20, 6),
                  child: Text(
                    'Revision cards',
                    style: AppTheme.heading3.copyWith(
                      color: AppColors.textPrimaryDark,
                    ),
                  ),
                ),
                for (final s in subjects)
                  ListTile(
                    title: Text(
                      s.name,
                      style: AppTheme.bodyMd.copyWith(
                        color: AppColors.textPrimaryDark,
                      ),
                    ),
                    onTap: () => Navigator.of(sheet).pop(s.id),
                  ),
              ],
            ),
          ),
        );
        if (picked == null || !context.mounted) return;
        context.push(cardsPath(picked));
      },
    );
  }
}
