import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paragon/core/questions/question_draft.dart';
import 'package:paragon/core/repositories/admin_flag_repository.dart';
import 'package:paragon/core/repositories/admin_question_repository.dart';

/// The studio's question edits: one batch writes the question and its
/// history record (the rules insist), and nothing outside the editable
/// fields ever changes.
Future<FakeFirebaseFirestore> _seed() async {
  final db = FakeFirebaseFirestore();
  Future<void> q(String id, Map<String, Object?> d) =>
      db.collection('questions').doc(id).set({
        'subjectId': 's1',
        'topicId': 't1',
        'source': 'waec',
        'year': 2018,
        'hasAnswer': true,
        'text': 'Q $id',
        'options': ['a', 'b', 'c', 'd'],
        'correctIndex': 0,
        'explanation': '',
        ...d,
      });
  await q('q1', {
    'text': 'Expression 0.612 in the form x/y',
    'options': ['153/250', '68/111', '61/100', '21/33'],
  });
  for (var i = 2; i <= 30; i++) {
    await q('q${i.toString().padLeft(2, '0')}', {});
  }
  await q('old', {'year': 2017});
  await q('hidden', {'hasAnswer': false, 'correctIndex': -1});
  await q('practice', {
    'source': 'drill',
    'origin': 'ai_generated',
    'year': null,
  });
  await db.collection('flags').doc('f1').set({
    'questionId': 'q1',
    'userId': 'u1',
    'reason': 'wrong_answer',
    'createdAt': Timestamp.fromDate(DateTime(2026, 10, 1)),
  });
  return db;
}

void main() {
  test('save writes the question and its history in one go', () async {
    final db = await _seed();
    final repo = AdminQuestionRepository(db);
    final flags = AdminFlagRepository(db);
    final row = await flags.forQuestion('q1');
    final before = QuestionDraft.fromMap(
      (await db.doc('questions/q1').get()).data()!,
    );
    final after = before.copyWith(
      text: r'Express \(0.\dot{6}\dot{1}\dot{2}\) in the form \(\frac{x}{y}\)',
      correctIndex: 1,
    );

    final editId = await repo.save(
      questionId: 'q1',
      before: before,
      after: after,
      reason: 'The paper had recurring dots; B is right',
      uid: 'rev',
      closeReports: row.openReports,
    );

    final q = (await db.doc('questions/q1').get()).data()!;
    expect(q['text'], startsWith(r'Express \(0.\dot{6}'));
    expect(q['correctIndex'], 1);
    expect(q['previousCorrectIndex'], 0);
    expect(q['editedBy'], 'rev');
    expect(q['lastEditId'], editId);
    // Seeder-only fields are never written.
    expect(q['subjectId'], 's1');
    expect(q['topicId'], 't1');
    expect(q['source'], 'waec');
    expect(q['year'], 2018);

    final h = (await db.doc('questions/q1/history/$editId').get()).data()!;
    expect(h['by'], 'rev');
    expect(h['reason'], 'The paper had recurring dots; B is right');
    expect((h['before'] as Map)['correctIndex'], 0);
    expect((h['after'] as Map)['correctIndex'], 1);

    expect((await db.doc('flags/f1').get()).data()!['status'], 'fixed');

    final history = await repo.history('q1');
    expect(history.single.after.correctIndex, 1);
    expect(history.single.before.text, 'Expression 0.612 in the form x/y');
  });

  test('CONTROL: an edit that keeps the answer writes no previousCorrectIndex, '
      'and leaves reports open unless asked', () async {
    final db = await _seed();
    final repo = AdminQuestionRepository(db);
    final before = QuestionDraft.fromMap(
      (await db.doc('questions/q1').get()).data()!,
    );
    await repo.save(
      questionId: 'q1',
      before: before,
      after: before.copyWith(text: 'Express 0.612 in the form x/y'),
      reason: 'Typo',
      uid: 'rev',
    );
    final q = (await db.doc('questions/q1').get()).data()!;
    expect(q.containsKey('previousCorrectIndex'), isFalse);
    expect(
      (await db.doc('flags/f1').get()).data()!.containsKey('status'),
      isFalse,
    );
  });

  group('browse', () {
    test('a paper, a page at a time, in id order', () async {
      final repo = AdminQuestionRepository(await _seed());
      const f = QuestionFilter(subjectId: 's1', year: 2018);
      final first = await repo.browse(f);
      expect(first.questions, hasLength(AdminQuestionRepository.pageSize));
      expect(first.hasMore, isTrue);
      final second = await repo.browse(f, after: first.last);
      // 30 live 2018 papers' questions: q1, q02…q30 (the old, hidden and
      // practice ones are not in it).
      expect(first.questions.length + second.questions.length, 30);
      expect(second.hasMore, isFalse);
      final ids = [
        ...first.questions.map((q) => q.question.id),
        ...second.questions.map((q) => q.question.id),
      ];
      expect(ids.toSet(), hasLength(30));
      expect(ids, isNot(contains('old')));
    });

    test('hidden questions only when asked for', () async {
      final repo = AdminQuestionRepository(await _seed());
      final hidden = await repo.browse(
        const QuestionFilter(subjectId: 's1', year: 2018, live: false),
      );
      expect(hidden.questions.map((q) => q.question.id), ['hidden']);
    });

    test('a topic by kind: practice is apart from past', () async {
      final repo = AdminQuestionRepository(await _seed());
      final practice = await repo.browse(
        const QuestionFilter(
          subjectId: 's1',
          kind: QuestionKind.practice,
          topicId: 't1',
        ),
      );
      expect(practice.questions.map((q) => q.question.id), ['practice']);
    });

    test('CONTROL: a whole subject is never queried in one go', () async {
      final repo = AdminQuestionRepository(await _seed());
      const f = QuestionFilter(subjectId: 's1', kind: QuestionKind.practice);
      expect(f.isQueryable, isFalse);
      expect((await repo.browse(f)).questions, isEmpty);
    });
  });

  test('byIds keeps the order asked for and skips missing ones', () async {
    final repo = AdminQuestionRepository(await _seed());
    final list = await repo.byIds(['q05', 'gone', 'q1', 'q02']);
    expect(list.map((q) => q.question.id), ['q05', 'q1', 'q02']);
  });
}
