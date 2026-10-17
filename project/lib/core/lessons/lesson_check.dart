import 'package:flutter_math_fork/tex.dart';

import '../latex/tex_preprocess.dart';

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

/// Titles that are scaffolding, not lessons: `test2`, `test_article`,
/// `Sample`, `lorem ipsum`, `untitled`… — the whole title, so a real lesson
/// called "Tests for divisibility" or "Sample space" is never caught. A
/// snake_case identifier (`test_article`, `new_video_1`) is caught too:
/// no student-facing title is written that way.
final RegExp placeholderTitle = RegExp(
  r'^(?:(?:test|testing|sample|placeholder|todo|asdf\w*|x{3,}|untitled|dummy|foo|bar)[\s_\-]*\d*[\s_\-]*(?:article|video|exercise|lesson)?\d*'
  r'|.*\blorem\b.*'
  r'|[a-z0-9]+(?:_[a-z0-9]+)+)$',
  caseSensitive: false,
);

/// What stops an item being shown to students, beyond its body's
/// [checkLesson] errors: a placeholder or empty title, an article with no
/// text, a video with no link. Line 0 — these are not about the body.
///
/// The editor refuses to publish while any of these stand (a reviewer can
/// override with a reason, recorded as a review comment), and
/// `tools/admin/content_lint.js` applies the same rules to what is already
/// live — change both together.
List<LessonIssue> checkPublishable({
  required String type,
  required String title,
  String body = '',
  String? youtubeId,
}) {
  final out = <LessonIssue>[];
  final t = title.trim();
  if (t.isEmpty) {
    out.add(const LessonIssue(0, 'The title is empty.'));
  } else if (placeholderTitle.hasMatch(t)) {
    out.add(LessonIssue(0, '"$t" looks like a placeholder title.'));
  }
  if (type == 'article' && body.trim().isEmpty) {
    out.add(const LessonIssue(0, 'The article has no text.'));
  }
  if (type == 'video' && (youtubeId ?? '').trim().isEmpty) {
    out.add(const LessonIssue(0, 'The video has no YouTube link.'));
  }
  if (type == 'article') {
    out.addAll(
      checkLesson(body).where((i) => i.severity == IssueSeverity.error),
    );
  }
  return out;
}

/// Maths commands whose KaTeX fonts the web build drops to save the first
/// load (`tools/site/trim_fonts.js`, `DROPPED_COMMANDS` — change both
/// together). They still render, in the main font.
final RegExp droppedFontCommand = RegExp(
  r'\\(mathcal|mathfrak|mathscr|mathsf|textsf|texttt|mathtt)\b',
);

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
      // As the renderer reads it: through the preprocessor first.
      TexParser(normalizeMath(tex), const TexParserSettings()).parse();
    } catch (e) {
      final shown = tex.length > 40 ? '${tex.substring(0, 37)}...' : tex;
      out.add(LessonIssue(lineAt(at), 'Maths won\'t render: $shown'));
      return;
    }
    final dropped = droppedFontCommand.firstMatch(tex);
    if (dropped != null) {
      out.add(
        LessonIssue(
          lineAt(at),
          '\\${dropped.group(1)} uses a font Paragon does not ship; it will '
          'show in the ordinary maths font.',
          severity: IssueSeverity.warning,
        ),
      );
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
