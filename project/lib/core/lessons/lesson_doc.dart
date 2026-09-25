import '../learn/youtube_id.dart';
import '../widgets/article_view.dart' show ArticleBlock, parseArticleBlocks;

/// The lesson format: a body of text parsed into typed blocks.
///
/// **The one parser.** The renderer, the editor's problems panel, the
/// subject index (glossary, formulas, revision cards) and read-aloud all go
/// through [parseLessonDoc], so no two features can disagree about what a
/// lesson says. The format itself is specified in `docs/LESSON_FORMAT.md`.
///
/// **It wraps, it does not replace.** Text outside the new fenced blocks is
/// handed to [parseArticleBlocks] unchanged, so every article written before
/// this format existed parses — and renders — exactly as it did. The only
/// lines this parser claims for itself are ones no old article contains: a
/// fence (`::: kind`), a pipe table, and a lone image line.
///
/// **It never throws and never drops text.** Anything malformed still
/// becomes a block the student can read, and is reported in
/// [LessonDoc.issues] for the author.
LessonDoc parseLessonDoc(String source) {
  final lines = source.replaceAll('\r\n', '\n').split('\n');
  final issues = <LessonIssue>[];
  final blocks = _parseBlocks(lines, 0, issues);
  return LessonDoc._(_keyed(blocks), issues);
}

class LessonDoc {
  LessonDoc._(this.blocks, this.issues);

  final List<LessonBlock> blocks;

  /// Problems an author should fix. Empty for a clean lesson. Never shown
  /// to students — the blocks already degrade to readable text.
  final List<LessonIssue> issues;

  bool get isEmpty => blocks.isEmpty;
}

enum IssueSeverity { error, warning }

class LessonIssue {
  const LessonIssue(
    this.line,
    this.message, {
    this.severity = IssueSeverity.error,
  });

  /// 1-based source line the problem starts on.
  final int line;
  final String message;
  final IssueSeverity severity;

  @override
  String toString() => 'line $line: $message';
}

// ─── Blocks ───────────────────────────────────────────────────────────

/// A top-level (or nested) piece of a lesson.
///
/// [key] identifies a top-level block stably across renders and, as far as
/// possible, across edits: it is the block's type, a hash of its normalised
/// text, and its occurrence among identical blocks. Highlights, notes and
/// revision cards attach to it. Edit a block's text and its key changes —
/// which is the honest outcome: a note on the old wording is shown as
/// belonging to an earlier version rather than silently re-attached. Nested
/// blocks carry an empty key.
sealed class LessonBlock {
  LessonBlock(this.source);

  /// The block's own source text, as written. Used for its key and for
  /// "copy block" in the editor.
  final String source;

  String key = '';

  /// Short machine name used in the key and in tests.
  String get type;
}

/// A block from the original article grammar: heading, paragraph, list,
/// quote, rule or display maths.
class BasicBlock extends LessonBlock {
  BasicBlock(this.block, super.source);
  final ArticleBlock block;

  @override
  String get type => block.kind.name;
}

/// Coloured, labelled boxes.
enum CalloutKind {
  note('Note'),
  tip('Tip'),
  remember('Remember'),
  mistake('Common mistake'),
  exam('Exam tip'),
  definition('Definition'),
  formula('Formula'),
  theorem('Theorem'),
  objectives('By the end of this lesson'),
  summary('Summary');

  const CalloutKind(this.label);
  final String label;

  static CalloutKind? tryParse(String name) {
    for (final k in values) {
      if (k.name == name) return k;
    }
    return null;
  }
}

class CalloutBlock extends LessonBlock {
  CalloutBlock(this.kind, this.title, this.body, super.source);
  final CalloutKind kind;

  /// The text after the kind on the fence line. For a definition this is
  /// the term; for a formula, its name. May be empty.
  final String title;
  final List<LessonBlock> body;

  @override
  String get type => 'callout.${kind.name}';
}

class ExampleStep {
  const ExampleStep(this.title, this.body);
  final String title;
  final List<LessonBlock> body;
}

/// A worked example: the problem, then steps revealed one at a time.
class ExampleBlock extends LessonBlock {
  ExampleBlock(this.title, this.problem, this.steps, this.answer, super.source);
  final String title;
  final List<LessonBlock> problem;
  final List<ExampleStep> steps;

  /// Null when the example has no separate answer section.
  final List<LessonBlock>? answer;

