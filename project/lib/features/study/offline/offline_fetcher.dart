import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/learn_resource.dart';
import 'offline_plan.dart';

/// The server reads that fill Firestore's persistent cache for a topic.
///
/// Behind an interface so the save button can be tested without Firestore.
/// Every read is `Source.server`: the point is to *put* documents in the
/// cache, and a cache hit would put nothing there — nor prove the device
/// is online.
abstract class OfflineFetcher {
  /// The topic's published resources.
  Future<List<LearnResource>> resources(String topicId);

  /// Fetches each `lessonAssets/{id}`; returns how many were saved.
  Future<int> assets(List<String> ids);

  /// Fetches bank questions by id; returns how many were saved.
  Future<int> questions(List<String> ids);

  /// Fetches up to [limit] of the topic's answerable questions; returns
  /// how many were saved.
  Future<int> topicQuestions(String topicId, int limit);
}

class FirestoreOfflineFetcher implements OfflineFetcher {
  FirestoreOfflineFetcher(this._db);

  final FirebaseFirestore _db;

  static const _server = GetOptions(source: Source.server);

  /// The exact query `topicResourcesProvider` runs — the `status` filter is
  /// what the rules require of a student's list — so the cached results
  /// are the ones that provider finds offline.
  @override
  Future<List<LearnResource>> resources(String topicId) async {
    final snap = await _db
        .collection('topics')
        .doc(topicId)
        .collection('resources')
        .where('status', isEqualTo: 'published')
        .orderBy('order')
        .get(_server);
    return snap.docs
        .map(LearnResource.fromFirestore)
        .where((r) => r.type != LearnResourceType.unknown)
        .toList();
  }

  /// One `get` per asset, the read `lessonAssetProvider` makes. A missing
  /// or refused asset is skipped, not fatal: the lesson still reads, and
  /// its figure says the image is unavailable.
  @override
  Future<int> assets(List<String> ids) async {
    var saved = 0;
    for (final id in ids) {
      try {
        final doc = await _db.collection('lessonAssets').doc(id).get(_server);
        if (doc.exists) saved++;
      } catch (_) {}
    }
    return saved;
  }

  /// `whereIn` over document ids, as `pinnedQuestionsProvider` reads them,
  /// in chunks of 30 (Firestore's `whereIn` limit).
  @override
  Future<int> questions(List<String> ids) async {
    var saved = 0;
    for (var i = 0; i < ids.length; i += 30) {
      final chunk = ids.sublist(i, i + 30 > ids.length ? ids.length : i + 30);
      final snap = await _db
          .collection('questions')
          .where(FieldPath.documentId, whereIn: chunk)
          .get(_server);
      saved += snap.docs.length;
    }
    return saved;
  }

  /// The base query of `_rotatedTopicQuestions` in `learn_repository.dart`
  /// (`topicId` + `hasAnswer`, ordered by document id — its existing
  /// index), without the random cursor: offline, the exercise and test
  /// queries rotate over whatever of this set is cached.
  @override
  Future<int> topicQuestions(String topicId, int limit) async {
    final snap = await _db
        .collection('questions')
        .where('topicId', isEqualTo: topicId)
        .where('hasAnswer', isEqualTo: true)
        .orderBy(FieldPath.documentId)
        .limit(limit)
        .get(_server);
    return snap.docs.length;
  }
}

final offlineFetcherProvider = Provider<OfflineFetcher>(
  (ref) => FirestoreOfflineFetcher(FirebaseFirestore.instance),
);

/// The result of one save.
class OfflineSaveResult {
  const OfflineSaveResult({
    required this.itemCount,
    required this.videoCount,
    required this.missingAssets,
  });

  final int itemCount;
  final int videoCount;

  /// Figures that could not be fetched (deleted, or refused).
  final int missingAssets;
}

/// The steps of a save, for the progress bar.
const int kOfflineSaveSteps = 4;

/// Saves one topic: resources first (the plan depends on them), then their
/// figures and pinned questions, then a set of the topic's own questions.
/// [onStep] is called with 1..[kOfflineSaveSteps] as each step finishes.
///
/// Throws if the resources or questions cannot be fetched — typically
/// because the device is offline. A missing figure does not throw.
Future<OfflineSaveResult> saveTopicForOffline(
  OfflineFetcher fetcher,
  String topicId, {
  void Function(int step)? onStep,
}) async {
  final resources = await fetcher.resources(topicId);
  onStep?.call(1);
  final plan = planOfflinePrefetch(resources);

  final assets = await fetcher.assets(plan.assetIds);
  onStep?.call(2);
  final pinned = await fetcher.questions(plan.questionIds);
  onStep?.call(3);
  final own = await fetcher.topicQuestions(topicId, kOfflineTopicQuestions);
  onStep?.call(4);

  return OfflineSaveResult(
    itemCount: resources.length + assets + pinned + own,
    videoCount: plan.videoCount,
    missingAssets: plan.assetIds.length - assets,
  );
}
