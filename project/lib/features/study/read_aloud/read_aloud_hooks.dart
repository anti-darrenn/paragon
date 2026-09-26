import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/learn_resource.dart';
import '../../../core/widgets/lesson_blocks/lesson_block_view.dart';

/// Where read-aloud plugs into a lesson article.
///
/// `ArticlePane` calls these and nothing else, so read-aloud can grow
/// without editing the renderer or the pane. Until it is built they change
/// nothing.

/// Wraps each top-level block, to mark the block being read.
BlockDecorator readAloudDecorator(WidgetRef ref, LearnResource resource) =>
    (block, child) => child;

/// The "Listen" control for the article's header row.
class ReadAloudButton extends ConsumerWidget {
  const ReadAloudButton({super.key, required this.resource});

  final LearnResource resource;

  @override
  Widget build(BuildContext context, WidgetRef ref) => const SizedBox.shrink();
}
