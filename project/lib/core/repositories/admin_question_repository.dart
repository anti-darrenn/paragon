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
  const QuestionPage(
    this.questions,
    this.last, {
    required this.hasMore,
    this.also = const [],
  });
  final List<ReviewedQuestion> questions;

  /// On a topic's first page: questions whose main topic is elsewhere but
  /// which also count for this one (`alsoTopicIds`).
  final List<ReviewedQuestion> also;
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
    var also = const <ReviewedQuestion>[];
    if (filter.topicId != null && after == null) {
      try {
        final extra = await _questions
            .where('alsoTopicIds', arrayContains: filter.topicId)
            .where('hasAnswer', isEqualTo: filter.live)
            .limit(50)
            .get()
            .metered();
        also = [
          for (final d in extra.docs)
            if ('${d.data()['source']}' == filter.kind.source)
              ReviewedQuestion.fromFirestore(d),
        ];
      } on FirebaseException {
        // The index still building: the topic's own questions still list.
      }
    }
    return QuestionPage(
      [for (final d in docs) ReviewedQuestion.fromFirestore(d)],
      docs.isEmpty ? null : docs.last,
      hasMore: snap.docs.length > pageSize,
      also: also,
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
  ///
  /// [placement] is the founder's: subject, topic, source, year, book
  /// reference and diagrams (`foundersEdit` in the rules). [vet] true vets
  /// the question in the same batch, false sends it back to pending; a
  /// reviewer may only ever pass false (a changed vetted question goes
  /// back to the founder).
  Future<String> save({
    required String questionId,
    required QuestionDraft before,
    required QuestionDraft after,
    required String reason,
    required String uid,
    List<ProblemReport> closeReports = const [],
    QuestionPlacement? placement,
    bool? vet,
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
      if (after.alsoTopicIds.isEmpty && before.alsoTopicIds.isNotEmpty)
        'alsoTopicIds': FieldValue.delete(),
      'editedAt': FieldValue.serverTimestamp(),
      'editedBy': uid,
      'lastEditId': history.id,
      ...?placement?.toUpdate(),
      ...?_vetting(vet, uid),
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

  /// Records that a reviewer looked at the content audit's [rule] finding
  /// on a question and it is not a problem — a suspect checked against the
  /// paper, say. The audit skips the rule on this question from then on.
  /// Written like a save, with a history record and no content change, so
  /// it is on the question's history and can be questioned later.
  Future<void> markChecked({
    required String questionId,
    required QuestionDraft current,
    required String rule,
    required String note,
    required String uid,
  }) async {
    final ref = _questions.doc(questionId);
    final history = ref.collection('history').doc();
    final reason = 'Checked "${rule.replaceAll('-', ' ')}": ${note.trim()}';
    final batch = _db.batch();
    batch.set(history, {
      'by': uid,
      'at': FieldValue.serverTimestamp(),
      'reason': reason.length > 500 ? reason.substring(0, 500) : reason,
      'before': current.toMap(),
      'after': current.toMap(),
    });
    batch.update(ref, {
      // The content as it is: unchanged, but present, which the edit rule
      // checks (an old scraped question may have no explanation field).
      ...current.toMap(),
      'auditDismissed': FieldValue.arrayUnion([rule]),
      'editedAt': FieldValue.serverTimestamp(),
      'editedBy': uid,
      'lastEditId': history.id,
    });
    await batch.commit();
  }

  Map<String, Object>? _vetting(bool? vet, String uid) => switch (vet) {
    true => {
      'vetted': true,
      'vettedAt': FieldValue.serverTimestamp(),
      'vettedBy': uid,
    },
    false => {
      'vetted': false,
      'vettedAt': FieldValue.delete(),
      'vettedBy': FieldValue.delete(),
    },
    null => null,
  };

  /// A new question from the founder's bank, with its history record, in
  /// one batch. Always pending (`vetted: false`) and `origin: 'authored'`.
  /// Returns its id.
  Future<String> create({
    required QuestionDraft draft,
    required QuestionPlacement placement,
    required String uid,
  }) async {
    final ref = _questions.doc();
    final history = ref.collection('history').doc();
    final batch = _db.batch();
    final content = draft.toMap();
    batch.set(ref, {
      ...content,
      ...placement.toCreate(),
      'origin': 'authored',
      'vetted': false,
      'createdBy': uid,
      'createdAt': FieldValue.serverTimestamp(),
      'editedAt': FieldValue.serverTimestamp(),
      'editedBy': uid,
      'lastEditId': history.id,
    });
    batch.set(history, {
      'by': uid,
      'at': FieldValue.serverTimestamp(),
      'reason': 'Written in the question bank',
      'before': <String, Object>{},
      'after': content,
    });
    await batch.commit();
    return ref.id;
  }

  /// A page of a topic's questions still waiting for the founder: answered
  /// (`hasAnswer`) and not vetted. A missing `vetted` means pending, and
  /// Firestore cannot query for a missing field, so this reads the topic's
  /// answered questions in id order and keeps the unvetted ones, refilling
  /// until it has a page or the topic runs out.
  Future<QuestionPage> pendingPage(
    String topicId, {
    DocumentSnapshot? after,
  }) async {
    final found = <ReviewedQuestion>[];
    var cursor = after;
    var exhausted = false;
    for (var round = 0; round < 8 && found.length < pageSize; round++) {
      var q = _questions
          .where('topicId', isEqualTo: topicId)
          .where('hasAnswer', isEqualTo: true)
          .orderBy(FieldPath.documentId);
      if (cursor != null) q = q.startAfterDocument(cursor);
      final snap = await q.limit(pageSize * 2).get().metered();
      for (final d in snap.docs) {
        final r = ReviewedQuestion.fromFirestore(d);
        if (!r.vetted) found.add(r);
        cursor = d;
        if (found.length == pageSize) break;
      }
      if (snap.docs.length < pageSize * 2) {
        exhausted = true;
        break;
      }
    }
    return QuestionPage(
      found,
      cursor,
      hasMore: !exhausted || found.length == pageSize,
    );
  }

  /// A page of a topic's vetted questions, in id order.
  Future<QuestionPage> vettedPage(
    String topicId, {
    DocumentSnapshot? after,
  }) async {
    var q = _questions
        .where('topicId', isEqualTo: topicId)
        .where('vetted', isEqualTo: true)
        .orderBy(FieldPath.documentId);
    if (after != null) q = q.startAfterDocument(after);
    final snap = await q.limit(pageSize + 1).get().metered();
    final docs = snap.docs.take(pageSize).toList();
    return QuestionPage(
      [for (final d in docs) ReviewedQuestion.fromFirestore(d)],
      docs.isEmpty ? null : docs.last,
      hasMore: snap.docs.length > pageSize,
    );
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

/// Where a question sits and comes from: the founder's fields
/// (`foundersEdit` / `foundersCreate` in the rules). Reviewers never send
/// these.
class QuestionPlacement {
  const QuestionPlacement({
    required this.subjectId,
    required this.topicId,
    required this.source,
    this.year,
    this.sourceRef = '',
    this.imageId,
    this.explanationImageId,
    this.previousTopicId,
  });

  final String subjectId;
  final String topicId;

  /// `waec` for a past paper, `drill` for practice.
  final String source;
  final int? year;

  /// A book and page, for a question typed in from a textbook.
  final String sourceRef;
  final String? imageId;
  final String? explanationImageId;

  /// The topic it moved from, kept so a retag can be undone.
  final String? previousTopicId;

  Map<String, Object?> _fields() => {
    'subjectId': subjectId,
    'topicId': topicId,
    'source': source,
    'year': source == 'waec' ? year : null,
  };

  Map<String, Object> toCreate() => {
    for (final e in _fields().entries)
      if (e.value != null) e.key: e.value!,
    if (sourceRef.trim().isNotEmpty) 'sourceRef': sourceRef.trim(),
    'imageId': ?imageId,
    'explanationImageId': ?explanationImageId,
  };

  Map<String, Object> toUpdate() => {
    for (final e in _fields().entries)
      e.key: e.value ?? FieldValue.delete(),
    'sourceRef': sourceRef.trim().isEmpty
        ? FieldValue.delete()
        : sourceRef.trim(),
    'imageId': imageId ?? FieldValue.delete(),
    'explanationImageId': explanationImageId ?? FieldValue.delete(),
    'previousTopicId': ?previousTopicId,
  };
}
