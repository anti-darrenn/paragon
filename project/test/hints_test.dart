import 'package:flutter_test/flutter_test.dart';
import 'package:paragon/core/learn/hints.dart';

void main() {
  test('every step but the last is a hint', () {
    const e =
        'The curve crosses the x-axis where \\(y = 0\\).\n\n'
        '\\((x + 3)(x - 5) = 0\\)\n\n'
        'So \\(x = -3\\) or \\(x = 5\\).';
    expect(hintSteps(e), [
      'The curve crosses the x-axis where \\(y = 0\\).',
      '\\((x + 3)(x - 5) = 0\\)',
    ]);
  });

  test('CONTROL: the last step, which holds the answer, is never a hint', () {
    const e = 'Step one.\n\nThe answer is 7.';
    expect(hintSteps(e), ['Step one.']);
    expect(hintSteps(e), isNot(contains('The answer is 7.')));
  });

  test('a one-step or empty explanation gives no hints', () {
    expect(hintSteps(''), isEmpty);
    expect(hintSteps('   '), isEmpty);
    expect(hintSteps('Just the answer: 4.'), isEmpty);
    // single line breaks are one step, not several
    expect(hintSteps('Line one\nline two\nso 4.'), isEmpty);
  });

  test('CRLF, stray blank lines and whitespace-only lines are tolerated', () {
    const e = 'A.\r\n\r\n  \n\nB.\n \t\nC.';
    expect(hintSteps(e), ['A.', 'B.']);
  });
}
