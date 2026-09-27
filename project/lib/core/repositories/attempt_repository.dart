import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// One question's worth of attempt data, minus [userId]/[source] — those are
/// shared across a whole [AttemptRepository.recordBatch] call and supplied
/// once, not per-draft.
class AttemptDraft {
  const AttemptDraft({
    required this.questionId,
    required this.topicId,
    required this.subjectId,
    required this.selectedIndex,
    required this.isCorrect,
    this.hintsUsed = 0,
  });

  final String questionId;
  final String topicId;
  final String subjectId;
  final int selectedIndex;
  final bool isCorrect;

  /// Hints shown before this answer. Stored only when non-zero; see
  /// `lib/core/learn/hints.dart` for what a hint costs.
  final int hintsUsed;
}

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
    // 'drill' | 'waec' | 'test' | 'exercise' | 'review'. Only drill feeds
    // mastery.
    required String source,
    int hintsUsed = 0,
  }) {
    return recordBatch(
      userId: userId,
      source: source,
      attempts: [
        AttemptDraft(
          questionId: questionId,
          topicId: topicId,
          subjectId: subjectId,
          selectedIndex: selectedIndex,
          isCorrect: isCorrect,
          hintsUsed: hintsUsed,
        ),
      ],
    );
  }

  /// Writes one attempt document per entry in [attempts], chunked into
  /// Firestore batches so a large session (more than [_batchChunkSize]
  /// answered questions) can't exceed the per-batch write limit.
  Future<void> recordBatch({
    required String userId,
    required String source,
    required List<AttemptDraft> attempts,
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
            hintsUsed: a.hintsUsed,
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
    int hintsUsed = 0,
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
      if (hintsUsed > 0) 'hintsUsed': hintsUsed,
    };
  }
}

final attemptRepositoryProvider = Provider<AttemptRepository>((ref) {
  return AttemptRepository(FirebaseFirestore.instance);
});
