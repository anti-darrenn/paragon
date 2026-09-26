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

  /// The reason stored as [value], or [other] for anything unrecognised —
  /// a report is still worth reviewing when its reason is not.
  static FlagReason parse(String? value) => FlagReason.values.firstWhere(
    (r) => r.value == value,
    orElse: () => FlagReason.other,
  );
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

/// Why a student is reporting a lesson item (an article or a video).
/// Stored in the same `reason` field as question reports; the value never
/// collides with a [FlagReason] value.
enum LessonReportReason {
  mistake('lesson_mistake', "There's a mistake in this lesson"),
  unclear('lesson_unclear', "It's unclear or confusing"),
  rendering('rendering', "Maths or text doesn't display properly"),
  video('video_broken', "The video doesn't play"),
  other('other', 'Something else');

  const LessonReportReason(this.value, this.label);
  final String value;
  final String label;

  static LessonReportReason parse(String? value) =>
      LessonReportReason.values.firstWhere(
        (r) => r.value == value,
        orElse: () => LessonReportReason.other,
      );
}

extension LessonReports on FlagRepository {
  /// A report on a lesson item rather than a question: `resourceId` and
  /// `topicId` instead of `questionId`, so the question queue never groups
  /// it. The reviewers' lesson-report list picks it up.
  Future<void> createLessonReport({
    required String userId,
    required String topicId,
    required String resourceId,
    required LessonReportReason reason,
  }) {
    return _db.collection('flags').add({
      'resourceId': resourceId,
      'topicId': topicId,
      'userId': userId,
      'reason': reason.value,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}

final flagRepositoryProvider = Provider<FlagRepository>((ref) {
  return FlagRepository(FirebaseFirestore.instance);
});
