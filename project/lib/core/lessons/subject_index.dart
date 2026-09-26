import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/firestore_parsing.dart';
import 'lesson_doc.dart';

/// The glossary, formula sheet and revision-card source for one subject:
/// `subjectIndex/{subjectId}`, one document, so a student gets all three
/// features for one read.
///
/// Built from **published** lessons only, by the studio whenever a
/// reviewer publishes, unpublishes or deletes (and by "Rebuild index").
/// Each topic's entry is replaced whole, so an entry always reflects its
/// topic's published lessons exactly.
///
/// Bodies are kept as lesson-format source, so they render through the
/// same renderer as the lesson they came from.
class SubjectIndex {
  const SubjectIndex({required this.subjectId, required this.topics});

  final String subjectId;

  /// Keyed by topic id.
  final Map<String, TopicIndex> topics;

  static const empty = SubjectIndex(subjectId: '', topics: {});

  List<IndexedDefinition> get definitions =>
      [for (final t in topics.values) ...t.definitions]
        ..sort((a, b) => a.term.toLowerCase().compareTo(b.term.toLowerCase()));

  List<IndexedFormula> get formulas => [
    for (final t in topics.values) ...t.formulas,
  ];

  List<IndexedCard> get cards => [for (final t in topics.values) ...t.cards];

  factory SubjectIndex.fromFirestore(DocumentSnapshot doc) {
    final d = docData(doc);
    final raw = d['topics'];
    final topics = <String, TopicIndex>{};
    if (raw is Map) {
      raw.forEach((k, v) {
        if (v is Map) topics['$k'] = TopicIndex.fromMap('$k', v);
      });
    }
    return SubjectIndex(subjectId: doc.id, topics: topics);
  }
}

class TopicIndex {
  const TopicIndex({
    required this.topicId,
    this.topicName = '',
    this.definitions = const [],
    this.formulas = const [],
    this.cards = const [],
  });

  final String topicId;
  final String topicName;
  final List<IndexedDefinition> definitions;
  final List<IndexedFormula> formulas;
  final List<IndexedCard> cards;

  bool get isEmpty => definitions.isEmpty && formulas.isEmpty && cards.isEmpty;

  Map<String, Object?> toMap() => {
    'topicName': topicName,
    'definitions': [for (final d in definitions) d.toMap()],
    'formulas': [for (final f in formulas) f.toMap()],
    'cards': [for (final c in cards) c.toMap()],
  };

  factory TopicIndex.fromMap(String topicId, Map m) {
    List<Map> list(String k) => [
      for (final e in (m[k] is List ? m[k] as List : const []))
        if (e is Map) e,
    ];
    final name = asString(m['topicName']);
    return TopicIndex(
      topicId: topicId,
      topicName: name,
      definitions: [
        for (final e in list('definitions'))
          IndexedDefinition.fromMap(e, topicId, name),
      ],
      formulas: [
        for (final e in list('formulas'))
          IndexedFormula.fromMap(e, topicId, name),
      ],
      cards: [
        for (final e in list('cards')) IndexedCard.fromMap(e, topicId, name),
      ],
    );
  }
}

/// Where an entry came from, so the student can open the lesson.
mixin _Source {
  String get topicId;
  String get topicName;
  String get resourceId;
}

class IndexedDefinition with _Source {
  const IndexedDefinition({
    required this.term,
    required this.body,
    required this.topicId,
    required this.resourceId,
    this.topicName = '',
  });

  final String term;

  /// Lesson-format source of the definition's contents.
  final String body;
  @override
  final String topicId;
  @override
  final String topicName;
  @override
  final String resourceId;

  Map<String, Object?> toMap() => {
    'term': term,
    'body': body,
    'resourceId': resourceId,
  };

  factory IndexedDefinition.fromMap(Map m, String topicId, String topicName) =>
      IndexedDefinition(
        term: asString(m['term']),
        body: asString(m['body']),
        resourceId: asString(m['resourceId']),
        topicId: topicId,
        topicName: topicName,
      );
}

class IndexedFormula with _Source {
  const IndexedFormula({
    required this.title,
    required this.body,
    required this.topicId,
    required this.resourceId,
    this.topicName = '',
  });

  final String title;
  final String body;
  @override
  final String topicId;
  @override
  final String topicName;
  @override
  final String resourceId;

  Map<String, Object?> toMap() => {
    'title': title,
    'body': body,
    'resourceId': resourceId,
  };

