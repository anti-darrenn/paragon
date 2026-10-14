import 'package:flutter_test/flutter_test.dart';
import 'package:paragon/core/lessons/lesson_check.dart';
import 'package:paragon/core/lessons/lesson_doc.dart';

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

  group('checkPublishable', () {
    test('control: real titles pass, including ones with "test" in them', () {
      for (final t in [
        'Laws of indices',
        'Tests for divisibility',
        'Sample space and events',
        'Testing a hypothesis',
        'Powers of the imaginary unit',
      ]) {
        expect(
          checkPublishable(type: 'article', title: t, body: 'Some text.'),
          isEmpty,
          reason: t,
        );
      }
    });

    test('the placeholders that reached students are caught', () {
      for (final t in [
        'test2',
        'test_article',
        'Test',
        'sample',
        'Lorem ipsum dolor',
        'untitled',
        'xxx',
        'new_video_1',
      ]) {
        expect(
          checkPublishable(type: 'article', title: t, body: 'Some text.'),
          isNotEmpty,
          reason: t,
        );
      }
    });

    test('empty title, empty article and linkless video are refused', () {
      expect(
        checkPublishable(type: 'article', title: ' ', body: 'x'),
        hasLength(1),
      );
      expect(
        checkPublishable(type: 'article', title: 'Indices', body: ''),
        hasLength(1),
      );
      expect(
        checkPublishable(type: 'video', title: 'Indices', youtubeId: null),
        hasLength(1),
      );
      expect(
        checkPublishable(type: 'video', title: 'Indices', youtubeId: 'abc123'),
        isEmpty,
      );
      expect(
        checkPublishable(type: 'exercise', title: 'Practice set'),
        isEmpty,
      );
    });

    test('broken maths in an article blocks publishing', () {
      expect(
        checkPublishable(
          type: 'article',
          title: 'Indices',
          body: r'\(\frac{1}\)',
        ),
        isNotEmpty,
      );
    });
  });

  test('a dropped KaTeX font is a warning, not an error', () {
    final issues = checkLesson(r'Set \(\mathcal{A}\) here.');
    expect(issues.single.severity, IssueSeverity.warning);
    expect(issues.single.message, contains('mathcal'));
    // Control: ordinary maths raises nothing, and a warning never blocks
    // publishing.
    expect(checkLesson(r'\(\mathbb{R}\) and \(\frac{a}{b}\)'), isEmpty);
    expect(
      checkPublishable(
        type: 'article',
        title: 'Sets',
        body: r'Set \(\mathcal{A}\) here.',
      ),
      isEmpty,
    );
  });
}
