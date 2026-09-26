import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/firestore_parsing.dart';
import '../models/learn_resource.dart';
import 'admin_resource_repository.dart';

/// The review workflow for lesson items: submit, request changes, approve,
/// unpublish, revisions, comments and version history.
///
/// The contract is `docs/CONTENT_ROLES.md`, and `firestore.rules` enforces
/// it: nothing here is trusted to keep a writer from publishing. What this
/// class guarantees is that every transition is **one batch** — status,
/// who did it, and the note for the email job move together.
///
/// **Emails.** Each transition that someone should hear about sets
/// `pendingNotice` to the new status. `tools/admin/notify_drafts.js` sends
/// the email and clears it, so each transition is emailed exactly once and
/// a failed send is retried. `submittedBy` records whose work it is, so a
/// verdict reaches the writer.
class LessonWorkflow {
  const LessonWorkflow(this._db);
  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _doc(String topicId, String id) =>
      _db.collection('topics').doc(topicId).collection('resources').doc(id);

  /// Writer → reviewers: "this is ready".
  Future<void> submitForReview(LearnResource r, {required String uid}) =>
      _doc(r.topicId, r.id).update({
        'status': ResourceStatus.inReview.value,
        'submittedBy': uid,
        'submittedAt': FieldValue.serverTimestamp(),
        'pendingNotice': ResourceStatus.inReview.value,
        'updatedAt': FieldValue.serverTimestamp(),
      });

