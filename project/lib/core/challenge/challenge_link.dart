import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/read_meter.dart';
import '../models/firestore_parsing.dart';
import '../models/question.dart';

/// "Challenge a friend": a student shares the questions they just did as a
/// link (`/c/:id`); a friend opens it — as a guest if they like — answers
/// the same questions, and sees both scores. The WhatsApp loop in place of
/// study buddies (launch plan phase 2).
///
/// `challenges/{id}`: `{userId, name, subjectId, topicId, topicName,
/// questionIds, score, total, createdAt}`. Written once, never edited.
/// Any signed-in user (guests included) may *get* one by id; only its
/// creator may list or delete theirs. `name` is the creator's first name,
/// which is all the friend sees of them. Deleted after 30 days by
/// `jobs.js --job=challenges`, and with the creator's account.
///
/// A friend's answers are recorded as `source: 'challenge_link'` attempts.
/// Like every non-drill source, they never reach `progress` — a challenge
/// must not be a way around the topic test.
class ChallengeLink {
  const ChallengeLink({
    required this.id,
    required this.userId,
    required this.name,
    required this.subjectId,
    required this.topicId,
    required this.topicName,
    required this.questionIds,
    required this.score,
    required this.total,
    this.createdAt,
  });

  final String id;
  final String userId;
  final String name;
  final String subjectId;
  final String topicId;
  final String topicName;
  final List<String> questionIds;
  final int score;
  final int total;
  final DateTime? createdAt;

  /// At most this many questions: one `whereIn` query to load them.
  static const int maxQuestions = 10;

  factory ChallengeLink.fromFirestore(DocumentSnapshot doc) {
    final d = docData(doc);
    final created = d['createdAt'];
    return ChallengeLink(
      id: doc.id,
      userId: asString(d['userId']),
      name: asString(d['name'], fallback: 'A friend'),
      subjectId: asString(d['subjectId']),
      topicId: asString(d['topicId']),
      topicName: asString(d['topicName']),
      questionIds: asStringList(d['questionIds']),
      score: asInt(d['score']),
      total: asInt(d['total']),
      createdAt: created is Timestamp ? created.toDate() : null,
    );
  }
}

/// What the challenger is called: the first word of their display name,
/// trimmed to 30 characters, or "A friend". Never a surname, an email or
/// a username — the link travels to people they may not know.
String challengerName(String? displayName) {
  final first = (displayName ?? '').trim().split(RegExp(r'\s+')).first;
  if (first.isEmpty || first.contains('@')) return 'A friend';
  return first.length > 30 ? first.substring(0, 30) : first;
}

/// The questions and outcomes of a finished session to challenge with:
/// the first [ChallengeLink.maxQuestions] answered ones.
({List<String> ids, int score}) challengeFrom(
  List<({String questionId, bool correct})> answered,
) {
  final take = answered.take(ChallengeLink.maxQuestions).toList();
  return (
    ids: [for (final a in take) a.questionId],
    score: take.where((a) => a.correct).length,
  );
}

/// "You 7/10 · Ada 8/10", and who is ahead.
String scoreLine({
  required int mine,
  required int theirs,
  required int total,
  required String name,
}) {
  final verdict = mine > theirs
      ? 'You win!'
      : mine == theirs
      ? "It's a draw."
      : '$name wins this one.';
  return 'You $mine/$total · $name $theirs/$total. $verdict';
}

class ChallengeRepository {
  ChallengeRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('challenges');

  /// Writes the challenge and returns its id. The rules pin every field.
  Future<String> create({
    required String uid,
    required String name,
    required String subjectId,
    required String topicId,
    required String topicName,
    required List<String> questionIds,
    required int score,
  }) async {
    final ref = _col.doc();
    await ref.set({
      'userId': uid,
      'name': name,
      'subjectId': subjectId,
      'topicId': topicId,
      'topicName': topicName,
      'questionIds': questionIds,
      'score': score,
      'total': questionIds.length,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  Future<ChallengeLink?> get(String id) async {
    final snap = await _col.doc(id).get().metered();
    return snap.exists ? ChallengeLink.fromFirestore(snap) : null;
  }

  /// The challenge's questions, in its order, answerable ones only.
  Future<List<Question>> questions(ChallengeLink c) async {
    if (c.questionIds.isEmpty) return const [];
    final snap = await _db
        .collection('questions')
        .where(FieldPath.documentId, whereIn: c.questionIds)
        .get()
        .metered();
    final byId = {for (final d in snap.docs) d.id: Question.fromFirestore(d)};
    return [
      for (final id in c.questionIds)
        if (byId[id] case final q? when q.correctIndex >= 0) q,
    ];
  }
}

final challengeRepositoryProvider = Provider<ChallengeRepository>(
  (ref) => ChallengeRepository(FirebaseFirestore.instance),
);

final challengeLinkProvider = FutureProvider.autoDispose
    .family<ChallengeLink?, String>(
      (ref, id) => ref.read(challengeRepositoryProvider).get(id),
    );