  @override
  String get type => 'example';
}

/// A problem for the student, with an optional hint and a hidden answer.
class TryItBlock extends LessonBlock {
  TryItBlock(this.title, this.problem, this.hint, this.answer, super.source);
  final String title;
  final List<LessonBlock> problem;
  final List<LessonBlock>? hint;
  final List<LessonBlock>? answer;

  @override
  String get type => 'tryit';
}

class CheckOption {
  const CheckOption(this.text, this.isCorrect);
  final String text;
  final bool isCorrect;
}

/// A multiple-choice question written into the lesson. Feedback only —
/// nothing is recorded.
class CheckBlock extends LessonBlock {
  CheckBlock(this.question, this.options, this.why, super.source);
  final List<LessonBlock> question;
  final List<CheckOption> options;
  final List<LessonBlock>? why;

  /// -1 unless exactly one option is marked correct; the parser reports
  /// that as an issue, and the renderer then shows the options without
  /// judging any answer.
  int get correctIndex {
    final correct = [
      for (var i = 0; i < options.length; i++)
        if (options[i].isCorrect) i,
    ];
    return correct.length == 1 ? correct.first : -1;
  }

  @override
  String get type => 'check';
}

/// A question drawn from the bank by id: `::: check q:<id>` or, labelled
/// as a real past question, `::: waec q:<id>`.
class BankQuestionBlock extends LessonBlock {
  BankQuestionBlock(
    this.questionId, {
    required this.isPastQuestion,
    required String source,
  }) : super(source);
  final String questionId;

  /// True for `::: waec`: shown as "Seen in WAEC" plus the year.
  final bool isPastQuestion;

  @override
  String get type => isPastQuestion ? 'waec' : 'check.bank';
}

/// A revision card: a front and a back. Also feeds the subject's deck.
class CardBlock extends LessonBlock {
  CardBlock(this.front, this.back, super.source);
  final String front;
  final String back;

  @override
  String get type => 'card';
}

/// An image. [ref] is `asset:<id>` (an uploaded `lessonAssets` doc) or an
/// `https://` URL.
class FigureBlock extends LessonBlock {
  FigureBlock(this.ref, this.caption, this.widthFraction, super.source);
  final String ref;
  final String caption;

  /// 0 < width ≤ 1 of the article column; 1 when not given.
  final double widthFraction;

  /// The `lessonAssets` id, or null for a URL.
  String? get assetId =>
      ref.startsWith('asset:') ? ref.substring(6).trim() : null;

  @override
  String get type => 'figure';
}

enum CellAlign { start, center, end }

class TableBlock extends LessonBlock {
  TableBlock(this.header, this.rows, this.align, super.source);
  final List<String> header;
  final List<List<String>> rows;
  final List<CellAlign> align;

  @override
  String get type => 'table';
}

/// A collapsed "Go deeper" section.
class MoreBlock extends LessonBlock {
  MoreBlock(this.title, this.body, super.source);
  final String title;
  final List<LessonBlock> body;

  @override
  String get type => 'more';
}

/// A YouTube video inside the text. [youtubeId] is null when the fence
/// line held nothing parseable; the parser reports it.
class VideoBlock extends LessonBlock {
  VideoBlock(this.youtubeId, super.source);
  final String? youtubeId;

  @override
  String get type => 'video';
}

/// A note to the author. **Never rendered for students.**
class TodoBlock extends LessonBlock {
  TodoBlock(this.text, super.source);
  final String text;

  @override
  String get type => 'todo';
}

/// A fence with a kind this build does not know. Its contents are shown as
/// ordinary text, so a lesson written for a newer build still reads.
class UnknownBlock extends LessonBlock {
  UnknownBlock(this.kind, this.body, super.source);
  final String kind;
  final List<LessonBlock> body;

  @override
  String get type => 'unknown';
}

// ─── Parsing ──────────────────────────────────────────────────────────

final _open = RegExp(r'^:::\s*([A-Za-z][\w-]*)\s*(.*)$');
final _figure = RegExp(r'^!\[(.*)\]\(([^)\s]+)\)\s*(\{[^}]*\})?$');
final _option = RegExp(r'^[-*]\s+\[( |x|X)\]\s+(.*)$');
final _section = RegExp(r'^---\s*([A-Za-z]+)\b\s*(.*)$');
final _tableSeparator = RegExp(r'^\|?\s*:?-{3,}:?\s*(\|\s*:?-{3,}:?\s*)*\|?$');

