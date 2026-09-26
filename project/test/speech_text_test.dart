import 'package:flutter_test/flutter_test.dart';
import 'package:paragon/features/study/read_aloud/speech_text.dart';

/// LaTeX to spoken British English, for read-aloud.
///
/// Table-driven so a failure names the input. The controls at the bottom
/// are what keep the rest honest: prose must come out untouched, and money
/// must stay money — a converter that turned every `$` into maths, or
/// "tidied" ordinary sentences, would pass most of the maths cases.
void main() {
  group('speakMath', () {
    const cases = <String, String>{
      // Fractions
      r'\frac{a}{b}': 'a over b',
      r'\dfrac{p}{q}': 'p over q',
      r'\frac{1}{2}': 'one half',
      r'\frac{3}{4}': 'three quarters',
      r'\frac{2}{3}': 'two thirds',
      r'\frac{5}{8}': 'five eighths',
      r'\frac12': 'one half',
      r'\frac{x+1}{2}': 'x plus 1, all over 2',
      r'\frac{1}{x+1}': '1 over the quantity x plus 1',
      r'\frac{22}{7}': '22 over 7',
      // Powers
      r'x^2': 'x squared',
      r'x^3': 'x cubed',
      r'x^n': 'x to the power n',
      r'x^{2}': 'x squared',
      r'2^5': '2 to the power 5',
      r'x^{-1}': 'x to the power minus 1',
      r'x^{2n+1} = y': 'x to the power 2 n plus 1, equals y',
      // Roots
      r'\sqrt{x}': 'the square root of x',
      r'\sqrt{16}': 'the square root of 16',
      r'\sqrt[3]{x}': 'the cube root of x',
      r'\sqrt[3]{27} = 3': 'the cube root of 27 equals 3',
      r'\sqrt{x+1} = 3': 'the square root of x plus 1, equals 3',
      // Subscripts and bases
      r'x_1': 'x sub 1',
      r'x_1 + x_2': 'x sub 1 plus x sub 2',
      r'101_2': 'one zero one, base two',
      r'1011_{2}': 'one zero one one, base two',
      r'17_8': 'one seven, base eight',
      r'H_2O': 'H sub 2 O',
      // Greek
      r'\alpha + \beta': 'alpha plus beta',
      r'\theta': 'theta',
      r'\Delta x': 'capital delta x',
      r'2\pi r': '2 pi r',
      // Operators and relations
      r'2 \times 3': '2 times 3',
      r'a \cdot b': 'a times b',
      r'6 \div 2': '6 divided by 2',
      r'x = \pm 3': 'x equals plus or minus 3',
      r'x \neq 0': 'x is not equal to 0',
      r'x \leq 5': 'x is less than or equal to 5',
      r'y \geq 2': 'y is greater than or equal to 2',
      r'x < 3': 'x is less than 3',
      r'\pi \approx 3.14': 'pi is approximately equal to 3.14',
      r'50\%': '50 percent',
      // Trig and logs
      r'\sin x': 'sine of x',
      r'\cos(A+B)': 'cos of A plus B',
      r'\tan \theta': 'tan of theta',
      r'\sin 30^\circ': 'sine of 30 degrees',
      r'\sin^2 x + \cos^2 x = 1':
          'sine squared of x plus cos squared of x equals 1',
      r'\sin^{-1} x': 'inverse sine of x',
      r'\log_2 8 = 3': 'log base 2 of 8 equals 3',
      r'\log_{10} 100': 'log base 10 of 100',
      r'\ln x': 'natural log of x',
      r'\log x': 'log of x',
      // Constants and units
      r'\infty': 'infinity',
      r'90\degree': '90 degrees',
      r'45^\circ': '45 degrees',
      r'30^{\circ}C': '30 degrees Celsius',
      // Text inside maths
      r'\textbf{Note}': 'Note',
      r'\textit{area}': 'area',
      r'5\text{ cm}^2': '5 cm squared',
      // Brackets and functions
      r'f(x) = 2x + 1': 'f of x equals 2 x plus 1',
      r'|x - 2|': 'the modulus of x minus 2',
      r'2(x + 1)': '2 open bracket x plus 1 close bracket',
      r'\left( x \right)': 'open bracket x close bracket',
      r'1{,}000': '1,000',
      // Anything unknown is "expression", never a backslash
      r'\mathscr{L}': 'expression',
      r'\foo': 'expression',
      r'a \weird b': 'a expression b',
    };

    cases.forEach((input, expected) {
      test(input, () => expect(speakMath(input), expected));
    });

    test('never speaks a backslash, whatever it is given', () {
      for (final input in [
        r'\unknowncommand{x}',
        r'\\',
        r'\,',
        r'\frac{\foo}{\bar}',
        r'\sqrt',
        r'{{{',
        r'}}}',
        r'x^',
        r'\begin{pmatrix} 1 & 2 \\ 3 & 4 \end{pmatrix}',
      ]) {
        expect(speakMath(input), isNot(contains(r'\')), reason: input);
      }
    });
  });

  group('speakText', () {
    test('inline maths inside prose', () {
      expect(
        speakText(r'Solve \(x^2 = 4\) for \(x\).'),
        'Solve x squared equals 4 for x.',
      );
    });

    test('display maths, both delimiters', () {
      expect(speakText(r'\[ \frac{a}{b} \]'), 'a over b');
      expect(speakText(r'$$x^2$$'), 'x squared');
    });

    test(r'\textbf and \textit read as their text', () {
      expect(
        speakText(r'\textbf{Bold} and \textit{italic}'),
        'Bold and italic',
      );
    });

    test(r'\vspace is silent', () {
      expect(speakText(r'The \vspace{1cm} gap'), 'The gap');
    });

    test('a command in prose is spoken, never recited', () {
      expect(speakText(r'Take \pi as 3.14'), 'Take pi as 3.14');
      expect(speakText(r'See \mathscr here'), 'See expression here');
    });

    test('unicode fractions and bases', () {
      expect(speakText('Half is ½'), 'Half is one half');
      expect(speakText('About 2½ hours'), 'About 2 and a half hours');
      expect(
        speakText('Convert 1011₂ to base ten'),
        'Convert one zero one one, base two to base ten',
      );
    });

    test('money', () {
      expect(speakText(r'It costs $5.'), 'It costs 5 dollars.');
      expect(speakText(r'Only \$1 today'), 'Only 1 dollar today');
      expect(speakText(r'$2.50 each'), '2.50 dollars each');
      expect(speakText(r'Earn $5 million'), 'Earn 5 million dollars');
      expect(speakText('Pay ₦500.'), 'Pay 500 naira.');
    });

    // ── Controls ──

    test('CONTROL: plain prose comes out exactly as it went in', () {
      const prose =
          'A number base is the number of digits a place-value system '
          'uses. In base ten there are ten digits: 0 to 9. Remember it!';
      expect(speakText(prose), prose);
    });

    test(r'CONTROL: "$5 and $10" is money, not a maths span', () {
      // Were `$` a delimiter, "5 and " would be read as an expression.
      expect(
        speakText(r'A pen costs $5 and a book $10.'),
        'A pen costs 5 dollars and a book 10 dollars.',
      );
    });

    test(r'CONTROL: a lone $ with no amount is left alone', () {
      expect(speakText(r'The $ sign'), r'The $ sign');
    });
  });
}
