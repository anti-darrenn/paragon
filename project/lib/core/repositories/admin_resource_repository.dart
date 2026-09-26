import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../learn/youtube_id.dart';
import '../models/learn_resource.dart';
import '../models/question.dart';

/// Writes and admin-only reads for the in-app content editor.
///
/// Every call here is refused by `firestore.rules` unless the signed-in
/// account carries the `admin` custom claim. That rule, not the
/// `/admin` route gate, is the real protection.
///
/// Kept apart from `learn_repository.dart` so no student-facing provider
/// can end up reading drafts by accident.
class AdminResourceRepository {
  const AdminResourceRepository(this._db);
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _resources(String topicId) =>
      _db.collection('topics').doc(topicId).collection('resources');

  /// Creates a new draft and returns its id.
  ///
  /// The id is a slug of the title, to match the seeder's convention, with
  /// a numeric suffix if that slug is taken in this topic. `notifiedAt`
  /// starts null; `tools/admin/notify_drafts.js` stamps it once the review
  /// email has gone out.
  Future<String> createDraft({
    required String topicId,
    required String subjectId,
    required String uid,
    required ResourceDraft draft,
  }) async {
    final id = await _freeSlug(topicId, slugify(draft.title));
    await _resources(topicId).doc(id).set({
      ...draft.toFields(),
      'subjectId': subjectId,
      'topicId': topicId,
      'origin': 'authored',
      'status': 'draft',
      'createdBy': uid,
      'notifiedAt': null,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return id;
  }

  /// Saves edits to an existing resource and sets its status.
  ///
  /// `notifiedAt` is left alone, so editing a draft that was already
  /// emailed about does not send a second email.
  ///
  /// The content as it stood before this save is kept in the resource's
  /// `versions` subcollection, in the same batch, so any edit can be
  /// undone from the studio's history.
  Future<void> save({
    required String topicId,
    required String resourceId,
    required ResourceDraft draft,
    required ResourceStatus status,
    String? savedBy,
  }) async {
    final ref = _resources(topicId).doc(resourceId);
    final before = (await ref.get()).data();
    final batch = _db.batch();
    if (before != null) {
      batch.set(ref.collection('versions').doc(), {
        for (final f in kResourceContentFields)
          if (before.containsKey(f)) f: before[f],
        'status': before['status'],
        'savedAt': FieldValue.serverTimestamp(),
        'savedBy': savedBy,
      });
    }
    batch.update(ref, {
      ...draft.toFields(),
      'status': status.value,
      // Tells `9_seed_resources.js` this resource now belongs to the
      // editor: without it, re-seeding would overwrite an in-app edit —
      // a YouTube link added to a seeded video — with the file's version.
      'editedInApp': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  /// One page of a topic's answerable questions, for pinning to an
  /// exercise. Paged because a topic can hold 350: loading them all to
  /// pick five would spend the read quota on a scroll. Uses the existing
  /// `topicId + hasAnswer + __name__` index.
  Future<List<Question>> questionPage({
    required String topicId,
    String? startAfterId,
    int limit = 20,
  }) async {
    Query<Map<String, dynamic>> q = _db
        .collection('questions')
        .where('topicId', isEqualTo: topicId)
        .where('hasAnswer', isEqualTo: true)
        .orderBy(FieldPath.documentId)
        .limit(limit);
    if (startAfterId != null) q = q.startAfter([startAfterId]);
    final snap = await q.get();
    return snap.docs.map(Question.fromFirestore).toList();
  }

  Future<void> delete({required String topicId, required String resourceId}) {
    return _resources(topicId).doc(resourceId).delete();
  }

  /// Recounts the topic's published, openable items into
  /// `topics/{id}.lessonCount` — the denominator of "2 of 6 lessons" on the
  /// course index. Called after every save and delete; writes only when
  /// the number changed. One small query per call.
  Future<void> refreshLessonCount(String topicId) async {
    final snap = await _resources(
      topicId,
    ).where('status', isEqualTo: 'published').get();
    final count = snap.docs
        .map(LearnResource.fromFirestore)
        .where((r) => r.isAvailable)
        .length;
    final topic = _db.collection('topics').doc(topicId);
    final current = (await topic.get()).data()?['lessonCount'];
    if (current == count) return;
    await topic.update({'lessonCount': count});
  }

  Future<String> _freeSlug(String topicId, String base) async {
    final stem = base.isEmpty ? 'article' : base;
    var candidate = stem;
    for (var n = 2; ; n++) {
      final snap = await _resources(topicId).doc(candidate).get();
      if (!snap.exists) return candidate;
      candidate = '$stem-$n';
    }
  }
}

/// The fields that make up a resource's content — what a version keeps
/// and what approving a revision copies into the published item. Exactly
/// the keys [ResourceDraft.toFields] writes; `order` is included for
/// versions but never copied by a revision (the published item keeps its
/// place).
const kResourceContentFields = [
  'type',
  'title',
  'order',
  'body',
  'youtubeId',
  'durationSeconds',
  'description',
  'transcript',
  'questionCount',
  'questionIds',
];

/// What the editor's form holds for one resource, before it is saved.
///
/// Pure, so the rules for what may be published are testable without a
/// widget: [validate] names the first problem, [toFields] is the exact
/// document content. Fields belonging to other types are written empty,
/// so changing nothing here can leave a stale `youtubeId` on an article.
class ResourceDraft {
  const ResourceDraft({
    required this.type,
    required this.title,
    required this.orderText,
    this.body = '',
    this.youtubeText = '',
    this.durationText = '',
    this.description = '',
    this.transcript = '',
    this.questionCountText = '',
    this.questionIds = const [],
  });

  static const int maxQuestionCount = 20;

  final LearnResourceType type;
  final String title;
  final String orderText;
  final String body;
  final String youtubeText;
  final String durationText;
  final String description;
  final String transcript;
  final String questionCountText;
  final List<String> questionIds;

  String? get youtubeId => parseYouTubeId(youtubeText);

  String get noun => type.label.toLowerCase();

  String? validate() {
    if (title.trim().isEmpty) return 'Give the $noun a title.';
    if (int.tryParse(orderText.trim()) == null) {
      return 'Position must be a whole number.';
    }
    switch (type) {
      case LearnResourceType.article:
        if (body.trim().isEmpty) return 'The article has no body.';
      case LearnResourceType.video:
        if (youtubeText.trim().isEmpty) return 'Paste the YouTube link.';
        if (youtubeId == null) {
          return "That doesn't look like a YouTube video link.";
        }
        if (durationText.trim().isNotEmpty &&
            parseDuration(durationText) == null) {
          return 'Duration should look like 9:30 or 1:05:00.';
        }
      case LearnResourceType.exercise:
        final n = int.tryParse(questionCountText.trim());
        if (questionIds.isEmpty &&
            (n == null || n < 1 || n > maxQuestionCount)) {
          return 'Number of questions must be 1 to $maxQuestionCount.';
        }
        if (questionIds.length > kMaxPinnedQuestions) {
          return 'Pin at most $kMaxPinnedQuestions questions.';
        }
      case LearnResourceType.unknown:
        return "This resource's type isn't recognised.";
    }
    return null;
  }

  /// Call only after [validate] returns null.
  Map<String, Object?> toFields() {
    final isVideo = type == LearnResourceType.video;
    final isExercise = type == LearnResourceType.exercise;
    String? optional(String s) => s.trim().isEmpty ? null : s.trim();
    return {
      'type': type.name,
      'title': title.trim(),
      'order': int.parse(orderText.trim()),
      'body': type == LearnResourceType.article ? body : '',
      'youtubeId': isVideo ? youtubeId : null,
      'durationSeconds': isVideo ? parseDuration(durationText) : null,
      'description': isVideo ? optional(description) : null,
      'transcript': isVideo ? optional(transcript) : null,
      'questionCount': isExercise
          ? (questionIds.isNotEmpty
                ? questionIds.length
                : int.parse(questionCountText.trim()))
          : 0,
      'questionIds': isExercise ? questionIds : const <String>[],
    };
  }
}

/// `9:30` → 570, `1:05:00` → 3900, `45` → 45. Null for anything else.
int? parseDuration(String text) {
  final parts = text.trim().split(':');
  if (parts.isEmpty || parts.length > 3 || parts.first.isEmpty) return null;
  final numbers = parts.map(int.tryParse).toList();
  if (numbers.any((n) => n == null || n < 0)) return null;
  if (parts.length > 1 && numbers.skip(1).any((n) => n! > 59)) return null;
  return numbers.fold<int>(0, (total, n) => total * 60 + n!);
}

/// Lower-case, ASCII letters and digits, hyphen-separated, at most 60
/// characters. Matches the shape of the seeder's filename-derived ids.
String slugify(String input) {
  final slug = input
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  if (slug.length <= 60) return slug;
  return slug.substring(0, 60).replaceAll(RegExp(r'-+$'), '');
}

final adminResourceRepositoryProvider = Provider<AdminResourceRepository>((
  ref,
) {
  return AdminResourceRepository(FirebaseFirestore.instance);
});

/// Every resource in a topic, drafts included. Admin-only: a non-admin
/// running this unfiltered query is refused by the rules.
final adminTopicResourcesProvider =
    FutureProvider.family<List<LearnResource>, String>((ref, topicId) async {
      final snap = await FirebaseFirestore.instance
          .collection('topics')
          .doc(topicId)
          .collection('resources')
          .orderBy('order')
          .get();
      final resources = snap.docs.map(LearnResource.fromFirestore).toList();
      resources.sort((a, b) {
        final byOrder = a.order.compareTo(b.order);
        return byOrder != 0 ? byOrder : a.id.compareTo(b.id);
      });
      return resources;
    });

/// Every item in one workflow state, across all topics: the studio's
/// review queue (`in_review`) and "sent back" list (`changes_requested`).
/// A collection-group query, allowed by the staff-only
/// `/{path=**}/resources` rule and served by the collection-group
/// `status` index. Sorted by title.
final adminStatusQueueProvider =
    FutureProvider.family<List<LearnResource>, ResourceStatus>((
      ref,
      status,
    ) async {
      final snap = await FirebaseFirestore.instance
          .collectionGroup('resources')
          .where('status', isEqualTo: status.value)
          .get();
      return snap.docs.map(LearnResource.fromFirestore).toList()
        ..sort((a, b) => a.title.compareTo(b.title));
    });

/// Every lesson item in one subject, any status: the course map's source.
/// One collection-group query per subject opened (served by the
/// collection-group `subjectId` override), rather than one per topic.
final adminSubjectResourcesProvider =
    FutureProvider.family<List<LearnResource>, String>((ref, subjectId) async {
      final snap = await FirebaseFirestore.instance
          .collectionGroup('resources')
          .where('subjectId', isEqualTo: subjectId)
          .get();
      return snap.docs.map(LearnResource.fromFirestore).toList();
    });

/// Key for [adminResourceProvider]: a resource lives under its topic, so
/// its id alone does not locate it.
typedef ResourceKey = ({String topicId, String resourceId});

final adminResourceProvider =
    FutureProvider.family<LearnResource?, ResourceKey>((ref, key) async {
      final snap = await FirebaseFirestore.instance
          .collection('topics')
          .doc(key.topicId)
          .collection('resources')
          .doc(key.resourceId)
          .get();
      return snap.exists ? LearnResource.fromFirestore(snap) : null;
    });