bool _isClose(String trimmed) => trimmed == ':::';

/// [offset] is the 0-based index of `lines[0]` in the whole document, so
/// issues report real line numbers from inside nested blocks.
List<LessonBlock> _parseBlocks(
  List<String> lines,
  int offset,
  List<LessonIssue> issues,
) {
  final blocks = <LessonBlock>[];
  final plain = <String>[];

  void flushPlain() {
    if (plain.isEmpty) return;
    final text = plain.join('\n');
    for (final b in parseArticleBlocks(text)) {
      blocks.add(BasicBlock(b, b.lines.join('\n')));
    }
    plain.clear();
  }

  var i = 0;
  while (i < lines.length) {
    final trimmed = lines[i].trim();

    // ── Fenced block ──
    final open = _open.firstMatch(trimmed);
    if (open != null) {
      flushPlain();
      final end = _findClose(lines, i + 1);
      final closed = end < lines.length;
      if (!closed) {
        issues.add(
          LessonIssue(
            offset + i + 1,
            "'::: ${open.group(1)}' is never closed with ':::'",
          ),
        );
      }
      final inner = lines.sublist(i + 1, end);
      blocks.add(
        _fenced(
          open.group(1)!.toLowerCase(),
          open.group(2)!.trim(),
          inner,
          offset + i + 1,
          [lines[i], ...inner, if (closed) lines[end]].join('\n'),
          issues,
        ),
      );
      i = closed ? end + 1 : end;
      continue;
    }

    // A stray close with nothing open: not printed, but still a boundary —
    // the author meant a break there, not one run-on paragraph.
    if (_isClose(trimmed)) {
      flushPlain();
      issues.add(
        LessonIssue(
          offset + i + 1,
          "':::' closes nothing",
          severity: IssueSeverity.warning,
        ),
      );
      i++;
      continue;
    }

    // ── Figure ──
    final fig = _figure.firstMatch(trimmed);
    if (fig != null) {
      flushPlain();
      blocks.add(_figureBlock(fig, trimmed, offset + i + 1, issues));
      i++;
      continue;
    }

    // ── Table: a header row, a separator row, then body rows ──
    if (_isRow(trimmed) &&
        i + 1 < lines.length &&
        _tableSeparator.hasMatch(lines[i + 1].trim())) {
      flushPlain();
      var j = i + 2;
      while (j < lines.length && _isRow(lines[j].trim())) {
        j++;
      }
      blocks.add(_table(lines.sublist(i, j), offset + i + 1, issues));
      i = j;
      continue;
    }

    plain.add(lines[i]);
    i++;
  }
  flushPlain();
  return blocks;
}

bool _isRow(String trimmed) => trimmed.startsWith('|') && trimmed.length > 1;

/// Index of the `:::` closing the fence whose contents start at [from],
/// honouring nested fences; `lines.length` when there is none.
int _findClose(List<String> lines, int from) {
  var depth = 0;
  for (var j = from; j < lines.length; j++) {
    final t = lines[j].trim();
    if (_open.hasMatch(t)) {
      depth++;
    } else if (_isClose(t)) {
      if (depth == 0) return j;
      depth--;
    }
  }
  return lines.length;
}

class _Section {
  _Section(this.label, this.title, this.start);
  final String label;
  final String title;

  /// Index into the fence's inner lines where this section's text begins.
  final int start;
  final List<String> lines = [];
}

/// Splits a fence's inner lines on labelled separators (`--- step`,
/// `--- answer`, …), ignoring any inside a nested fence. The first section
/// has label `''`. A bare `---` is not a separator — it stays a rule.
List<_Section> _sections(List<String> inner, Set<String> labels) {
  final sections = [_Section('', '', 0)];
  var depth = 0;
  for (var j = 0; j < inner.length; j++) {
    final t = inner[j].trim();
    if (_open.hasMatch(t)) {
      depth++;
    } else if (_isClose(t) && depth > 0) {
      depth--;
    } else if (depth == 0) {
      final m = _section.firstMatch(t);
      if (m != null && labels.contains(m.group(1)!.toLowerCase())) {
        sections.add(
          _Section(m.group(1)!.toLowerCase(), m.group(2)!.trim(), j + 1),
        );
        continue;
      }
    }
    sections.last.lines.add(inner[j]);
  }
  return sections;
}

