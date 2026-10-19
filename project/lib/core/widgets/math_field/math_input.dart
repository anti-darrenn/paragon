/// Typing maths without knowing LaTeX: the "Normal" side of the editor's
/// Normal/LaTeX switch.
///
/// Pure Dart, tested on its own (`math_input_test.dart`). Stored text is
/// always the renderers' LaTeX dialect; Normal mode is a way of typing it.
///
/// **Normal mode** reads calculator-style text and finds the maths in it:
/// `x^2 + 1`, `(x+1)/(x-1)`, `sqrt(2)`, `3/4`, `pi r^2`, `>=`, `!=`, `+-`,
/// `30 deg`, a recurring decimal as `0.(3)` or `0.3 rec`, `log_2(8)`.
/// Prose stays prose: a run of words is never maths, and a lone number or
/// letter ("in 2019", "a car") is left alone. Anything already in
/// `\( \)` is kept exactly as typed.
///
/// **The way back** ([latexToPlain]) is best effort. A field whose LaTeX it
/// cannot show faithfully ([showsInNormalMode] is false) is edited in LaTeX
/// mode instead: switching modes never rewrites a stored value.
library;

import '../../latex/tex_preprocess.dart';

enum MathInputMode { normal, latex }

// ─── Normal → LaTeX ───────────────────────────────────────────────────

/// Function and constant names Normal mode understands.
const _functions = {
  'sin', 'cos', 'tan', 'sec', 'csc', 'cot', 'arcsin', 'arccos', 'arctan',
  'sinh', 'cosh', 'tanh', 'log', 'ln', 'exp', 'lim', 'det', 'min', 'max',
};
const _greek = {
  'pi', 'theta', 'alpha', 'beta', 'gamma', 'delta', 'lambda', 'mu', 'sigma',
  'omega', 'phi', 'rho', 'epsilon', 'Delta', 'Sigma', 'Omega',
};
const _mathWords = {
  ..._functions,
  ..._greek,
  'sqrt', 'cbrt', 'inf', 'infinity', 'deg', 'rec',
};

/// Calculator-style [plain] with its maths turned into `\( … \)` LaTeX.
String plainToLatex(String plain) {
  final out = StringBuffer();
  var i = 0;
  // Maths the author already wrote as LaTeX is theirs: kept as it is.
  final kept = RegExp(r'\\\(.*?\\\)|\\\[.*?\\\]|\$\$.*?\$\$', dotAll: true);
  for (final m in kept.allMatches(plain)) {
    out.write(_textToLatex(plain.substring(i, m.start)));
    out.write(m.group(0));
    i = m.end;
  }
  out.write(_textToLatex(plain.substring(i)));
  return out.toString();
}

class _Tok {
  const _Tok(this.kind, this.text);
  final String kind; // num, word, op, open, close, space, other
  final String text;
}

final _tokenRe = RegExp(
  r'(\d+(?:\.\d*)?(?:\(\d+\))?|\.\d+)|([A-Za-z]+)|(>=|<=|!=|\+-|->|~=|[\^_/*=<>+\-|√°%])|(\()|(\))|([ \t]+)|([\s\S])',
);

List<_Tok> _tokens(String s) => [
  for (final m in _tokenRe.allMatches(s))
    if (m.group(1) != null)
      _Tok('num', m.group(1)!)
    else if (m.group(2) != null)
      _Tok('word', m.group(2)!)
    else if (m.group(3) != null)
      _Tok('op', m.group(3)!)
    else if (m.group(4) != null)
      const _Tok('open', '(')
    else if (m.group(5) != null)
      const _Tok('close', ')')
    else if (m.group(6) != null)
      _Tok('space', m.group(6)!)
    else
      _Tok('other', m.group(7)!),
];

bool _mathy(_Tok t, _Tok? before) => switch (t.kind) {
  'num' || 'op' || 'open' || 'close' || 'space' => true,
  'word' =>
    t.text.length == 1 ||
        _mathWords.contains(t.text) ||
        // Letters joined to a number or operator are a product: 4ac, 2xy.
        // Not an ordinal (2nd) and never a long word.
        (t.text.length <= 3 &&
            !const {'st', 'nd', 'rd', 'th'}.contains(t.text) &&
            before != null &&
            (before.kind == 'num' ||
                before.kind == 'op' ||
                before.kind == 'open')),
  _ => false,
};

