import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../lessons/subject_index.dart';
import '../models/learn_resource.dart';

/// Writes and reads `subjectIndex/{subjectId}`; see [SubjectIndex].
///
/// Writes are reviewer-only in the rules. The studio calls [rebuildTopic]
/// after every publish, unpublish, revision approval and delete, so the
/// index follows exactly what students can see.
class SubjectIndexRepository {
  const SubjectIndexRepository(this._db);
  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _doc(String subjectId) =>
      _db.collection('subjectIndex').doc(subjectId);

  /// Re-extracts one topic from its published lessons and replaces its
  /// entry. The entry is kept even when nothing is published, since the
  /// topic's name is still what search finds. One small query plus one
  /// write.
  Future<void> rebuildTopic({
    required String subjectId,
    required String topicId,
    required String topicName,
  }) async {
    final snap = await _db
        .collection('topics')
        .doc(topicId)
        .collection('resources')
        .where('status', isEqualTo: 'published')
        .orderBy('order')
        .get();
    final entry = _entry(
      topicId,
      topicName,
      snap.docs.map(LearnResource.fromFirestore),
    );
    await _doc(subjectId).set({
      'topics': {topicId: entry.toMap()},
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Rebuilds a whole subject from scratch: one collection-group query for
  /// its published lessons, one write. For "Rebuild index" in the studio.
  /// [topicNames] maps topic id to name and should hold **every** topic
  /// of the subject: each one gets an entry, published lessons or not, so
  /// search can find it. A topic with lessons but missing from the map
  /// keeps its id as the name.
  Future<void> rebuildSubject({
    required String subjectId,
    required Map<String, String> topicNames,
  }) async {
    final snap = await _db
        .collectionGroup('resources')
        .where('subjectId', isEqualTo: subjectId)
        .where('status', isEqualTo: 'published')
        .get();
    final byTopic = <String, List<LearnResource>>{};
    for (final d in snap.docs) {
      final r = LearnResource.fromFirestore(d);
      byTopic.putIfAbsent(r.topicId, () => []).add(r);
    }
    final topics = <String, Object?>{};
    for (final topicId in {...topicNames.keys, ...byTopic.keys}) {
      final resources = byTopic[topicId] ?? <LearnResource>[]
        ..sort((a, b) => a.order.compareTo(b.order));
      topics[topicId] = _entry(
        topicId,
        topicNames[topicId] ?? topicId,
        resources,
      ).toMap();
    }
    // Not a merge: a full rebuild must also drop topics that have since
    // been deleted.
    await _doc(
      subjectId,
    ).set({'topics': topics, 'updatedAt': FieldValue.serverTimestamp()});
  }

  TopicIndex _entry(
    String topicId,
    String name,
    Iterable<LearnResource> resources,
  ) => extractTopicIndex(
    topicId: topicId,
    topicName: name,
    articles: [
      for (final r in resources)
        if (r.type == LearnResourceType.article && r.status.isLive)
          (r.id, r.body),
    ],
    lessons: [
      for (final r in resources)
        if (r.status.isLive && r.isAvailable)
          IndexedLesson(id: r.id, title: r.title, type: r.type.name),
    ],
  );
}

final subjectIndexRepositoryProvider = Provider<SubjectIndexRepository>((ref) {
  return SubjectIndexRepository(FirebaseFirestore.instance);
});

/// A subject's glossary, formulas and cards. [SubjectIndex.empty] when no
/// lesson in the subject has been published yet.
final subjectIndexProvider = FutureProvider.family<SubjectIndex, String>((
  ref,
  subjectId,
) async {
  final doc = await FirebaseFirestore.instance
      .collection('subjectIndex')
      .doc(subjectId)
      .get();
  return doc.exists ? SubjectIndex.fromFirestore(doc) : SubjectIndex.empty;
});
