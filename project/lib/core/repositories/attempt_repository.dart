import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AttemptRepository {
  const AttemptRepository(this._db);
  final FirebaseFirestore _db;

  Future<void> record({
    required String userId,
    required String questionId,
    required String topicId,
    required String subjectId,
    required int selectedIndex,
    required bool isCorrect,
    required String source, // 'drill' or 'waec'
  }) async {
    await _db.collection('attempts').add({
      'userId': userId,
      'questionId': questionId,
      'topicId': topicId,
      'subjectId': subjectId,
      'selectedIndex': selectedIndex,
      'isCorrect': isCorrect,
      'source': source,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }
}

final attemptRepositoryProvider = Provider<AttemptRepository>((ref) {
  return AttemptRepository(FirebaseFirestore.instance);
});