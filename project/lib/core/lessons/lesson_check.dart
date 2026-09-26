import 'package:flutter_math_fork/tex.dart';

import 'lesson_doc.dart';

/// Everything wrong with a lesson body that an author should fix: the
/// parser's structural issues (unclosed blocks, quick checks without one
/// right answer, to-dos…) plus every maths span that would render as the
/// red fallback, found with the same `flutter_math_fork` parser `Math.tex`
/// uses. Sorted by line.
///
/// The studio's problems panel shows this; anything that validates lessons
/// in bulk (a seeder, future AI drafts) should call it too, so "clean" means
/// the same thing everywhere.
List<LessonIssue> checkLesson(String body) {
  final issues = [...parseLessonDoc(body).issues, ...mathIssues(body)];
  issues.sort((a, b) => a.line.compareTo(b.line));
  return issues;
}

/// Maths spans that fail to parse: `\(...\)`, `\[...\]` and `$$...$$`,
/// matched the way `FullLatexView` matches them. An unclosed `\(` or `\[`
/// is reported too — `FullLatexView` would print it as raw text.
List<LessonIssue> mathIssues(String body) {
  final out = <LessonIssue>[];
  final s = body.replaceAll('\r\n', '\n');
  var pos = 0;

  int lineAt(int offset) {
    var line = 1;
    for (var i = 0; i < offset && i < s.length; i++) {
      if (s.codeUnitAt(i) == 10) line++;
    }
    return line;
  }

  void check(String tex, int at) {
    try {
      TexParser(tex, const TexParserSettings()).parse();
    } catch (e) {
      final shown = tex.length > 40 ? '${tex.substring(0, 37)}...' : tex;
      out.add(LessonIssue(lineAt(at), 'Maths won\'t render: $shown'));
    }
  }

  while (pos < s.length) {
    final c = s.codeUnitAt(pos);
    // \$ is an escaped dollar, never maths.
    if (c == 92 && pos + 1 < s.length && s[pos + 1] == r'$') {
      pos += 2;
      continue;
    }
    if (c == 92 &&
        pos + 1 < s.length &&
        (s[pos + 1] == '(' || s[pos + 1] == '[')) {
      final close = s[pos + 1] == '(' ? r'\)' : r'\]';
      final end = s.indexOf(close, pos + 2);
      if (end < 0) {
        out.add(
          LessonIssue(
            lineAt(pos),
            "'${s.substring(pos, pos + 2)}' is never closed with '$close'",
          ),
        );
        pos += 2;
        continue;
      }
      check(s.substring(pos + 2, end), pos);
      pos = end + 2;
      continue;
    }
    if (s.startsWith(r'$$', pos)) {
      final end = s.indexOf(r'$$', pos + 2);
      if (end > pos + 2) {
        check(s.substring(pos + 2, end), pos);
        pos = end + 2;
        continue;
      }
    }
    pos++;
  }
  return out;
}
