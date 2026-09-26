import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/lessons/lesson_doc.dart';
import '../../../core/lessons/subject_index.dart';
import '../../../core/models/learn_resource.dart';
import '../../../core/repositories/subject_index_repository.dart';
import '../../../core/widgets/lesson_blocks/lesson_block_view.dart';
import 'glossary_match.dart';
import 'glossary_widgets.dart';

/// Where the glossary plugs into a lesson article: marking terms the
/// subject defines so a student can look them up in place.
///
/// `ArticlePane` calls this and nothing else. The renderer is not touched:
/// a block where a term first appears gets a small row of term chips
/// beneath it, and tapping one opens the definition.
///
/// **Every block is wrapped, with or without terms**, so the glossary
/// arriving (it loads after the article) never changes the shape of the
/// tree above a block — a block holding a video iframe must not remount.
BlockDecorator glossaryDecorator(WidgetRef ref, LearnResource resource) {
  final subjectId = resource.subjectId;
  final index = subjectId.isEmpty
      ? null
      : ref.watch(subjectIndexProvider(subjectId)).asData?.value;
  final definitions = index?.definitions ?? const <IndexedDefinition>[];

  var termsByBlock = const <String, List<String>>{};
  final byTerm = <String, List<IndexedDefinition>>{};
  if (definitions.isNotEmpty) {
    for (final d in definitions) {
      final k = d.term.trim().toLowerCase();
      if (k.isNotEmpty) byTerm.putIfAbsent(k, () => []).add(d);
    }
    termsByBlock = glossaryTermsByBlock(
      parseLessonDoc(resource.body),
      definitions.map((d) => d.term),
    );
  }

  return (LessonBlock block, Widget child) {
    final terms = termsByBlock[block.key] ?? const <String>[];
    return GlossaryTermsRow(
      terms: [
        for (final t in terms)
          if (byTerm[t.trim().toLowerCase()] case final defs?) (t, defs),
      ],
      child: child,
    );
  };
}
