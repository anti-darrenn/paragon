import 'package:cloud_firestore/cloud_firestore.dart';

import 'firestore_parsing.dart';

class Topic {
  final String id;
  final String unitId;
  final String subjectId;
  final String name;
  final int questionCount;
  final int order;

  /// Published, openable Learn items. Zero means "not known", never "no
  /// lessons" — the same convention as `subjects.topicCount` — so callers
  /// hide a count rather than draw "0 of 0".
  final int lessonCount;
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
    this.lessonCount = 0,
    this.hasNotes = false,
    this.notesMarkdown,
  });

  factory Topic.fromFirestore(DocumentSnapshot doc) {
    final d = docData(doc);
    return Topic(
      id: doc.id,
      unitId: asString(d['unitId']),
      subjectId: asString(d['subjectId']),
      name: asString(d['name']),
      questionCount: asInt(d['questionCount']),
      order: asInt(d['order']),
      lessonCount: asInt(d['lessonCount']),
      hasNotes: asBool(d['hasNotes']),
      notesMarkdown: d['notesMarkdown'] == null ? null : asString(d['notesMarkdown']),
    );
  }
}
