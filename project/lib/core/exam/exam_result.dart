import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/firestore_parsing.dart';
import '../models/question.dart';

/// One question of a finished WAEC exam: which it was and what was picked.
class ExamItem {
  const ExamItem({
    required this.questionId,
    required this.topicId,
    required this.selected,
  });

  final String questionId;
  final String topicId;

  /// The option picked, or -1 when the question was left unanswered.
  final int selected;

  bool get answered => selected >= 0;

  Map<String, dynamic> toMap() => {
    'q': questionId,
    't': topicId,
    's': selected,
  };

  factory ExamItem.fromMap(dynamic raw) {
    final m = raw is Map ? raw : const {};
    return ExamItem(
      questionId: asString(m['q']),
      topicId: asString(m['t']),
      selected: asIntOrNull(m['s']) ?? -1,
    );
  }
}

/// A finished WAEC exam: `examResults/{id}`.
///
/// Written once, when the exam is submitted, alongside its attempts. It
/// exists so an exam can be reviewed after a reload and listed in the
/// subject's history: attempts alone cannot say which answers were one
/// sitting. Owner-only, never updated (see `firestore.rules`).
class ExamResult {
  const ExamResult({
    required this.id,
    required this.subjectId,
    required this.items,
    required this.correct,
    required this.timed,
    required this.durationSeconds,
    this.submittedAt,
  });

  final String id;
  final String subjectId;
  final List<ExamItem> items;

  /// Right answers. Unanswered questions count as not right.
  final int correct;
  final bool timed;

  /// Time spent, submit minus start.
  final int durationSeconds;

  /// Null until the server timestamp comes back.
  final DateTime? submittedAt;

  int get total => items.length;
  int get answered => items.where((i) => i.answered).length;
  double get percent => total == 0 ? 0 : correct * 100 / total;

  /// The fields a client writes; `userId` and `submittedAt` are added by
  /// the repository.
  Map<String, dynamic> toFirestore() => {
    'subjectId': subjectId,
    'items': [for (final i in items) i.toMap()],
    'total': total,
    'correct': correct,
    'timed': timed,
    'durationSeconds': durationSeconds,
  };

  factory ExamResult.fromFirestore(DocumentSnapshot doc) {
    final d = docData(doc);
    final items = d['items'] is List
        ? [for (final raw in d['items'] as List) ExamItem.fromMap(raw)]
        : const <ExamItem>[];
    return ExamResult(
      id: doc.id,
      subjectId: asString(d['subjectId']),
      items: items,
      correct: asInt(d['correct']),
      timed: asBool(d['timed']),
      durationSeconds: asInt(d['durationSeconds']),
      submittedAt: d['submittedAt'] is Timestamp
          ? (d['submittedAt'] as Timestamp).toDate()
          : null,
    );
  }

  /// Built from the exam as it was sat.
  factory ExamResult.fromSitting({
    required String id,
    required String subjectId,
    required List<Question> questions,
    required Map<int, int> answers,
    required bool timed,
    required int durationSeconds,
  }) {
    final items = [
      for (var i = 0; i < questions.length; i++)
        ExamItem(
          questionId: questions[i].id,
          topicId: questions[i].topicId,
          selected: answers[i] ?? -1,
        ),
    ];
    var correct = 0;
    for (var i = 0; i < questions.length; i++) {
      if (answers[i] != null && answers[i] == questions[i].correctIndex) {
        correct++;
      }
    }
    return ExamResult(
      id: id,
      subjectId: subjectId,
      items: items,
      correct: correct,
      timed: timed,
      durationSeconds: durationSeconds,
    );
  }
}

/// How one topic went in an exam.
class TopicScore {
  const TopicScore(this.topicId, this.correct, this.total);
  final String topicId;
  final int correct;
  final int total;
  double get fraction => total == 0 ? 0 : correct / total;
}

/// The topics an exam went worst in, weakest first, at most [limit].
///
/// Marked against [questions] (by id), so the verdict is the current
/// answer key. Only topics with a question missed are listed: a topic
/// answered perfectly is not weak however small its share.
List<TopicScore> weakestTopics(
  List<ExamItem> items,
  Map<String, Question> questions, {
  int limit = 3,
}) {
  final right = <String, int>{};
  final total = <String, int>{};
  for (final item in items) {
    if (item.topicId.isEmpty) continue;
    final q = questions[item.questionId];
    if (q == null) continue;
    total[item.topicId] = (total[item.topicId] ?? 0) + 1;
    if (item.answered && item.selected == q.correctIndex) {
      right[item.topicId] = (right[item.topicId] ?? 0) + 1;
    }
  }
  final scores = [
    for (final t in total.keys)
      if ((right[t] ?? 0) < total[t]!) TopicScore(t, right[t] ?? 0, total[t]!),
  ];
  // weakest first; among equals, the topic with more questions missed
  scores.sort((a, b) {
    final byFraction = a.fraction.compareTo(b.fraction);
    if (byFraction != 0) return byFraction;
    return (b.total - b.correct).compareTo(a.total - a.correct);
  });
  return scores.take(limit).toList();
}
