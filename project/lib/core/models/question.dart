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
    );
  }
}
