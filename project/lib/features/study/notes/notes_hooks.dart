import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/lessons/lesson_doc.dart';
import '../../../core/models/learn_resource.dart';
import '../../../core/widgets/lesson_blocks/lesson_block_view.dart';
import 'notes_widgets.dart';
import 'study_models.dart';
import 'study_providers.dart';

/// Where highlights, notes and bookmarks plug into a lesson article.
///
/// `ArticlePane` calls these and nothing else, so the notes feature grows
/// here without editing the renderer or the pane.

/// Wraps each top-level block of [resource]'s article with its highlight,
/// its note marker, and long-press to annotate.
///
/// Watches the lesson's notes through [ref], so the pane rebuilds when a
/// note changes. Every block is wrapped — annotated or not — so
/// highlighting a block never changes the shape of the tree (see
/// [AnnotatedBlock]).
BlockDecorator notesDecorator(WidgetRef ref, LearnResource resource) {
  final notes =
      ref.watch(lessonNotesProvider(lessonRefOf(resource))).asData?.value ??
      const <LessonNote>[];
  final byKey = {for (final n in notes) n.blockKey: n};
  return (LessonBlock block, Widget child) => AnnotatedBlock(
    block: block,
    resource: resource,
    note: byKey[block.key],
    child: child,
  );
}

/// Buttons for the article's header row: bookmark this lesson, and
/// "Notes (n)", which lists this lesson's notes — including any written on
/// an earlier version of it.
class NotesHeaderActions extends ConsumerWidget {
  const NotesHeaderActions({super.key, required this.resource});

  final LearnResource resource;

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      LessonHeaderActions(resource: resource);
}
