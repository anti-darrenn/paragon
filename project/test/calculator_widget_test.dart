import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paragon/core/content/subject_tools.dart';
import 'package:paragon/core/models/subject.dart';
import 'package:paragon/core/repositories/learning_repository.dart';
import 'package:paragon/core/study/study_dock.dart';
import 'package:paragon/core/study/study_tool.dart';
import 'package:paragon/core/study/study_tool_registry.dart';
import 'package:paragon/features/study/calculator/calculator_panel.dart';
import 'package:paragon/features/study/calculator/calculator_tool.dart';

Finder _key(String name) => find.byKey(ValueKey('calc-key-$name'));

String _text(WidgetTester tester, String key) =>
    tester.widget<Text>(find.byKey(ValueKey(key))).data!;

Future<void> _tapAll(WidgetTester tester, List<String> names) async {
  for (final n in names) {
    await tester.tap(_key(n));
    await tester.pump();
  }
}

void main() {
  test('the calculator is registered as a panel tool', () {
    final tool = studyTools.whereType<CalculatorTool>().single;
    expect(tool.id, StudyToolId.calculator);
    expect(tool.label, 'Calculator');
    expect(tool.icon, Icons.calculate_outlined);
    expect(tool.mode, StudyPanelMode.panel);
  });

  testWidgets('tapping keys computes and shows a result', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 360,
                height: 640,
                child: CalculatorPanel(),
              ),
            ),
          ),
        ),
      ),
    );
    await _tapAll(tester, ['d1', 'd2', 'multiply', 'open', 'd3', 'add', 'd4']);
    expect(_text(tester, 'calc-expression'), '12×(3+4');
    expect(_text(tester, 'calc-result'), '');

    await _tapAll(tester, ['equals']);
    expect(_text(tester, 'calc-result'), '84');

    // SHIFT then sin enters sin⁻¹; DEG is the default.
    await _tapAll(tester, ['shift']);
    expect(find.byKey(const ValueKey('calc-shift-indicator')), findsOneWidget);
    await _tapAll(tester, ['sin', 'd0', 'point', 'd5', 'equals']);
    expect(_text(tester, 'calc-expression'), 'sin⁻¹(0.5');
    expect(_text(tester, 'calc-result'), '30');
    expect(_text(tester, 'calc-angle'), 'DEG');

    await _tapAll(tester, ['d1', 'divide', 'd0', 'equals']);
    expect(_text(tester, 'calc-result'), 'Math ERROR');
  });

  testWidgets('the physical keyboard types into it', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: Scaffold(body: CalculatorPanel())),
      ),
    );
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.digit7);
    await tester.sendKeyEvent(LogicalKeyboardKey.numpadMultiply);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit6);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(_text(tester, 'calc-result'), '42');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(_text(tester, 'calc-expression'), '');
  });

  testWidgets('closing and reopening the dock panel keeps its state', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          subjectsProvider.overrideWith(
            (ref) async => const [
              Subject(id: 'p1', name: 'Physics', unitCount: 1),
            ],
          ),
        ],
        // The real registry: this is what a drill screen gets.
        child: const MaterialApp(
          home: StudyDock(
            subjectId: 'p1',
            studyContext: StudyContext.drill,
            child: Scaffold(body: Text('the question')),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    Future<void> open() async {
      await tester.tap(find.byTooltip('Study tools'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Calculator'));
      await tester.pumpAndSettle();
    }

    await open();
    await _tapAll(tester, ['d9', 'memoryPlus', 'angle', 'd2', 'add', 'd3']);
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.byType(CalculatorPanel), findsNothing);

    await open();
    expect(_text(tester, 'calc-expression'), '2+3');
    expect(_text(tester, 'calc-angle'), 'RAD');
    expect(find.byKey(const ValueKey('calc-memory-indicator')), findsOneWidget);
    await _tapAll(tester, ['equals']);
    expect(_text(tester, 'calc-result'), '5');
    // The screen behind is still there: the panel is not modal.
    expect(find.text('the question'), findsOneWidget);
  });

  testWidgets('fits a phone sheet: keys at least 40px tall, no overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              // The dock's 60% sheet on a 700px phone.
              child: SizedBox(height: 420, child: CalculatorPanel()),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(tester.getSize(_key('sin')).height, greaterThanOrEqualTo(40));
    expect(tester.getSize(_key('equals')).height, greaterThanOrEqualTo(40));
    // The pad is reachable by scrolling.
    await tester.dragUntilVisible(
      _key('d0'),
      find.byType(SingleChildScrollView).last,
      const Offset(0, -100),
    );
    await tester.tap(_key('d0'));
    await tester.pump();
    expect(_text(tester, 'calc-expression'), '0');
  });
}
