import 'package:cloud_firestore/cloud_firestore.dart';

import '../content/question_counts.dart';
import 'firestore_parsing.dart';

class Subject {
  final String id;
  final String name;
  final int unitCount;

  /// How many topics the subject has, written by the seeders and kept
  /// true nightly by `tools/admin/jobs.js --job=counts`.
  ///
  /// It is the denominator for a subject-level progress ring. Zero means
  /// "not known", not "no topics" — a subject seeded before the field
  /// existed reads zero until the job next runs — so callers must treat
  /// zero as "cannot show a ring" rather than as an empty course.
  final int topicCount;

  /// How many questions a student can be served in this subject — only
  /// those with `hasAnswer: true` — kept true nightly by
  /// `tools/admin/jobs.js --job=counts`. Zero means "not known", like
  /// [topicCount], so callers hide the number rather than show 0.
  final int questionCount;

  /// [questionCount] split into past and practice questions, by the same
  /// job and from the same query as each topic's split, so the welcome
  /// ticker and the course page always agree.
  final int pastQuestionCount;
  final int practiceQuestionCount;

  /// Published theory (Paper 2) questions. The theory tile appears at
  /// `kTheoryMinQuestions`.
  final int theoryCount;

  QuestionCounts get counts => QuestionCounts(
    past: pastQuestionCount,
    practice: practiceQuestionCount,
    total: questionCount,
  );

  const Subject({
    required this.id,
    required this.name,
    required this.unitCount,
    this.topicCount = 0,
    this.questionCount = 0,
    this.pastQuestionCount = 0,
    this.practiceQuestionCount = 0,
    this.theoryCount = 0,
  });

  factory Subject.fromFirestore(DocumentSnapshot doc) {
    final d = docData(doc);
    return Subject(
      id: doc.id,
      name: asString(d['name']),
      unitCount: asInt(d['unitCount']),
      topicCount: asInt(d['topicCount']),
      questionCount: asInt(d['questionCount']),
      pastQuestionCount: asInt(d['pastQuestionCount']),
      practiceQuestionCount: asInt(d['practiceQuestionCount']),
      theoryCount: asInt(d['theoryCount']),
    );
  }
}
