import 'package:cloud_firestore/cloud_firestore.dart';

class Topic {
  final String id;
  final String unitId;
  final String subjectId;
  final String name;
  final int questionCount;
  final int order;

  const Topic({
    required this.id,
    required this.unitId,
    required this.subjectId,
    required this.name,
    required this.questionCount,
    required this.order,
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
    );
  }
}