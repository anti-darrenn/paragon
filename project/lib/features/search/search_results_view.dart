import 'package:flutter/material.dart';

import '../../core/search/search.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_theme.dart';

/// Search results, grouped. Used by the top bar's palette and by the
/// `/search` page, so the two always look the same.
///
/// Lessons and videos come first, then topics, then courses, all open.
/// Past questions sit below in a section of their own, folded away until
/// [questionsOpen] (owner's request, 2026-10-19): a search for "waves"
/// should lead with the lesson on waves, not twenty question stems. When
/// questions are all that matched, they show open.
class SearchResultsView extends StatelessWidget {
  const SearchResultsView({
    super.key,
    required this.query,
    required this.results,
    required this.onOpen,
    required this.questionsOpen,
    required this.onToggleQuestions,
    this.highlighted,
    this.perGroup,
    this.shrinkWrap = false,
  });

  final String query;
  final SearchResults results;
  final ValueChanged<SearchItem> onOpen;

  /// Whether the past questions are unfolded.
  final bool questionsOpen;
  final VoidCallback onToggleQuestions;

  /// The row the arrow keys are on, if any.
  final SearchItem? highlighted;

  /// Rows shown per group; null shows them all.
  final int? perGroup;
  final bool shrinkWrap;

  /// Whether [results] shows its past questions, given the fold.
  static bool showsQuestions(SearchResults results, bool questionsOpen) =>
      questionsOpen || !results.hasLearning;

  @override
  Widget build(BuildContext context) {
    List<SearchItem> cap(List<SearchItem> l) =>
        perGroup == null ? l : l.take(perGroup!).toList();

    final groups = [
      ('Videos and lessons', cap(results.lessons)),
      ('Topics', cap(results.topics)),
      ('Courses', cap(results.courses)),
    ];
    final questions = cap(results.pastQuestions);
    final open = showsQuestions(results, questionsOpen);

    Widget tile(SearchItem item) => SearchResultTile(
      item: item,
      query: query,
      isHighlighted: identical(item, highlighted),
      onTap: () => onOpen(item),
    );

    return ListView(
      shrinkWrap: shrinkWrap,
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        for (final (label, items) in groups)
          if (items.isNotEmpty) ...[
            _GroupLabel(label),
            for (final item in items) tile(item),
          ],
        if (questions.isNotEmpty) ...[
          if (results.hasLearning)
            _QuestionsFold(
              // The index keeps the best twenty; say so rather than
              // promise an exact count.
              count: results.pastQuestions.length,
              open: open,
              onTap: onToggleQuestions,
            )
          else
            const _GroupLabel('Past questions'),
          if (open)
            for (final item in questions) tile(item),
        ],
      ],
    );
  }
}

class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
    child: Text(
      label.toUpperCase(),
      style: AppTheme.caption.copyWith(
        color: context.palette.textSecondary,
        letterSpacing: 0.8,
      ),
    ),
  );
}

/// "Questions (20)", folded: tap to see the past questions that match.
class _QuestionsFold extends StatelessWidget {
  const _QuestionsFold({
    required this.count,
    required this.open,
    required this.onTap,
  });

  final int count;
  final bool open;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final n = count >= 20 ? '20+' : '$count';
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 2),
      child: Semantics(
        button: true,
        expanded: open,
        label: 'Past questions, $n matches',
        excludeSemantics: true,
        onTap: onTap,
        child: Material(
          color: palette.background,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: palette.border),
          ),
          child: InkWell(
            key: const ValueKey('search.questionsFold'),
            borderRadius: BorderRadius.circular(10),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              child: Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: AppColors.accentBlue.withAlpha(36),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.history_edu_rounded,
                      size: 17,
                      color: AppColors.accentBlue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: 'Questions',
                            style: AppTheme.bodyMd.copyWith(
                              color: palette.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          TextSpan(
                            text: '  $n WAEC past questions match',
                            style: AppTheme.label.copyWith(
                              color: palette.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  AnimatedRotation(
                    turns: open ? 0.5 : 0,
                    duration: MediaQuery.disableAnimationsOf(context)
                        ? Duration.zero
                        : const Duration(milliseconds: 180),
                    child: Icon(
                      Icons.expand_more_rounded,
                      color: palette.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SearchResultTile extends StatelessWidget {
  const SearchResultTile({
    super.key,
    required this.item,
    required this.query,
    required this.onTap,
    this.isHighlighted = false,
  });

  final SearchItem item;
  final String query;
  final VoidCallback onTap;
  final bool isHighlighted;

  @override
  Widget build(BuildContext context) {
    final accent = switch (item.kind) {
      SearchKind.course => AppColors.forSubject(item.title),
      SearchKind.topic => AppColors.forSubject(item.subtitle),
      SearchKind.lesson => AppColors.primary,
      SearchKind.pastQuestion => AppColors.accentBlue,
    };
    final icon = switch (item.kind) {
      SearchKind.course => Icons.auto_stories_rounded,
      SearchKind.topic => Icons.topic_outlined,
      SearchKind.lesson => switch (item.detail) {
        'Video' => Icons.play_circle_outline_rounded,
        'Exercise' => Icons.edit_note_rounded,
        _ => Icons.article_outlined,
      },
      SearchKind.pastQuestion => Icons.history_edu_rounded,
    };
    final subtitle = [
      if (item.subtitle.isNotEmpty) item.subtitle,
      if (item.detail.isNotEmpty) item.detail,
    ].join(' · ');

    return Material(
      color: isHighlighted ? context.palette.track : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: accent.withAlpha(36),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, size: 18, color: accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _Highlighted(text: item.title, query: query),
                    if (subtitle.isNotEmpty)
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.label.copyWith(
                          color: context.palette.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              if (isHighlighted)
                Icon(
                  Icons.keyboard_return_rounded,
                  size: 16,
                  color: context.palette.textSecondary,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The title with the part that matched in the brand colour.
class _Highlighted extends StatelessWidget {
  const _Highlighted({required this.text, required this.query});

  final String text;
  final String query;

  @override
  Widget build(BuildContext context) {
    final base = AppTheme.bodyMd.copyWith(
      color: context.palette.textPrimary,
      fontWeight: FontWeight.w500,
      height: 1.35,
    );
    final q = query.trim().toLowerCase();
    final at = q.isEmpty ? -1 : text.toLowerCase().indexOf(q);
    if (at < 0) {
      return Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: base,
      );
    }
    return Text.rich(
      TextSpan(
        style: base,
        children: [
          TextSpan(text: text.substring(0, at)),
          TextSpan(
            text: text.substring(at, at + q.length),
            style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          TextSpan(text: text.substring(at + q.length)),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

/// What the field and the page say when nothing matches.
class SearchEmptyMessage extends StatelessWidget {
  const SearchEmptyMessage({super.key, required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    final blank = query.trim().isEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            blank ? Icons.search_rounded : Icons.search_off_rounded,
            size: 36,
            color: context.palette.textSecondary,
          ),
          const SizedBox(height: 10),
          Text(
            blank
                ? 'Search lessons, videos, topics, courses and past questions'
                : 'Nothing matches “${query.trim()}”',
            textAlign: TextAlign.center,
            style: AppTheme.bodyMd.copyWith(color: context.palette.textPrimary),
          ),
          if (!blank) ...[
            const SizedBox(height: 4),
            Text(
              'Try a shorter word, or the name of the topic.',
              textAlign: TextAlign.center,
              style: AppTheme.label.copyWith(
                color: context.palette.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
