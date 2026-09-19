import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Why a student is reporting a question. Fixed set rather than free text —
/// keeps the reports queryable and avoids a free-text field that would need
/// moderating.
enum FlagReason {
  wrongAnswer('wrong_answer', 'The marked answer is wrong'),
  unclearQuestion('unclear_question', "The question is unclear or incomplete"),
  rendering('rendering', "Maths or text doesn't display properly"),
  other('other', 'Something else');

  const FlagReason(this.value, this.label);

  /// Stored in Firestore — keep stable, reports are queried on it.
  final String value;
  final String label;
}

/// Student-reported problems with a question.
///
/// The answer key is scraped from a third party with a measured error rate,
/// so this is the only way wrong answers get found once the app is live.
/// Write-only by design: the security rules deny all reads, and reports are
/// read out with the Admin SDK instead.
class FlagRepository {
  const FlagRepository(this._db);
  final FirebaseFirestore _db;

  Future<void> create({
    required String userId,
    required String questionId,
    required FlagReason reason,
  }) {
    return _db.collection('flags').add({
      'questionId': questionId,
      'userId': userId,
      'reason': reason.value,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}

final flagRepositoryProvider = Provider<FlagRepository>((ref) {
  return FlagRepository(FirebaseFirestore.instance);
});
