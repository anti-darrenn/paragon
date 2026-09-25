// Every authored Learn article, parsed with the real flutter_math_fork
// parser and rendered through the real ArticleView.
//
// This is `generated_latex_test.dart`'s discipline applied to hand-written
// content, and hand-written content needs it more: the generated corpus is
// emitted by 216 modules that all format maths the same way, whereas an
// article is typed by a person who may reach for `$x$` or `\emph{}` out of
// habit. Neither works in this app, and neither fails loudly — `$` renders
// as a dollar sign and a bad command renders as red monospace, so a broken
// article looks like a slightly odd article rather than an error.
//
// CLAUDE.md: a green suite is not evidence that content is *correct*, only
// that it parses and renders. That remains true here. What this catches is
// the dialect mistakes, not the mathematics.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_math_fork/tex.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paragon/core/widgets/article_view.dart';

/// Every `.md` under the authored content tree, with its frontmatter
/// stripped — the same split `9_seed_resources.js` performs, so what is
/// tested is what is seeded.
Map<String, String> authoredArticles() {
  final dir = Directory('tools/scraper/content');
  if (!dir.existsSync()) return {};

  final out = <String, String>{};
  for (final entity in dir.listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.md')) continue;
    final raw = entity.readAsStringSync().replaceAll('\r\n', '\n');
    if (!raw.startsWith('---\n')) continue;
    final end = raw.indexOf('\n---', 3);
    if (end == -1) continue;
    final body = raw.substring(raw.indexOf('\n', end + 1) + 1).trim();
    // Videos and exercises have no body; only articles are testable here.
    if (body.isEmpty) continue;
    out[entity.path.split(RegExp(r'[/\\]')).sublist(3).join('/')] = body;
  }
  return out;
}

/// Pulls out `\(...\)` and `\[...\]` segments exactly the way
/// `FullLatexView` does, so these are precisely the strings that reach
/// `Math.tex`.
List<String> extractMath(String s) {
  final out = <String>[];
  var pos = 0;
  while (pos < s.length) {
    if (s.codeUnitAt(pos) == 92 &&
        pos + 1 < s.length &&
        (s[pos + 1] == '(' || s[pos + 1] == '[')) {
      final open = s[pos + 1];
      final close = open == '(' ? r'\)' : r'\]';
      final start = pos + 2;
      final end = s.indexOf(close, start);
      if (end != -1) {
        out.add(s.substring(start, end));
        pos = end + 2;
        continue;
      }
    }
    pos++;
  }
  return out;
}

void main() {
  // Control. Without it, every assertion below passes just as happily on
  // an empty corpus or a parser that never rejects anything.
  test('control — the parser really does reject bad LaTeX', () {
    for (final bad in [r'\frac{1}{', r'\emph{x}', r'\notacommand{x}']) {
      var threw = false;
      try {
        TexParser(bad, const TexParserSettings()).parse();
      } catch (_) {
        threw = true;
      }
      expect(threw, isTrue, reason: 'expected "$bad" to fail parsing');
    }
  });

  test('there is authored content to check', () {
    // The pilot topic. If this ever goes to zero the suite below becomes
    // vacuous, and would stay green through the deletion of every article.
    expect(
      authoredArticles(),
      isNotEmpty,
      reason: 'no authored articles found under tools/scraper/content',
    );
  });

  test('every maths expression in every authored article parses', () {
    var expressions = 0;
    final failures = <String>[];

    authoredArticles().forEach((file, body) {
      for (final tex in extractMath(body)) {
        expressions++;
        try {
          TexParser(tex, const TexParserSettings()).parse();
        } catch (e) {
          failures.add('$file: "$tex" — $e');
        }
      }
    });

    expect(expressions, greaterThan(0), reason: 'no maths found to check');
    expect(failures, isEmpty, reason: failures.join('\n'));
    // ignore: avoid_print
    print('Authored expressions parsed: $expressions');
  });

  test('no authored article uses a banned dialect', () {
    // The two habits a human writer brings that this app does not support,
    // and that fail silently rather than loudly:
    //
    //   $...$   — a lone $ is currency here, so `$x$` renders as literal
    //             dollar signs around an italic-looking nothing
    //   \emph{} — not implemented by FullLatexView at all
    //
    // `$$...$$` IS supported, so the check has to skip those pairs rather
    // than counting their dollars.
    final problems = <String>[];

    authoredArticles().forEach((file, body) {
      final withoutDisplay = body.replaceAll(RegExp(r'\$\$.*?\$\$', dotAll: true), '');
      if (withoutDisplay.contains(r'$')) {
        problems.add('$file: contains a lone \$ — use \\(...\\) for inline maths');
      }
      if (body.contains(r'\emph{')) {
        problems.add('$file: uses \\emph{} — use \\textit{} instead');
      }
    });

    expect(problems, isEmpty, reason: problems.join('\n'));
  });

  testWidgets('every authored article renders without the red fallback',
      (tester) async {
    final articles = authoredArticles();
    expect(articles, isNotEmpty);

    for (final entry in articles.entries) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: ArticleView(body: entry.value)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull, reason: entry.key);

      // The fallback is a red monospace Text. Finding one means Math.tex
      // rejected an expression at render time even though it parsed.
      final fallbacks = tester
          .widgetList<Text>(find.byType(Text))
          .where((t) =>
              t.style?.color == Colors.redAccent &&
              t.style?.fontFamily == 'monospace');
      expect(fallbacks, isEmpty, reason: '${entry.key} rendered a fallback');
    }
  });
}
