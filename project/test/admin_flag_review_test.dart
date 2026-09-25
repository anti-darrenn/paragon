import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paragon/core/repositories/admin_flag_repository.dart';
import 'package:paragon/core/repositories/flag_repository.dart';

/// Seeds question `q1` (answer B) and `q2`, with two open reports on q1,
/// one already-dismissed report on q1, and one open report on q2 — the
/// control: resolving q1 must never touch it.
Future<FakeFirebaseFirestore> _seed() async {
  final db = FakeFirebaseFirestore();
  await db.collection('questions').doc('q1').set({
    'topicId': 't1',
    'subjectId': 's1',
    'text': 'What is 2 + 2?',
    'options': ['3', '5', '4', '22'],
    'correctIndex': 1,
    'hasAnswer': true,
    'origin': 'ai_generated',
  });
  await db.collection('questions').doc('q2').set({
    'topicId': 't1',
    'subjectId': 's1',
    'text': 'Other',
    'options': ['a', 'b'],
    'correctIndex': 0,
    'hasAnswer': true,
  });
  Future<void> flag(
    String id,
    String q,
    String reason, {
    String? status,
    int day = 1,
  }) {
    return db.collection('flags').doc(id).set({
      'questionId': q,
      'userId': 'u-$id',
      'reason': reason,
      'createdAt': Timestamp.fromDate(DateTime(2026, 9, day)),
      'status': ?status,
    });
  }

  await flag('f1', 'q1', 'wrong_answer', day: 2);
  await flag('f2', 'q1', 'wrong_answer', day: 3);
  await flag('f3', 'q1', 'rendering', status: 'dismissed', day: 1);
  await flag('f4', 'q2', 'unclear_question', day: 4);
  return db;
}

Future<Map<String, dynamic>> _doc(
  FakeFirebaseFirestore db,
  String path,
) async => (await db.doc(path).get()).data()!;

void main() {
  group('parsing', () {
    test('a report with no status reads as open', () async {
      final db = await _seed();
      final report = ProblemReport.fromFirestore(
        await db.doc('flags/f1').get(),
      );
      expect(report.status, FlagStatus.open);
      expect(report.isOpen, isTrue);
    });

    test('unknown status and reason fall back to open and other', () {
      expect(FlagStatus.parse('archived'), FlagStatus.open);
      expect(FlagStatus.parse(null), FlagStatus.open);
      expect(FlagReason.parse('nonsense'), FlagReason.other);
      expect(FlagReason.parse('wrong_answer'), FlagReason.wrongAnswer);
    });
  });

  group('groupReports', () {
    ProblemReport r(
      String id,
      String q, {
      FlagStatus s = FlagStatus.open,
      int day = 1,
    }) => ProblemReport(
      id: id,
      questionId: q,
      reason: FlagReason.wrongAnswer,
      status: s,
      createdAt: DateTime(2026, 9, day),
    );

    test('groups by question, open first, then by open count, then newest', () {
      final rows = groupReports([
        r('a', 'resolved', s: FlagStatus.fixed, day: 9),
        r('b', 'one', day: 8),
        r('c', 'two', day: 1),
        r('d', 'two', day: 2),
        r('e', 'one-older', day: 3),
      ], {});
      expect(rows.map((x) => x.questionId), [
        'two',
        'one',
        'one-older',
        'resolved',
      ]);
      expect(rows.first.openReports, hasLength(2));
      expect(rows.last.isOpen, isFalse);
    });

    test('reports with no questionId are dropped, not grouped under ""', () {
      expect(groupReports([r('a', '')], {}), isEmpty);
    });
  });

  group('AdminFlagRepository', () {
    test('queue groups every report and attaches the question', () async {
      final db = await _seed();
      final rows = await AdminFlagRepository(db).queue();
      expect(rows.map((r) => r.questionId), ['q1', 'q2']);
      final q1 = rows.first;
      expect(q1.reports, hasLength(3));
      expect(q1.openReports, hasLength(2));
      expect(q1.question!.isGenerated, isTrue);
      expect(q1.question!.question.correctIndex, 1);
    });

    test(
      'changeAnswer sets the answer, keeps the old one, closes only open reports on that question',
      () async {
        final db = await _seed();
        final repo = AdminFlagRepository(db);
        final row = await repo.forQuestion('q1');

        await repo.changeAnswer(row: row, newIndex: 2, uid: 'admin');

        final q = await _doc(db, 'questions/q1');
        expect(q['correctIndex'], 2);
        expect(q['previousCorrectIndex'], 1);
        expect(q['hasAnswer'], isTrue);
        expect(q['reviewedBy'], 'admin');
        // Nothing outside the rules' allow-list changed.
        expect(q['text'], 'What is 2 + 2?');
        expect(q['options'], ['3', '5', '4', '22']);

        expect((await _doc(db, 'flags/f1'))['status'], 'fixed');
        expect((await _doc(db, 'flags/f2'))['status'], 'fixed');
        expect((await _doc(db, 'flags/f2'))['resolvedBy'], 'admin');
        // Already closed: keeps the resolution it was given.
        expect((await _doc(db, 'flags/f3'))['status'], 'dismissed');
        // Control: a report on another question is untouched.
        expect((await _doc(db, 'flags/f4')).containsKey('status'), isFalse);
      },
    );

    test('retire hides the question and leaves its answer alone', () async {
      final db = await _seed();
      final repo = AdminFlagRepository(db);
      await repo.retire(row: await repo.forQuestion('q1'), uid: 'admin');

      final q = await _doc(db, 'questions/q1');
      expect(q['hasAnswer'], isFalse);
      expect(q['correctIndex'], 1);
      expect(q.containsKey('previousCorrectIndex'), isFalse);
      expect((await _doc(db, 'flags/f1'))['status'], 'fixed');
      expect((await _doc(db, 'flags/f4')).containsKey('status'), isFalse);
    });

    test('dismiss closes the reports and never writes the question', () async {
      final db = await _seed();
      final repo = AdminFlagRepository(db);
      await repo.dismiss(row: await repo.forQuestion('q1'), uid: 'admin');

      final q = await _doc(db, 'questions/q1');
      expect(q.containsKey('reviewedAt'), isFalse);
      expect(q['correctIndex'], 1);
      expect((await _doc(db, 'flags/f1'))['status'], 'dismissed');
      expect((await _doc(db, 'flags/f2'))['status'], 'dismissed');
      expect((await _doc(db, 'flags/f4')).containsKey('status'), isFalse);
    });

    test(
      'a missing question still loads, so its reports can be dismissed',
      () async {
        final db = await _seed();
        await db.doc('questions/q2').delete();
        final repo = AdminFlagRepository(db);
        final row = await repo.forQuestion('q2');
        expect(row.question, isNull);
        await repo.dismiss(row: row, uid: 'admin');
        expect((await _doc(db, 'flags/f4'))['status'], 'dismissed');
      },
    );
  });
}
