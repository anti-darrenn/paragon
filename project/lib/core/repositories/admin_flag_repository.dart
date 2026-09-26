import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/firestore_parsing.dart';
import '../models/question.dart';
import 'flag_repository.dart';

/// Review of student problem reports, for the content editor.
///
/// Every read and write here is refused by `firestore.rules` unless the
/// signed-in account carries the `admin` claim. Kept apart from
/// `flag_repository.dart`, which is the student's write-only side.
///
/// A report's `status` is open | fixed | dismissed, and a **missing status
/// means open**: reports filed before review existed, or by a cached old
/// build, carry none, and nothing backfills them.
enum FlagStatus {
  open('open'),
  fixed('fixed'),
  dismissed('dismissed');

  const FlagStatus(this.value);
  final String value;

  static FlagStatus parse(String? value) => FlagStatus.values.firstWhere(
    (s) => s.value == value,
    orElse: () => FlagStatus.open,
  );
}

/// One student's report on one question.
class ProblemReport {
  const ProblemReport({
    required this.id,
    required this.questionId,
    required this.reason,
    required this.status,
    this.createdAt,
  });

  final String id;
  final String questionId;
  final FlagReason reason;
  final FlagStatus status;
  final DateTime? createdAt;

  bool get isOpen => status == FlagStatus.open;

  factory ProblemReport.fromFirestore(DocumentSnapshot doc) {
    final d = docData(doc);
    final created = d['createdAt'];
    return ProblemReport(
      id: doc.id,
      questionId: asString(d['questionId']),
      reason: FlagReason.parse(asStringOrNull(d['reason'])),
      status: FlagStatus.parse(asStringOrNull(d['status'])),
      createdAt: created is Timestamp ? created.toDate() : null,
    );
  }
}

/// A question as the reviewer needs it: the student-facing [Question]
/// plus the fields that decide what a fix means.
class ReviewedQuestion {
  const ReviewedQuestion({
    required this.question,
    required this.hasAnswer,
    required this.origin,
    this.previousCorrectIndex,
  });

  final Question question;

  /// False means drill, WAEC and tests all skip it — retired, or never
  /// had a verified answer.
  final bool hasAnswer;

  /// `ai_generated` for the procedural corpus, where a wrong answer is a
  /// generator bug and the fix belongs in `tools/scraper/gen` too.
  final String origin;

  /// The answer before the last in-app change, for reverting it.
  final int? previousCorrectIndex;

  bool get isGenerated => origin == 'ai_generated';

  factory ReviewedQuestion.fromFirestore(DocumentSnapshot doc) {
    final d = docData(doc);
    return ReviewedQuestion(
      question: Question.fromFirestore(doc),
      hasAnswer: asBool(d['hasAnswer']),
      origin: asString(d['origin']),
      previousCorrectIndex: asIntOrNull(d['previousCorrectIndex']),
    );
  }
}

/// Every report on one question, with the question itself — one row of
/// the review queue. [question] is null when the question no longer
/// exists; its reports are still shown so they can be dismissed.
class FlaggedQuestion {
  const FlaggedQuestion({
    required this.questionId,
    required this.reports,
    this.question,
  });

  final String questionId;
  final List<ProblemReport> reports;
  final ReviewedQuestion? question;

  List<ProblemReport> get openReports =>
      reports.where((r) => r.isOpen).toList();

  bool get isOpen => reports.any((r) => r.isOpen);

  /// Open reports per reason, most common first.
  List<(FlagReason, int)> get openReasonCounts {
    final counts = <FlagReason, int>{};
    for (final r in openReports) {
      counts[r.reason] = (counts[r.reason] ?? 0) + 1;
    }
    return counts.entries.map((e) => (e.key, e.value)).toList()
      ..sort((a, b) => b.$2.compareTo(a.$2));
  }

  DateTime? get latestReportAt => reports
      .map((r) => r.createdAt)
      .whereType<DateTime>()
      .fold<DateTime?>(null, (a, b) => a == null || b.isAfter(a) ? b : a);
}

