import 'package:flutter/material.dart';

import '../lessons/lesson_doc.dart';
import '../theme/app_theme.dart';
import 'lesson_blocks/figure_block.dart';

/// A question's diagram (or an explanation's picture), from `lessonAssets`.
///
/// A thin wrapper over the lesson [FigureView], so questions get what
/// figures already have: low-data mode's "tap to load", tap to zoom, and a
/// broken image that says so in place rather than taking the question
/// down. Renders nothing when [assetId] is null — most questions have none.
class QuestionImage extends StatelessWidget {
  const QuestionImage({super.key, required this.assetId});

  final String? assetId;

  /// Past-paper diagrams are small scans; stretched across a desktop
  /// column they blur and push the options off screen.
  static const double maxWidth = 520;

  @override
  Widget build(BuildContext context) {
    final id = assetId;
    if (id == null) return const SizedBox.shrink();
    final ref = 'asset:$id';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: maxWidth),
          child: FigureView(
            // keyed by asset so a new question never shows the old
            // question's "loaded" state in low-data mode
            key: ValueKey(ref),
            block: FigureBlock(ref, '', 1, ref),
            base: AppTheme.bodyMd,
          ),
        ),
      ),
    );
  }
}
