import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/read_meter.dart';
import '../models/firestore_parsing.dart';
import '../models/question.dart';
import '../progress/mistakes.dart';
import '../providers/auth_provider.dart';

/// Reads for the mistakes notebook. See `lib/core/progress/mistakes.dart`
/// for what counts as a mistake.
class MistakesRepository {
  const MistakesRepository(this._db);
  final FirebaseFirestore _db;

  /// The student's latest [limit] attempts, newest first. Served by the
  /// `userId ASC, timestamp DESC` index in `firestore.indexes.json`.
  Future<List<AttemptRecord>> recentAttempts(
    String uid, {
    int limit = kMistakesWindow,
  }) async {
    final snap = await _db
        .collection('attempts')
        .where('userId', isEqualTo: uid)
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .get()
        .metered();
    return [
      for (final doc in snap.docs)
        if (docData(doc) case final d)
          AttemptRecord(
            questionId: asString(d['questionId']),
            topicId: asString(d['topicId']),
            subjectId: asString(d['subjectId']),
            selectedIndex: asIntOrNull(d['selectedIndex']) ?? -1,
            isCorrect: asBool(d['isCorrect']),
            source: asString(d['source']),
            at: d['timestamp'] is Timestamp
                ? (d['timestamp'] as Timestamp).toDate()
                : null,
          ),
    ];
  }

  /// The questions behind [ids] that can still be answered, by id.
  ///
  /// A question retired since (`hasAnswer: false`), deleted, or without a
  /// usable answer is left out: the notebook must never offer a question
  /// it cannot mark.
  Future<Map<String, Question>> answerable(List<String> ids) async {
    final out = <String, Question>{};
    for (var i = 0; i < ids.length; i += 30) {
      final chunk = ids.sublist(i, i + 30 > ids.length ? ids.length : i + 30);
      final snap = await _db
          .collection('questions')
          .where(FieldPath.documentId, whereIn: chunk)
          .get()
          .metered();
      for (final doc in snap.docs) {
        if (!asBool(docData(doc)['hasAnswer'])) continue;
        final q = Question.fromFirestore(doc);
        if (q.correctIndex < 0 || q.correctIndex >= q.options.length) continue;
        out[q.id] = q;
      }
    }
    return out;
  }
}

final mistakesRepositoryProvider = Provider<MistakesRepository>(
  (ref) => MistakesRepository(FirebaseFirestore.instance),
);

/// One notebook entry: the mistake and the question it was made on.
class MistakeEntry {
  const MistakeEntry(this.mistake, this.question);
  final Mistake mistake;
  final Question question;

  /// The subject the notebook files this under: the question's own, which
  /// is current, rather than the one stamped on the attempt. Some old
  /// attempts carry the id of a subject that has since been re-seeded and
  /// deleted, and would otherwise show as "Other".
  String get subjectId => question.subjectId.isNotEmpty
      ? question.subjectId
      : mistake.subjectId;
}

/// The signed-in student's open mistakes, newest first.
///
/// Not auto-disposed: the reads (up to [kMistakesWindow] attempts plus the
/// questions) are paid once per session, not on every visit. Practice
/// invalidates it, so cleared questions leave straight away.
final mistakesProvider = FutureProvider<List<MistakeEntry>>((ref) async {
  final uid = ref.watch(currentUserProvider)?.uid;
  if (uid == null) return const [];
  final repo = ref.read(mistakesRepositoryProvider);
  final open = openMistakes(await repo.recentAttempts(uid));
  if (open.isEmpty) return const [];
  final questions = await repo.answerable([for (final m in open) m.questionId]);
  return [
    for (final m in open)
      if (questions[m.questionId] case final q?) MistakeEntry(m, q),
  ];
});
