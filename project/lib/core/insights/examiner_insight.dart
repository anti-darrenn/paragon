import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/read_meter.dart';
import '../models/firestore_parsing.dart';

/// "What examiners saw": what WAEC's Chief Examiners' reports say
/// candidates did with a question or a topic, **in Paragon's own words**
/// with a citation — never the report's text (PLAN.md P7.1).
///
/// `insights/{id}`, written by reviewers in the studio:
/// - for a question, the id is the question's id and `kind` is `question`;
/// - for a topic's recurring weaknesses, the id is `topic_<topicId>` and
///   `kind` is `topic`.
///
/// Students read only `status: published`. **No read is spent on a
/// question without one**: `jobs.js --job=insights` stamps
/// `questions.hasInsight` and `topics.hasExaminerThemes`, and the app
/// fetches an insight only when that flag is set.
class ExaminerInsight {
  const ExaminerInsight({
    required this.id,
    required this.kind,
    required this.subjectId,
    required this.summary,
    required this.reportYear,
    required this.reportRef,
    required this.status,
    this.questionId = '',
    this.topicId = '',
    this.commonWrongOption,
    this.tip = '',
    this.years = const [],
  });

  final String id;

  /// `question` or `topic`.
  final String kind;
  final String subjectId;
  final String questionId;
  final String topicId;

  /// What candidates did, in Paragon's words.
  final String summary;

  /// The wrong option most candidates chose (0-based), if the report says.
  final int? commonWrongOption;
  final String tip;
  final int reportYear;

  /// A citation, e.g. "WASSCE May/June 2018, Mathematics, Q12".
  final String reportRef;

  /// For a topic: the years the weakness was reported.
  final List<int> years;
  final String status;

  bool get isPublished => status == 'published';

  static String topicDocId(String topicId) => 'topic_$topicId';

  factory ExaminerInsight.fromFirestore(DocumentSnapshot doc) {
    final d = docData(doc);
    final years = d['years'];
    return ExaminerInsight(
      id: doc.id,
      kind: asString(d['kind'], fallback: 'question'),
      subjectId: asString(d['subjectId']),
      questionId: asString(d['questionId']),
      topicId: asString(d['topicId']),
      summary: asString(d['summary']),
      commonWrongOption: asIntOrNull(d['commonWrongOption']),
      tip: asString(d['tip']),
      reportYear: asInt(d['reportYear']),
      reportRef: asString(d['reportRef']),
      years: years is List ? [for (final y in years) asInt(y)] : const [],
      status: asString(d['status'], fallback: 'draft'),
    );
  }

  Map<String, Object?> toFirestore({required String uid}) => {
    'kind': kind,
    'subjectId': subjectId,
    'questionId': questionId,
    'topicId': topicId,
    'summary': summary,
    'commonWrongOption': commonWrongOption,
    'tip': tip,
    'reportYear': reportYear,
    'reportRef': reportRef,
    'years': years,
    'status': status,
    'updatedAt': FieldValue.serverTimestamp(),
    'updatedBy': uid,
  };
}

/// The longest run of consecutive words two texts share — the
/// original-wording check (PLAN.md P7.1.4). A reviewer pastes the report's
/// text beside their own summary; twenty or more words in a row is copied
/// prose, not a summary. Case, punctuation and spacing are ignored.
int longestSharedRun(String a, String b) {
  List<String> words(String s) => s
      .toLowerCase()
      .replaceAll(RegExp(r"[^a-z0-9'\s]"), ' ')
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .toList();
  final x = words(a), y = words(b);
  if (x.isEmpty || y.isEmpty) return 0;
  var best = 0;
  var prev = List<int>.filled(y.length + 1, 0);
  for (var i = 1; i <= x.length; i++) {
    final cur = List<int>.filled(y.length + 1, 0);
    for (var j = 1; j <= y.length; j++) {
      if (x[i - 1] == y[j - 1]) {
        cur[j] = prev[j - 1] + 1;
        if (cur[j] > best) best = cur[j];
      }
    }
    prev = cur;
  }
  return best;
}

/// Over this, the studio refuses to publish until it is reworded.
const int kMaxSharedRun = 20;

class InsightRepository {
  InsightRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('insights');

  /// The published insight with [id], or null. Only ever called when a
  /// flag says one exists, so a student never pays for a miss. A
  /// permission error (a draft) reads as "none".
  Future<ExaminerInsight?> published(String id) async {
    try {
      final s = await _col.doc(id).get().metered();
      if (!s.exists) return null;
      final i = ExaminerInsight.fromFirestore(s);
      return i.isPublished ? i : null;
    } on FirebaseException {
      return null;
    }
  }

  /// Any status — the studio's view.
  Future<ExaminerInsight?> any(String id) async {
    final s = await _col.doc(id).get().metered();
    return s.exists ? ExaminerInsight.fromFirestore(s) : null;
  }

  Future<void> save(
    String id,
    ExaminerInsight insight, {
    required String uid,
  }) => _col.doc(id).set(insight.toFirestore(uid: uid));
}

final insightRepositoryProvider = Provider<InsightRepository>(
  (ref) => InsightRepository(FirebaseFirestore.instance),
);

/// A published insight by id (a question id, or `topic_<topicId>`).
final publishedInsightProvider =
    FutureProvider.family<ExaminerInsight?, String>(
      (ref, id) => ref.read(insightRepositoryProvider).published(id),
    );
