import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/models/learn_resource.dart';
import '../core/repositories/learn_repository.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';
import '../core/widgets/app_top_nav.dart';
import '../core/widgets/article_view.dart';

/// A published Learn article — `/learn/topic/:topicId/article/:resourceId`.
///
/// Reads from `topicResourcesProvider`, the same published-only query the
/// topic page lists from, so opening an article from that list costs no
/// extra read, and a draft can never be opened here: it is not in the
/// list, and the rules refuse it by id anyway.
class ArticleScreen extends ConsumerWidget {
  const ArticleScreen({
    super.key,
    required this.topicId,
    required this.resourceId,
  });

  final String topicId;
  final String resourceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resources = ref.watch(topicResourcesProvider(topicId));

    return ParagonPage(
      child: resources.when(
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: 120),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (_, _) => const _Message("This article couldn't be loaded."),
        data: (list) {
          final matches = list.where(
            (r) =>
                r.id == resourceId &&
                r.type == LearnResourceType.article &&
                r.isAvailable,
          );
          if (matches.isEmpty) {
            return const _Message('This article is not available.');
          }
          final article = matches.first;
          return Center(
            child: ConstrainedBox(
              // A readable line length, narrower than the course pages.
              constraints: const BoxConstraints(maxWidth: 720),
              child: Padding(
                padding: const EdgeInsets.only(top: 32, bottom: 80),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ARTICLE',
                      style: AppTheme.caption.copyWith(
                        color: AppColors.textSecondaryDark,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      article.title,
                      style: AppTheme.heading1.copyWith(
                        color: AppColors.textPrimaryDark,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ArticleView(body: article.body),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 120),
      child: Center(
        child: Text(
          text,
          style: AppTheme.bodyLg.copyWith(color: AppColors.textSecondaryDark),
        ),
      ),
    );
  }
}
