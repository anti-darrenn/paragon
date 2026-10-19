import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paragon/core/widgets/math_field/math_field.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The editor box: Normal mode writes LaTeX into the stored value, LaTeX
/// mode edits it directly, and a value Normal mode cannot show is never
/// rewritten.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<(TextEditingController, MathEditing)> pump(
    WidgetTester tester, {
    String text = '',
    MathInputMode mode = MathInputMode.normal,
    bool paragraphs = false,
  }) async {
    final c = TextEditingController(text: text);
    final e = MathEditing(prefsKey: 'test', initialMode: mode);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              MathToolbar(editing: e),
              MathField(controller: c, editing: e, paragraphs: paragraphs),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return (c, e);
  }

  testWidgets('Normal mode: calculator typing is stored as LaTeX', (
    tester,
  ) async {
    final (c, _) = await pump(tester);
    await tester.enterText(find.byType(TextField), 'Express 0.(3) as x/y');
    await tester.pump();
    expect(c.text, r'Express \(0.\overline{3}\) as \(\frac{x}{y}\)');
  });

  testWidgets('LaTeX mode: the box is the stored text; \$..\$ converts on blur', (
    tester,
  ) async {
    final (c, _) = await pump(tester, mode: MathInputMode.latex);
    await tester.enterText(find.byType(TextField), r'Find $x^2$');
    await tester.pump();
    expect(c.text, r'Find $x^2$');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    expect(c.text, r'Find \(x^2\)');
  });

  for (final mode in MathInputMode.values) {
    testWidgets('a worked answer: one Enter starts a new step (${mode.name})', (
      tester,
    ) async {
      final (c, _) = await pump(tester, mode: mode, paragraphs: true);
      await tester.enterText(find.byType(TextField), 'Step one');
      await tester.enterText(find.byType(TextField), 'Step one\n');
      await tester.pump();
      expect(c.text, 'Step one\n\n');
    });
  }

  testWidgets('CONTROL: other boxes keep one Enter as one new line', (
    tester,
  ) async {
    final (c, _) = await pump(tester, mode: MathInputMode.latex);
    await tester.enterText(find.byType(TextField), 'Step one');
    await tester.enterText(find.byType(TextField), 'Step one\n');
    await tester.pump();
    expect(c.text, 'Step one\n');
  });

  testWidgets('a matrix is not rewritten by opening it in Normal mode', (
    tester,
  ) async {
    const matrix = r'\(\begin{pmatrix}1&2\\3&4\end{pmatrix}\)';
    final (c, _) = await pump(tester, text: matrix);
    expect(find.textContaining('Normal mode cannot show'), findsOneWidget);
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.readOnly, isTrue);
    expect(c.text, matrix);
  });

  testWidgets('switching modes leaves the stored value alone', (tester) async {
    const stored = r'Solve \(x^{2} + 1 = 5\)';
    final (c, e) = await pump(tester, text: stored);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'Solve x^2 + 1 = 5',
    );
    e.mode = MathInputMode.latex;
    await tester.pump();
    expect(c.text, stored);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      stored,
    );
  });

  testWidgets('the toolbar types a fraction where the cursor is', (
    tester,
  ) async {
    final (c, _) = await pump(tester, mode: MathInputMode.latex);
    await tester.enterText(find.byType(TextField), 'Find ');
    await tester.tap(find.text('a/b'));
    await tester.pump();
    expect(c.text, r'Find \(\frac{}{}\)');
  });
}
