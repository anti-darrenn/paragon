import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../content/subject_catalog.dart';
import '../models/subject.dart';
import 'learning_repository.dart';

/// Read-model for the course index pages (`/subject/:subjectKey/course`).
///
/// It sits on top of the existing providers in `learning_repository.dart`
/// rather than issuing its own Firestore queries, for two reasons: those
/// providers are already cached per-key by Riverpod, and they use only the
/// composite indexes that exist today (`units: subjectId+order`, `topics:
/// unitId+order`). Fetching every topic for a subject in one query would
/// need a `topics: subjectId+order` index that production doesn't have.
///
/// A subject is either **live** (seeded into Firestore) or **planned** (in
/// `SubjectCatalog` only). Both render through the same widgets; the
/// difference is carried by [CourseStatus] and [CourseTopic.isPlaceholder],
/// never by a separate code path in the UI.

enum CourseStatus {
  /// Units and topics came from Firestore. Topics are practisable.
  live,

  /// Outline came from `SubjectCatalog`. Nothing here is practisable yet.
  planned,
}

/// One topic link inside a module card.
class CourseTopic {
  const CourseTopic({
    required this.id,
    required this.name,
    required this.questionCount,
    required this.hasNotes,
    required this.isPlaceholder,
    this.lessonCount = 0,
  });

  /// Published, openable Learn items (`topics.lessonCount`). Zero means
  /// "not known" — show no count rather than "0 of 0".
  final int lessonCount;

  /// Firestore document id when live; a slug when placeholder. Either way
  /// it is the `:topicKey` path parameter.
  final String id;
  final String name;

  /// Seeded question count. Always 0 for placeholders — and note that even
  /// for live topics this is the count written at seed time, which includes
  /// questions with no verified answer. `drillQuestionsProvider` filters on
  /// `hasAnswer`, so the practisable count can be lower. Treated as
  /// "roughly this many", never as a promise.
  final int questionCount;

  /// Whether authored Learn-mode notes exist on the topic document. No
  /// seeded topic sets this today (see `Topic.hasNotes`), so the topic
  /// overview reads it rather than assuming — the Article row becomes real
  /// the moment notes are written, with no further change here.
  final bool hasNotes;

  /// True when this topic exists only in `SubjectCatalog` — no Firestore
  /// document, nothing to practise. The UI must not offer drill for these.
  final bool isPlaceholder;
}

/// One module (a Firestore `unit`, or a catalog unit) — the repeating card.
class CourseModule {
  const CourseModule({
    required this.id,
    required this.name,
    required this.topics,
    required this.isPlaceholder,
  });

  final String id;
  final String name;
  final List<CourseTopic> topics;
  final bool isPlaceholder;

  int get questionCount =>
      topics.fold(0, (sum, topic) => sum + topic.questionCount);
}

/// A whole subject course page.
class Course {
  const Course({
    required this.key,
    required this.slug,
    required this.name,
    required this.blurb,
    required this.subjectId,
    required this.status,
    required this.modules,
  });

  /// The `:subjectKey` this course was resolved from — used when building
  /// child routes so deep links keep whichever form the user arrived with
  /// (Firestore id or slug).
  final String key;

  final String slug;
  final String name;
  final String blurb;

  /// Firestore subject document id — null for a planned subject.
  final String? subjectId;

  final CourseStatus status;
  final List<CourseModule> modules;

  bool get isLive => status == CourseStatus.live;

  int get topicCount =>
      modules.fold(0, (sum, module) => sum + module.topics.length);

  int get questionCount =>
      modules.fold(0, (sum, module) => sum + module.questionCount);

  /// Finds a topic by its route key, with the module it belongs to — the
  /// topic overview page needs both (for the breadcrumb and for the Learn
  /// route, which takes a unitId).
  (CourseModule, CourseTopic)? findTopic(String topicKey) {
    for (final module in modules) {
      for (final topic in module.topics) {
        if (topic.id == topicKey) return (module, topic);
      }
    }
    return null;
  }
}

/// Lightweight row for the `/courses` catalog page — no topic fetches.
class CourseSummary {
  const CourseSummary({
    required this.key,
    required this.slug,
    required this.name,
    required this.blurb,
    required this.status,
    required this.moduleCount,
    this.topicCount = 0,
  });

  final String key;

  /// Stable catalog slug. Preferred over [key] for anything persisted —
  /// a live subject's [key] is its Firestore document id, which would
  /// change if the subject were ever reseeded, whereas the slug is
  /// derived from the name and stays put. `selectedSubjects` stores this.
  final String slug;

  final String name;
  final String blurb;
  final CourseStatus status;

  /// Unit count. Live subjects use the `unitCount` written on the subject
  /// document by the seeder; planned subjects use their outline length.
  final int moduleCount;

