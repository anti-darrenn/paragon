import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ai/ask_tutor_button.dart';
import '../../core/models/learn_resource.dart';
import '../../core/providers/reading_settings_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/article_view.dart';
import '../../core/widgets/lesson_blocks/lesson_block_view.dart';
import '../../core/widgets/report_lesson_button.dart';
import '../study/glossary/glossary_hooks.dart';
import '../study/notes/notes_hooks.dart';
import '../study/read_aloud/read_aloud_hooks.dart';
import '../../core/theme/app_palette.dart';

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
    final base = ArticleView.defaultTextStyleOf(context);
    final style = ref.watch(readingFontProvider).apply(
      base.copyWith(height: base.height! * ref.watch(lineSpacingProvider)),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // The header row carries the study features' controls (ask,
        // listen, notes, bookmark, report). They plug in through their hook
        // files, never here. On a phone there are more of them than fit on
        // one line, so they wrap rather than overflow.
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                'ARTICLE',
                style: AppTheme.caption.copyWith(
                  color: context.palette.textSecondary,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Wrap(
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  AskTutorButton(resource: resource),
                  ReadAloudButton(resource: resource),
                  NotesHeaderActions(resource: resource),
                  ReportLessonButton(resource: resource),
                ],
              ),
            ),
          ],
        ),
        if (!bodyRepeatsTitle(resource)) ...[
          const SizedBox(height: 8),
          Text(
            resource.title,
            style: AppTheme.heading1.copyWith(color: context.palette.textPrimary),
          ),
          const SizedBox(height: 24),
        ],
        ArticleView(
          body: resource.body,
          textStyle: style,
          decorate: composeDecorators([
            glossaryDecorator(ref, resource),
            notesDecorator(ref, resource),
            readAloudDecorator(ref, resource),
          ]),
        ),
      ],
    );
  }
}
