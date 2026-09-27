import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../exam/exam_result.dart';
import '../models/question.dart';
import '../providers/auth_provider.dart';

/// `examResults/{id}`: one document per finished WAEC exam.
class ExamResultRepository {
  const ExamResultRepository(this._db);
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('examResults');

  /// An id for an exam about to be saved. Chosen before the write, so a
  /// retry after a failure writes the same document instead of a second.
  String newId() => _col.doc().id;

  /// Writes [result] for [uid]. `set` on a fixed id is safe to repeat.
  Future<void> save(String uid, ExamResult result) {
    return _col.doc(result.id).set({
      ...result.toFirestore(),
      'userId': uid,
      'submittedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<ExamResult?> load(String id) async {
    final doc = await _col.doc(id).get();
    return doc.exists ? ExamResult.fromFirestore(doc) : null;
  }

  /// The student's latest exams in one subject, newest first. Served by
  /// the `userId, subjectId, submittedAt DESC` index.
  Future<List<ExamResult>> history(
    String uid,
    String subjectId, {
    int limit = 20,
  }) async {
    final snap = await _col
        .where('userId', isEqualTo: uid)
        .where('subjectId', isEqualTo: subjectId)
        .orderBy('submittedAt', descending: true)
        .limit(limit)
        .get();
    return snap.docs.map(ExamResult.fromFirestore).toList();
  }

  /// The questions of an exam, by id — retired ones included, since a
  /// review shows what was sat, not what is served today.
  Future<Map<String, Question>> questions(List<String> ids) async {
    final out = <String, Question>{};
    final unique = ids.toSet().toList();
    for (var i = 0; i < unique.length; i += 30) {
      final chunk = unique.sublist(
        i,
        i + 30 > unique.length ? unique.length : i + 30,
      );
      final snap = await _db
          .collection('questions')
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      for (final doc in snap.docs) {
        out[doc.id] = Question.fromFirestore(doc);
      }
    }
    return out;
  }
}

final examResultRepositoryProvider = Provider<ExamResultRepository>(
  (ref) => ExamResultRepository(FirebaseFirestore.instance),
);

/// A finished exam and its questions, ready to review.
class ExamReview {
  const ExamReview(this.result, this.questions);
  final ExamResult result;
  final Map<String, Question> questions;
}

/// A saved exam, loaded for `/waec/review/:examId` after a reload or from
/// the history list. Null when it does not exist or is not the student's
/// (the rules refuse another student's, which surfaces as an error).
final examReviewProvider = FutureProvider.autoDispose
    .family<ExamReview?, String>((ref, examId) async {
      final repo = ref.read(examResultRepositoryProvider);
      final result = await repo.load(examId);
      if (result == null) return null;
      final questions = await repo.questions([
        for (final i in result.items) i.questionId,
      ]);
      return ExamReview(result, questions);
    });

/// The signed-in student's latest exams in a subject, newest first.
final examHistoryProvider = FutureProvider.autoDispose
    .family<List<ExamResult>, String>((ref, subjectId) async {
      final uid = ref.watch(currentUserProvider)?.uid;
      if (uid == null) return const [];
      return ref.read(examResultRepositoryProvider).history(uid, subjectId);
    });
