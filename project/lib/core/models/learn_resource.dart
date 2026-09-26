import 'package:cloud_firestore/cloud_firestore.dart';

import 'firestore_parsing.dart';

/// One item in a topic's Learn sequence — a video, an article, or a short
/// formative exercise.
///
/// ## Where these live
///
/// `topics/{topicId}/resources/{resourceId}`, a subcollection. Every other
/// collection in this app is top-level, so the departure is worth naming:
/// resources are only ever read for one topic at a time. The student query
/// is `status == 'published'` ordered by `order`, which needs the
/// `status + order` composite index in `firestore.indexes.json` — the
/// status filter is not optional, because the rules refuse any list that
/// could return a draft. Firestore rules do not cascade into
/// subcollections, so this path has its own block.
///
/// Document ids are **slugs, not auto-ids**. CLAUDE.md requires auto-ids
/// for `questions`, and the reason is specific to them:
/// `drillQuestionsProvider` rotates its session window with a random
/// cursor over `FieldPath.documentId`, which sequential ids would cluster
/// and break. Nothing cursors over resources — they are fetched whole and
/// sorted by `order` — so a stable slug is the better id here: re-running
/// the seeder updates a resource in place instead of duplicating it.
///
/// ## What is deliberately not modelled
///
/// [description] and [transcript] are read but have no UI in v1. There is
/// no video content yet to describe or transcribe, and building a
/// transcript viewer before a single transcript exists is how a field ends
/// up collected and never read — the mistake `profile` already made. They
/// are parsed so that authoring one does not need a schema change.
///
/// There is no offline-video field and never will be: YouTube-embedded
/// video cannot legally or technically be cached this way.
enum LearnResourceType {
  video,
  article,
  exercise,

  /// A `type` this build does not recognise.
  ///
  /// Not an error case to be logged and forgotten — it is what a student
  /// on an older build sees when a newer resource type is seeded. The UI
  /// must skip these silently rather than render a broken row, which is
  /// why this is a real enum value and not a null.
  unknown;

  static LearnResourceType parse(dynamic value) {
    switch (asString(value).trim().toLowerCase()) {
      case 'video':
        return LearnResourceType.video;
      case 'article':
        return LearnResourceType.article;
      case 'exercise':
        return LearnResourceType.exercise;
      default:
        return LearnResourceType.unknown;
    }
  }

  /// What the student is asked to do with it — used for the "Up next"
  /// control and the kind label on each row.
  String get label => switch (this) {
    LearnResourceType.video => 'Video',
    LearnResourceType.article => 'Article',
    LearnResourceType.exercise => 'Exercise',
    LearnResourceType.unknown => 'Unknown',
  };
}

/// Where a resource is in the review workflow (`docs/CONTENT_ROLES.md`):
/// `draft → in_review → published`, with `changes_requested` sending it
/// back to the writer.
///
/// Parsed exactly the way `firestore.rules` reads it, so the studio never
/// labels something "Published" that students cannot actually see: only
/// the exact string `published` is visible to students. Every other value
/// is staff-only, and anything unrecognised — including a missing field —
/// reads as [draft]. (Every resource carries the field; see the rules file
/// for why "missing means published" was tried and removed.)
enum ResourceStatus {
  draft('draft', 'Draft'),
  inReview('in_review', 'In review'),
  changesRequested('changes_requested', 'Changes requested'),
  published('published', 'Published');

  const ResourceStatus(this.value, this.label);

  /// Stored in Firestore and matched by the rules. Never rename.
  final String value;
  final String label;

  /// True only for [published] — the one status students can see.
  bool get isLive => this == ResourceStatus.published;

  static ResourceStatus parse(dynamic value) {
    for (final s in values) {
      if (s.value == value) return s;
    }
    return ResourceStatus.draft;
  }
}

class LearnResource {
  const LearnResource({
    required this.id,
    required this.type,
    required this.order,
    required this.title,
    required this.subjectId,
    required this.topicId,
    this.origin = 'authored',
    this.youtubeId,
    this.durationSeconds,
    this.description,
    this.transcript,
    this.body = '',
    this.questionCount = 0,
    this.questionIds = const [],
    this.status = ResourceStatus.published,
    this.createdBy,
    this.revisionOf,
  });

  final String id;
  final LearnResourceType type;
  final int order;