bool _operand(_Tok t) =>
    t.kind == 'num' ||
    t.kind == 'open' ||
    t.kind == 'close' ||
    (t.kind == 'word' && t.text.length == 1) ||
    (t.kind == 'word' && _greek.contains(t.text)) ||
    (t.kind == 'word' && (t.text == 'inf' || t.text == 'infinity'));

/// Whether a run of maths-looking tokens is really maths: an operator
/// between two operands, a function applied, a root, degrees, a recurring
/// decimal. "in 2019" and "a car" are not.
bool _isMaths(List<_Tok> run) {
  final t = [for (final x in run) if (x.kind != 'space') x];
  for (var k = 0; k < t.length; k++) {
    final x = t[k];
    if (x.kind == 'num' && x.text.contains('(')) return true; // 0.(3)
    if (x.kind == 'op' && (x.text == '√' || x.text == '°')) return true;
    if (x.kind == 'word' &&
        (_functions.contains(x.text) ||
            x.text == 'sqrt' ||
            x.text == 'cbrt') &&
        k + 1 < t.length &&
        (_operand(t[k + 1]) || t[k + 1].kind == 'op')) {
      return true;
    }
    if (x.kind == 'word' &&
        (x.text == 'deg' || x.text == 'rec') &&
        k > 0 &&
        t[k - 1].kind == 'num') {
      return true;
    }
    if (x.kind == 'word' && _greek.contains(x.text)) return true;
    if (x.kind == 'op' &&
        x.text != '|' &&
        k > 0 &&
        k + 1 < t.length &&
        _operand(t[k - 1]) &&
        (_operand(t[k + 1]) ||
            (t[k + 1].kind == 'op' && t[k + 1].text == '-') ||
            (t[k + 1].kind == 'word' && _mathWords.contains(t[k + 1].text)))) {
      return true;
    }
  }
  return false;
}

String _textToLatex(String s) {
  if (s.isEmpty) return s;
  final toks = _tokens(s);
  final out = StringBuffer();
  var k = 0;
  _Tok? prev(int i) => i > 0 ? toks[i - 1] : null;
  while (k < toks.length) {
    if (!_mathy(toks[k], prev(k)) || toks[k].kind == 'space') {
      out.write(toks[k].text);
      k++;
      continue;
    }
    var end = k;
    while (end < toks.length && _mathy(toks[end], prev(end))) {
      end++;
    }
    // Trailing spaces belong to the text after; so does a closing bracket
    // with no opener in the run.
    var last = end;
    while (last > k && toks[last - 1].kind == 'space') {
      last--;
    }
    // A letter after a space with no operator before it is a unit or a
    // word: "10^-3 m", "x = 3 m". "x + y" keeps its y.
    while (last - k >= 3 &&
        toks[last - 1].kind == 'word' &&
        toks[last - 1].text.length == 1 &&
        toks[last - 2].kind == 'space' &&
        toks[last - 3].kind != 'op') {
      last -= 2;
      while (last > k && toks[last - 1].kind == 'space') {
        last--;
      }
    }
    var run = toks.sublist(k, last);
    var depth = 0;
    for (final t in run) {
      if (t.kind == 'open') depth++;
      if (t.kind == 'close') depth--;
    }
    while (depth < 0 && run.isNotEmpty && run.last.kind == 'close') {
      run = run.sublist(0, run.length - 1);
      depth++;
    }
    if (run.isEmpty) {
      out.write(toks[k].text);
      k++;
      continue;
    }
    final text = run.map((t) => t.text).join();
    out.write(_isMaths(run) ? '\\(${convertPlainMaths(text)}\\)' : text);
    // Whatever was trimmed off the run is written as text next time round.
    k += run.length;
  }
  return out.toString();
}

