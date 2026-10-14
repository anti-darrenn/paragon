import 'package:cloud_firestore/cloud_firestore.dart';

import 'firestore_parsing.dart';

class Question {
  final String id;
  final String topicId;
  final String subjectId;
  final String text;
  final List<String> options;
  final int correctIndex;
  final String explanation;
  final String source;
  final int? year;

  /// `ai_generated` on the procedurally generated corpus, empty on scraped
  /// past questions. What tells a student "Paragon practice" from a real
  /// past paper — see [provenanceLabel].
  final String origin;

  /// A diagram the question depends on: a `lessonAssets` id, or null.
  /// Set on scraped past questions by `tools/scraper/10_fetch_question_images.js`.
  final String? imageId;

  /// A picture belonging to the worked answer, shown with the explanation.
  final String? explanationImageId;

  const Question({
    required this.id,
    required this.topicId,
    required this.subjectId,
    required this.text,
    required this.options,
    required this.correctIndex,
    required this.explanation,
    required this.source,
    this.year,
    this.origin = '',
    this.imageId,
    this.explanationImageId,
  });

  factory Question.fromFirestore(DocumentSnapshot doc) {
    final d = docData(doc);
    return Question(
      id: doc.id,
      topicId: asString(d['topicId']),
      subjectId: asString(d['subjectId']),
      text: asString(d['text']),
      options: asStringList(d['options']),
      // -1 means "no verified answer" and is what the app already treats as
      // unanswerable, so it is the right fallback for a missing or unusable
      // value rather than 0, which would silently mark option A correct.
      correctIndex: asIntOrNull(d['correctIndex']) ?? -1,
      explanation: asString(d['explanation']),
      source: asString(d['source'], fallback: 'drill'),
      year: asIntOrNull(d['year']),
      origin: asString(d['origin']),
      imageId: asStringOrNull(d['imageId']),
      explanationImageId: asStringOrNull(d['explanationImageId']),
    );
  }

  /// Written by Paragon's generators, not taken from an exam paper.
  bool get isGenerated => origin == 'ai_generated';

  /// A question from a real exam paper. Generated questions are stamped
  /// `source: 'drill'`, but the origin is checked first so a generated
  /// question can never claim to be a past question.
  bool get isPastQuestion => !isGenerated && source == 'waec';

  /// What a student is told about where a question came from: "WAEC 2018",
  /// "WAEC past question" when the year is unknown, "Paragon practice" for
  /// generated ones, and null — no badge — for anything unclassified.
  /// Adding NECO or JAMB later is one case here.
  String? get provenanceLabel {
    if (isGenerated) return 'Paragon practice';
    if (isPastQuestion) {
      return year == null ? 'WAEC past question' : 'WAEC $year';
    }
    return null;
  }
}