  /// Topic count, for a progress ring's denominator. Zero when unknown —
  /// see [Subject.topicCount]. Planned subjects deliberately report zero
  /// rather than their outline length: an outline is not practisable
  /// content, and a ring drawn against it would measure a student against
  /// topics that do not exist.
  final int topicCount;

  bool get isLive => status == CourseStatus.live;

  /// Whether a ring can honestly be drawn for this subject.
  bool get hasTopicCount => isLive && topicCount > 0;
}

/// Matches a route key against the live subjects — by Firestore document id
/// first, then by slugified name, so both `/subject/<docId>/course` and
/// `/subject/physics/course` resolve.
Subject? _matchLiveSubject(List<Subject> subjects, String key) {
  for (final subject in subjects) {
    if (subject.id == key) return subject;
  }
  final wanted = SubjectCatalog.slugify(key);
  for (final subject in subjects) {
    if (SubjectCatalog.slugify(subject.name) == wanted) return subject;
  }
  return null;
}

CourseModule _placeholderModule(String subjectSlug, CatalogUnit unit) {
  final unitSlug = SubjectCatalog.slugify(unit.name);
  return CourseModule(
    id: '$subjectSlug--$unitSlug',
    name: unit.name,
    isPlaceholder: true,
    topics: [
      for (final topic in unit.topics)
        CourseTopic(
          id: '$unitSlug--${SubjectCatalog.slugify(topic)}',
          name: topic,
          questionCount: 0,
          hasNotes: false,
          isPlaceholder: true,
        ),
    ],
  );
}

/// Every subject Paragon plans to ship, live ones first, each tagged with
/// whether its content actually exists yet.
final courseCatalogProvider = FutureProvider<List<CourseSummary>>((ref) async {
  final subjects = await ref.watch(subjectsProvider.future);

  return [
    for (final entry in SubjectCatalog.all)
      () {
        final live = _matchLiveSubject(subjects, entry.slug);
        return CourseSummary(
          // Live subjects route by document id: that's the form every other
          // screen in the app already links with.
          key: live?.id ?? entry.slug,
          slug: entry.slug,
          name: live?.name ?? entry.name,
          blurb: entry.blurb,
          status: live == null ? CourseStatus.planned : CourseStatus.live,
          moduleCount: live?.unitCount ?? entry.outline.length,
          topicCount: live?.topicCount ?? 0,
        );
      }(),
  ];
});

/// The full course outline for one subject.
///
/// Throws [CourseNotFoundException] for a key that matches neither a live
/// subject nor a catalog entry, so a bad deep link shows a real message
/// instead of an empty page.
final courseProvider = FutureProvider.family<Course, String>((ref, key) async {
  final subjects = await ref.watch(subjectsProvider.future);
  final live = _matchLiveSubject(subjects, key);
  final catalogEntry = live == null
      ? SubjectCatalog.bySlug(SubjectCatalog.slugify(key))
      : SubjectCatalog.byName(live.name);

  if (live == null && catalogEntry == null) {
    throw CourseNotFoundException(key);
  }

  final slug = catalogEntry?.slug ?? SubjectCatalog.slugify(live!.name);
  final name = live?.name ?? catalogEntry!.name;
  final blurb = catalogEntry?.blurb ?? '';

  if (live != null) {
    final units = await ref.watch(unitsProvider(live.id).future);

    // One topics query per unit — 3 to 13 in practice, issued in parallel.
    // See the note at the top of this file for why this isn't a single
    // subject-wide query.
    final topicLists = await Future.wait([
      for (final unit in units) ref.watch(topicsProvider(unit.id).future),
    ]);

    final modules = [
      for (var i = 0; i < units.length; i++)
        CourseModule(
          id: units[i].id,
          name: units[i].name,
          isPlaceholder: false,
          topics: [
            for (final topic in topicLists[i])
              CourseTopic(
                id: topic.id,
                name: topic.name,
                questionCount: topic.questionCount,
                hasNotes: topic.hasNotes,
                isPlaceholder: false,
                lessonCount: topic.lessonCount,
              ),
          ],
        ),
    ];

    // A seeded subject with zero units shouldn't happen, but if it does,
    // fall back to the outline rather than rendering a blank page.
    if (modules.isNotEmpty) {
      return Course(
        key: key,
        slug: slug,
        name: name,
        blurb: blurb,
        subjectId: live.id,
        status: CourseStatus.live,
        modules: modules,
      );
    }
  }

  return Course(
    key: key,
    slug: slug,
    name: name,
    blurb: blurb,
    subjectId: live?.id,
    status: CourseStatus.planned,
    modules: [
      for (final unit in catalogEntry?.outline ?? const <CatalogUnit>[])
        _placeholderModule(slug, unit),
    ],
  );
});

class CourseNotFoundException implements Exception {
  const CourseNotFoundException(this.key);

  final String key;

  @override
  String toString() => 'No course matches "$key".';
}