  /// Reviewer → writer: "not yet". The reason goes in a comment, which is
  /// written in the same batch so the writer never gets a verdict without it.
  Future<void> requestChanges(
    LearnResource r, {
    required String uid,
    required String authorName,
    required String reason,
  }) async {
    final ref = _doc(r.topicId, r.id);
    final batch = _db.batch()
      ..update(ref, {
        'status': ResourceStatus.changesRequested.value,
        'reviewedBy': uid,
        'reviewedAt': FieldValue.serverTimestamp(),
        'pendingNotice': ResourceStatus.changesRequested.value,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    if (reason.trim().isNotEmpty) {
      batch.set(
        ref.collection('comments').doc(),
        _comment(uid, authorName, reason),
      );
    }
    await batch.commit();
  }

  /// Reviewer: publish. For a revision, its content is copied into the
  /// published original — which keeps its id, and so every student's
  /// completion tick — the original's old content goes to its history,
  /// and the revision is deleted. Returns the id that is now live.
  Future<String> approve(LearnResource r, {required String uid}) async {
    final original = r.revisionOf;
    if (original == null) {
      await _doc(r.topicId, r.id).update({
        'status': ResourceStatus.published.value,
        'reviewedBy': uid,
        'reviewedAt': FieldValue.serverTimestamp(),
        'pendingNotice': ResourceStatus.published.value,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return r.id;
    }

    final revRef = _doc(r.topicId, r.id);
    final origRef = _doc(r.topicId, original);
    final rev = (await revRef.get()).data() ?? const {};
    final orig = (await origRef.get()).data();
    if (orig == null) {
      // The original was deleted while the revision was in review: publish
      // the revision as an item in its own right rather than lose it.
      await revRef.update({
        'status': ResourceStatus.published.value,
        'revisionOf': FieldValue.delete(),
        'reviewedBy': uid,
        'reviewedAt': FieldValue.serverTimestamp(),
        'pendingNotice': ResourceStatus.published.value,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return r.id;
    }

    final batch = _db.batch()
      ..set(origRef.collection('versions').doc(), {
        for (final f in kResourceContentFields)
          if (orig.containsKey(f)) f: orig[f],
        'status': orig['status'],
        'savedAt': FieldValue.serverTimestamp(),
        'savedBy': uid,
        'replacedByRevision': r.id,
      })
      ..update(origRef, {
        for (final f in kResourceContentFields)
          if (f != 'order' && rev.containsKey(f)) f: rev[f],
        'status': ResourceStatus.published.value,
        'editedInApp': true,
        'reviewedBy': uid,
        'reviewedAt': FieldValue.serverTimestamp(),
        'submittedBy': rev['submittedBy'] ?? rev['createdBy'],
        'pendingNotice': ResourceStatus.published.value,
        'updatedAt': FieldValue.serverTimestamp(),
      })
      ..delete(revRef);
    await batch.commit();
    return original;
  }

  /// Reviewer: take a published item down. Back to draft, no email.
  Future<void> unpublish(LearnResource r, {required String uid}) =>
      _doc(r.topicId, r.id).update({
        'status': ResourceStatus.draft.value,
        'reviewedBy': uid,
        'reviewedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

  /// Anyone on the team: a draft copy of a published item to edit and
  /// submit, because a published item is never edited in place — every
  /// keystroke would go live. Returns the revision's id. If a revision is
  /// already open for [published], returns that one instead of a second.
  Future<String> startRevision(
    LearnResource published, {
    required String uid,
  }) async {
    final col = _db
        .collection('topics')
        .doc(published.topicId)
        .collection('resources');
    final open = await col
        .where('revisionOf', isEqualTo: published.id)
        .limit(1)
        .get();
    if (open.docs.isNotEmpty) return open.docs.first.id;

    final source = (await col.doc(published.id).get()).data() ?? const {};
    final id = await _freeId(published.topicId, '${published.id}-revision');
    await col.doc(id).set({
      for (final f in kResourceContentFields)
        if (source.containsKey(f)) f: source[f],
      'subjectId': published.subjectId,
      'topicId': published.topicId,
      'origin': 'authored',
      'status': ResourceStatus.draft.value,
      'revisionOf': published.id,
      'createdBy': uid,
      'notifiedAt': null,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return id;
  }

  /// Puts an older version's content back, keeping the current content as
  /// a version of its own (so a restore can itself be undone). The status
  /// is unchanged — restoring on a published item is a reviewer's action,
  /// and the rules say so.
  Future<void> restoreVersion(
    LearnResource r,
    ResourceVersion version, {
    required String uid,
  }) async {
    final ref = _doc(r.topicId, r.id);
    final current = (await ref.get()).data() ?? const {};
    final batch = _db.batch()
      ..set(ref.collection('versions').doc(), {
        for (final f in kResourceContentFields)
          if (current.containsKey(f)) f: current[f],
        'status': current['status'],
        'savedAt': FieldValue.serverTimestamp(),
        'savedBy': uid,
      })
      ..update(ref, {
        for (final e in version.content.entries)
          if (e.key != 'order') e.key: e.value,
        'editedInApp': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    await batch.commit();
  }

  Future<void> addComment(
    LearnResource r, {
    required String uid,
    required String authorName,
    required String text,
  }) => _doc(
    r.topicId,
    r.id,
  ).collection('comments').add(_comment(uid, authorName, text));

  Future<void> setCommentResolved(
    LearnResource r,
    String commentId, {
    required bool resolved,
  }) => _doc(
    r.topicId,
    r.id,
  ).collection('comments').doc(commentId).update({'resolved': resolved});

  Map<String, Object?> _comment(String uid, String name, String text) => {
    'authorUid': uid,
    'authorName': name,
    'text': text.trim(),
    'resolved': false,
    'createdAt': FieldValue.serverTimestamp(),
  };

  Future<String> _freeId(String topicId, String base) async {
    var candidate = base;
    for (var n = 2; ; n++) {
      final snap = await _doc(topicId, candidate).get();
      if (!snap.exists) return candidate;
      candidate = '$base-$n';
    }
  }
}

/// One saved state of a resource's content.
class ResourceVersion {
  const ResourceVersion({
    required this.id,
    required this.content,
    this.status,
    this.savedAt,
    this.savedBy,
  });

  final String id;

  /// Only the [kResourceContentFields] present in the version.
  final Map<String, Object?> content;
  final ResourceStatus? status;
  final DateTime? savedAt;
  final String? savedBy;

  String get title => asString(content['title']);
  String get body => asString(content['body']);

  factory ResourceVersion.fromFirestore(DocumentSnapshot doc) {
    final d = docData(doc);
    final at = d['savedAt'];
    return ResourceVersion(
      id: doc.id,
      content: {
        for (final f in kResourceContentFields)
          if (d.containsKey(f)) f: d[f],
      },
      status: d.containsKey('status')
          ? ResourceStatus.parse(d['status'])
          : null,
      savedAt: at is Timestamp ? at.toDate() : null,
      savedBy: asStringOrNull(d['savedBy']),
    );
  }
}

class ReviewComment {
  const ReviewComment({
    required this.id,
    required this.authorUid,
    required this.authorName,
    required this.text,
    required this.resolved,
    this.createdAt,
  });

  final String id;
  final String authorUid;
  final String authorName;
  final String text;
  final bool resolved;
  final DateTime? createdAt;

  factory ReviewComment.fromFirestore(DocumentSnapshot doc) {
    final d = docData(doc);
    final at = d['createdAt'];
    return ReviewComment(
      id: doc.id,
      authorUid: asString(d['authorUid']),
      authorName: asString(d['authorName'], fallback: 'Someone'),
      text: asString(d['text']),
      resolved: asBool(d['resolved']),
      createdAt: at is Timestamp ? at.toDate() : null,
    );
  }
}

final lessonWorkflowProvider = Provider<LessonWorkflow>((ref) {
  return LessonWorkflow(FirebaseFirestore.instance);
});

/// A resource's saved versions, newest first.
final resourceVersionsProvider =
    FutureProvider.family<List<ResourceVersion>, ResourceKey>((ref, key) async {
      final snap = await FirebaseFirestore.instance
          .collection('topics')
          .doc(key.topicId)
          .collection('resources')
          .doc(key.resourceId)
          .collection('versions')
          .orderBy('savedAt', descending: true)
          .limit(50)
          .get();
      return snap.docs.map(ResourceVersion.fromFirestore).toList();
    });

/// A resource's review thread, oldest first, live.
final resourceCommentsProvider =
    StreamProvider.family<List<ReviewComment>, ResourceKey>((ref, key) {
      return FirebaseFirestore.instance
          .collection('topics')
          .doc(key.topicId)
          .collection('resources')
          .doc(key.resourceId)
          .collection('comments')
          .orderBy('createdAt')
          .snapshots()
          .map((s) => s.docs.map(ReviewComment.fromFirestore).toList());
    });
