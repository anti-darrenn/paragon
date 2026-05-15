import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paragon/core/widgets/math_text.dart';

void main() {
  testWidgets('MathText lightweight parser handles textbf and vspace', (tester) async {
    const sample = 'Intro \\textbf{BoldText} mid \\vspace{0.5cm} end';

    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: MathText(text: sample, useLightRenderer: true)),
    ));

    // Ensure a RichText widget exists
    expect(find.byType(RichText), findsOneWidget);

    final rich = tester.widget<RichText>(find.byType(RichText));
    final span = rich.text as TextSpan;

    // There should be at least one TextSpan child with the bold style
    bool foundBold = false;
    bool foundWidgetSpan = false;
    void visit(TextSpan ts) {
      if (ts.style != null && ts.style!.fontWeight == FontWeight.bold) foundBold = true;
      if (ts.children != null) {
        for (final c in ts.children!) {
          if (c is TextSpan) visit(c);
          if (c is WidgetSpan) foundWidgetSpan = true;
        }
      }
    }

    visit(span);

    expect(foundBold, isTrue, reason: 'Expected a bold TextSpan for \\textbf');
    expect(foundWidgetSpan, isTrue, reason: 'Expected a WidgetSpan for \\vspace');
  });
}