LessonBlock _fenced(
  String kind,
  String args,
  List<String> inner,
  int line, // 1-based line of the fence opener
  String source,
  List<LessonIssue> issues,
) {
  List<LessonBlock> parse(List<String> ls, int start) =>
      _parseBlocks(ls, line + start, issues);

  final callout = CalloutKind.tryParse(kind);
  if (callout != null) {
    if ((callout == CalloutKind.definition) && args.isEmpty) {
      issues.add(
        LessonIssue(
          line,
          "A definition needs its term: '::: definition Term'",
          severity: IssueSeverity.warning,
        ),
      );
    }
    return CalloutBlock(callout, args, parse(inner, 0), source);
  }

  switch (kind) {
    case 'example':
      final s = _sections(inner, {'step', 'answer'});
      final steps = [
        for (final x in s.skip(1).where((x) => x.label == 'step'))
          ExampleStep(x.title, parse(x.lines, x.start)),
      ];
      final answers = s.where((x) => x.label == 'answer').toList();
      if (steps.isEmpty && answers.isEmpty) {
        issues.add(
          LessonIssue(
            line,
            "A worked example needs at least one '--- step' or an '--- answer'",
            severity: IssueSeverity.warning,
          ),
        );
      }
      return ExampleBlock(
        args,
        parse(s.first.lines, 0),
        steps,
        answers.isEmpty
            ? null
            : parse(answers.first.lines, answers.first.start),
        source,
      );

    case 'tryit':
      final s = _sections(inner, {'hint', 'answer'});
      _Section? pick(String l) {
        for (final x in s) {
          if (x.label == l) return x;
        }
        return null;
      }
      final hint = pick('hint');
      final answer = pick('answer');
      if (answer == null) {
        issues.add(
          LessonIssue(
            line,
            "A 'try it' problem has no '--- answer'",
            severity: IssueSeverity.warning,
          ),
        );
      }
      return TryItBlock(
        args,
        parse(s.first.lines, 0),
        hint == null ? null : parse(hint.lines, hint.start),
        answer == null ? null : parse(answer.lines, answer.start),
        source,
      );

    case 'check':
    case 'waec':
      final ref = RegExp(r'^q:\s*(\S+)$').firstMatch(args);
      if (ref != null) {
        return BankQuestionBlock(
          ref.group(1)!,
          isPastQuestion: kind == 'waec',
          source: source,
        );
      }
      if (kind == 'waec') {
        issues.add(
          LessonIssue(
            line,
            "'::: waec' needs a question id: '::: waec q:<id>'",
          ),
        );
        return UnknownBlock(kind, parse(inner, 0), source);
      }
      final s = _sections(inner, {'why'});
      final question = <String>[];
      final options = <CheckOption>[];
      for (final l in s.first.lines) {
        final m = _option.firstMatch(l.trim());
        if (m != null) {
          options.add(CheckOption(m.group(2)!.trim(), m.group(1) != ' '));
        } else if (options.isEmpty) {
          question.add(l);
        }
      }
      final correct = options.where((o) => o.isCorrect).length;
      if (options.length < 2) {
        issues.add(
          LessonIssue(
            line,
            'A quick check needs at least two options: - [ ] wrong, - [x] right',
          ),
        );
      } else if (correct != 1) {
        issues.add(
          LessonIssue(
            line,
            'A quick check needs exactly one option marked [x] (found $correct)',
          ),
        );
      }
      final why = s.length > 1 ? s[1] : null;
      return CheckBlock(
        parse(question, 0),
        options,
        why == null ? null : parse(why.lines, why.start),
        source,
      );

    case 'card':
      final split = inner.indexWhere((l) => l.trim() == '---');
      if (split < 0) {
        issues.add(
          LessonIssue(
            line,
            "A card needs a front and a back, separated by '---'",
          ),
        );
        return CardBlock(inner.join('\n').trim(), '', source);
      }
      return CardBlock(
        inner.sublist(0, split).join('\n').trim(),
        inner.sublist(split + 1).join('\n').trim(),
        source,
      );

    case 'more':
      return MoreBlock(
        args.isEmpty ? 'Go deeper' : args,
        parse(inner, 0),
        source,
      );

    case 'video':
      final id = parseYouTubeId(args);
      if (id == null) {
        issues.add(LessonIssue(line, "'::: video' needs a YouTube link or id"));
      }
      return VideoBlock(id, source);

    case 'todo':
      final text = [args, ...inner].join('\n').trim();
      issues.add(
        LessonIssue(
          line,
          'To do: ${text.split('\n').first}',
          severity: IssueSeverity.warning,
        ),
      );
      return TodoBlock(text, source);

    default:
      issues.add(
        LessonIssue(line, "Unknown block '::: $kind' — shown as plain text"),
      );
      return UnknownBlock(kind, parse(inner, 0), source);
  }
}