/// Groups reports by question for the queue: questions with open reports
/// first, then by how many open reports they have, then newest first.
List<FlaggedQuestion> groupReports(
  List<ProblemReport> reports,
  Map<String, ReviewedQuestion> questions,
) {
  final byQuestion = <String, List<ProblemReport>>{};
  for (final r in reports) {
    if (r.questionId.isEmpty) continue;
    byQuestion.putIfAbsent(r.questionId, () => []).add(r);
  }

  final rows = [
    for (final e in byQuestion.entries)
      FlaggedQuestion(
        questionId: e.key,
        reports: e.value,
        question: questions[e.key],
      ),
  ];

  rows.sort((a, b) {
    if (a.isOpen != b.isOpen) return a.isOpen ? -1 : 1;
    final byCount = b.openReports.length.compareTo(a.openReports.length);
    if (byCount != 0) return byCount;
    final aAt = a.latestReportAt, bAt = b.latestReportAt;
    if (aAt == null || bAt == null) return aAt == null ? 1 : -1;
    return bAt.compareTo(aAt);
  });
  return rows;
}

class AdminFlagRepository {
  const AdminFlagRepository(this._db);
  final FirebaseFirestore _db;

  /// How many recent reports the queue loads. A single-field order, so no
  /// composite index. Older reports fall out of view, which is acceptable
  /// while resolved reports vastly outnumber open ones — revisit if the
  /// open backlog ever approaches it.
  static const queueSize = 200;

  CollectionReference<Map<String, dynamic>> get _flags =>
      _db.collection('flags');

  Future<List<FlaggedQuestion>> queue() async {
    final snap = await _flags
        .orderBy('createdAt', descending: true)
        .limit(queueSize)
        .get();
    final reports = snap.docs.map(ProblemReport.fromFirestore).toList();
    final ids = reports.map((r) => r.questionId).where((id) => id.isNotEmpty);
    return groupReports(reports, await _questions(ids.toSet().toList()));
  }

  /// Open reports on lesson items (articles, videos), newest first, from
  /// the same recent window as [queue]. They carry a `resourceId` and no
  /// `questionId`, so [groupReports] never sees them.
  Future<List<LessonItemReport>> lessonReports() async {
    final snap = await _flags
        .orderBy('createdAt', descending: true)
        .limit(queueSize)
        .get();
    return [
      for (final d in snap.docs)
        if (asString(docData(d)['resourceId']).isNotEmpty)
          LessonItemReport.fromFirestore(d),
    ].where((r) => r.isOpen).toList();
  }

  /// Closes one lesson report as fixed or dismissed.
  Future<void> resolveLessonReport(
    LessonItemReport report, {
    required FlagStatus status,
    required String uid,
  }) {
    return _flags.doc(report.id).update({
      'status': status.value,
      'resolvedAt': FieldValue.serverTimestamp(),
      'resolvedBy': uid,
    });
  }

  /// One question and every report on it, for the review screen.
  Future<FlaggedQuestion> forQuestion(String questionId) async {
    final results = await Future.wait([
      _flags.where('questionId', isEqualTo: questionId).get(),
      _db.collection('questions').doc(questionId).get(),
    ]);
    final flags = results[0] as QuerySnapshot;
    final question = results[1] as DocumentSnapshot;
    return FlaggedQuestion(
      questionId: questionId,
      reports: flags.docs.map(ProblemReport.fromFirestore).toList()
        ..sort(
          (a, b) => (b.createdAt ?? DateTime(0)).compareTo(
            a.createdAt ?? DateTime(0),
          ),
        ),
      question: question.exists
          ? ReviewedQuestion.fromFirestore(question)
          : null,
    );
  }

  /// `whereIn` takes at most 30 values, so ids are fetched in chunks.
  Future<Map<String, ReviewedQuestion>> _questions(List<String> ids) async {
    final out = <String, ReviewedQuestion>{};
    for (var i = 0; i < ids.length; i += 30) {
      final chunk = ids.sublist(i, i + 30 > ids.length ? ids.length : i + 30);
      final snap = await _db
          .collection('questions')
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      for (final doc in snap.docs) {
        out[doc.id] = ReviewedQuestion.fromFirestore(doc);
      }
    }
    return out;
  }

