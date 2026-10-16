import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/web/browser.dart';

import '../../core/content/subject_catalog.dart';
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
  final live = [
    for (final c in catalog)
      if (c.isLive) c,
  ];
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
        path: '/subject/${c.slug}/course',
      ),
    for (var i = 0; i < live.length; i++)
      for (final t in indexes[i]?.topics.values ?? const <TopicIndex>[])
        if (t.topicName.isNotEmpty) ...[
          SearchItem(
            kind: SearchKind.topic,
            title: t.topicName,
            subtitle: live[i].name,
            path:
                '/subject/${live[i].slug}/course/topic/'
                '${SubjectCatalog.slugify(t.topicName)}',
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

/// Every published WAEC past question, from `/past-questions/search.json`,
/// which the static site build writes beside the question pages (audit
/// C13). A file on Hosting, not Firestore: searching question text costs
/// no reads. Only fetched once someone types a real query; empty off the
/// web or if the file is missing, so search degrades rather than fails.
final pastQuestionCorpusProvider = FutureProvider<List<SearchItem>>((
  ref,
) async {
  final text = await fetchText('/past-questions/search.json');
  if (text == null) return const [];
  try {
    return pastQuestionItems(jsonDecode(text) as Map<String, dynamic>);
  } on Object {
    return const [];
  }
});

/// [searchCatalog] over [searchCorpusProvider], and, from three characters
/// on, over the past questions too. Empty while the corpus loads, so the
/// field never shows an error for something it can't know yet.
final searchResultsProvider = Provider.family<SearchResults, String>((
  ref,
  query,
) {
  final corpus = ref.watch(searchCorpusProvider).asData?.value;
  if (corpus == null) return SearchResults.empty;
  final past = normalizeForSearch(query).length >= 3
      ? ref.watch(pastQuestionCorpusProvider).asData?.value ?? const []
      : const <SearchItem>[];
  return searchCatalog(query, [...corpus, ...past]);
});

/// Opens a search result: a route in the app, or, for a past question, its
/// static page, which lives outside the app's router.
void openSearchPath(BuildContext context, String path) {
  if (path.startsWith('/past-questions/')) {
    launchUrl(Uri.parse('$appOrigin$path'), webOnlyWindowName: '_self');
  } else {
    context.push(path);
  }
}
