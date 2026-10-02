import 'package:flutter/material.dart';

import '../../core/search/search.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_theme.dart';

/// Search results in their three groups. Used by the top bar's dropdown
/// and by the `/search` page, so the two always look the same.
class SearchResultsView extends StatelessWidget {
  const SearchResultsView({
    super.key,
    required this.query,
    required this.results,
    required this.onOpen,
    this.highlighted,
    this.perGroup,
    this.shrinkWrap = false,
  });

  final String query;
  final SearchResults results;
  final ValueChanged<SearchItem> onOpen;

  /// The row the arrow keys are on, if any.
  final SearchItem? highlighted;

  /// Rows shown per group; null shows them all.
  final int? perGroup;
  final bool shrinkWrap;

  @override
  Widget build(BuildContext context) {
    List<SearchItem> cap(List<SearchItem> l) =>
        perGroup == null ? l : l.take(perGroup!).toList();

    final groups = [
      ('Courses', cap(results.courses)),
      ('Topics', cap(results.topics)),
      ('Lessons', cap(results.lessons)),
    ];

    return ListView(
      shrinkWrap: shrinkWrap,
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        for (final (label, items) in groups)
          if (items.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
              child: Text(
                label.toUpperCase(),
                style: AppTheme.caption.copyWith(
                  color: context.palette.textSecondary,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            for (final item in items)
              SearchResultTile(
                item: item,
                query: query,
                isHighlighted: identical(item, highlighted),
                onTap: () => onOpen(item),
              ),
          ],
      ],
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
    };
    final icon = switch (item.kind) {
      SearchKind.course => Icons.auto_stories_rounded,
      SearchKind.topic => Icons.topic_outlined,
      SearchKind.lesson => switch (item.detail) {
        'Video' => Icons.play_circle_outline_rounded,
        'Exercise' => Icons.edit_note_rounded,
        _ => Icons.article_outlined,
      },
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
                ? 'Search courses, topics and lessons'
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