  /// **Not a unique key.** A video and an article covering the same
  /// sub-concept legitimately share a title — "Powers of the imaginary
  /// unit" as both a watch and a read. Never dedupe or merge on it.
  final String title;

  final String subjectId;
  final String topicId;

  /// `authored` or `ai_generated`, mirroring the `origin` stamp on the
  /// generated question corpus — the field an audit or a rollback uses to
  /// find synthetic content.
  final String origin;

  // ── Video ──────────────────────────────────────────────────────────

  /// Null or empty for the overwhelming majority of topics, which is the
  /// **normal** state, not an edge case: almost nothing has been recorded.
  /// Such a resource still appears in the list, greyed out and disabled —
  /// hiding it would misrepresent the shape of the lesson.
  final String? youtubeId;

  final int? durationSeconds;

  /// Reserved. Parsed, stored, and shown nowhere in v1 — see the class doc.
  final String? description;

  /// Reserved. Parsed, stored, and shown nowhere in v1 — see the class doc.
  final String? transcript;

  // ── Article ────────────────────────────────────────────────────────

  /// Prose with embedded LaTeX, in the corpus dialect: `\(...\)` inline,
  /// `\[...\]` or `$$...$$` for display. A lone `$` is a dollar sign.
  /// Rendered by `ArticleView`, which delegates every inline span to
  /// `FullLatexView` so articles and questions cannot disagree about what
  /// a string means.
  final String body;

  // ── Exercise ───────────────────────────────────────────────────────

  /// How many questions to serve from the topic's bank. Zero means "use
  /// the default" — see `kDefaultExerciseQuestions`.
  final int questionCount;

  /// Questions an author pinned to this exercise, in order. Empty means
  /// "rotate from the topic's bank", which is the default. At most
  /// [kMaxPinnedQuestions] — one `whereIn` query.
  final List<String> questionIds;

  final ResourceStatus status;

  /// Uid of the admin who authored it in the editor. Null for seeded
  /// content. Audit only — access is decided by the `admin` claim.
  final String? createdBy;

  /// Set on a revision: the id of the published item this draft will
  /// replace when a reviewer approves it (`docs/CONTENT_ROLES.md`). The
  /// published item keeps its id, so students' completion ticks survive.
  final String? revisionOf;

  bool get isRevision => revisionOf != null;

  /// True when the resource can actually be opened.
  ///
  /// A video with no `youtubeId` and an article with no `body` are both
  /// placeholders. This is read from the data rather than assumed, so a
  /// row turns real the moment content is seeded, with no code change.
  bool get isAvailable => switch (type) {
    LearnResourceType.video => (youtubeId ?? '').trim().isNotEmpty,
    LearnResourceType.article => body.trim().isNotEmpty,
    LearnResourceType.exercise => true,
    LearnResourceType.unknown => false,
  };

  factory LearnResource.fromFirestore(DocumentSnapshot doc) {
    final d = docData(doc);
    return LearnResource(
      id: doc.id,
      type: LearnResourceType.parse(d['type']),
      order: asInt(d['order']),
      title: asString(d['title']),
      subjectId: asString(d['subjectId']),
      topicId: asString(d['topicId']),
      origin: asString(d['origin'], fallback: 'authored'),
      youtubeId: asStringOrNull(d['youtubeId']),
      durationSeconds: asIntOrNull(d['durationSeconds']),
      description: asStringOrNull(d['description']),
      transcript: asStringOrNull(d['transcript']),
      body: asString(d['body']),
      questionCount: asInt(d['questionCount']),
      questionIds: asStringList(
        d['questionIds'],
      ).where((id) => id.trim().isNotEmpty).take(kMaxPinnedQuestions).toList(),
      status: ResourceStatus.parse(d['status']),
      createdBy: asStringOrNull(d['createdBy']),
      revisionOf: asStringOrNull(d['revisionOf']),
    );
  }
}

/// How many questions an inline exercise serves when the resource does not
/// say.
///
/// Small on purpose. An exercise is formative practice inside a lesson, not
/// a drill session (20, `learning_repository.dart`) and not the topic test
/// (`kTopicTestQuestions`). Making all three the same number would collapse
/// three different things into one.
const int kDefaultExerciseQuestions = 5;

/// Firestore's `whereIn` limit, so pinned questions load in one query.
const int kMaxPinnedQuestions = 30;