/// One run of calculator-style maths as LaTeX (no delimiters).
String convertPlainMaths(String run) {
  var s = run.trim();
  // Recurring decimals: 0.(3), 0.1(6), 0.3 rec.
  s = s.replaceAllMapped(
    RegExp(r'(\d*)\.(\d*)\((\d+)\)'),
    (m) => '${m.group(1)}.${m.group(2)}\\overline{${m.group(3)}}',
  );
  s = s.replaceAllMapped(
    RegExp(r'(\d*)\.(\d+)\s*rec\b'),
    (m) => '${m.group(1)}.\\overline{${m.group(2)}}',
  );
  // Roots: sqrt(…), cbrt(…), √(…), √x.
  s = _applyFunction(s, 'cbrt', (inner) => '\\sqrt[3]{$inner}');
  s = _applyFunction(s, 'sqrt', (inner) => '\\sqrt{$inner}');
  s = _applyFunction(s, '√', (inner) => '\\sqrt{$inner}');
  s = s.replaceAllMapped(
    RegExp(r'√\s*([A-Za-z0-9.]+)'),
    (m) => '\\sqrt{${m.group(1)}}',
  );
  // Degrees: 30 deg, 30°.
  s = s.replaceAllMapped(
    RegExp(r'(\d+(?:\.\d+)?)\s*(?:deg\b|°)'),
    (m) => '${m.group(1)}^{\\circ}',
  );
  s = s.replaceAll('°', r'^{\circ}');
  s = _fractions(s);
  s = _scripts(s, '^');
  s = _scripts(s, '_');
  // Names.
  s = s.replaceAllMapped(RegExp(r'\b(infinity|inf)\b'), (_) => r'\infty ');
  for (final f in _functions) {
    s = s.replaceAllMapped(
      RegExp('(?<![A-Za-z\\\\])$f(?![A-Za-z])'),
      (_) => '\\$f',
    );
  }
  for (final g in _greek) {
    s = s.replaceAllMapped(
      RegExp('(?<![A-Za-z\\\\])$g(?![A-Za-z])'),
      (_) => '\\$g ',
    );
  }
  // Operators.
  s = s
      .replaceAll('>=', r'\geq ')
      .replaceAll('<=', r'\leq ')
      .replaceAll('!=', r'\neq ')
      .replaceAll('+-', r'\pm ')
      .replaceAll('->', r'\to ')
      .replaceAll('~=', r'\approx ')
      .replaceAll('*', r'\times ')
      .replaceAll(RegExp(r'(?<!\\)%'), r'\%');
  return s.replaceAll(RegExp(r' +'), ' ').replaceAll(RegExp(r' $'), '').trim();
}

/// `name(…)` with balanced brackets replaced by [wrap] of its inside.
String _applyFunction(String s, String name, String Function(String) wrap) {
  var out = s;
  var from = 0;
  while (true) {
    final at = out.indexOf(name, from);
    if (at < 0) break;
    var p = at + name.length;
    while (p < out.length && out[p] == ' ') {
      p++;
    }
    if (p >= out.length || out[p] != '(') {
      from = at + name.length;
      continue;
    }
    final close = _closeParen(out, p);
    if (close < 0) break;
    final inner = out.substring(p + 1, close);
    final replaced = wrap(inner);
    out = out.substring(0, at) + replaced + out.substring(close + 1);
    from = at + replaced.length;
  }
  return out;
}

int _closeParen(String s, int open) {
  var depth = 0;
  for (var i = open; i < s.length; i++) {
    if (s[i] == '(') depth++;
    if (s[i] == ')') {
      depth--;
      if (depth == 0) return i;
    }
  }
  return -1;
}

int _openParen(String s, int close) {
  var depth = 0;
  for (var i = close; i >= 0; i--) {
    if (s[i] == ')') depth++;
    if (s[i] == '(') {
      depth--;
      if (depth == 0) return i;
    }
  }
  return -1;
}

int _openBrace(String s, int close) {
  var depth = 0;
  for (var i = close; i >= 0; i--) {
    if (s[i] == '}') depth++;
    if (s[i] == '{') {
      depth--;
      if (depth == 0) return i;
    }
  }
  return -1;
}

final _atomChar = RegExp(r'[A-Za-z0-9.]');

