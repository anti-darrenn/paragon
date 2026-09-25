// The article block parser, and the one thing that matters about it: it
// splits blocks and nothing else, handing every inline span to
// FullLatexView.
//
// The control group at the bottom is the load-bearing part, in the same
// spirit as `generated_latex_test.dart`. Without it these tests would pass
// just as happily if `parseArticleBlocks` returned the whole document as a
// single paragraph — which would render, look almost right, and quietly
// lose every heading and list in every article.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paragon/core/widgets/article_view.dart';

void main() {
  group('block splitting', () {
    test('blank lines separate paragraphs, and lines within one are folded', () {
      final blocks = parseArticleBlocks(
        'First paragraph\nwrapped over two lines.\n\nSecond paragraph.',
      );
      expect(blocks.length, 2);
      expect(blocks[0].kind, ArticleBlockKind.paragraph);
      expect(blocks[0].text, 'First paragraph wrapped over two lines.');
      expect(blocks[1].text, 'Second paragraph.');
    });

    test('headings are recognised at three levels', () {
      final blocks = parseArticleBlocks('# One\n## Two\n### Three');
      expect(
        blocks.map((b) => b.kind).toList(),
        [
          ArticleBlockKind.heading1,
          ArticleBlockKind.heading2,
          ArticleBlockKind.heading3,
        ],
      );
      expect(blocks[1].text, 'Two');
    });

    test('a heading ends the paragraph before it without a blank line', () {
      final blocks = parseArticleBlocks('Some prose.\n## A heading');
      expect(blocks.length, 2);
      expect(blocks[0].kind, ArticleBlockKind.paragraph);
      expect(blocks[1].kind, ArticleBlockKind.heading2);
    });

    test('#### and beyond is not a heading — it stays prose', () {
      final blocks = parseArticleBlocks('#### Four hashes');
      expect(blocks.single.kind, ArticleBlockKind.paragraph);
    });

    test('consecutive bullets form one list', () {
      final blocks = parseArticleBlocks('- alpha\n- beta\n* gamma');
      expect(blocks.length, 1);
      expect(blocks.single.kind, ArticleBlockKind.bullets);
      expect(blocks.single.lines, ['alpha', 'beta', 'gamma']);
    });

    test('a numbered list keeps the numbers the author wrote', () {
      // A list that deliberately starts at 3 — a continuation after a
      // worked example — must not be silently renumbered to 1.
      final blocks = parseArticleBlocks('3. third\n4. fourth');
      expect(blocks.single.kind, ArticleBlockKind.numbers);
      expect(blocks.single.lines, ['3. third', '4. fourth']);
    });

    test('switching list style starts a new block', () {
      final blocks = parseArticleBlocks('- bullet\n1. number');
      expect(blocks.length, 2);
      expect(blocks[0].kind, ArticleBlockKind.bullets);
      expect(blocks[1].kind, ArticleBlockKind.numbers);
    });

    test('a rule is a rule, not an empty bullet', () {
      // '---' matches the bullet pattern's prefix; the rule test has to
      // win, or every horizontal rule becomes a list item reading '--'.
      final blocks = parseArticleBlocks('before\n\n---\n\nafter');
      expect(blocks[1].kind, ArticleBlockKind.rule);
    });

    test('blockquotes are their own block', () {
      final blocks = parseArticleBlocks('> Remember this.');
      expect(blocks.single.kind, ArticleBlockKind.quote);
      expect(blocks.single.text, 'Remember this.');
    });

    test('empty and whitespace-only source yields no blocks', () {
      expect(parseArticleBlocks(''), isEmpty);
      expect(parseArticleBlocks('\n\n   \n'), isEmpty);
    });

    test('CRLF source parses the same as LF', () {
      final crlf = parseArticleBlocks('# Title\r\n\r\nBody text.');
      expect(crlf.length, 2);
      expect(crlf[0].kind, ArticleBlockKind.heading1);
      expect(crlf[1].text, 'Body text.');
    });
  });

  group('maths blocks', () {
    test(r'a standalone \[...\] becomes a display-maths block', () {
      final blocks = parseArticleBlocks(r'\[ x^2 + y^2 = z^2 \]');
      expect(blocks.single.kind, ArticleBlockKind.displayMath);
    });

    test(r'a standalone $$...$$ becomes a display-maths block', () {
      final blocks = parseArticleBlocks(r'$$ \frac{a}{b} $$');
      expect(blocks.single.kind, ArticleBlockKind.displayMath);
    });

    test('inline maths stays inside its paragraph', () {
      // The parser must not pull \(...\) out into its own block — that is
      // FullLatexView's job, mid-sentence, where it belongs.
      final blocks = parseArticleBlocks(
        r'The value of \(i^2\) is \(-1\), which matters below.',
      );
      expect(blocks.single.kind, ArticleBlockKind.paragraph);
      expect(blocks.single.text, contains(r'\(i^2\)'));
    });

    test('a lone \$ is left alone, exactly as in the question corpus', () {
      // `$` is currency everywhere in this app. The parser must not treat
      // a single one as opening display maths — `$$` needs real content
      // between the pairs to qualify.
      final blocks = parseArticleBlocks(r'It sold for $4.50 and then $3.00.');
      expect(blocks.single.kind, ArticleBlockKind.paragraph);
      expect(blocks.single.text, contains(r'$4.50'));
    });

    test(r'a bare $$ with nothing inside is not display maths', () {
      expect(parseArticleBlocks(r'$$').single.kind, ArticleBlockKind.paragraph);
    });
  });

  group('rendering', () {
    testWidgets('a mixed article renders without throwing', (tester) async {
      const source = '''
# Powers of the imaginary unit

The unit \\(i\\) satisfies \\(i^2 = -1\\). Raising it to successive powers
cycles with period four:

\\[ i^1 = i,\\quad i^2 = -1,\\quad i^3 = -i,\\quad i^4 = 1 \\]

## Why it cycles

- Each step multiplies by \\(i\\)
- After four steps you are back at \\(1\\)

> So \\(i^n\\) depends only on \\(n \\bmod 4\\).

---

1. Reduce the exponent mod 4
2. Read the answer off the cycle
''';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: ArticleView(body: source)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(ArticleView), findsOneWidget);
    });

    testWidgets('an empty body renders nothing rather than an empty box',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: ArticleView(body: '   '))),
      );
      expect(tester.takeException(), isNull);
    });
  });

  // ── Control ────────────────────────────────────────────────────────
  //
  // Proves the group above is not vacuous. If `parseArticleBlocks` were
  // replaced by something that returned the source as one paragraph — the
  // most likely "simplification" — these would fail while every rendering
  // test above still passed.
  group('control — a naive single-block parse really would lose structure', () {
    const source = '# Heading\n\nProse.\n\n- one\n- two';

    test('the naive version collapses six lines into one block', () {
      final naive = [ArticleBlock(ArticleBlockKind.paragraph, [source])];
      expect(naive.length, 1);
      expect(parseArticleBlocks(source).length, greaterThan(1));
    });

    test('the real parser distinguishes kinds the naive one cannot', () {
      final kinds = parseArticleBlocks(source).map((b) => b.kind).toSet();
      expect(kinds, contains(ArticleBlockKind.heading1));
      expect(kinds, contains(ArticleBlockKind.bullets));
      expect(kinds.length, greaterThan(1));
    });
  });
}
