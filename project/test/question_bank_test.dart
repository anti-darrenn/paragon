import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paragon/core/auth/staff_role.dart';
import 'package:paragon/core/questions/question_draft.dart';
import 'package:paragon/core/questions/servable.dart';
import 'package:paragon/core/repositories/admin_question_repository.dart';

/// The founder's question bank (owner's decision, 2026-10-17): only vetted
/// questions reach students; everything else is pending until the founder
/// approves it.
void main() {
  late FakeFirebaseFirestore db;
  late AdminQuestionRepository repo;

  Future<void> put(String id, {bool vetted = false, bool hasAnswer = true}) =>
      db.collection('questions').doc(id).set({
        'topicId': 't1',
        'subjectId': 's1',
        'source': 'drill',
        'text': 'Question $id',
        'options': ['a', 'b', 'c', 'd'],
        'correctIndex': 0,
        'explanation': '',
        'hasAnswer': hasAnswer,
        if (vetted) 'vetted': true,
      });

  setUp(() {
    db = FakeFirebaseFirestore();
    repo = AdminQuestionRepository(db);
  });

  group('what students are served', () {
    test('servable() keeps vetted, answered questions only', () async {
      await put('live', vetted: true);
      await put('pending');
      await put('retired', vetted: true, hasAnswer: false);
      final snap = await db.collection('questions').servable().get();
      expect(snap.docs.map((d) => d.id), ['live']);
    });

    test('isServable says the same for a question loaded by id', () {
      expect(isServable({'hasAnswer': true, 'vetted': true}), isTrue);
      // A question with no `vetted` field is pending: this is every
      // question in the bank on the day this ships.
      expect(isServable({'hasAnswer': true}), isFalse);
      expect(isServable({'hasAnswer': false, 'vetted': true}), isFalse);
      expect(isServable(null), isFalse);
    });
  });

  group('the bank', () {
    test('pending lists answered, unvetted questions; vetted the rest', () async {
      await put('a');
      await put('b', vetted: true);
      await put('c');
      await put('d', hasAnswer: false);
      final pending = await repo.pendingPage('t1');
      expect(pending.questions.map((q) => q.question.id), ['a', 'c']);
      final vetted = await repo.vettedPage('t1');
      expect(vetted.questions.map((q) => q.question.id), ['b']);
    });

    test('pending refills past a run of vetted questions', () async {
      for (var i = 0; i < 70; i++) {
        await put('v${i.toString().padLeft(3, '0')}', vetted: true);
      }
      await put('w_last');
      final pending = await repo.pendingPage('t1');
      expect(pending.questions.map((q) => q.question.id), ['w_last']);
    });

    test('approving vets the question with who and when', () async {
      await put('q');
      final d = QuestionDraft.fromMap((await db.doc('questions/q').get()).data()!);
      await repo.save(
        questionId: 'q',
        before: d,
        after: d,
        reason: 'Vetted',
        uid: 'founder',
        vet: true,
      );
      final saved = (await db.doc('questions/q').get()).data()!;
      expect(saved['vetted'], isTrue);
      expect(saved['vettedBy'], 'founder');
      expect(saved.containsKey('vettedAt'), isTrue);
      expect(isServable(saved), isTrue);
    });

    test('sending back removes the mark', () async {
      await put('q', vetted: true);
      final d = QuestionDraft.fromMap((await db.doc('questions/q').get()).data()!);
      await repo.save(
        questionId: 'q',
        before: d,
        after: d,
        reason: 'Back',
        uid: 'founder',
        vet: false,
      );
      final saved = (await db.doc('questions/q').get()).data()!;
      expect(saved['vetted'], isFalse);
      expect(saved.containsKey('vettedBy'), isFalse);
    });

    test('a retag records where the question came from', () async {
      await put('q');
      final d = QuestionDraft.fromMap((await db.doc('questions/q').get()).data()!);
      await repo.save(
        questionId: 'q',
        before: d,
        after: d,
        reason: 'Wrong topic',
        uid: 'founder',
        placement: const QuestionPlacement(
          subjectId: 's1',
          topicId: 't2',
          source: 'waec',
          year: 2019,
          sourceRef: 'WAEC May/June 2019',
          previousTopicId: 't1',
        ),
      );
      final saved = (await db.doc('questions/q').get()).data()!;
      expect(saved['topicId'], 't2');
      expect(saved['previousTopicId'], 't1');
      expect(saved['source'], 'waec');
      expect(saved['year'], 2019);
      expect(saved['sourceRef'], 'WAEC May/June 2019');
    });

    test('a new question is authored, pending, and has its history', () async {
      final id = await repo.create(
        draft: const QuestionDraft(
          text: r'Express \(0.\overline{3}\) as a fraction',
          options: ['1/3', '3/10', '1/30', '3/100'],
          correctIndex: 0,
          explanation: 'Let x = 0.333…; 10x − x = 3.',
          hasAnswer: true,
        ),
        placement: const QuestionPlacement(
          subjectId: 's1',
          topicId: 't1',
          source: 'drill',
          sourceRef: 'New General Mathematics SS1, p. 22',
        ),
        uid: 'founder',
      );
      final saved = (await db.doc('questions/$id').get()).data()!;
      expect(saved['origin'], 'authored');
      expect(saved['vetted'], isFalse);
      expect(saved['createdBy'], 'founder');
      expect(saved['sourceRef'], 'New General Mathematics SS1, p. 22');
      expect(saved.containsKey('year'), isFalse);
      expect(isServable(saved), isFalse);
      final history = await db.collection('questions/$id/history').get();
      expect(history.docs.single.data()['by'], 'founder');
    });
  });

  group('who is the founder', () {
    test('an admin with the founder claim', () {
      expect(
        StaffAccess.fromClaims({'admin': true, 'founder': true}).isFounder,
        isTrue,
      );
    });
    test('CONTROL: the claim alone, without admin, is not enough', () {
      expect(StaffAccess.fromClaims({'founder': true}).isFounder, isFalse);
      expect(
        StaffAccess.fromClaims({'reviewer': true, 'founder': true}).isFounder,
        isFalse,
      );
      expect(StaffAccess.fromClaims({'admin': true}).isFounder, isFalse);
    });
  });
}
