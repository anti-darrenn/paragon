import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/learn_resource.dart';
import '../../core/providers/reading_settings_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/article_view.dart';

/// An article lesson. Completion is decided by the lesson screen, which
/// owns the scroll: reaching the end counts as read.
class ArticlePane extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    // The student's reading settings: text size is already applied app-wide
    // (never scale again here); line spacing and font apply to body text.
    final base = ArticleView.defaultTextStyle;
    final style = ref.watch(readingFontProvider).apply(
      base.copyWith(height: base.height! * ref.watch(lineSpacingProvider)),
    );

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
        ArticleView(body: resource.body, textStyle: style),
      ],
    );
  }
}
