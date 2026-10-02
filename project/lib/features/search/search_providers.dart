import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/lessons/subject_index.dart';
import '../../core/models/learn_resource.dart';
import '../../core/repositories/course_repository.dart';
import '../../core/repositories/subject_index_repository.dart';
import '../../core/search/search.dart';
import '../lesson/lesson_screen.dart' show lessonPath;

/// Everything search can find: every course in the catalog, and the
/// topics and lessons in each live subject's `subjectIndex` document.
///
/// One read per live subject, made once and then cached — the same
/// documents the glossary and revision cards read, so a student who has
/// used either has already paid for them. A subject whose index cannot be
/// read still contributes its course; search degrades, it does not fail.
final searchCorpusProvider = FutureProvider<List<SearchItem>>((ref) async {
  final catalog = await ref.watch(courseCatalogProvider.future);
  final live = [for (final c in catalog) if (c.isLive) c];
  final indexes = await Future.wait([
    for (final c in live)
      ref
          .watch(subjectIndexProvider(c.key).future)
          .then<SubjectIndex?>((i) => i, onError: (Object _) => null),
  ]);

  return [
    for (final c in catalog)
      SearchItem(
        kind: SearchKind.course,
        title: c.name,
        detail: c.isLive ? '' : 'Coming soon',
        path: '/subject/${c.key}/course',
      ),
    for (var i = 0; i < live.length; i++)
      for (final t in indexes[i]?.topics.values ?? const <TopicIndex>[])
        if (t.topicName.isNotEmpty) ...[
          SearchItem(
            kind: SearchKind.topic,
            title: t.topicName,
            subtitle: live[i].name,
            path: '/subject/${live[i].key}/course/topic/${t.topicId}',
          ),
          for (final l in t.lessons)
            if (l.title.isNotEmpty)
              SearchItem(
                kind: SearchKind.lesson,
                title: l.title,
                subtitle: '${t.topicName} · ${live[i].name}',
                detail: LearnResourceType.parse(l.type).label,
                path: lessonPath(t.topicId, l.id),
              ),
        ],
  ];
});

/// [searchCatalog] over [searchCorpusProvider]. Empty while the corpus
/// loads, so the field never shows an error for something it can't know
/// yet.
final searchResultsProvider = Provider.family<SearchResults, String>((
  ref,
  query,
) {
  final corpus = ref.watch(searchCorpusProvider).asData?.value;
  if (corpus == null) return SearchResults.empty;
  return searchCatalog(query, corpus);
});
