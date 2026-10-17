import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_math_fork/tex.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paragon/core/latex/tex_preprocess.dart';
import 'package:paragon/core/widgets/full_latex_view.dart';

/// Every maths span in normalised text.
final _span = RegExp(r'\\\((.*?)\\\)|\\\[(.*?)\\\]|\$\$(.*?)\$\$', dotAll: true);

List<String> _mathIn(String s) => [
  for (final m in _span.allMatches(s)) m.group(1) ?? m.group(2) ?? m.group(3)!,
];

bool _parses(String tex) {
  try {
    TexParser(tex, const TexParserSettings()).parse();
    return true;
  } catch (_) {
    return false;
  }
}

void main() {
  // Shared with tools/site/tex_preprocess.test.js: the JS mirror must give
  // the same output for every case.
  final cases = (jsonDecode(
    File('test/fixtures/tex_preprocess_cases.json').readAsStringSync(),
  ) as List).cast<Map<String, dynamic>>();

  group('normalizeTex — the shared cases', () {
    for (final c in cases) {
      final input = c['in'] as String;
      test(input.replaceAll('\n', r'\n'), () {
        final out = normalizeTex(input);
        expect(out, c['out']);
        expect(normalizeTex(out), out, reason: 'must be idempotent');
        for (final tex in _mathIn(out)) {
          expect(_parses(tex), isTrue, reason: 'does not parse: $tex');
        }
      });
    }
  });

  group('the owner\'s case', () {
    test('a bar over a recurring decimal typed without delimiters', () {
      expect(
        normalizeTex(r'Express 0.1\overline{6} as a fraction'),
        r'Express \(0.1\overline{6}\) as a fraction',
      );
    });

    testWidgets('renders as maths, not as source', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: FullLatexView(latex: r'Express 0.\overline{3}')),
        ),
      );
      expect(find.byType(Math), findsOneWidget);
      expect(find.textContaining(r'\overline'), findsNothing);
    });

    testWidgets('control: inside \\(..\\) it always rendered', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FullLatexView(latex: r'Express \(0.\overline{3}\)'),
          ),
        ),
      );
      expect(find.byType(Math), findsOneWidget);
    });
  });

  group('the corpus is left alone', () {
    test('no backslash, no change — dashes, tildes, quotes, dollars', () {
      for (final s in [
        'A blank ------ here',
        'about ~ 5 m',
        "5'' long",
        r'costs $4.50 and $3.00',
        '2--3 days',
      ]) {
        expect(normalizeTex(s), s);
      }
    });

    test('maths already delimited is untouched unless it needs help', () {
      for (final s in [
        r'Simplify \(\frac{2x-1}{x+3}\)',
        r'\[\int_0^1 x\,dx\]',
        r'$$\sqrt{2}$$ and \(\begin{pmatrix}1&2\\3&4\end{pmatrix}\)',
      ]) {
        expect(normalizeTex(s), s);
      }
    });

    test('a long fill-in blank stays, even in LaTeX text', () {
      expect(
        normalizeTex(r'\(x\) is ------ than \(y\)'),
        r'\(x\) is ------ than \(y\)',
      );
    });
  });

  group('dollarMathToParens (the editor\'s LaTeX mode)', () {
    test('Overleaf inline maths becomes \\(..\\)', () {
      expect(dollarMathToParens(r'Let $x^2$ be'), r'Let \(x^2\) be');
    });
    test('an escaped dollar and display maths are kept', () {
      expect(
        dollarMathToParens(r'\$5 and $$a$$'),
        r'\$5 and $$a$$',
      );
    });
    test(r'an unmatched $ becomes a literal dollar', () {
      expect(dollarMathToParens(r'costs $5'), r'costs \$5');
    });
  });

  group('the renderers agree', () {
    const samples = [
      r'\textbf{Bold \textit{and italic}} then \(x\)',
      r'\underline{Note} \texttt{code}',
      r'\section*{Heading} text',
    ];
    for (final s in samples) {
      testWidgets('light and full: $s', (tester) async {
        Future<String> semantics(Widget w) async {
          await tester.pumpWidget(MaterialApp(home: Scaffold(body: w)));
          return tester
              .getSemantics(find.byWidget(w).first)
              .label;
        }

        final full = await semantics(FullLatexView(latex: s));
        final light = await semantics(
          FullLatexView(latex: s, scrollWideMath: false),
        );
        expect(light, full);
      });
    }

    testWidgets('nested styles render without raw commands', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FullLatexView(latex: r'\textbf{Bold \textit{and italic}}'),
          ),
        ),
      );
      final rich = tester.widget<RichText>(find.byType(RichText).first);
      final text = rich.text.toPlainText();
      expect(text, contains('Bold and italic'));
      expect(text, isNot(contains(r'\textit')));
    });
  });
}
