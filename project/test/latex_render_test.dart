import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paragon/core/widgets/full_latex_view.dart';
import 'package:paragon/core/widgets/math_text.dart';

/// Every text span the reader sees, flattened, with its bold/italic state.
List<(String, bool, bool)> _spans(WidgetTester tester) {
  final out = <(String, bool, bool)>[];
  tester.widget<RichText>(find.byType(RichText).first).text.visitChildren((
    span,
  ) {
    if (span is TextSpan && span.text != null && span.text!.isNotEmpty) {
      out.add((
        span.text!,
        span.style?.fontWeight == FontWeight.bold,
        span.style?.fontStyle == FontStyle.italic,
      ));
    }
    return true;
  });
  return out;
}

String _shown(WidgetTester tester) => _spans(tester).map((s) => s.$1).join();

Future<void> _pumpFull(WidgetTester tester, String latex) => tester.pumpWidget(
  MaterialApp(home: Scaffold(body: FullLatexView(latex: latex))),
);

void main() {
  group('FullLatexView on a phone-width line', () {
    // Seen on an Android emulator: a worked solution's equation ran 50px
    // past the edge of a 411-wide screen. Math cannot wrap, so a wide
    // expression must scroll rather than overflow.
    const wide =
        r'Write each digit as a power of 2: '
        r'\(1111_2 = 1 \times 2^3 + 1 \times 2^2 + 1 \times 2^1 + 1 \times 2^0 = 8 + 4 + 2 + 1 = 15\).';

    testWidgets('a wide equation does not overflow', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(width: 300, child: FullLatexView(latex: wide)),
          ),
        ),
      );
      // An overflow is reported as an exception by the test binding.
      expect(tester.takeException(), isNull);
    });

    testWidgets('control: a short equation still renders inline', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              child: FullLatexView(latex: r'So \(x = 2\).'),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(SingleChildScrollView), findsWidgets);
    });
  });

  group('FullLatexView without any math on the line', () {
    // Regression: a line with no equation was returned as raw source, so
    // `\textbf{base}` appeared literally on a published article.
    testWidgets(r'\textbf is bold, not source', (tester) async {
      await _pumpFull(tester, r'That ten is the \textbf{base}. Nothing more.');
      expect(_shown(tester), 'That ten is the base. Nothing more.');
      expect(_spans(tester).where((s) => s.$2).map((s) => s.$1), ['base']);
    });

    testWidgets(r'\textit is italic, not source', (tester) async {
      await _pumpFull(tester, r'Read the remainders \textit{upwards}.');
      expect(_shown(tester), 'Read the remainders upwards.');
      expect(_spans(tester).where((s) => s.$3).map((s) => s.$1), ['upwards']);
    });

    testWidgets(r'\$ shows a dollar sign, not a backslash', (tester) async {
      await _pumpFull(tester, r'It costs \$5.');
      expect(_shown(tester), r'It costs $5.');
    });

    testWidgets('control: plain text passes through unchanged', (tester) async {
      await _pumpFull(tester, 'Nothing special here, even a lone \$ sign.');
      expect(_shown(tester), 'Nothing special here, even a lone \$ sign.');
      expect(_spans(tester).any((s) => s.$2 || s.$3), isFalse);
    });

    testWidgets('control: the same line with math was already right', (
      tester,
    ) async {
      await _pumpFull(tester, r'The \textbf{base} is \(b\).');
      expect(_spans(tester).where((s) => s.$2).map((s) => s.$1), ['base']);
    });
  });

  testWidgets('MathText lightweight parser handles textbf and vspace', (
    tester,
  ) async {
    const sample = 'Intro \\textbf{BoldText} mid \\vspace{0.5cm} end';

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: MathText(text: sample, useLightRenderer: true)),
      ),
    );

    // Ensure a RichText widget exists
    expect(find.byType(RichText), findsOneWidget);

    final rich = tester.widget<RichText>(find.byType(RichText));
    final span = rich.text as TextSpan;

    // There should be at least one TextSpan child with the bold style
    bool foundBold = false;
    bool foundWidgetSpan = false;
    void visit(TextSpan ts) {
      if (ts.style != null && ts.style!.fontWeight == FontWeight.bold) {
        foundBold = true;
      }
      if (ts.children != null) {
        for (final c in ts.children!) {
          if (c is TextSpan) visit(c);
          if (c is WidgetSpan) foundWidgetSpan = true;
        }
      }
    }

    visit(span);

    expect(foundBold, isTrue, reason: 'Expected a bold TextSpan for \\textbf');
    expect(
      foundWidgetSpan,
      isTrue,
      reason: 'Expected a WidgetSpan for \\vspace',
    );
  });
}
