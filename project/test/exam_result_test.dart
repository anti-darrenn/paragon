import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paragon/core/exam/exam_result.dart';
import 'package:paragon/core/exam/waec_grade.dart';
import 'package:paragon/core/models/question.dart';

Question _q(String id, String topic, {int correct = 0}) => Question(
  id: id,
  topicId: topic,
  subjectId: 's',
  text: id,
  options: const ['a', 'b', 'c', 'd'],
  correctIndex: correct,
  explanation: '',
  source: 'waec',
);

void main() {
  group('waecGradeFor', () {
    test('band edges', () {
      expect(waecGradeFor(100).code, 'A1');
      expect(waecGradeFor(75).code, 'A1');
      expect(waecGradeFor(74.9).code, 'B2');
      expect(waecGradeFor(70).code, 'B2');
      expect(waecGradeFor(65).code, 'B3');
      expect(waecGradeFor(60).code, 'C4');
      expect(waecGradeFor(55).code, 'C5');
      expect(waecGradeFor(50).code, 'C6');
      expect(waecGradeFor(49).code, 'D7');
      expect(waecGradeFor(40).code, 'E8');
      expect(waecGradeFor(39.9).code, 'F9');
      expect(waecGradeFor(0).code, 'F9');
    });

    test('out-of-range input is clamped, never throws', () {
      expect(waecGradeFor(-5).code, 'F9');
      expect(waecGradeFor(140).code, 'A1');
      expect(waecGradeFor(double.nan).code, 'F9');
    });

    test('credit means C6 or better', () {
      expect(waecGradeFor(50).isCredit, isTrue);
      expect(waecGradeFor(49).isCredit, isFalse);
    });

    test('rolling estimate is the mean of the latest three', () {
      expect(rollingPercent(const []), isNull);
      expect(rollingPercent(const [80]), 80);
      expect(rollingPercent(const [90, 60, 60, 0]), 70);
    });
  });

  group('ExamResult', () {
    final questions = [
      _q('q1', 'algebra'),
      _q('q2', 'algebra'),
      _q('q3', 'geometry', correct: 2),
    ];

    test('marks from the sitting; unanswered counts as not right', () {
      final r = ExamResult.fromSitting(
        id: 'e1',
        subjectId: 's',
        questions: questions,
        answers: {0: 0, 2: 1},
        timed: true,
        durationSeconds: 600,
      );
      expect(r.correct, 1);
      expect(r.total, 3);
      expect(r.answered, 2);
      expect(r.items[1].selected, -1);
      expect(r.percent, closeTo(33.3, 0.1));
    });

    test('round-trips through Firestore', () async {
      final db = FakeFirebaseFirestore();
      final r = ExamResult.fromSitting(
        id: 'e1',
        subjectId: 's',
        questions: questions,
        answers: {0: 0, 1: 3},
        timed: false,
        durationSeconds: 90,
      );
      await db.collection('examResults').doc('e1').set(r.toFirestore());
      final back = ExamResult.fromFirestore(
        await db.collection('examResults').doc('e1').get(),
      );
      expect(back.correct, 1);
      expect([for (final i in back.items) i.selected], [0, 3, -1]);
      expect(back.items.first.topicId, 'algebra');
      expect(back.timed, isFalse);
    });

    test('a malformed document parses without throwing', () async {
      final db = FakeFirebaseFirestore();
      await db.collection('examResults').doc('bad').set({
        'items': ['nonsense', 3, null],
        'correct': 'x',
      });
      final r = ExamResult.fromFirestore(
        await db.collection('examResults').doc('bad').get(),
      );
      expect(r.items, hasLength(3));
      expect(r.items.every((i) => !i.answered), isTrue);
      expect(r.correct, 0);
    });
  });

  group('weakestTopics', () {
    final byId = {
      for (final q in [
        _q('a1', 'algebra'),
        _q('a2', 'algebra'),
        _q('g1', 'geometry'),
        _q('g2', 'geometry'),
        _q('t1', 'trig'),
      ])
        q.id: q,
    };

    test('weakest first, perfect topics left out', () {
      final items = [
        const ExamItem(questionId: 'a1', topicId: 'algebra', selected: 0),
        const ExamItem(questionId: 'a2', topicId: 'algebra', selected: 1),
        const ExamItem(questionId: 'g1', topicId: 'geometry', selected: 1),
        const ExamItem(questionId: 'g2', topicId: 'geometry', selected: -1),
        const ExamItem(questionId: 't1', topicId: 'trig', selected: 0),
      ];
      final weak = weakestTopics(items, byId);
      expect([for (final t in weak) t.topicId], ['geometry', 'algebra']);
      expect(weak.first.correct, 0);
      expect(weak.first.total, 2);
    });

    test('CONTROL: a perfect exam has no weak topics', () {
      final items = [
        const ExamItem(questionId: 'a1', topicId: 'algebra', selected: 0),
        const ExamItem(questionId: 't1', topicId: 'trig', selected: 0),
      ];
      expect(weakestTopics(items, byId), isEmpty);
    });

    test('a question no longer found is skipped, not counted wrong', () {
      final items = [
        const ExamItem(questionId: 'gone', topicId: 'algebra', selected: 2),
      ];
      expect(weakestTopics(items, byId), isEmpty);
    });
  });
}
