import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/read_meter.dart';
import '../models/firestore_parsing.dart';
import '../questions/question_draft.dart';
import 'admin_flag_repository.dart';

/// The studio's question workspace: browsing the bank and editing a
/// question with a record of every change.
///
/// Reviewers only; `firestore.rules` (`editsQuestion`) refuses an edit
/// unless the same batch writes `questions/{id}/history/{editId}` signed by
/// the same reviewer, so a question never changes without a record that can
/// restore it.

/// Which questions the browser lists.
enum QuestionKind {
  past('Past questions'),
  practice('Paragon practice');

  const QuestionKind(this.label);
  final String label;

  /// `source` as stored: past questions are `waec`, generated ones `drill`.
  String get source => this == QuestionKind.past ? 'waec' : 'drill';
}

class QuestionFilter {
  const QuestionFilter({
    required this.subjectId,
    this.kind = QuestionKind.past,
    this.year,
    this.topicId,
    this.live = true,
  });

  final String subjectId;
  final QuestionKind kind;

  /// Past questions only: one paper.
  final int? year;

  /// Narrows to one topic (either kind).
  final String? topicId;

  /// True for what students see (`hasAnswer`), false for retired ones.
  final bool live;

  QuestionFilter copyWith({
    String? subjectId,
    QuestionKind? kind,
    int? Function()? year,
    String? Function()? topicId,
    bool? live,
  }) => QuestionFilter(
    subjectId: subjectId ?? this.subjectId,
    kind: kind ?? this.kind,
    year: year != null ? year() : this.year,
    topicId: topicId != null ? topicId() : this.topicId,
    live: live ?? this.live,
  );

  /// Whether a query can serve this: by topic, or a past paper by year.
  /// A whole subject's practice bank is 2,000+ questions and is browsed a
  /// topic at a time.
  bool get isQueryable =>
      topicId != null || (kind == QuestionKind.past && year != null);

  @override
  bool operator ==(Object other) =>
      other is QuestionFilter &&
      other.subjectId == subjectId &&
      other.kind == kind &&
      other.year == year &&
      other.topicId == topicId &&
      other.live == live;

  @override
  int get hashCode => Object.hash(subjectId, kind, year, topicId, live);
}

class QuestionPage {
  const QuestionPage(this.questions, this.last, {required this.hasMore});
  final List<ReviewedQuestion> questions;
  final DocumentSnapshot? last;
  final bool hasMore;
}

/// One saved edit: who, when, why, and the fields before and after.
class QuestionEdit {
  const QuestionEdit({
    required this.id,
    required this.by,
    required this.reason,
    required this.before,
    required this.after,
    this.at,
  });

  final String id;
  final String by;
  final String reason;
  final QuestionDraft before;
  final QuestionDraft after;
  final DateTime? at;

  factory QuestionEdit.fromFirestore(DocumentSnapshot doc) {
    final d = docData(doc);
    final at = d['at'];
    Map<String, dynamic> map(Object? v) =>
        v is Map ? v.cast<String, dynamic>() : const {};
    return QuestionEdit(
      id: doc.id,
      by: asString(d['by']),
      reason: asString(d['reason']),
      before: QuestionDraft.fromMap(map(d['before'])),
      after: QuestionDraft.fromMap(map(d['after'])),
      at: at is Timestamp ? at.toDate() : null,
    );
  }
}

class AdminQuestionRepository {
  AdminQuestionRepository(this._db);

  final FirebaseFirestore _db;

  static const pageSize = 25;

  CollectionReference<Map<String, dynamic>> get _questions =>
      _db.collection('questions');

