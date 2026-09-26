import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/lessons/subject_index.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/article_view.dart';
import '../../lesson/lesson_screen.dart' show lessonPath;

/// Opens a lesson from a pushed page or sheet: the page is closed first,
/// then the router moves, so the student is not left with a stale page
/// stacked above the lesson.
void openIndexedLesson(
  BuildContext context, {
  required String topicId,
  required String resourceId,
  VoidCallback? close,
}) {
  final router = GoRouter.maybeOf(context);
  if (close != null) {
    close();
  } else {
    Navigator.of(context).maybePop();
  }
  router?.go(lessonPath(topicId, resourceId));
}

/// "From Number bases · Open lesson". Shown under a definition or formula.
class IndexSourceLine extends StatelessWidget {
  const IndexSourceLine({
    super.key,
    required this.topicName,
    required this.onOpen,
  });

  final String topicName;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (topicName.isNotEmpty)
          Flexible(
            child: Text(
              'From $topicName',
              style: AppTheme.caption.copyWith(
                color: AppColors.textSecondaryDark,
              ),
            ),
          ),
        if (onOpen != null)
          TextButton(
            onPressed: onOpen,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              visualDensity: VisualDensity.compact,
            ),
            child: const Text('Open lesson'),
          ),
      ],
    );
  }
}

/// A block, with the glossary terms first found in it listed underneath.
///
/// The [child] is always the first child of the same [Column], whether or
/// not there are terms, so terms arriving never remount the block.
class GlossaryTermsRow extends StatelessWidget {
  const GlossaryTermsRow({super.key, required this.terms, required this.child});

  /// Each term as written in the lesson's subject glossary, with its
  /// definitions (usually one; a term defined in two topics has two).
  final List<(String, List<IndexedDefinition>)> terms;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        child,
        if (terms.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'Terms:',
                  style: AppTheme.caption.copyWith(
                    color: AppColors.textSecondaryDark,
                  ),
                ),
                for (final (term, defs) in terms)
                  InkWell(
                    key: ValueKey('glossary.term.${term.toLowerCase()}'),
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => showDefinitionSheet(context, term, defs),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.borderDark),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        term,
                        style: AppTheme.caption.copyWith(
                          color: AppColors.textPrimaryDark,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// The definition of [term], in a bottom sheet over the lesson.
Future<void> showDefinitionSheet(
  BuildContext context,
  String term,
  List<IndexedDefinition> definitions,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surfaceDark,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (sheet) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(sheet).height * 0.7,
        ),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
          children: [
            Text(
              term,
              style: AppTheme.heading3.copyWith(
                color: AppColors.textPrimaryDark,
              ),
            ),
            for (final d in definitions) ...[
              const SizedBox(height: 10),
              ArticleView(body: d.body),
              IndexSourceLine(
                topicName: d.topicName,
                onOpen: d.resourceId.isEmpty
                    ? null
                    : () => openIndexedLesson(
                        sheet,
                        topicId: d.topicId,
                        resourceId: d.resourceId,
                      ),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}
