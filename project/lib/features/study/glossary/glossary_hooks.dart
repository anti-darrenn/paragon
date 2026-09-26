import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/learn_resource.dart';
import '../../../core/widgets/lesson_blocks/lesson_block_view.dart';

/// Where the glossary plugs into a lesson article: marking terms the
/// subject defines elsewhere so a student can look them up in place.
///
/// `ArticlePane` calls this and nothing else. Until the glossary is built
/// it changes nothing.
BlockDecorator glossaryDecorator(WidgetRef ref, LearnResource resource) =>
    (block, child) => child;
