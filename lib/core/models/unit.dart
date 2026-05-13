import 'package:cloud_firestore/cloud_firestore.dart';

class Unit {
  final String id;
  final String subjectId;
  final String name;
  final int order;

  const Unit({
    required this.id,
    required this.subjectId,
    required this.name,
    required this.order,
  });

  factory Unit.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return Unit(
      id: doc.id,
      subjectId: d['subjectId'] as String,
      name: d['name'] as String,
      order: (d['order'] as num).toInt(),
    );
  }
}