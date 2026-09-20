// A '$' in question text is currency, not a math delimiter.
//
// WAEC questions are full of money. While '$...$' was treated as inline math,
// a question reading "sold at $4.50 and $3.00 respectively" rendered the span
// between the two prices as math: the second price disappeared into it and the
// words came out as italic variables. Six seeded Mathematics questions read as
// nonsense because of it.
//
// The strings below are taken from the seeded corpus (classified_mathematics),
// not invented, so this test fails if the delimiter handling regresses on the
// content that actually shipped.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paragon/core/widgets/full_latex_view.dart';
import 'package:paragon/core/widgets/math_text.dart';

/// The text the reader actually sees, with math excluded.
///
/// Only the outermost RichText is read. It is first in tree order, and the
/// math widgets hang off it inside WidgetSpans, which carry no text of their
/// own - so anything drawn by Math.tex is skipped rather than flattened back
/// into the string. (Reading every RichText instead would reassemble the glyphs
/// flutter_math lays out one at a time, and "x+1" would look like plain text.)
String _plainText(WidgetTester tester) {
  final buf = StringBuffer();
  tester.widget<RichText>(find.byType(RichText).first).text.visitChildren((
    span,
  ) {
    if (span is TextSpan && span.text != null) buf.write(span.text);
    return true;
  });
  return buf.toString();
}

Future<void> _pump(WidgetTester tester, Widget child) => tester.pumpWidget(
  MaterialApp(home: Scaffold(body: Center(child: child))),
);

/// Real seeded questions, verbatim.
const corpus = <String>[
  '500 tickets were sold for a concert tickets for adults and children were '
      'sold at \$4.50 and \$3.00  respectively if the total receipts were '
      '\$1987.50 how many tickets were sold for adults?',
  'A weaver bought a bundle of grass for \$ 50.00 from which he made 8 mats. '
      'If each mat was sold for \$ 15.00, find the percentage profit.',
  'Mary has \$ 3.00 more than Ben but \$ 5.00 less than Jane. If Mary has '
      '\$ x, how much does Jane and Ben have altogether?',
  'A trader bought an engine for \$15,000.00 outside Nigeria. If the exchange '
      'rate is \$0.075 to N1.00, how much did the engine cost in Naira?',
];

void main() {
  group('currency survives rendering intact', () {
    for (var i = 0; i < corpus.length; i++) {
      testWidgets('seeded question ${i + 1} keeps every price', (tester) async {
        await _pump(tester, FullLatexView(latex: corpus[i]));
        final shown = _plainText(tester);

        // Every '$' in the source must still be on screen. Under the old
        // behaviour the opening and closing '$' of the accidental math span
        // were both consumed, so this count dropped.
        expect(
          '\$'.allMatches(shown).length,
          '\$'.allMatches(corpus[i]).length,
          reason: 'a price was swallowed by a math span:\n$shown',
        );
        expect(shown, corpus[i], reason: 'text should pass through unchanged');
      });
    }

    testWidgets('the light renderer agrees with the full one', (tester) async {
      // Both are reachable from the same widget via useLightRenderer, so a
      // question must not change meaning depending on which one drew it.
      await _pump(tester, MathText(text: corpus[0], useLightRenderer: true));
      expect(_plainText(tester), corpus[0]);
    });
  });

  group('the delimiters the corpus actually uses still render as math', () {
    testWidgets(r'\(...\) is math', (tester) async {
      await _pump(tester, const FullLatexView(latex: r'Evaluate \(2^{3}\) now'));
      expect(find.byType(RichText), findsWidgets);
      final shown = _plainText(tester);
      expect(shown, contains('Evaluate '));
      // The math is drawn as a widget, so its source must not appear as text.
      expect(shown, isNot(contains('2^{3}')));
    });

    testWidgets(r'$$...$$ is still display math', (tester) async {
      await _pump(tester, const FullLatexView(latex: r'A $$x+1$$ B'));
      expect(_plainText(tester), isNot(contains('x+1')));
    });

    testWidgets('a price and real math can coexist', (tester) async {
      await _pump(
        tester,
        const FullLatexView(latex: r'Cost is $4.50 when \(x = 2\).'),
      );
      final shown = _plainText(tester);
      expect(shown, contains(r'$4.50'));
      expect(shown, isNot(contains('x = 2')));
    });
  });
}