  factory IndexedFormula.fromMap(Map m, String topicId, String topicName) =>
      IndexedFormula(
        title: asString(m['title']),
        body: asString(m['body']),
        resourceId: asString(m['resourceId']),
        topicId: topicId,
        topicName: topicName,
      );
}

/// One revision card. [id] is stable for as long as the card's source
/// block is unchanged — it is built from the topic and the block's key —
/// so a student's review schedule survives unrelated edits, and a card
/// whose wording changes starts fresh.
class IndexedCard with _Source {
  const IndexedCard({
    required this.id,
    required this.front,
    required this.back,
    required this.kind,
    required this.topicId,
    required this.resourceId,
    this.topicName = '',
  });

  final String id;
  final String front;
  final String back;

  /// `card`, `definition`, `formula` or `remember`.
  final String kind;
  @override
  final String topicId;
  @override
  final String topicName;
  @override
  final String resourceId;

  Map<String, Object?> toMap() => {
    'id': id,
    'front': front,
    'back': back,
    'kind': kind,
    'resourceId': resourceId,
  };

  factory IndexedCard.fromMap(Map m, String topicId, String topicName) =>
      IndexedCard(
        id: asString(m['id']),
        front: asString(m['front']),
        back: asString(m['back']),
        kind: asString(m['kind'], fallback: 'card'),
        resourceId: asString(m['resourceId']),
        topicId: topicId,
        topicName: topicName,
      );
}

/// The source text of a list of blocks, as written.
String _source(List<LessonBlock> blocks) =>
    blocks.map((b) => b.source).join('\n\n').trim();

/// Extracts one topic's index entry from its published articles.
///
/// [articles] is `(resourceId, body)` in lesson order. Definitions need a
/// term, formulas a title, and cards both sides — incomplete blocks are
/// skipped rather than indexed half-empty.
TopicIndex extractTopicIndex({
  required String topicId,
  required String topicName,
  required List<(String, String)> articles,
}) {
  final definitions = <IndexedDefinition>[];
  final formulas = <IndexedFormula>[];
  final cards = <IndexedCard>[];

  for (final (resourceId, body) in articles) {
    final doc = parseLessonDoc(body);
    for (final block in doc.blocks) {
      // Card ids become map keys in `study/{uid}.cards`, and Firestore
      // reads a `.` in an update path as nesting — callout keys contain
      // one (`callout.definition:…`), so it is replaced.
      final cardId = '$topicId:$resourceId:${block.key}'.replaceAll('.', '_');
      switch (block) {
        case CalloutBlock(kind: CalloutKind.definition):
          final body = _source(block.body);
          if (block.title.isEmpty || body.isEmpty) continue;
          definitions.add(
            IndexedDefinition(
              term: block.title,
              body: body,
              topicId: topicId,
              resourceId: resourceId,
            ),
          );
          cards.add(
            IndexedCard(
              id: cardId,
              front: block.title,
              back: body,
              kind: 'definition',
              topicId: topicId,
              resourceId: resourceId,
            ),
          );
        case CalloutBlock(kind: CalloutKind.formula):
          final body = _source(block.body);
          if (block.title.isEmpty || body.isEmpty) continue;
          formulas.add(
            IndexedFormula(
              title: block.title,
              body: body,
              topicId: topicId,
              resourceId: resourceId,
            ),
          );
          cards.add(
            IndexedCard(
              id: cardId,
              front: block.title,
              back: body,
              kind: 'formula',
              topicId: topicId,
              resourceId: resourceId,
            ),
          );
        case CalloutBlock(kind: CalloutKind.remember):
          final body = _source(block.body);
          if (body.isEmpty) continue;
          cards.add(
            IndexedCard(
              id: cardId,
              front: block.title.isEmpty ? 'Remember: $topicName' : block.title,
              back: body,
              kind: 'remember',
              topicId: topicId,
              resourceId: resourceId,
            ),
          );
        case CardBlock():
          if (block.front.isEmpty || block.back.isEmpty) continue;
          cards.add(
            IndexedCard(
              id: cardId,
              front: block.front,
              back: block.back,
              kind: 'card',
              topicId: topicId,
              resourceId: resourceId,
            ),
          );
        default:
          break;
      }
    }
  }

  return TopicIndex(
    topicId: topicId,
    topicName: topicName,
    definitions: definitions,
    formulas: formulas,
    cards: cards,
  );
}
