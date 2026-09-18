import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AttemptRepository {
  const AttemptRepository(this._db);
  final FirebaseFirestore _db;

  // Stay under Firestore's 500-write-per-batch hard limit.
  static const _batchChunkSize = 450;

  Future<void> record({
    required String userId,
    required String questionId,
    required String topicId,
    required String subjectId,
    required int selectedIndex,
    required bool isCorrect,
    required String source, // 'drill' or 'waec'
  }) async {
    await _db
        .collection('attempts')
        .add(
          _attemptData(
            userId: userId,
            questionId: questionId,
            topicId: topicId,
            subjectId: subjectId,
            selectedIndex: selectedIndex,
            isCorrect: isCorrect,
            source: source,
          ),
        );
  }

  /// Writes one attempt document per entry in [attempts], chunked into
  /// Firestore batches so a large session (more than [_batchChunkSize]
  /// answered questions) can't exceed the per-batch write limit.
  Future<void> recordBatch({
    required String userId,
    required String source,
    required List<
      ({
        String questionId,
        String topicId,
        String subjectId,
        int selectedIndex,
        bool isCorrect,
      })
    >
    attempts,
  }) async {
    for (var i = 0; i < attempts.length; i += _batchChunkSize) {
      final chunk = attempts.skip(i).take(_batchChunkSize);
      final batch = _db.batch();
      for (final a in chunk) {
        batch.set(
          _db.collection('attempts').doc(),
          _attemptData(
            userId: userId,
            questionId: a.questionId,
            topicId: a.topicId,
            subjectId: a.subjectId,
            selectedIndex: a.selectedIndex,
            isCorrect: a.isCorrect,
            source: source,
          ),
        );
      }
      await batch.commit();
    }
  }

  Map<String, dynamic> _attemptData({
    required String userId,
    required String questionId,
    required String topicId,
    required String subjectId,
    required int selectedIndex,
    required bool isCorrect,
    required String source,
  }) {
    return {
      'userId': userId,
      'questionId': questionId,
      'topicId': topicId,
      'subjectId': subjectId,
      'selectedIndex': selectedIndex,
      'isCorrect': isCorrect,
      'source': source,
      'timestamp': FieldValue.serverTimestamp(),
    };
  }
}

final attemptRepositoryProvider = Provider<AttemptRepository>((ref) {
  return AttemptRepository(FirebaseFirestore.instance);
});
