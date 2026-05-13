import 'package:cloud_firestore/cloud_firestore.dart';

class Subject {
  final String id;
  final String name;
  final int unitCount;

  const Subject({
    required this.id,
    required this.name,
    required this.unitCount,
  });

  factory Subject.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return Subject(
      id: doc.id,
      name: d['name'] as String,
      unitCount: (d['unitCount'] as num).toInt(),
    );
  }
}