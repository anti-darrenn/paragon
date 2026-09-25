import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paragon/core/models/lesson_asset.dart';
import 'package:paragon/core/models/question.dart';
import 'package:paragon/core/repositories/learn_repository.dart';
import 'package:paragon/core/widgets/article_view.dart';

const _pastQuestion = Question(
  id: 'pq1',
  topicId: 't',
  subjectId: 's',
  text: 'Convert 1011 to base ten.',
  options: ['9', '10', '11', '12'],
  correctIndex: 2,
  explanation: 'Eight plus two plus one.',
  source: 'waec',
  year: 2019,
);

const _svg =
    '<svg xmlns="http://www.w3.org/2000/svg" width="10" height="10"><rect width="10" height="10"/></svg>';

Future<void> _pump(
  WidgetTester tester,
  String body, {
  bool authorPreview = false,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        pinnedQuestionsProvider.overrideWith(
          (ref, ids) async => ids == 'pq1' ? [_pastQuestion] : const [],
        ),
        lessonAssetProvider.overrideWith(
          (ref, id) async => id == 'svg1'
              ? const LessonAsset(
                  id: 'svg1',
                  mime: 'image/svg+xml',
                  data: _svg,
                  width: 10,
                  height: 10,
                )
              : null,
        ),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ArticleView(body: body, authorPreview: authorPreview),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _text(String s) => find.textContaining(s, findRichText: true);

void main() {
  group('worked example', () {
    const example = '''
::: example Convert 1011
The problem statement.
--- step Expand
First step text.
--- step
Second step text.
--- answer
The final answer.
:::''';

    testWidgets('steps are revealed one at a time, then the answer', (
      tester,
    ) async {
      await _pump(tester, example);
      expect(_text('The problem statement.'), findsOneWidget);
      expect(_text('First step text.'), findsNothing);

      await tester.tap(find.text('Show the first step'));
      await tester.pumpAndSettle();
      expect(_text('First step text.'), findsOneWidget);
      expect(_text('Second step text.'), findsNothing);

      await tester.tap(find.text('Show next step'));
      await tester.pumpAndSettle();
      expect(_text('Second step text.'), findsOneWidget);
      expect(_text('The final answer.'), findsNothing);

      await tester.tap(find.text('Show the answer'));
      await tester.pumpAndSettle();
      expect(_text('The final answer.'), findsOneWidget);
      expect(find.text('Show next step'), findsNothing);
    });

    testWidgets('Show all reveals everything at once', (tester) async {
      await _pump(tester, example);
      await tester.tap(find.text('Show all'));
      await tester.pumpAndSettle();
      expect(_text('Second step text.'), findsOneWidget);
      expect(_text('The final answer.'), findsOneWidget);
    });

    testWidgets('the editor preview shows every step, for proofreading', (
      tester,
    ) async {
      await _pump(tester, example, authorPreview: true);
      expect(_text('Second step text.'), findsOneWidget);
      expect(_text('The final answer.'), findsOneWidget);
    });
  });

  testWidgets('try-it hides the hint and answer until asked', (tester) async {
    await _pump(
      tester,
      '::: tryit\nFind x.\n--- hint\nThe hint.\n--- answer\nThe answer.\n:::',
    );
    expect(_text('The hint.'), findsNothing);
    expect(_text('The answer.'), findsNothing);
    await tester.tap(find.text('Show a hint'));
    await tester.pumpAndSettle();
    expect(_text('The hint.'), findsOneWidget);
    expect(_text('The answer.'), findsNothing);
    await tester.tap(find.text('Show the answer'));
    await tester.pumpAndSettle();
    expect(_text('The answer.'), findsOneWidget);
  });

  group('quick checks', () {
    const check =
        '::: check\nWhat is 101 in base two?\n- [ ] three\n- [x] five\n- [ ] six\n--- why\nFour plus one.\n:::';

    testWidgets('a wrong pick names the right answer and explains', (
      tester,
    ) async {
      await _pump(tester, check);
      expect(_text('Four plus one.'), findsNothing);
      await tester.tap(find.text('three'));
      await tester.pumpAndSettle();
      expect(find.text('Not quite. The answer is B.'), findsOneWidget);
      expect(_text('Four plus one.'), findsOneWidget);

      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text('Not quite. The answer is B.'), findsNothing);

      await tester.tap(find.text('five'));
      await tester.pumpAndSettle();
      expect(find.text('Correct'), findsOneWidget);
    });

    testWidgets('control: a check with two right answers judges nothing', (
      tester,
    ) async {
      await _pump(tester, '::: check\nQ?\n- [x] one\n- [x] two\n:::');
      await tester.tap(find.text('one'));
      await tester.pumpAndSettle();
      expect(find.text('Correct'), findsNothing);
      expect(find.textContaining('Not quite'), findsNothing);
    });

    testWidgets(
      'a WAEC past question shows its year and judges from the bank',
      (tester) async {
        await _pump(tester, '::: waec q:pq1\n:::');
        expect(find.text('SEEN IN WAEC 2019'), findsOneWidget);
        await tester.tap(find.text('11'));
        await tester.pumpAndSettle();
        expect(find.text('Correct'), findsOneWidget);
        expect(_text('Eight plus two plus one.'), findsOneWidget);
      },
    );

    testWidgets('a missing bank question says so instead of failing', (
      tester,
    ) async {
      await _pump(tester, '::: check q:gone\n:::');
      expect(
        find.text('This question is no longer available.'),
        findsOneWidget,
      );
    });
  });

  testWidgets('a revision card flips', (tester) async {
    await _pump(tester, '::: card\nThe front.\n---\nThe back.\n:::');
    expect(_text('The front.'), findsOneWidget);
    await tester.tap(_text('The front.'));
    await tester.pumpAndSettle();
    expect(_text('The back.'), findsOneWidget);
    expect(_text('The front.'), findsNothing);
  });

  group('author to-dos', () {
    const body = 'Visible text.\n\n::: todo Draw triangle ABC\n:::';

    testWidgets('students never see them', (tester) async {
      await _pump(tester, body);
      expect(_text('Visible text.'), findsOneWidget);
      expect(find.textContaining('Draw triangle ABC'), findsNothing);
    });

    testWidgets('control: the editor preview shows them', (tester) async {
      await _pump(tester, body, authorPreview: true);
      expect(find.textContaining('Draw triangle ABC'), findsOneWidget);
    });
  });

  group('figures', () {
    testWidgets('an uploaded SVG renders with its caption', (tester) async {
      await _pump(tester, '![A square](asset:svg1)');
      expect(find.byType(SvgPicture), findsOneWidget);
      expect(_text('A square'), findsOneWidget);
    });

    testWidgets('a missing asset says so, and the rest still renders', (
      tester,
    ) async {
      await _pump(tester, 'Before.\n\n![Gone](asset:nope)\n\nAfter.');
      expect(find.text("This image couldn't be loaded."), findsOneWidget);
      expect(_text('Before.'), findsOneWidget);
      expect(_text('After.'), findsOneWidget);
    });
  });

  testWidgets('callouts, tables, go-deeper and the rest render together', (
    tester,
  ) async {
    await _pump(tester, '''
# A full lesson

::: objectives
- Convert between bases
:::

::: definition Number base
The number of digits a system uses.
:::

::: formula Place value
\\[ d_n b^n + \\cdots + d_0 \\]
:::

| Base | Digits |
|---|---|
| 2 | 0, 1 |

::: more Why ten?
Because of fingers.
:::

::: video not-a-link
:::

::: hologram
Still readable.
:::''');

    expect(find.text('BY THE END OF THIS LESSON'), findsOneWidget);
    expect(find.text('DEFINITION'), findsOneWidget);
    expect(_text('Number base'), findsOneWidget);
    expect(find.text('FORMULA'), findsOneWidget);
    expect(_text('Digits'), findsOneWidget);
    expect(_text('0, 1'), findsOneWidget);
    expect(find.text('This video is not available.'), findsOneWidget);
    expect(_text('Still readable.'), findsOneWidget);

    expect(_text('Because of fingers.'), findsNothing);
    await tester.tap(_text('Why ten?'));
    await tester.pumpAndSettle();
    expect(_text('Because of fingers.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
