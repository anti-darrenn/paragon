import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paragon/core/insights/examiner_insight.dart';
import 'package:paragon/core/models/question.dart';
import 'package:paragon/core/widgets/examiner_insight_panel.dart';

Question _q({bool hasInsight = true}) => Question(
  id: 'q1',
  topicId: 't1',
  subjectId: 's1',
  text: 'Simplify',
  options: const ['a', 'b', 'c', 'd'],
  correctIndex: 0,
  explanation: '',
  source: 'waec',
  year: 2018,
  hasInsight: hasInsight,
);

const _insight = ExaminerInsight(
  id: 'q1',
  kind: 'question',
  subjectId: 's1',
  summary: 'Many candidates added the indices instead of multiplying them.',
  reportYear: 2018,
  reportRef: 'WASSCE May/June 2018, Mathematics, Q12',
  status: 'published',
  commonWrongOption: 2,
);

void main() {
  group('originality check', () {
    test('control: an honest summary shares only short runs', () {
      const report =
          'The majority of candidates were unable to apply the laws of '
          'indices correctly and added the powers when multiplying.';
      const mine =
          'Most added the powers; the rule is to add them only when '
          'the bases match and you multiply.';
      expect(longestSharedRun(mine, report), lessThan(kMaxSharedRun));
    });

    test('copied prose is caught, whatever the case and punctuation', () {
      final report = List.generate(30, (i) => 'word$i').join(' ');
      final copied = 'Intro. ${report.toUpperCase().replaceAll(' ', ', ')}!';
      expect(longestSharedRun(copied, report), 30);
    });

    test('empty text shares nothing', () {
      expect(longestSharedRun('', 'anything'), 0);
    });
  });

  Future<void> pump(WidgetTester tester, Question q, {int? selected}) =>
      tester.pumpWidget(
        ProviderScope(
          overrides: [
            publishedInsightProvider.overrideWith((ref, id) async {
              // A read for a question without the flag would be a bug.
              if (!q.hasInsight) {
                fail('read an insight for an unflagged question');
              }
              return _insight;
            }),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: ExaminerInsightPanel(question: q, selected: selected),
            ),
          ),
        ),
      );

  testWidgets('no flag: nothing drawn and nothing read', (tester) async {
    await pump(tester, _q(hasInsight: false));
    await tester.pump();
    expect(find.text('What examiners saw'), findsNothing);
  });

  testWidgets('shown with its citation', (tester) async {
    await pump(tester, _q(), selected: 0);
    await tester.pump();
    expect(find.text('What examiners saw'), findsOneWidget);
    expect(find.textContaining('Many candidates added'), findsOneWidget);
    expect(find.textContaining('Summarised by Paragon'), findsOneWidget);
    expect(find.textContaining('Most candidates chose this too'), findsNothing);
  });

  testWidgets('choosing the common wrong answer leads with it', (tester) async {
    await pump(tester, _q(), selected: 2);
    await tester.pump();
    expect(
      find.textContaining('Most candidates chose this too'),
      findsOneWidget,
    );
  });
}
