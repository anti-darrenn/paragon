import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paragon/core/lessons/subject_index.dart';
import 'package:paragon/core/repositories/subject_index_repository.dart';

const _lesson = '''
# Number bases

::: definition Number base
The number of digits a place-value system uses.
:::

::: formula Place value
\\[ d_n b^n + \\cdots + d_0 \\]
:::

::: remember
There is no digit 8 in base 8.
:::

::: card
What does the subscript in \\(101_2\\) mean?
---
The base.
:::

::: definition
A definition with no term is skipped.
:::

::: tip
Tips are not indexed.
:::
''';

void main() {
  group('extractTopicIndex', () {
    final index = extractTopicIndex(
      topicId: 't1',
      topicName: 'Number bases',
      articles: const [('a1', _lesson)],
    );

    test('definitions and formulas keep their source and origin', () {
      expect(index.definitions.single.term, 'Number base');
      expect(index.definitions.single.body, contains('place-value'));
      expect(index.definitions.single.resourceId, 'a1');
      expect(index.formulas.single.title, 'Place value');
      expect(index.formulas.single.body, contains(r'\['));
    });

    test('cards come from definitions, formulas, remember and card blocks', () {
      expect(index.cards.map((c) => c.kind), [
        'definition',
        'formula',
        'remember',
        'card',
      ]);
      expect(index.cards.last.back, 'The base.');
      expect(index.cards[2].front, 'Remember: Number bases');
    });

    test('control: a definition without a term and a tip are not indexed', () {
      expect(index.definitions, hasLength(1));
      expect(index.cards.where((c) => c.back.contains('Tips')), isEmpty);
    });

    test('card ids are stable, distinct and safe as Firestore map keys', () {
      final again = extractTopicIndex(
        topicId: 't1',
        topicName: 'Number bases',
        articles: const [('a1', _lesson)],
      );
      expect(again.cards.map((c) => c.id), index.cards.map((c) => c.id));
      expect(
        index.cards.map((c) => c.id).toSet(),
        hasLength(index.cards.length),
      );
      for (final c in index.cards) {
        expect(c.id.contains('.'), isFalse, reason: c.id);
      }
    });

    test(
      'rewording a card gives it a new id, so its schedule starts fresh',
      () {
        final edited = extractTopicIndex(
          topicId: 't1',
          topicName: 'Number bases',
          articles: [
            ('a1', _lesson.replaceFirst('The base.', 'The number base.')),
          ],
        );
        expect(edited.cards.last.id, isNot(index.cards.last.id));
        expect(edited.cards.first.id, index.cards.first.id);
      },
    );
  });

  group('SubjectIndexRepository', () {
    Future<void> seed(
      FakeFirebaseFirestore db,
      String id,
      String status, {
      String body = _lesson,
      String type = 'article',
    }) => db.collection('topics/t1/resources').doc(id).set({
      'type': type,
      'title': id,
      'order': 1,
      'body': body,
      'subjectId': 's1',
      'topicId': 't1',
      'status': status,
    });

    test('rebuildTopic indexes only published articles', () async {
      final db = FakeFirebaseFirestore();
      await seed(db, 'live', 'published');
      await seed(
        db,
        'draft',
        'draft',
        body: '::: definition Secret\nNot yet.\n:::',
      );
      await SubjectIndexRepository(
        db,
      ).rebuildTopic(subjectId: 's1', topicId: 't1', topicName: 'Number bases');

      final index = SubjectIndex.fromFirestore(
        await db.doc('subjectIndex/s1').get(),
      );
      expect(index.definitions.map((d) => d.term), ['Number base']);
      expect(index.topics['t1']!.topicName, 'Number bases');
    });

    test('a topic with nothing published is removed from the index', () async {
      final db = FakeFirebaseFirestore();
      await seed(db, 'live', 'published');
      final repo = SubjectIndexRepository(db);
      await repo.rebuildTopic(subjectId: 's1', topicId: 't1', topicName: 'N');
      await db.doc('topics/t1/resources/live').update({'status': 'draft'});
      await repo.rebuildTopic(subjectId: 's1', topicId: 't1', topicName: 'N');

      final index = SubjectIndex.fromFirestore(
        await db.doc('subjectIndex/s1').get(),
      );
      expect(index.topics, isEmpty);
    });
  });
}
