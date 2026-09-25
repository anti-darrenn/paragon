import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/learn_resource.dart';
import '../models/topic.dart';

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

  /// Creates a new article draft and returns its id.
  ///
  /// The id is a slug of the title, to match the seeder's convention, with
  /// a numeric suffix if that slug is taken in this topic. `notifiedAt`
  /// starts null; `tools/admin/notify_drafts.js` stamps it once the review
  /// email has gone out.
  Future<String> createDraft({
    required String topicId,
    required String subjectId,
    required String uid,
    required String title,
    required int order,
    required String body,
  }) async {
    final id = await _freeSlug(topicId, slugify(title));
    await _resources(topicId).doc(id).set({
      'type': 'article',
      'order': order,
      'title': title.trim(),
      'subjectId': subjectId,
      'topicId': topicId,
      'origin': 'authored',
      'body': body,
      'questionCount': 0,
      'status': 'draft',
      'createdBy': uid,
      'notifiedAt': null,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return id;
  }

  /// Saves edits to an existing article and sets its status.
  ///
  /// `notifiedAt` is left alone, so editing a draft that was already
  /// emailed about does not send a second email.
  Future<void> save({
    required String topicId,
    required String resourceId,
    required String title,
    required int order,
    required String body,
    required ResourceStatus status,
  }) {
    return _resources(topicId).doc(resourceId).update({
      'title': title.trim(),
      'order': order,
      'body': body,
      'status': status.name,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> delete({required String topicId, required String resourceId}) {
    return _resources(topicId).doc(resourceId).delete();
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

/// Every draft in every topic, oldest-updated last. A collection-group
/// query, allowed only by the admin-only `/{path=**}/resources` rule and
/// served by the collection-group `status` index.
final adminDraftsProvider = FutureProvider<List<LearnResource>>((ref) async {
  final snap = await FirebaseFirestore.instance
      .collectionGroup('resources')
      .where('status', isEqualTo: 'draft')
      .get();
  return snap.docs.map(LearnResource.fromFirestore).toList()
    ..sort((a, b) => a.title.compareTo(b.title));
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

/// One topic by id — the editor needs its `subjectId` and name, and
/// nothing else in the app reads a single topic.
final adminTopicProvider = FutureProvider.family<Topic?, String>((
  ref,
  topicId,
) async {
  final snap = await FirebaseFirestore.instance
      .collection('topics')
      .doc(topicId)
      .get();
  return snap.exists ? Topic.fromFirestore(snap) : null;
});
