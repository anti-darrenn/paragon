import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paragon/core/content/subject_tools.dart';
import 'package:paragon/core/models/subject.dart';
import 'package:paragon/core/repositories/learning_repository.dart';
import 'package:paragon/core/study/study_dock.dart';
import 'package:paragon/core/study/study_tool.dart';

class _FakeTool extends StudyTool {
  const _FakeTool(this.id, this.label, [this.mode = StudyPanelMode.panel]);
  @override
  final StudyToolId id;
  @override
  final String label;
  @override
  final StudyPanelMode mode;
  @override
  IconData get icon => Icons.calculate_outlined;
  @override
  Widget build(BuildContext context, StudyScope scope, VoidCallback close) =>
      Text('$label panel for ${scope.subjectName}');
}

const _calc = _FakeTool(StudyToolId.calculator, 'Calculator');
const _sheet = _FakeTool(StudyToolId.formulaSheet, 'Formula sheet');

const _subjects = [
  Subject(id: 'm1', name: 'Mathematics', unitCount: 1),
  Subject(id: 'g1', name: 'Government', unitCount: 1),
];

Future<void> _pump(
  WidgetTester tester, {
  required String subjectId,
  StudyContext studyContext = StudyContext.drill,
  List<StudyTool> tools = const [_calc, _sheet],
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [subjectsProvider.overrideWith((ref) async => _subjects)],
      child: MaterialApp(
        home: StudyDock(
          subjectId: subjectId,
          studyContext: studyContext,
          tools: tools,
          child: const Scaffold(body: Text('the screen')),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<List<String>> _listedTools(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Study tools'));
  await tester.pumpAndSettle();
  return tester
      .widgetList<ListTile>(find.byType(ListTile))
      .map((t) => (t.title as Text).data!)
      .toList();
}

void main() {
  group('subject tools map', () {
    test('names are normalised, and unknown subjects get only the basics', () {
      expect(
        toolsForSubject(' Further Mathematics '),
        contains(StudyToolId.calculator),
      );
      expect(toolsForSubject('Economics'), {
        StudyToolId.scratchpad,
        StudyToolId.glossary,
      });
    });

    test('an exam narrows to the hall-allowed tools', () {
      const scope = StudyScope(
        subjectName: 'Chemistry',
        context: StudyContext.waecExam,
      );
      expect(scope.allowed, {StudyToolId.calculator, StudyToolId.scratchpad});
      // Periodic table stays off in exams until WAEC's rule is verified.
      expect(scope.allowed, isNot(contains(StudyToolId.periodicTable)));
    });

    test('an unresolved subject allows nothing', () {
      expect(
        const StudyScope(subjectName: '', context: StudyContext.lesson).allowed,
        isEmpty,
      );
    });
  });

  group('StudyDock', () {
    testWidgets('with no registered tools it is invisible', (tester) async {
      await _pump(tester, subjectId: 'm1', tools: const []);
      expect(find.text('the screen'), findsOneWidget);
      expect(find.byTooltip('Study tools'), findsNothing);
    });

    testWidgets('lists the subject\'s tools and opens one as a panel', (
      tester,
    ) async {
      await _pump(tester, subjectId: 'm1');
      expect(await _listedTools(tester), ['Calculator', 'Formula sheet']);

      await tester.tap(find.text('Calculator'));
      await tester.pumpAndSettle();
      expect(find.text('Calculator panel for Mathematics'), findsOneWidget);
      // A panel sits beside the screen; the screen is still there.
      expect(find.text('the screen'), findsOneWidget);

      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(find.textContaining('panel for'), findsNothing);
    });

    testWidgets('in a WAEC exam only hall-allowed tools are offered', (
      tester,
    ) async {
      await _pump(tester, subjectId: 'm1', studyContext: StudyContext.waecExam);
      expect(await _listedTools(tester), ['Calculator']);
    });

    testWidgets('control: Government gets no calculator', (tester) async {
      await _pump(tester, subjectId: 'g1', tools: const [_calc]);
      expect(find.byTooltip('Study tools'), findsNothing);
    });

    testWidgets('a page tool opens as its own page', (tester) async {
      await _pump(
        tester,
        subjectId: 'm1',
        tools: const [
          _FakeTool(
            StudyToolId.formulaSheet,
            'Formula sheet',
            StudyPanelMode.page,
          ),
        ],
      );
      await _listedTools(tester);
      await tester.tap(find.text('Formula sheet'));
      await tester.pumpAndSettle();
      expect(find.text('Formula sheet panel for Mathematics'), findsOneWidget);
      expect(find.text('the screen'), findsNothing);
    });
  });
}