  /// Marks [newIndex] as the answer and closes every open report as fixed.
  ///
  /// Also sets `hasAnswer: true`, so this is how a question that never had
  /// a verified answer, or was retired, comes back into circulation.
  /// Answers already recorded in `attempts` keep the grading they got.
  Future<void> changeAnswer({
    required FlaggedQuestion row,
    required int newIndex,
    required String uid,
  }) {
    final q = row.question!;
    return _resolve(
      row: row,
      uid: uid,
      status: FlagStatus.fixed,
      question: {
        'correctIndex': newIndex,
        'previousCorrectIndex': q.question.correctIndex,
        'hasAnswer': true,
      },
    );
  }

  /// Takes the question out of drill, WAEC and tests (`hasAnswer: false`)
  /// and closes every open report as fixed. The answer is left as it was.
  Future<void> retire({required FlaggedQuestion row, required String uid}) {
    return _resolve(
      row: row,
      uid: uid,
      status: FlagStatus.fixed,
      question: {'hasAnswer': false},
    );
  }

  /// The question is fine: closes every open report as dismissed and
  /// leaves the question untouched.
  Future<void> dismiss({required FlaggedQuestion row, required String uid}) {
    return _resolve(row: row, uid: uid, status: FlagStatus.dismissed);
  }

  /// One batch, so a question is never changed with its reports left open
  /// or the other way round. Only open reports are touched; a report closed
  /// earlier keeps the resolution it was given.
  Future<void> _resolve({
    required FlaggedQuestion row,
    required String uid,
    required FlagStatus status,
    Map<String, Object?>? question,
  }) async {
    final batch = _db.batch();
    if (question != null) {
      batch.update(_db.collection('questions').doc(row.questionId), {
        ...question,
        'reviewedAt': FieldValue.serverTimestamp(),
        'reviewedBy': uid,
      });
    }
    for (final r in row.openReports) {
      batch.update(_flags.doc(r.id), {
        'status': status.value,
        'resolvedAt': FieldValue.serverTimestamp(),
        'resolvedBy': uid,
      });
    }
    await batch.commit();
  }
}

final adminFlagRepositoryProvider = Provider<AdminFlagRepository>((ref) {
  return AdminFlagRepository(FirebaseFirestore.instance);
});

/// The review queue: recent reports grouped by question.
final adminFlagQueueProvider = FutureProvider<List<FlaggedQuestion>>((ref) {
  return ref.watch(adminFlagRepositoryProvider).queue();
});

/// One flagged question with all its reports.
final adminFlaggedQuestionProvider =
    FutureProvider.family<FlaggedQuestion, String>((ref, questionId) {
      return ref.watch(adminFlagRepositoryProvider).forQuestion(questionId);
    });

/// A student's report on a lesson item rather than a question.
class LessonItemReport {
  const LessonItemReport({
    required this.id,
    required this.topicId,
    required this.resourceId,
    required this.reason,
    required this.status,
    this.createdAt,
  });

  final String id;
  final String topicId;
  final String resourceId;
  final LessonReportReason reason;
  final FlagStatus status;
  final DateTime? createdAt;

  bool get isOpen => status == FlagStatus.open;

  factory LessonItemReport.fromFirestore(DocumentSnapshot doc) {
    final d = docData(doc);
    final created = d['createdAt'];
    return LessonItemReport(
      id: doc.id,
      topicId: asString(d['topicId']),
      resourceId: asString(d['resourceId']),
      reason: LessonReportReason.parse(asStringOrNull(d['reason'])),
      status: FlagStatus.parse(asStringOrNull(d['status'])),
      createdAt: created is Timestamp ? created.toDate() : null,
    );
  }
}

/// Open lesson-item reports, newest first.
final adminLessonReportsProvider = FutureProvider<List<LessonItemReport>>((
  ref,
) {
  return ref.watch(adminFlagRepositoryProvider).lessonReports();
});
