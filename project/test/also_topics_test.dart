import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paragon/core/models/question.dart';
import 'package:paragon/core/questions/question_draft.dart';
import 'package:paragon/core/repositories/admin_question_repository.dart';
import 'package:paragon/core/repositories/also_in_topic.dart';

/// A question can count for several topics: one main `topicId`, and
/// `alsoTopicIds` (owner's decision, 2026-10-17).
Question _q(String id) => Question(
  id: id,
  topicId: 'main',
  subjectId: 's',
  text: id,
  options: const ['a', 'b'],
  correctIndex: 0,
  explanation: '',
  source: 'waec',
);

void main() {
  group('mergeAlso', () {
    final own = [for (var i = 0; i < 20; i++) _q('own$i')];
    test('also-questions take the last places, never past the size', () {
      final out = mergeAlso(own, [_q('x1'), _q('x2')], 20);
      expect(out, hasLength(20));
      expect(out.map((q) => q.id), containsAll(['x1', 'x2']));
      expect(out.map((q) => q.id), isNot(contains('own19')));
    });
    test('never the same question twice', () {
      final out = mergeAlso([_q('a'), _q('b')], [_q('b')], 20);
      expect(out.map((q) => q.id), ['a', 'b']);
    });
    test('CONTROL: with none, the session is the topic\'s own', () {
      expect(
        mergeAlso(own, const [], 20).map((q) => q.id),
        own.map((q) => q.id),
      );
    });
  });

  test(
    'alsoInTopic finds questions tagged with the topic, answerable only',
    () async {
      final db = FakeFirebaseFirestore();
      Future<void> put(String id, Map<String, Object?> d) =>
          db.collection('questions').doc(id).set({
            'topicId': 'other',
            'subjectId': 's',
            'text': id,
            'options': ['a', 'b'],
            'correctIndex': 0,
            'hasAnswer': true,
            ...d,
          });
      await put('tagged', {
        'alsoTopicIds': ['indices'],
      });
      await put('hidden', {
        'alsoTopicIds': ['indices'],
        'hasAnswer': false,
      });
      await put('elsewhere', {
        'alsoTopicIds': ['logs'],
      });
      await put('plain', {});
      final found = await alsoInTopic(db, 'indices', 5);
      expect(found.map((q) => q.id), ['tagged']);
      expect(found.single.alsoTopicIds, ['indices']);
    },
  );

  test(
    'the studio saves extra topics, and removes the field when cleared',
    () async {
      final db = FakeFirebaseFirestore();
      await db.collection('questions').doc('q').set({
        'topicId': 'main',
        'subjectId': 's',
        'source': 'waec',
        'hasAnswer': true,
        'text': 'Q',
        'options': ['a', 'b'],
        'correctIndex': 0,
        'explanation': '',
      });
      final repo = AdminQuestionRepository(db);
      final before = QuestionDraft.fromMap(
        (await db.doc('questions/q').get()).data()!,
      );
      final tagged = before.copyWith(alsoTopicIds: ['logs', 'indices']);
      expect(tagged.changedFrom(before), {'alsoTopicIds'});
      await repo.save(
        questionId: 'q',
        before: before,
        after: tagged,
        reason: 'Tests logs too',
        uid: 'rev',
      );
      expect((await db.doc('questions/q').get()).data()!['alsoTopicIds'], [
        'logs',
        'indices',
      ]);
      // Browsing the extra topic shows it apart from the topic's own.
      final page = await repo.browse(
        const QuestionFilter(subjectId: 's', topicId: 'logs'),
      );
      expect(page.questions, isEmpty);
      expect(page.also.map((q) => q.question.id), ['q']);

      await repo.save(
        questionId: 'q',
        before: tagged,
        after: tagged.copyWith(alsoTopicIds: const []),
        reason: 'Only its own topic after all',
        uid: 'rev',
      );
      expect(
        (await db.doc('questions/q').get()).data()!.containsKey('alsoTopicIds'),
        isFalse,
      );
    },
  );
}
