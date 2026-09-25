import 'package:flutter_test/flutter_test.dart';
import 'package:paragon/core/learn/exercise_session.dart';
import 'package:paragon/core/models/question.dart';

Question q(String id, {int correct = 1, int options = 4}) => Question(
  id: id,
  topicId: 't',
  subjectId: 's',
  text: 'Q $id',
  options: [for (var i = 0; i < options; i++) 'opt $i'],
  correctIndex: correct,
  explanation: '',
  source: 'drill',
);

void main() {
  test('right first time scores and moves on', () {
    final s = ExerciseSession([q('a'), q('b')]);
    s
      ..select(1)
      ..check();
    expect(s.step, ExerciseStep.correct);
    s.next();
    expect(s.index, 1);
    expect(s.step, ExerciseStep.answering);
    expect(s.firstTryCorrect, 1);
  });

  test('a wrong answer allows one retry and blocks the tried option', () {
    final s = ExerciseSession([q('a')])
      ..select(0)
      ..check();
    expect(s.step, ExerciseStep.retrying);
    expect(s.wrongOptions, {0});
    expect(s.selected, isNull);
    s.select(0);
    expect(s.selected, isNull, reason: 'a tried-wrong option cannot be re-picked');
  });

  test('right on the retry is shown correct but scored wrong', () {
    final s = ExerciseSession([q('a')])
      ..select(0)
      ..check()
      ..select(1)
      ..check();
    expect(s.step, ExerciseStep.correct);
    expect(s.firstTryCorrect, 0);
    expect(s.firstTries.single.selectedIndex, 0);
    expect(s.firstTries.single.isCorrect, isFalse);
  });

  test('a second miss reveals the answer', () {
    final s = ExerciseSession([q('a')])
      ..select(0)
      ..check()
      ..select(2)
      ..check();
    expect(s.step, ExerciseStep.revealed);
  });

  test('only the first try is recorded, once per question', () {
    final s = ExerciseSession([q('a'), q('b')])
      ..select(0)
      ..check()
      ..select(1)
      ..check()
      ..next()
      ..select(1)
      ..check()
      ..next();
    expect(s.isFinished, isTrue);
    expect(s.firstTries.map((t) => t.questionId), ['a', 'b']);
    expect(s.firstTryCorrect, 1);
  });

  test('checking with nothing selected does nothing', () {
    final s = ExerciseSession([q('a')])..check();
    expect(s.step, ExerciseStep.answering);
    expect(s.firstTries, isEmpty);
  });

  test('next is refused until the question is resolved', () {
    final s = ExerciseSession([q('a'), q('b')])..next();
    expect(s.index, 0);
  });

  test('a correctIndex outside the options is revealed, never scored', () {
    final s = ExerciseSession([q('bad', correct: 7)])
      ..select(0)
      ..check();
    expect(s.step, ExerciseStep.revealed);
    expect(s.firstTries, isEmpty);
  });

  test('control: -1 (no verified answer) is also never scored', () {
    final s = ExerciseSession([q('none', correct: -1)])
      ..select(0)
      ..check();
    expect(s.firstTries, isEmpty);
  });

  test('an empty set starts finished', () {
    expect(ExerciseSession(const []).isFinished, isTrue);
  });
}
