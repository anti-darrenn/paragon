import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/subject.dart';
import '../../core/repositories/learning_repository.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/page_layout.dart';
import '../../core/widgets/ui/ui.dart';
import '../study/cards/card_providers.dart';
import '../study/cards/card_review_screen.dart' show cardsPath;
import '../study/notes/study_providers.dart';
import '../study/offline/saved_topics_store.dart';
import '../../core/widgets/nav/back_navigation.dart';

/// `/review`: everything for going back over what you have learnt, in one
/// place — the mistakes notebook, revision cards, saved lessons and
/// questions, and topics kept for offline.
///
/// Stores nothing of its own and reads nothing new: each card opens a
/// screen that already existed, and the counts come from documents those
/// screens read anyway. The mistakes notebook shows no count on purpose,
/// for the dashboard's reason — counting means reading up to 200 attempts.
class ReviewScreen extends ConsumerWidget {
  const ReviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookmarks = ref.watch(bookmarksProvider).asData?.value.length;
    final offline = ref.watch(savedTopicsProvider).length;
    final subjects = ref.watch(subjectsProvider).asData?.value ?? const [];

    return Scaffold(
      backgroundColor: context.palette.background,
      appBar: const ParagonAppBar(
        title: Text('Review'),
        collapseWhenWide: true,
        actions: [SearchAction()],
      ),
      body: PageBody(
        children: [
          const PageIntro(
            title: 'Review',
            subtitle:
                'Go back over what you have learnt. Short, regular '
                'review is what makes it stick.',
          ),
          _ReviewCard(
            key: const ValueKey('review.mistakes'),
            icon: Icons.replay_rounded,
            accent: AppColors.wrong,
            title: 'Mistakes notebook',
            subtitle:
                'Questions you got wrong, with the working. '
                'Practise them until they leave.',
            onTap: () => context.push('/mistakes'),
          ),
          const SizedBox(height: 12),
          _CardsPanel(subjects: subjects),
          const SizedBox(height: 12),
          _ReviewCard(
            key: const ValueKey('review.saved'),
            icon: Icons.bookmark_outline_rounded,
            accent: AppColors.accentBlue,
            title: 'Saved',
            subtitle: switch (bookmarks) {
              null || 0 =>
                'Lessons and questions you bookmark, '
                    'and your notes',
              1 => '1 bookmark, and your notes',
              final n => '$n bookmarks, and your notes',
            },
            onTap: () => context.push('/saved'),
          ),
          const SizedBox(height: 12),
          _ReviewCard(
            key: const ValueKey('review.offline'),
            icon: Icons.download_for_offline_outlined,
            accent: AppColors.correct,
            title: 'Saved for offline',
            subtitle: switch (offline) {
              0 =>
                'Keep a topic on this device for when the '
                    'connection drops',
              1 => '1 topic on this device',
              final n => '$n topics on this device',
            },
            onTap: () => context.push('/settings/offline'),
          ),
        ],
      ),
    );
  }
}

/// Revision cards, one row per subject that has any, with how many are
/// due. One `subjectIndex` read per subject, shared with search and the
/// course pages.
class _CardsPanel extends ConsumerWidget {
  const _CardsPanel({required this.subjects});

  final List<Subject> subjects;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = [
      for (final s in subjects)
        if (ref.watch(cardDeckProvider(s.id)) case final deck?
            when deck.cards.isNotEmpty)
          (s, deck.dueCount, deck.cards.length),
    ];
    final totalDue = rows.fold<int>(0, (sum, r) => sum + r.$2);

    return Container(
      key: const ValueKey('review.cards'),
      decoration: BoxDecoration(
        color: context.palette.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: _CardHeading(
              icon: Icons.style_outlined,
              accent: AppColors.secondary,
              title: 'Revision cards',
              subtitle: rows.isEmpty
                  ? 'Definitions and formulas from published lessons become '
                        'cards here.'
                  : totalDue == 0
                  ? 'Nothing due. Come back tomorrow.'
                  : '$totalDue due today',
            ),
          ),
          for (final (subject, due, total) in rows) ...[
            Divider(height: 1, color: context.palette.border),
            InkWell(
              onTap: () => context.push(cardsPath(subject.id)),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: AppColors.forSubject(subject.name),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        subject.name,
                        style: AppTheme.bodyMd.copyWith(
                          color: context.palette.textPrimary,
                        ),
                      ),
                    ),
                    Text(
                      due > 0 ? '$due due' : '$total cards',
                      style: AppTheme.label.copyWith(
                        color: due > 0
                            ? AppColors.primary
                            : context.palette.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 20,
                      color: context.palette.textSecondary,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({
    super.key,
    required this.icon,
    required this.accent,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color accent;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.palette.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: context.palette.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: _CardHeading(
                  icon: icon,
                  accent: accent,
                  title: title,
                  subtitle: subtitle,
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: context.palette.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CardHeading extends StatelessWidget {
  const _CardHeading({
    required this.icon,
    required this.accent,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final Color accent;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: accent.withAlpha(32),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, color: accent, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTheme.bodyLg.copyWith(
                  color: context.palette.textPrimary,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: AppTheme.label.copyWith(
                  color: context.palette.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