FigureBlock _figureBlock(
  RegExpMatch m,
  String source,
  int line,
  List<LessonIssue> issues,
) {
  final ref = m.group(2)!.trim();
  var width = 1.0;
  final attrs = m.group(3);
  if (attrs != null) {
    final w = RegExp(r'width\s*=\s*(\d{1,3})%').firstMatch(attrs);
    if (w != null) {
      final pct = int.parse(w.group(1)!);
      if (pct > 0 && pct <= 100) {
        width = pct / 100;
      } else {
        issues.add(
          LessonIssue(
            line,
            'Image width must be between 1% and 100%',
            severity: IssueSeverity.warning,
          ),
        );
      }
    }
  }
  final okRef = ref.startsWith('asset:')
      ? ref.length > 6
      : ref.startsWith('https://');
  if (!okRef) {
    issues.add(
      LessonIssue(
        line,
        "An image must point at an uploaded asset (asset:<id>) or an https:// link",
      ),
    );
  }
  return FigureBlock(ref, m.group(1)!.trim(), width, source);
}

List<String> _cells(String row) {
  var t = row.trim();
  if (t.startsWith('|')) t = t.substring(1);
  if (t.endsWith('|') && !t.endsWith(r'\|')) t = t.substring(0, t.length - 1);
  // `\|` is a literal bar inside a cell.
  return t
      .split(RegExp(r'(?<!\\)\|'))
      .map((c) => c.replaceAll(r'\|', '|').trim())
      .toList();
}

TableBlock _table(List<String> rows, int line, List<LessonIssue> issues) {
  final header = _cells(rows[0]);
  final align = _cells(rows[1]).map((c) {
    final l = c.startsWith(':'), r = c.endsWith(':');
    return l && r ? CellAlign.center : (r ? CellAlign.end : CellAlign.start);
  }).toList();
  final body = <List<String>>[];
  for (var k = 2; k < rows.length; k++) {
    var cells = _cells(rows[k]);
    if (cells.length != header.length) {
      issues.add(
        LessonIssue(
          line + k,
          'Table row has ${cells.length} cells; the header has ${header.length}',
          severity: IssueSeverity.warning,
        ),
      );
      cells = [
        for (var c = 0; c < header.length; c++)
          c < cells.length ? cells[c] : '',
      ];
    }
    body.add(cells);
  }
  while (align.length < header.length) {
    align.add(CellAlign.start);
  }
  return TableBlock(
    header,
    body,
    align.sublist(0, header.length),
    rows.join('\n'),
  );
}

// ─── Keys ─────────────────────────────────────────────────────────────

List<LessonBlock> _keyed(List<LessonBlock> blocks) {
  final seen = <String, int>{};
  for (final b in blocks) {
    final base = '${b.type}:${_hash(_normalise(b.source))}';
    final n = seen[base] ?? 0;
    seen[base] = n + 1;
    b.key = '$base:$n';
  }
  return blocks;
}

String _normalise(String s) =>
    s.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();

/// FNV-1a, 32-bit, as 8 hex digits. Stable across runs and platforms,
/// which `String.hashCode` is not guaranteed to be.
///
/// The multiply by the FNV prime (2^24 + 0x193) is split in two so no
/// intermediate exceeds 2^53: on the web, ints are JavaScript doubles, and
/// a plain `h * 0x01000193` loses low bits there — the same block would
/// get a different key in the browser than in tests, and every note on it
/// would detach.
String _hash(String s) {
  var h = 0x811c9dc5;
  for (final c in s.codeUnits) {
    h = (h ^ c) & 0xffffffff;
    h = ((h * 0x193) + ((h & 0xff) * 0x1000000)) % 0x100000000;
  }
  return h.toRadixString(16).padLeft(8, '0');
}
