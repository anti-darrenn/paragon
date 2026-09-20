import 'package:cloud_firestore/cloud_firestore.dart';

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

  const Subject({
    required this.id,
    required this.name,
    required this.unitCount,
    this.topicCount = 0,
  });

  factory Subject.fromFirestore(DocumentSnapshot doc) {
    final d = docData(doc);
    return Subject(
      id: doc.id,
      name: asString(d['name']),
      unitCount: asInt(d['unitCount']),
      topicCount: asInt(d['topicCount']),
    );
  }
}
