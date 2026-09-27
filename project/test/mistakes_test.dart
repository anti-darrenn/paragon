import 'package:flutter_test/flutter_test.dart';
import 'package:paragon/core/progress/mistakes.dart';

AttemptRecord _a(
  String q,
  bool correct, {
  int picked = 1,
  String source = 'drill',
}) => AttemptRecord(
  questionId: q,
  topicId: 't',
  subjectId: 's',
  selectedIndex: picked,
  isCorrect: correct,
  source: source,
);

List<String> _ids(List<Mistake> m) => [for (final x in m) x.questionId];

void main() {
  test('a question answered wrong most recently is open', () {
    expect(_ids(openMistakes([_a('q1', false), _a('q2', true)])), ['q1']);
  });

  test('getting it right later clears it', () {
    // newest first: the correct answer came after the wrong one
    expect(openMistakes([_a('q1', true), _a('q1', false)]), isEmpty);
  });

  test('CONTROL: right then wrong again reopens it', () {
    expect(_ids(openMistakes([_a('q1', false), _a('q1', true)])), ['q1']);
  });

  test('only the latest wrong answer is kept, with what was picked', () {
    final open = openMistakes([
      _a('q1', false, picked: 3, source: 'waec'),
      _a('q1', false, picked: 0),
    ]);
    expect(open, hasLength(1));
    expect(open.single.selectedIndex, 3);
    expect(open.single.latest.source, 'waec');
  });

  test('keeps newest-first order and skips attempts with no question id', () {
    final open = openMistakes([
      _a('q3', false),
      _a('', false),
      _a('q1', false),
      _a('q2', true),
    ]);
    expect(_ids(open), ['q3', 'q1']);
  });

  test('every source has a label', () {
    for (final s in ['drill', 'waec', 'test', 'exercise', 'review']) {
      expect(mistakeSourceLabel(s), isNotEmpty);
    }
    expect(mistakeSourceLabel('waec'), 'WAEC exam');
  });
}
