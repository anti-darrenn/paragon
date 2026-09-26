import 'package:flutter_test/flutter_test.dart';
import 'package:paragon/core/lessons/lesson_check.dart';

void main() {
  test('control: a clean lesson has no issues', () {
    expect(
      checkLesson(
        r'Inline \(x^2\) and display \[ \frac{a}{b} \] and $$y=1$$ and \$5.',
      ),
      isEmpty,
    );
  });

  test('broken maths is found, with its line', () {
    final issues = checkLesson(
      'First line.\nSecond has \\(\\frac{1}\\) bad maths.',
    );
    expect(issues.single.line, 2);
    expect(issues.single.message, contains("won't render"));
  });

  test('an unclosed inline delimiter is reported', () {
    final issues = checkLesson(r'Open \( x^2 and never close.');
    expect(issues.single.message, contains('never closed'));
  });

  test('a lone dollar is money, not maths', () {
    expect(checkLesson(r'It costs $5 and $10.'), isEmpty);
  });

  test('structural and maths issues come together, sorted by line', () {
    final issues = checkLesson('\\(\\frac{1}\\)\n::: check\nQ?\n- [x] a\n:::');
    expect(issues.map((i) => i.line), [1, 2]);
  });
}
