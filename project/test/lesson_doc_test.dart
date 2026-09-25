import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:paragon/core/lessons/lesson_doc.dart';
import 'package:paragon/core/widgets/article_view.dart';

/// Strips a seeded content file's frontmatter, leaving the article body.
String _body(String file) {
  final text = File(file).readAsStringSync().replaceAll('\r\n', '\n');
  if (!text.startsWith('---')) return text;
  final end = text.indexOf('\n---', 3);
  return end < 0 ? text : text.substring(end + 4);
}

List<String> _types(LessonDoc d) => d.blocks.map((b) => b.type).toList();

void main() {
  group(
    'control: articles written before the format parse exactly as before',
    () {
      final dir = Directory('tools/scraper/content/mathematics/number-bases');
      final files = dir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.md'))
          .toList();

      test('the number-bases articles exist to compare against', () {
        expect(files, isNotEmpty);
      });

      for (final f in files) {
        test(f.uri.pathSegments.last, () {
          final body = _body(f.path);
          final old = parseArticleBlocks(body);
          final doc = parseLessonDoc(body);

          expect(doc.issues, isEmpty);
          expect(doc.blocks, everyElement(isA<BasicBlock>()));
          final now = doc.blocks
              .cast<BasicBlock>()
              .map((b) => b.block)
              .toList();
          expect(now.map((b) => b.kind), old.map((b) => b.kind));
          expect(now.map((b) => b.lines), old.map((b) => b.lines));
        });
      }
    },
  );

  group('callouts', () {
    test('every callout kind parses, with its title and a body', () {
      for (final kind in CalloutKind.values) {
        final doc = parseLessonDoc(
          '::: ${kind.name} Pythagoras\nSome \\(a^2\\) text.\n:::',
        );
        final block = doc.blocks.single as CalloutBlock;
        expect(block.kind, kind);
        expect(block.title, 'Pythagoras');
        expect(block.body.single, isA<BasicBlock>());
      }
    });

    test('a definition without its term is a warning, not a failure', () {
      final doc = parseLessonDoc('::: definition\nA base is...\n:::');
      expect(doc.blocks.single, isA<CalloutBlock>());
      expect(doc.issues.single.severity, IssueSeverity.warning);
    });

    test('a callout body can hold lists, maths and nested blocks', () {
      final doc = parseLessonDoc('''
::: summary
- one
- two

\\[ x^2 \\]

::: tip Inner
nested
:::
:::''');
      final body = (doc.blocks.single as CalloutBlock).body;
      expect(body.map((b) => b.type), [
        'bullets',
        'displayMath',
        'callout.tip',
      ]);
      expect(doc.issues, isEmpty);
    });
  });

  group('worked examples and try-it', () {
    test('problem, titled steps and an answer', () {
      final doc = parseLessonDoc('''
::: example Convert 1011 to base ten
Write the place values.
--- step Expand
\\(1 \\times 2^3 + 0 + 2 + 1\\)
--- step
Add them up.
--- answer
\\(11\\)
:::''');
      final ex = doc.blocks.single as ExampleBlock;
      expect(ex.title, 'Convert 1011 to base ten');
      expect(ex.problem, hasLength(1));
      expect(ex.steps.map((s) => s.title), ['Expand', '']);
      expect(ex.answer, isNotNull);
      expect(doc.issues, isEmpty);
    });

    test('a bare --- inside an example is still a rule, not a step', () {
      final doc = parseLessonDoc(
        '::: example\nA\n\n---\n\nB\n--- step\nC\n:::',
      );
      final ex = doc.blocks.single as ExampleBlock;
      expect(ex.problem.map((b) => b.type), ['paragraph', 'rule', 'paragraph']);
      expect(ex.steps, hasLength(1));
    });

    test('an example with no steps and no answer is flagged', () {
      final doc = parseLessonDoc('::: example\nJust a problem.\n:::');
      expect(doc.issues.single.message, contains('step'));
    });

    test('try-it separates problem, hint and answer', () {
      final doc = parseLessonDoc(
        '::: tryit\nFind x.\n--- hint\nIsolate x.\n--- answer\n\\(x = 3\\)\n:::',
      );
      final t = doc.blocks.single as TryItBlock;
      expect(t.problem, hasLength(1));
      expect(t.hint, hasLength(1));
      expect(t.answer, hasLength(1));
    });

    test(
      'a separator inside a nested fence does not split the outer block',
      () {
        final doc = parseLessonDoc('''
::: example Outer
Problem.
::: tryit
Inner.
--- answer
Inner answer.
:::
--- step
Outer step.
:::''');
        final ex = doc.blocks.single as ExampleBlock;
        expect(ex.problem.map((b) => b.type), ['paragraph', 'tryit']);
        expect(ex.steps, hasLength(1));
        expect(ex.answer, isNull);
      },
    );
  });

  group('quick checks', () {
    test('options, the one right answer and the explanation', () {
      final doc = parseLessonDoc('''
::: check
What is \\(101_2\\) in base ten?
- [ ] 3
- [x] 5
- [ ] 6
--- why
\\(4 + 0 + 1 = 5\\)
:::''');
      final c = doc.blocks.single as CheckBlock;
      expect(c.options.map((o) => o.text), ['3', '5', '6']);
      expect(c.correctIndex, 1);
      expect(c.why, isNotNull);
      expect(doc.issues, isEmpty);
    });

    test('zero or two right answers are errors, and nothing is judged', () {
      for (final marks in [
        ['- [ ] a', '- [ ] b'],
        ['- [x] a', '- [X] b'],
      ]) {
        final doc = parseLessonDoc('::: check\nQ?\n${marks.join('\n')}\n:::');
        expect((doc.blocks.single as CheckBlock).correctIndex, -1);
        expect(doc.issues.single.severity, IssueSeverity.error);
      }
    });

    test('fewer than two options is an error', () {
      final doc = parseLessonDoc('::: check\nQ?\n- [x] only\n:::');
      expect(doc.issues.single.message, contains('two options'));
    });

    test('bank references: check q: and waec q:', () {
      final a =
          parseLessonDoc('::: check q:abc123\n:::').blocks.single
              as BankQuestionBlock;
      final b =
          parseLessonDoc('::: waec q:xyz\n:::').blocks.single
              as BankQuestionBlock;
      expect((a.questionId, a.isPastQuestion), ('abc123', false));
      expect((b.questionId, b.isPastQuestion), ('xyz', true));
    });

    test('waec without a question id is an error and degrades to text', () {
      final doc = parseLessonDoc('::: waec\nSome text\n:::');
      expect(doc.blocks.single, isA<UnknownBlock>());
      expect(doc.issues.single.severity, IssueSeverity.error);
    });
  });

  group('cards, figures, tables, more, video, todo', () {
    test('a card has a front and a back', () {
      final c =
          parseLessonDoc(
                '::: card\nWhat is a base?\n---\nThe number of digits used.\n:::',
              ).blocks.single
              as CardBlock;
      expect(
        (c.front, c.back),
        ('What is a base?', 'The number of digits used.'),
      );
    });

    test('a card with no back is an error but keeps its text', () {
      final doc = parseLessonDoc('::: card\nFront only\n:::');
      expect((doc.blocks.single as CardBlock).front, 'Front only');
      expect(doc.issues, hasLength(1));
    });

    test('figures: asset or https, caption and width', () {
      final a =
          parseLessonDoc(
                '![A right triangle](asset:tri01){width=60%}',
              ).blocks.single
              as FigureBlock;
      expect(
        (a.assetId, a.caption, a.widthFraction),
        ('tri01', 'A right triangle', 0.6),
      );
      final u =
          parseLessonDoc('![](https://example.org/x.png)').blocks.single
              as FigureBlock;
      expect((u.assetId, u.widthFraction), (null, 1.0));
    });

    test('an image pointing anywhere else is an error', () {
      final doc = parseLessonDoc('![x](http://insecure.example/x.png)');
      expect(doc.issues.single.severity, IssueSeverity.error);
    });

    test('a pipe table with alignment, maths in cells and an escaped bar', () {
      final t =
          parseLessonDoc('''
| Base | Digits | Example |
|:---|:---:|---:|
| 2 | \\(0, 1\\) | \\(101_2\\) |
| 8 | 0 to 7 | a \\| b |''').blocks.single
              as TableBlock;
      expect(t.header, ['Base', 'Digits', 'Example']);
      expect(t.align, [CellAlign.start, CellAlign.center, CellAlign.end]);
      expect(t.rows[1][2], 'a | b');
    });

    test('a ragged row is padded and warned about', () {
      final doc = parseLessonDoc('| a | b |\n|---|---|\n| 1 |');
      expect((doc.blocks.single as TableBlock).rows.single, ['1', '']);
      expect(doc.issues.single.severity, IssueSeverity.warning);
    });

    test(
      'control: a line starting with | but no separator row stays prose',
      () {
        final doc = parseLessonDoc('| not a table');
        expect(_types(doc), ['paragraph']);
      },
    );

    test('more, video and todo', () {
      final doc = parseLessonDoc('''
::: more Why this works
Deeper text.
:::

::: video https://youtu.be/dQw4w9WgXcQ
:::

::: todo Diagram needed: triangle ABC
:::''');
      expect(_types(doc), ['more', 'video', 'todo']);
      expect((doc.blocks[1] as VideoBlock).youtubeId, 'dQw4w9WgXcQ');
      expect((doc.blocks[2] as TodoBlock).text, 'Diagram needed: triangle ABC');
      // A todo is always reported, so nothing ships with one forgotten.
      expect(doc.issues.single.message, startsWith('To do'));
    });
  });

  group('never throws, never drops text', () {
    test('an unclosed fence keeps everything after it, and says so', () {
      final doc = parseLessonDoc('Before.\n::: note\nInside.\nStill inside.');
      expect(_types(doc), ['paragraph', 'callout.note']);
      expect(doc.issues.single.message, contains('never closed'));
      expect(doc.issues.single.line, 2);
    });

    test(
      'an unknown kind is shown as text, for newer lessons on older builds',
      () {
        final doc = parseLessonDoc('::: hologram\nStill readable.\n:::');
        final u = doc.blocks.single as UnknownBlock;
        expect(u.body.single, isA<BasicBlock>());
      },
    );

    test('a stray close is ignored with a warning, not printed', () {
      final doc = parseLessonDoc('Text.\n:::\nMore.');
      expect(_types(doc), ['paragraph', 'paragraph']);
      expect(doc.issues.single.severity, IssueSeverity.warning);
    });

    test('issues report the real line, from inside nested blocks', () {
      final doc = parseLessonDoc(
        'Line one.\n\n::: example\nProblem.\n--- step\n::: check\nQ?\n- [x] a\n:::\n:::',
      );
      final issue = doc.issues.singleWhere(
        (i) => i.message.contains('two options'),
      );
      expect(issue.line, 6);
    });
  });

  group('block keys', () {
    test('stable across parses, distinct for repeated identical blocks', () {
      const src = 'Same.\n\nSame.\n\n::: tip\nA tip.\n:::';
      final a = parseLessonDoc(src).blocks.map((b) => b.key).toList();
      final b = parseLessonDoc(src).blocks.map((b) => b.key).toList();
      expect(a, b);
      expect(a.toSet(), hasLength(3));
      expect(a[0], endsWith(':0'));
      expect(a[1], endsWith(':1'));
    });

    test(
      'whitespace and case changes keep a key; a wording change moves it',
      () {
        final k1 = parseLessonDoc('Add the digits.').blocks.single.key;
        final k2 = parseLessonDoc('add   the DIGITS.').blocks.single.key;
        final k3 = parseLessonDoc('Multiply the digits.').blocks.single.key;
        expect(k1, k2);
        expect(k1, isNot(k3));
      },
    );

    test('inserting a block elsewhere does not change other keys', () {
      final before = parseLessonDoc(
        'A.\n\nB.',
      ).blocks.map((b) => b.key).toList();
      final after = parseLessonDoc(
        'New.\n\nA.\n\nB.',
      ).blocks.map((b) => b.key).toList();
      expect(after.sublist(1), before);
    });

    test('the hash is real FNV-1a (standard test vectors)', () {
      // The key embeds fnv1a32(normalised source). Normalising leaves
      // these lowercase single words unchanged, so the published vectors
      // apply directly.
      String hashOf(String word) =>
          parseLessonDoc(word).blocks.single.key.split(':')[1];
      expect(hashOf('a'), 'e40c292c');
      expect(hashOf('foobar'), 'bf9cf968');
    });
  });
}
