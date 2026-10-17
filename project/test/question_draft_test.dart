import 'package:flutter_test/flutter_test.dart';
import 'package:paragon/core/questions/question_draft.dart';

/// The studio's question editor: what blocks a save, what only warns, and
/// how options and the answer move together.
void main() {
  const good = QuestionDraft(
    text: r'Express \(0.6\) as a fraction',
    options: ['3/5', '2/3', '6/10', '1/6'],
    correctIndex: 0,
    explanation: r'\(0.6 = \frac{6}{10} = \frac{3}{5}\)',
    hasAnswer: true,
  );

  List<String> blocks(QuestionDraft d) => [
    for (final i in checkDraft(d))
      if (i.blocks) i.message,
  ];
  List<String> warns(QuestionDraft d) => [
    for (final i in checkDraft(d))
      if (!i.blocks) i.message,
  ];

  test('CONTROL: a sound question has nothing to say', () {
    expect(checkDraft(good), isEmpty);
  });

  group('blocks the save', () {
    test('an empty stem', () {
      expect(
        blocks(good.copyWith(text: '  ')),
        contains('The question is empty.'),
      );
    });
    test('an empty option', () {
      expect(
        blocks(good.copyWith(options: ['3/5', ' ', '6/10', '1/6'])),
        contains('Option B is empty.'),
      );
    });
    test('the same option twice, ignoring spaces and dollar signs', () {
      expect(
        blocks(good.copyWith(options: ['3/5', '3 / 5', '6/10', '1/6'])),
        contains('Options A and B are the same.'),
      );
    });
    test('too few or too many options', () {
      expect(
        blocks(good.copyWith(options: ['a'], correctIndex: 0)),
        isNotEmpty,
      );
      expect(
        blocks(good.copyWith(options: ['a', 'b', 'c', 'd', 'e', 'f', 'g'])),
        isNotEmpty,
      );
    });
    test('live with no answer marked', () {
      expect(
        blocks(good.copyWith(correctIndex: -1)),
        contains('Mark the right answer, or hide the question from students.'),
      );
      // Hidden, it may have no answer (the scraped corpus's -1).
      expect(
        blocks(good.copyWith(correctIndex: -1, hasAnswer: false)),
        isEmpty,
      );
    });
    test('an answer past the options', () {
      expect(blocks(good.copyWith(correctIndex: 4)), isNotEmpty);
    });
  });

  group('warns but saves', () {
    test('unclosed maths', () {
      expect(warns(good.copyWith(text: r'Find \(x + 1')), isNotEmpty);
    });
    test('"Expression 0.612", the 2018 typo', () {
      expect(
        warns(good.copyWith(text: 'Expression 0.612 in the form x/y')),
        contains('"Expression" at the start probably means "Express".'),
      );
    });
    test('ASCII maths outside \\( \\)', () {
      expect(warns(good.copyWith(text: 'Evaluate 2^(x+1)')), isNotEmpty);
      expect(warns(good.copyWith(text: r'Evaluate \(2^{x+1}\)')), isEmpty);
    });
    test('no explanation', () {
      expect(warns(good.copyWith(explanation: '')), isNotEmpty);
    });
    test('blocks come before warnings', () {
      final issues = checkDraft(good.copyWith(text: '', explanation: ''));
      expect(issues.first.blocks, isTrue);
      expect(issues.last.blocks, isFalse);
    });
  });

  group('options and the answer', () {
    test('removing an option before the answer keeps the answer on it', () {
      final d = good.copyWith(correctIndex: 2).withoutOption(0);
      expect(d.options, ['2/3', '6/10', '1/6']);
      expect(d.correctIndex, 1);
      expect(d.options[d.correctIndex], '6/10');
    });
    test('removing the answer clears it', () {
      expect(good.withoutOption(0).correctIndex, -1);
    });
    test('removing one after the answer leaves it', () {
      expect(good.withoutOption(3).correctIndex, 0);
    });
  });

  test('changedFrom names exactly the fields that differ, trimmed', () {
    expect(good.copyWith(text: '${good.text}  ').changedFrom(good), isEmpty);
    expect(good.copyWith(correctIndex: 1, explanation: 'x').changedFrom(good), {
      'correctIndex',
      'explanation',
    });
  });

  test('fromMap reads what toMap wrote, and survives junk', () {
    expect(QuestionDraft.fromMap(good.toMap()).changedFrom(good), isEmpty);
    final junk = QuestionDraft.fromMap({'options': 'no', 'correctIndex': '2'});
    expect(junk.options, isEmpty);
    expect(junk.correctIndex, -1);
    expect(junk.hasAnswer, isFalse);
  });
}
