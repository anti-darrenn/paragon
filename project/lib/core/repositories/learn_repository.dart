import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/learn_resource.dart';
import '../models/question.dart';

/// Learn mode's reads: a topic's ordered resource list, and the question
/// sets that the inline exercises and the topic test serve.
///
/// Separate from `learning_repository.dart` rather than added to it. That
/// file is the Subject/Unit/Topic/Drill/WAEC read model and is already
/// long; Learn mode is a distinct surface with its own collection and its
/// own question-selection rules, and keeping them apart is what stops
/// somebody wiring a Learn provider into a drill screen by accident — the
/// mode separation CLAUDE.md is emphatic about.
final _firestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

/// A topic's Learn sequence, in author order.
///
/// One query, no composite index — `orderBy('order')` inside a
/// subcollection is served by the automatic single-field index. Resources
/// whose `type` this build does not recognise are dropped here rather than
/// in every widget that lists them, so an older client seeing a newer
/// resource type shows a shorter list instead of a broken row.
///
/// Ties on `order` are broken by document id, so the sequence is stable
/// across reads even when an author gives two resources the same number.
final topicResourcesProvider =
    FutureProvider.family<List<LearnResource>, String>((ref, topicId) async {
      final db = ref.read(_firestoreProvider);
      final snap = await db
          .collection('topics')
          .doc(topicId)
          .collection('resources')
          .orderBy('order')
          .get();

      final resources = snap.docs
          .map((d) => LearnResource.fromFirestore(d))
          .where((r) => r.type != LearnResourceType.unknown)
          .toList();

      resources.sort((a, b) {
        final byOrder = a.order.compareTo(b.order);
        return byOrder != 0 ? byOrder : a.id.compareTo(b.id);
      });
      return resources;
    });

// ─── Question selection ───────────────────────────────────────────────

/// How many questions one topic test serves.
///
/// Named rather than inlined because it is the number most likely to need
/// tuning: too low and the 80% threshold quantises badly (on 10 questions
/// it means 8, and there is no way to score 85%), too high and a retake is
/// a chore. A topic with a smaller bank serves its whole bank —
/// `min(kTopicTestQuestions, bank size)`.
const int kTopicTestQuestions = 10;

// The pass mark and the scoring live in `lib/core/learn/topic_test.dart`,
// with the gate they feed — deliberately not here. This file decides which
// questions a test serves; it has no opinion about what passing one means.

/// Firestore auto-ID alphabet, for synthesising a random cursor over
/// `FieldPath.documentId` — the same rotation trick `drillQuestionsProvider`
/// uses, and for the same reason: there is no random field on a question to
/// order by, but the ids are themselves random strings, so a random start
/// point samples the bank without a new index or a stored field.
const _autoIdAlphabet =
    '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz';

String _randomAutoId(Random random) {
  return List.generate(
    20,
    (_) => _autoIdAlphabet[random.nextInt(_autoIdAlphabet.length)],
  ).join();
}

/// Fetches up to [limit] questions for [topicId], rotated so repeat visits
/// do not serve the same fixed subset.
///
/// Shared by the topic test and the inline exercises. Both filter on
/// `hasAnswer` — a question with no verified answer can never be marked
/// correct, and on the topic test that would mean a question a student
/// cannot pass. Uses the existing `topicId + hasAnswer + __name__` index;
/// no new index.
///
/// Wraps to the start of the id range when the random cursor lands near
/// the end, filtering out ids the forward query already returned, so a
/// topic whose bank is close to [limit] cannot serve the same question
/// twice in one set.
Future<List<Question>> _rotatedTopicQuestions(
  FirebaseFirestore db,
  String topicId,
  int limit,
) async {
  if (limit <= 0) return const [];

  final base = db
      .collection('questions')
      .where('topicId', isEqualTo: topicId)
      .where('hasAnswer', isEqualTo: true);

  final forward = await base
      .orderBy(FieldPath.documentId)
      .startAt([_randomAutoId(Random())])
      .limit(limit)
      .get();

  var docs = forward.docs;
  if (docs.length < limit) {
    final seen = docs.map((d) => d.id).toSet();
    final wrap = await base.orderBy(FieldPath.documentId).limit(limit).get();
    docs = [
      ...docs,
      ...wrap.docs.where((d) => !seen.contains(d.id)).take(limit - docs.length),
    ];
  }

  final shuffled = docs.toList()..shuffle();
  return shuffled.map((d) => Question.fromFirestore(d)).toList();
}

/// One topic test's questions — a fresh random subset per attempt, since
/// retakes are unlimited and a fixed set would be a memory test.
final topicTestQuestionsProvider =
    FutureProvider.family<List<Question>, String>((ref, topicId) async {
      return _rotatedTopicQuestions(
        ref.read(_firestoreProvider),
        topicId,
        kTopicTestQuestions,
      );
    });

/// Family key for [exerciseQuestionsProvider]. A resource id alone is not
/// enough — the questions come from the *topic's* bank, and the resource
/// only says how many.
class ExerciseQuery {
  const ExerciseQuery({
    required this.topicId,
    required this.resourceId,
    required this.questionCount,
  });

  final String topicId;
  final String resourceId;
  final int questionCount;

  @override
  bool operator ==(Object other) =>
      other is ExerciseQuery &&
      other.topicId == topicId &&
      other.resourceId == resourceId &&
      other.questionCount == questionCount;

  @override
  int get hashCode => Object.hash(topicId, resourceId, questionCount);
}

/// Questions for one inline exercise.
///
/// Keyed by resource id as well as topic so two exercises in the same
/// topic get their own cached sets rather than sharing one — otherwise
/// walking the sequence would show the student the same five questions
/// twice under two different headings.
final exerciseQuestionsProvider =
    FutureProvider.family<List<Question>, ExerciseQuery>((ref, query) async {
      final count = query.questionCount > 0
          ? query.questionCount
          : kDefaultExerciseQuestions;
      return _rotatedTopicQuestions(
        ref.read(_firestoreProvider),
        query.topicId,
        count,
      );
    });
