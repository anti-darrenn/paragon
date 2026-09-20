import 'package:cloud_firestore/cloud_firestore.dart';

import 'firestore_parsing.dart';

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
    final d = docData(doc);
    return Unit(
      id: doc.id,
      subjectId: asString(d['subjectId']),
      name: asString(d['name']),
      order: asInt(d['order']),
    );
  }
}
