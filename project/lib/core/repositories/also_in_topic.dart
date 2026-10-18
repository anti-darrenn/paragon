import 'package:cloud_firestore/cloud_firestore.dart';

import '../data/read_meter.dart';
import '../models/question.dart';
import '../questions/servable.dart';

/// Up to [limit] answerable questions that list [topicId] in
/// `alsoTopicIds` (a second topic they count for), in random order. One
/// small query, served by the `alsoTopicIds + hasAnswer` index; almost
/// always empty, and then it costs a single read.
Future<List<Question>> alsoInTopic(
  FirebaseFirestore db,
  String topicId,
  int limit,
) async {
  if (limit <= 0) return const [];
  try {
    final snap = await db
        .collection('questions')
        .where('alsoTopicIds', arrayContains: topicId)
        .servable()
        .limit(limit * 3)
        .get()
        .metered();
    final list = [for (final d in snap.docs) Question.fromFirestore(d)]
      ..shuffle();
    return list.take(limit).toList();
  } on FirebaseException {
    // The index not built yet, or offline: the topic's own questions are
    // still a full session.
    return const [];
  }
}

/// A session of [size]: the topic's own [primary] questions, with [also]
/// (questions that also count for it) taking the last places. Never the
/// same question twice, and never more than [size].
List<Question> mergeAlso(
  List<Question> primary,
  List<Question> also,
  int size,
) {
  final alsoIds = {for (final q in also) q.id};
  final own = [
    for (final q in primary)
      if (!alsoIds.contains(q.id)) q,
  ];
  final extra = also.take(size).toList();
  return [...own.take(size - extra.length), ...extra];
}
