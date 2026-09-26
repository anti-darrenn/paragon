import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/learn_resource.dart';
import '../../../core/widgets/lesson_blocks/lesson_block_view.dart';

/// Where highlights, notes and bookmarks plug into a lesson article.
///
/// `ArticlePane` calls these and nothing else, so the notes feature can
/// grow without editing the renderer or the pane. Until it is built they
/// change nothing.

/// Wraps each top-level block of [resource]'s article (highlight colour,
/// note marker, tap-to-annotate).
BlockDecorator notesDecorator(WidgetRef ref, LearnResource resource) =>
    (block, child) => child;

/// Buttons for the article's header row (for example, bookmark this
/// lesson).
class NotesHeaderActions extends ConsumerWidget {
  const NotesHeaderActions({super.key, required this.resource});

  final LearnResource resource;

  @override
  Widget build(BuildContext context, WidgetRef ref) => const SizedBox.shrink();
}
