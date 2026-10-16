import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paragon/core/a11y/speech_text.dart';
import 'package:paragon/core/widgets/full_latex_view.dart';
import 'package:paragon/core/widgets/math_text.dart';

/// F9 from the live-site review: a screen reader heard "If F = " then
/// "C + 32" — the maths itself was silent, and the stem was split in two.
/// Now a line with maths is one node, labelled with the read-aloud words.
void main() {
  Future<void> pump(WidgetTester tester, Widget child) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: Center(child: child)),
    ),
  );

  const stem = r'If F = \(\frac{9}{5}C + 32\), find C when F = 212.';

  testWidgets('a stem with maths is one node, and the maths is spoken', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pump(tester, const FullLatexView(latex: stem));
    final label = speakText(stem);
    expect(find.bySemanticsLabel(label), findsOneWidget);
    // The fraction is in the label; the reviewer's screen reader dropped it.
    expect(label, contains('nine fifths C plus 32'));
    // Control: the text either side of the maths is not a separate node.
    expect(find.bySemanticsLabel('If F = '), findsNothing);
    handle.dispose();
  });

  testWidgets('Plan v2 4.1: in a drill-shaped page the stem is its own node, '
      'not folded into the scroll view or the options', (tester) async {
    // The reviewer's tree: "Back | 0 | Option A: 16 | …" with no stem. A
    // stem inside a scroll view, above tappable options, as in drill.
    const drillStem = r'Evaluate \(4^{\frac{3}{2}}\)';
    final handle = tester.ensureSemantics();
    await pump(
      tester,
      SingleChildScrollView(
        child: Column(
          children: [
            const Text('Comes up in about 1 in 34 WAEC Mathematics questions'),
            const FullLatexView(latex: drillStem),
            for (final o in ['16', '6', '5', '8'])
              Semantics(
                button: true,
                label: 'Option: $o',
                onTap: () {},
                excludeSemantics: true,
                child: Text(o),
              ),
          ],
        ),
      ),
    );
    expect(speakText(drillStem), 'Evaluate 4 to the power three halves');
    final node = tester.getSemantics(
      find.bySemanticsLabel(speakText(drillStem)),
    );
    // Exactly the stem: not merged with the line above or an option.
    expect(node.label, speakText(drillStem));
    expect(
      tester
          .getSemantics(find.bySemanticsLabel(RegExp('Comes up in about')))
          .label,
      'Comes up in about 1 in 34 WAEC Mathematics questions',
    );
    handle.dispose();
  });

  testWidgets('the light renderer is labelled the same way', (tester) async {
    final handle = tester.ensureSemantics();
    await pump(tester, const MathText(text: stem, useLightRenderer: true));
    expect(find.bySemanticsLabel(speakText(stem)), findsOneWidget);
    handle.dispose();
  });

  testWidgets('the light renderer no longer shows raw macros (control: the '
      'full one never did)', (tester) async {
    const plain = r'\textbf{Note:} it costs \$5.';
    await pump(tester, const MathText(text: plain, useLightRenderer: true));
    expect(find.textContaining(r'\textbf'), findsNothing);
    expect(find.textContaining(r'\$'), findsNothing);
    await pump(tester, const FullLatexView(latex: plain));
    expect(find.textContaining(r'\textbf'), findsNothing);
  });

  test('30+ real question stems are spoken with no LaTeX left in them', () {
    final dir = Directory('tools/scraper/data');
    final files =
        dir
            .listSync()
            .whereType<File>()
            .where(
              (f) =>
                  f.path
                      .split(RegExp(r'[/\\]'))
                      .last
                      .startsWith('generated_') &&
                  f.path.endsWith('.json'),
            )
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));
    final samples = <String>[];
    for (final f in files) {
      final list = jsonDecode(f.readAsStringSync()) as List<dynamic>;
      for (final q in list.take(3)) {
        final text = (q as Map<String, dynamic>)['text'] as String;
        if (text.contains(r'\(')) samples.add(text);
      }
      if (samples.length >= 60) break;
    }
    expect(samples.length, greaterThanOrEqualTo(30));
    for (final s in samples) {
      final spoken = speakText(s);
      expect(spoken.trim(), isNotEmpty, reason: s);
      expect(spoken, isNot(contains(r'\')), reason: '$s\n→ $spoken');
      expect(spoken, isNot(contains('{')), reason: '$s\n→ $spoken');
    }
  });
}
