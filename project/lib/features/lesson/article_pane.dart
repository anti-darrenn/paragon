import 'package:flutter/material.dart';

import '../../core/models/learn_resource.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/article_view.dart';

/// An article lesson. Completion is decided by the lesson screen, which
/// owns the scroll: reaching the end counts as read.
class ArticlePane extends StatelessWidget {
  const ArticlePane({super.key, required this.resource});

  final LearnResource resource;

  /// Whether the body already opens with the title as its heading — the
  /// seeded articles do — in which case printing it again above would
  /// show it twice.
  static bool bodyRepeatsTitle(LearnResource r) {
    final blocks = parseArticleBlocks(r.body);
    if (blocks.isEmpty) return false;
    final first = blocks.first;
    return first.kind == ArticleBlockKind.heading1 &&
        first.text.trim().toLowerCase() == r.title.trim().toLowerCase();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ARTICLE',
          style: AppTheme.caption.copyWith(
            color: AppColors.textSecondaryDark,
            letterSpacing: 0.8,
          ),
        ),
        if (!bodyRepeatsTitle(resource)) ...[
          const SizedBox(height: 8),
          Text(
            resource.title,
            style: AppTheme.heading1.copyWith(color: AppColors.textPrimaryDark),
          ),
          const SizedBox(height: 24),
        ],
        ArticleView(body: resource.body),
      ],
    );
  }
}
