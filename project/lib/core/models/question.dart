import 'package:cloud_firestore/cloud_firestore.dart';

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
    final d = doc.data() as Map<String, dynamic>;
    return Question(
      id: doc.id,
      topicId: d['topicId'] as String,
      subjectId: d['subjectId'] as String? ?? '',
      text: d['text'] as String,
      options: List<String>.from(d['options'] as List),
      correctIndex: d['correctIndex'] != null ? (d['correctIndex'] as num).toInt() : -1,
      explanation: d['explanation'] as String,
      source: d['source'] as String? ?? 'drill',
      year: d['year'] != null ? (d['year'] as num).toInt() : null,
    );
  }
}