  /// A page of [filter]'s questions, in id order (the indexes'
  /// `topicId + source + hasAnswer`, and `subjectId + source + hasAnswer +
  /// year` for a paper). [after] continues from a previous page.
  Future<QuestionPage> browse(
    QuestionFilter filter, {
    DocumentSnapshot? after,
  }) async {
    Query<Map<String, dynamic>> q;
    if (filter.topicId != null) {
      q = _questions
          .where('topicId', isEqualTo: filter.topicId)
          .where('source', isEqualTo: filter.kind.source)
          .where('hasAnswer', isEqualTo: filter.live);
    } else if (filter.kind == QuestionKind.past && filter.year != null) {
      q = _questions
          .where('subjectId', isEqualTo: filter.subjectId)
          .where('source', isEqualTo: 'waec')
          .where('hasAnswer', isEqualTo: filter.live)
          .where('year', isEqualTo: filter.year);
    } else {
      return const QuestionPage([], null, hasMore: false);
    }
    q = q.orderBy(FieldPath.documentId);
    // The cursor before the limit: Firestore takes either order, but the
    // test fake applies a limit set first before the cursor.
    if (after != null) q = q.startAfterDocument(after);
    q = q.limit(pageSize + 1);
    final snap = await q.get().metered();
    final docs = snap.docs.take(pageSize).toList();
    return QuestionPage(
      [for (final d in docs) ReviewedQuestion.fromFirestore(d)],
      docs.isEmpty ? null : docs.last,
      hasMore: snap.docs.length > pageSize,
    );
  }

  /// The questions with [ids], in that order; missing ones are skipped.
  /// `whereIn` takes at most 30 values, so ids are fetched in chunks.
  Future<List<ReviewedQuestion>> byIds(List<String> ids) async {
    final found = <String, ReviewedQuestion>{};
    for (var i = 0; i < ids.length; i += 30) {
      final chunk = ids.sublist(i, i + 30 > ids.length ? ids.length : i + 30);
      final snap = await _questions
          .where(FieldPath.documentId, whereIn: chunk)
          .get()
          .metered();
      for (final d in snap.docs) {
        found[d.id] = ReviewedQuestion.fromFirestore(d);
      }
    }
    return [for (final id in ids) ?found[id]];
  }

  /// Saves [after] over [before], with the history record in the same
  /// batch, and closes [closeReports] as fixed. Returns the edit's id.
  Future<String> save({
    required String questionId,
    required QuestionDraft before,
    required QuestionDraft after,
    required String reason,
    required String uid,
    List<ProblemReport> closeReports = const [],
  }) async {
    final ref = _questions.doc(questionId);
    final history = ref.collection('history').doc();
    final batch = _db.batch();
    batch.set(history, {
      'by': uid,
      'at': FieldValue.serverTimestamp(),
      'reason': reason.trim().length > 500
          ? reason.trim().substring(0, 500)
          : reason.trim(),
      'before': before.toMap(),
      'after': after.toMap(),
    });
    batch.update(ref, {
      ...after.toMap(),
      // So an answer change can still be reverted from the report screen.
      if (after.correctIndex != before.correctIndex)
        'previousCorrectIndex': before.correctIndex,
      // Back to the estimate: the reviewer's level is removed.
      if (after.difficulty == null && before.difficulty != null)
        'difficulty': FieldValue.delete(),
      'editedAt': FieldValue.serverTimestamp(),
      'editedBy': uid,
      'lastEditId': history.id,
    });
    for (final r in closeReports) {
      batch.update(_db.collection('flags').doc(r.id), {
        'status': FlagStatus.fixed.value,
        'resolvedAt': FieldValue.serverTimestamp(),
        'resolvedBy': uid,
      });
    }
    await batch.commit();
    return history.id;
  }

  /// Every recorded edit of a question, newest first.
  Future<List<QuestionEdit>> history(String questionId) async {
    final snap = await _questions
        .doc(questionId)
        .collection('history')
        .orderBy('at', descending: true)
        .limit(50)
        .get()
        .metered();
    return [for (final d in snap.docs) QuestionEdit.fromFirestore(d)];
  }
}

final adminQuestionRepositoryProvider = Provider<AdminQuestionRepository>(
  (ref) => AdminQuestionRepository(FirebaseFirestore.instance),
);

final questionHistoryProvider = FutureProvider.autoDispose
    .family<List<QuestionEdit>, String>(
      (ref, id) => ref.read(adminQuestionRepositoryProvider).history(id),
    );

/// The questions a reviewer is working through, in order: set by whichever
/// list opened the editor (the browser, a report queue, an audit rule), so
/// the editor can offer Previous and Next without going back.
class StudioWorkList extends Notifier<List<String>> {
  @override
  List<String> build() => const [];

  void set(List<String> ids) => state = List.unmodifiable(ids);
}

final studioWorkListProvider = NotifierProvider<StudioWorkList, List<String>>(
  StudioWorkList.new,
);