/// `a/b` → `\frac{a}{b}`. An operand is a bracketed group (brackets
/// dropped, unless a function name owns them: `sin(x)/2`), a `\cmd{…}`
/// group, or a run of letters, digits and points.
String _fractions(String input) {
  var s = input;
  for (var guard = 0; guard < 50; guard++) {
    final slash = s.indexOf('/');
    if (slash < 0) break;
    // Left operand.
    var l = slash - 1;
    while (l >= 0 && s[l] == ' ') {
      l--;
    }
    if (l < 0) break;
    int lStart;
    String left;
    if (s[l] == ')') {
      final open = _openParen(s, l);
      if (open < 0) break;
      var owner = open;
      while (owner > 0 && RegExp(r'[A-Za-z]').hasMatch(s[owner - 1])) {
        owner--;
      }
      final word = s.substring(owner, open);
      if (_functions.contains(word)) {
        lStart = owner;
        left = s.substring(owner, l + 1);
      } else {
        lStart = open;
        left = s.substring(open + 1, l);
      }
    } else if (s[l] == '}') {
      final open = _openBrace(s, l);
      if (open < 0) break;
      var cmd = open;
      while (cmd > 0 && RegExp(r'[A-Za-z\[\]0-9]').hasMatch(s[cmd - 1])) {
        cmd--;
      }
      if (cmd > 0 && s[cmd - 1] == r'\') cmd--;
      lStart = cmd;
      left = s.substring(cmd, l + 1);
    } else if (_atomChar.hasMatch(s[l])) {
      var st = l;
      while (st > 0 && _atomChar.hasMatch(s[st - 1])) {
        st--;
      }
      lStart = st;
      left = s.substring(st, l + 1);
    } else {
      break;
    }
    // Right operand.
    var r = slash + 1;
    while (r < s.length && s[r] == ' ') {
      r++;
    }
    if (r >= s.length) break;
    int rEnd;
    String right;
    if (s[r] == '(') {
      final close = _closeParen(s, r);
      if (close < 0) break;
      rEnd = close + 1;
      right = s.substring(r + 1, close);
    } else if (s[r] == r'\') {
      final m = RegExp(r'\\[A-Za-z]+(\[[^\]]*\])?(\{[^{}]*\})?').matchAsPrefix(
        s,
        r,
      );
      if (m == null) break;
      rEnd = m.end;
      right = m.group(0)!;
    } else {
      final m = RegExp(r'-?[A-Za-z0-9.]+').matchAsPrefix(s, r);
      if (m == null) break;
      rEnd = m.end;
      right = m.group(0)!;
    }
    s = '${s.substring(0, lStart)}\\frac{${left.trim()}}{${right.trim()}}'
        '${s.substring(rEnd)}';
  }
  return s;
}

/// `x^2`, `x^(n+1)`, `10^-3`, `x_1`, `log_2` with the script in braces.
String _scripts(String s, String mark) {
  final out = StringBuffer();
  var i = 0;
  while (i < s.length) {
    if (s[i] != mark) {
      out.write(s[i]);
      i++;
      continue;
    }
    out.write(mark);
    var p = i + 1;
    while (p < s.length && s[p] == ' ') {
      p++;
    }
    if (p < s.length && s[p] == '{') {
      i = p; // already braced
      continue;
    }
    if (p < s.length && s[p] == '(') {
      final close = _closeParen(s, p);
      if (close > 0) {
        out.write('{${s.substring(p + 1, close)}}');
        i = close + 1;
        continue;
      }
    }
    final m = RegExp(r'-?[A-Za-z0-9.]+').matchAsPrefix(s, p);
    if (m != null) {
      // A script of letters is one symbol at a time, as in a textbook:
      // x^n, but x^2y is x² times y.
      final t = m.group(0)!;
      final digits = RegExp(r'^-?[0-9.]+').firstMatch(t)?.group(0);
      final take = digits ?? (t.startsWith('-') ? t.substring(0, 2) : t[0]);
      out.write('{$take}');
      i = p + take.length;
      continue;
    }
    i = p;
  }
  return out.toString();
}

// ─── LaTeX → Normal ───────────────────────────────────────────────────

/// [latex] as Normal mode shows it: each maths span in calculator style.
/// Best effort; see [showsInNormalMode].
String latexToPlain(String latex) {
  final s = normalizeTex(latex);
  final out = StringBuffer();
  var i = 0;
  final span = RegExp(r'\\\((.*?)\\\)', dotAll: true);
  for (final m in span.allMatches(s)) {
    out.write(s.substring(i, m.start));
    out.write(_mathToPlain(m.group(1)!));
    i = m.end;
  }
  out.write(s.substring(i));
  return out.toString();
}

/// Whether [latex] survives a trip through Normal mode unchanged, so the
/// field can be edited there. A display equation, a matrix or a command
/// Normal mode has no words for keeps the field in LaTeX mode.
bool showsInNormalMode(String latex) {
  if (latex.trim().isEmpty) return true;
  final plain = latexToPlain(latex);
  // Anything Normal mode would still show as a backslash command (display
  // maths, a matrix, \textbf) is not something it can edit.
  if (plain.replaceAll(r'\$', '').contains(r'\')) return false;
  final back = plainToLatex(plain);
  return _canonical(back) == _canonical(normalizeTex(latex));
}

String _canonical(String s) => s.replaceAllMapped(
  RegExp(r'\\\((.*?)\\\)', dotAll: true),
  (m) => '\\(${m.group(1)!.replaceAll(RegExp(r'\s+'), '')}\\)',
);

String _mathToPlain(String tex) {
  var s = tex;
  for (var guard = 0; guard < 30; guard++) {
    final before = s;
    s = s.replaceAllMapped(
      RegExp(r'\\frac\{([^{}]*)\}\{([^{}]*)\}'),
      (m) => '${_group(m.group(1)!)}/${_group(m.group(2)!)}',
    );
    s = s.replaceAllMapped(
      RegExp(r'\\sqrt\[3\]\{([^{}]*)\}'),
      (m) => 'cbrt(${m.group(1)})',
    );
    s = s.replaceAllMapped(
      RegExp(r'\\sqrt\{([^{}]*)\}'),
      (m) => 'sqrt(${m.group(1)})',
    );
    s = s.replaceAllMapped(
      RegExp(r'(\d*)\.(\d*)\\overline\{(\d+)\}'),
      (m) => '${m.group(1)}.${m.group(2)}(${m.group(3)})',
    );
    s = s.replaceAll(RegExp(r'\^\{\\circ\}'), '°');
    s = s.replaceAllMapped(
      RegExp(r'([\^_])\{([^{}]*)\}'),
      (m) => '${m.group(1)}${_group(m.group(2)!)}',
    );
    if (s == before) break;
  }
  const ops = {
    r'\times': '*', r'\geq': '>=', r'\leq': '<=', r'\neq': '!=',
    r'\pm': '+-', r'\to': '->', r'\approx': '~=', r'\infty': 'infinity',
    r'\%': '%', r'\ge': '>=', r'\le': '<=', r'\ne': '!=', r'\cdot': '*',
  };
  for (final e in ops.entries) {
    s = s.replaceAllMapped(
      RegExp('${RegExp.escape(e.key)}(?![A-Za-z])\\s?'),
      (_) => e.value,
    );
  }
  for (final name in {..._functions, ..._greek}) {
    s = s.replaceAllMapped(
      RegExp('\\\\$name(?![A-Za-z])\\s?'),
      (_) => _greek.contains(name) ? '$name ' : name,
    );
  }
  return s.trim();
}

/// An operand as Normal mode writes it: bare when it is one number or
/// symbol, in brackets otherwise.
String _group(String inner) =>
    RegExp(r'^-?[A-Za-z0-9.]+$').hasMatch(inner) ? inner : '($inner)';

// ─── Steps in a worked answer ─────────────────────────────────────────

/// A worked answer is steps separated by a blank line: the generators
/// write them that way, and hints (`hints.dart`) offer one step at a time.
/// Authors had to press Enter twice for every step (owner's request,
/// 2026-10-19), so in a box that holds steps one Enter starts a new step.
///
/// Given the box's text before and after one keystroke and the cursor, the
/// text with the new line doubled, or null to leave it as typed. Left as
/// typed: anything but a single newline typed at the cursor, a newline at
/// the very start or next to another one (Enter on an empty line stays
/// one line, so a third Enter is still possible), and one inside maths,
/// where a blank line would break the expression.
({String text, int caret})? paragraphBreak(
  String before,
  String after,
  int caret,
) {
  if (after.length != before.length + 1) return null;
  if (caret < 2 || caret > after.length || after[caret - 1] != '\n') {
    return null;
  }
  if (after.replaceRange(caret - 1, caret, '') != before) return null;
  if (after[caret - 2] == '\n') return null;
  if (caret < after.length && after[caret] == '\n') return null;
  if (isInsideMath(after, caret - 1)) return null;
  return (text: after.replaceRange(caret, caret, '\n'), caret: caret + 1);
}

// ─── Inserting from the toolbar ───────────────────────────────────────

/// One toolbar button: what it shows, and what it types in each mode. `|`
/// marks where the cursor lands; a selection is put there.
class MathSnippet {
  const MathSnippet(this.label, this.tip, {required this.latex, this.plain});
  final String label;
  final String tip;
  final String latex;

  /// What Normal mode types; null hides the button there.
  final String? plain;
}

const kMathSnippets = <MathSnippet>[
  MathSnippet('a/b', 'Fraction', latex: r'\frac{|}{}', plain: '(|)/()'),
  MathSnippet('xⁿ', 'Power', latex: '^{|}', plain: '^(|)'),
  MathSnippet('x₁', 'Subscript', latex: '_{|}', plain: '_(|)'),
  MathSnippet('√', 'Square root', latex: r'\sqrt{|}', plain: 'sqrt(|)'),
  MathSnippet('∛', 'Cube root', latex: r'\sqrt[3]{|}', plain: 'cbrt(|)'),
  MathSnippet(
    '0.3̅',
    'Recurring decimal (bar over the digits that repeat)',
    latex: r'\overline{|}',
    plain: '(|)',
  ),
  MathSnippet('×', 'Times', latex: r'\times ', plain: ' * '),
  MathSnippet('÷', 'Divide', latex: r'\div ', plain: ' / '),
  MathSnippet('±', 'Plus or minus', latex: r'\pm ', plain: '+-'),
  MathSnippet('°', 'Degrees', latex: r'^{\circ}', plain: '°'),
  MathSnippet('π', 'Pi', latex: r'\pi ', plain: 'pi'),
  MathSnippet('θ', 'Theta', latex: r'\theta ', plain: 'theta'),
  MathSnippet('≤', 'Less than or equal', latex: r'\leq ', plain: '<='),
  MathSnippet('≥', 'Greater than or equal', latex: r'\geq ', plain: '>='),
  MathSnippet('≠', 'Not equal', latex: r'\neq ', plain: '!='),
  MathSnippet('v⃗', 'Vector', latex: r'\vec{|}'),
  MathSnippet('AB̅', 'Line segment', latex: r'\overline{|}'),
  MathSnippet(
    '[ ]',
    'Matrix',
    latex: r'\begin{pmatrix} | & \\ & \end{pmatrix}',
  ),
  MathSnippet('H₂O', 'Chemical formula', latex: r'\ce{|}'),
  MathSnippet('m/s²', 'Units', latex: r'\si{|}'),
];

/// Whether [offset] in [text] is inside `\( … \)` or `\[ … \]`.
bool isInsideMath(String text, int offset) {
  final span = RegExp(r'\\\(.*?(\\\)|$)|\\\[.*?(\\\]|$)', dotAll: true);
  for (final m in span.allMatches(text)) {
    // The closing delimiter is group 1 for \( and group 2 for \[; empty
    // while the maths is still open.
    final closed = (m.group(1) ?? m.group(2) ?? '').isNotEmpty;
    if (offset > m.start + 1 && offset <= m.end - (closed ? 2 : 0)) {
      return true;
    }
    if (m.start > offset) break;
  }
  return false;
}

/// [text] with [snippet] typed over `start..end`: the new text and where
/// the cursor goes. In LaTeX mode a snippet typed outside maths comes
/// wrapped in `\( \)`, so a toolbar button never produces raw source.
({String text, int caret}) applySnippet(
  String text,
  int start,
  int end,
  String snippet, {
  required bool latexMode,
}) {
  final s = start.clamp(0, text.length);
  final e = end.clamp(s, text.length);
  final picked = text.substring(s, e);
  var t = snippet;
  if (latexMode && !isInsideMath(text, s)) t = '\\(${t.trimRight()}\\)';
  final caret = t.indexOf('|');
  final clean = t.replaceFirst('|', '');
  final typed = caret >= 0
      ? clean.substring(0, caret) + picked + clean.substring(caret)
      : clean;
  final at = caret >= 0
      ? s + caret + picked.length
      : s + (latexMode && t.startsWith(r'\(') ? typed.length - 2 : typed.length);
  return (text: text.replaceRange(s, e, typed), caret: at);
}
