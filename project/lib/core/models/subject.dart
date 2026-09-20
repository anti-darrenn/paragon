import 'package:cloud_firestore/cloud_firestore.dart';

import 'firestore_parsing.dart';

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
    final d = docData(doc);
    return Subject(
      id: doc.id,
      name: asString(d['name']),
      unitCount: asInt(d['unitCount']),
    );
  }
}
