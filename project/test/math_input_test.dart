import 'package:flutter_math_fork/tex.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paragon/core/widgets/math_field/math_input.dart';

final _span = RegExp(r'\\\((.*?)\\\)', dotAll: true);

void _parses(String latex) {
  for (final m in _span.allMatches(latex)) {
    expect(
      () => TexParser(m.group(1)!, const TexParserSettings()).parse(),
      returnsNormally,
      reason: 'does not parse: ${m.group(1)}',
    );
  }
}

/// Normal mode: maths typed the way people type it on a calculator.
void main() {
  group('plainToLatex', () {
    const cases = {
      'Solve x^2 + 1 = 5': r'Solve \(x^{2} + 1 = 5\)',
      'Simplify (x+1)/(x-1)': r'Simplify \(\frac{x+1}{x-1}\)',
      'What is 3/4 of 20?': r'What is \(\frac{3}{4}\) of 20?',
      'Find sqrt(2x+1)': r'Find \(\sqrt{2x+1}\)',
      'Express 0.(3) as a fraction': r'Express \(0.\overline{3}\) as a fraction',
      'Express 0.1(6) as a fraction': r'Express \(0.1\overline{6}\) as a fraction',
      'Express 0.3 rec as a fraction': r'Express \(0.\overline{3}\) as a fraction',
      'The area is pi r^2': r'The area is \(\pi r^{2}\)',
      'If x >= 3 and y != 0': r'If \(x \geq 3\) and \(y \neq 0\)',
      'An angle of 30 deg': r'An angle of \(30^{\circ}\)',
      'Evaluate log_2(8)': r'Evaluate \(\log_{2}(8)\)',
      'Find 10^-3 m': r'Find \(10^{-3}\) m',
      'x = -b +- sqrt(b^2 - 4ac)': r'\(x = -b \pm \sqrt{b^{2} - 4ac}\)',
      'Work out 2 * 3': r'Work out \(2 \times 3\)',
    };
    cases.forEach((plain, latex) {
      test(plain, () {
        final out = plainToLatex(plain);
        expect(out, latex);
        _parses(out);
      });
    });

    test('CONTROL: prose with numbers and letters is left alone', () {
      for (final s in [
        'In 2019 a car cost 5 million naira.',
        'I have 2 apples.',
        'A well-known x-ray machine.',
        'Choose (a) or (b).',
        'It costs \$5.',
      ]) {
        expect(plainToLatex(s), s, reason: s);
      }
    });

    test('LaTeX the author typed is kept exactly', () {
      const s = r'Find \(\int_0^1 x\,dx\) and 3/4';
      expect(plainToLatex(s), r'Find \(\int_0^1 x\,dx\) and \(\frac{3}{4}\)');
    });
  });

  group('the way back', () {
    test('a Normal-mode answer survives a round trip', () {
      for (final plain in [
        'Solve x^2 + 1 = 5',
        'Simplify (x+1)/(x-1)',
        'Express 0.(3) as a fraction',
        'Find sqrt(2x+1)',
        'If x >= 3 and y != 0',
      ]) {
        final latex = plainToLatex(plain);
        expect(showsInNormalMode(latex), isTrue, reason: latex);
        expect(plainToLatex(latexToPlain(latex)), latex);
      }
    });

    test('a matrix or display maths stays in LaTeX mode', () {
      expect(
        showsInNormalMode(r'\(\begin{pmatrix}1&2\\3&4\end{pmatrix}\)'),
        isFalse,
      );
      expect(showsInNormalMode(r'\[\int_0^1 f(x)\,dx\]'), isFalse);
    });

    test('plain prose shows in Normal mode as it is', () {
      expect(showsInNormalMode('Which of these is a prime?'), isTrue);
      expect(latexToPlain('Which of these is a prime?'),
          'Which of these is a prime?');
    });
  });

  group('the toolbar', () {
    test('LaTeX mode wraps a button outside maths in \\( \\)', () {
      final r = applySnippet('Find ', 5, 5, r'\frac{|}{}', latexMode: true);
      expect(r.text, r'Find \(\frac{}{}\)');
      expect(r.caret, 'Find \\(\\frac{'.length);
    });
    test('inside maths it types the command alone', () {
      const t = r'Find \(x + \)';
      final at = t.indexOf(r'\)');
      final r = applySnippet(t, at, at, r'\sqrt{|}', latexMode: true);
      expect(r.text, r'Find \(x + \sqrt{}\)');
    });
    test('a selection goes inside the braces', () {
      final r = applySnippet('0.3', 2, 3, r'\overline{|}', latexMode: true);
      expect(r.text, r'0.\(\overline{3}\)');
    });
    test('Normal mode types calculator text', () {
      final r = applySnippet('x', 1, 1, '^(|)', latexMode: false);
      expect(r.text, 'x^()');
      expect(r.caret, 3);
    });
  });
}
