import 'package:cloud_firestore/cloud_firestore.dart';

class Topic {
  final String id;
  final String unitId;
  final String subjectId;
  final String name;
  final int questionCount;
  final int order;
  // Learn mode content. No seeded topic has these yet — always null/false
  // today, but null-safe so Learn mode doesn't need a schema migration
  // once notes get authored.
  final bool hasNotes;
  final String? notesMarkdown;

  const Topic({
    required this.id,
    required this.unitId,
    required this.subjectId,
    required this.name,
    required this.questionCount,
    required this.order,
    this.hasNotes = false,
    this.notesMarkdown,
  });

  factory Topic.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return Topic(
      id: doc.id,
      unitId: d['unitId'] as String,
      subjectId: d['subjectId'] as String,
      name: d['name'] as String,
      questionCount: (d['questionCount'] as num).toInt(),
      order: (d['order'] as num).toInt(),
      hasNotes: d['hasNotes'] as bool? ?? false,
      notesMarkdown: d['notesMarkdown'] as String?,
    );
  }
}
