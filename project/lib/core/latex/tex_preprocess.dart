/// Turns LaTeX as people write it in Overleaf into the dialect Paragon's
/// renderers draw.
///
/// Pure Dart, no Flutter: `FullLatexView`, `MathText`, read-aloud and the
/// question checks all call [normalizeTex] first, and
/// `tools/site/tex_preprocess.js` is its line-for-line mirror for the
/// static pages (`test/fixtures/tex_preprocess_cases.json` is shared by
/// both test suites, so the two cannot drift).
///
/// What comes out uses only:
/// - maths in `\(...\)`, `\[...\]` or `$$...$$`, containing commands
///   flutter_math_fork parses;
/// - the text commands the renderers draw: `\textbf`, `\textit`,
///   `\underline`, `\texttt`, `\vspace` and `\$`;
/// - plain characters.
///
/// It is **idempotent**: normalising its own output changes nothing, so a
/// caller never has to know whether a string was normalised already.
///
/// **What it adds.**
/// - **Bare maths.** A maths command typed without delimiters
///   (`0.\overline{3}`, `\frac{1}{2}`) is wrapped as inline maths. Before
///   this it showed as raw source.
/// - **Text mode:** `\emph`, `\textsc`, `\textsuperscript`, sections,
///   `itemize`/`enumerate`, `tabular`, `center`, `\\`, `--`, quotes,
///   accents, escapes.
/// - **Maths:** `\ce`/`\pu` (a subset of mhchem), `\si`/`\SI`/`\unit`/
///   `\qty`/`\num`/`\ang` (siunitx), `gathered`, `align`, `split`,
///   `\recurring`, `\degree`, `\celsius`, `\ohm`, `\nicefrac`, `\substack`
///   and the other commands the parser lacks.
/// - **Macros:** `\newcommand`, `\renewcommand`, `\def` and
///   `\DeclareMathOperator`, within one string.
///
/// **What it cannot do:** TikZ, pgfplots, `\includegraphics` and other
/// packages that draw. Diagrams are image uploads.
///
/// **The dialect stays the corpus dialect:** a lone `$` is a dollar sign.
/// The editor's LaTeX mode converts `$...$` on save (`dollarMathToParens`).
library;

/// [source] in the renderers' dialect. Safe on any string, and a no-op on
/// one with no backslash in it.
String normalizeTex(String source) {
  if (!source.contains(r'\')) return source;
  final s = expandMacros(source.replaceAll('\r\n', '\n'));
  final outer = _held;
  final held = _held = <String>[];
  try {
    // Finished maths is held as a placeholder while the text passes run,
    // so a list or table around it is processed whole and nothing inside
    // it is mistaken for text.
    final b = StringBuffer();
    var i = 0;
    while (i < s.length) {
      final m = _nextMathSpan(s, i);
      if (m == null) {
        b.write(s.substring(i));
        break;
      }
      b.write(s.substring(i, m.start));
      final inner = s.substring(m.start + m.open.length, m.innerEnd);
      b.write(_hold('${m.open}${normalizeMath(inner)}${m.close}'));
      i = m.end;
    }
    var out = _restore(_text(b.toString()), held);
    // A list or table at either end leaves a line break the author did not
    // type.
    if (!source.startsWith('\n')) out = out.replaceFirst(RegExp(r'^\n+'), '');
    if (!source.endsWith('\n')) out = out.replaceFirst(RegExp(r'\n+$'), '');
    return out;
  } finally {
    _held = outer;
  }
}

/// Maths already in its final form, by placeholder number, for the
/// [normalizeTex] call in progress.
List<String>? _held;

final _placeholder = RegExp('\u0001(\\d+)\u0002');

String _hold(String rendered) {
  _held!.add(rendered);
  return '\u0001${_held!.length - 1}\u0002';
}

String _restore(String t, List<String> held) =>
    t.replaceAllMapped(_placeholder, (m) => held[int.parse(m.group(1)!)]);

/// A held span's maths without its delimiters.
String _heldInner(int n) {
  final r = _held![n];
  return r.substring(2, r.length - 2);
}

/// `$...$` as inline maths and `\$` as a literal dollar, for text typed in
/// the editor's LaTeX mode, where a `$` means what it means in Overleaf.
/// `$$...$$` is left alone (the renderers draw it already).
String dollarMathToParens(String s) {
  final out = StringBuffer();
  var i = 0;
  while (i < s.length) {
    final c = s[i];
    if (c == r'\' && i + 1 < s.length) {
      out.write(s.substring(i, i + 2));
      i += 2;
      continue;
    }
    if (c == r'$') {
      if (i + 1 < s.length && s[i + 1] == r'$') {
        final close = s.indexOf(r'$$', i + 2);
        if (close < 0) {
          out.write(s.substring(i));
          break;
        }
        out.write(s.substring(i, close + 2));
        i = close + 2;
        continue;
      }
      final close = _unescapedDollar(s, i + 1);
      if (close > i + 1) {
        out.write(r'\(');
        out.write(s.substring(i + 1, close));
        out.write(r'\)');
        i = close + 1;
        continue;
      }
      out.write(r'\$');
      i++;
      continue;
    }
    out.write(c);
    i++;
  }
  return out.toString();
}

int _unescapedDollar(String s, int from) {
  for (var i = from; i < s.length; i++) {
    if (s[i] == r'\') {
      i++;
      continue;
    }
    if (s[i] == r'$') return i;
  }
  return -1;
}

// ─── Math spans ───────────────────────────────────────────────────────

class _Span {
  final int start;
  final int innerEnd;
  final int end;
  final String open;
  final String close;
  const _Span(this.start, this.innerEnd, this.end, this.open, this.close);
}

/// The next `\(...\)`, `\[...\]` or `$$...$$` at or after [from], matched
/// exactly as `FullLatexView` matches them (first closing delimiter).
_Span? _nextMathSpan(String s, int from) {
  var i = from;
  while (i < s.length) {
    final c = s.codeUnitAt(i);
    if (c == 92 && i + 1 < s.length) {
      final n = s[i + 1];
      if (n == '(' || n == '[') {
        final close = n == '(' ? r'\)' : r'\]';
        final end = s.indexOf(close, i + 2);
        if (end != -1) {
          return _Span(i, end, end + 2, '\\$n', close);
        }
      }
      i += 2; // an escaped character is never a delimiter
      continue;
    }
    if (c == 36 && i + 1 < s.length && s.codeUnitAt(i + 1) == 36) {
      final end = s.indexOf(r'$$', i + 2);
      if (end != -1) return _Span(i, end, end + 2, r'$$', r'$$');
    }
    i++;
  }
  return null;
}

// ─── Macros ───────────────────────────────────────────────────────────

class _Macro {
  final int args;
  final String body;
  const _Macro(this.args, this.body);
}

final _defineCommand = RegExp(
  r'\\(?:re)?newcommand\*?\s*\{?\s*\\([A-Za-z]+)\s*\}?\s*(?:\[(\d)\])?\s*(?:\[[^\]]*\])?\s*\{',
);
final _defCommand = RegExp(r'\\[gex]?def\s*\\([A-Za-z]+)\s*((?:#\d)*)\s*\{');
final _declareOperator = RegExp(
  r'\\DeclareMathOperator\*?\s*\{\s*\\([A-Za-z]+)\s*\}\s*\{',
);
final _letCommand = RegExp(r'\\let\s*\\([A-Za-z]+)\s*=?\s*(\\[A-Za-z]+)');

/// Definitions removed and every use expanded. Nested macros expand up to
/// eight levels deep, which also stops a self-referential definition.
String expandMacros(String source) {
  if (!source.contains('command') &&
      !source.contains('def') &&
      !source.contains(r'\let') &&
      !source.contains('DeclareMathOperator')) {
    return source;
  }
  final macros = <String, _Macro>{};
  var s = source;

  String cut(RegExp re, void Function(Match m, String body) take) {
    var out = s;
    while (true) {
      final m = re.firstMatch(out);
      if (m == null) break;
      final open = m.end - 1;
      final close = matchingBrace(out, open);
      if (close < 0) break;
      take(m, out.substring(open + 1, close));
      // The definition goes, and the space or line break after it.
      out = out.substring(0, m.start) +
          out.substring(close + 1).replaceFirst(RegExp(r'^[ \t]*\n?[ \t]*'), '');
    }
    return out;
  }

  s = cut(_defineCommand, (m, body) {
    macros[m.group(1)!] = _Macro(int.tryParse(m.group(2) ?? '') ?? 0, body);
  });
  s = cut(_defCommand, (m, body) {
    macros[m.group(1)!] =
        _Macro('#'.allMatches(m.group(2) ?? '').length, body);
  });
  s = cut(_declareOperator, (m, body) {
    macros[m.group(1)!] = _Macro(0, '\\operatorname{$body}');
  });
  s = s.replaceAllMapped(_letCommand, (m) {
    macros[m.group(1)!] = _Macro(0, m.group(2)!);
    return '';
  });
  if (macros.isEmpty) return s;

  final names = macros.keys.toList()
    ..sort((a, b) => b.length.compareTo(a.length));
  for (var pass = 0; pass < 8; pass++) {
    var changed = false;
    for (final name in names) {
      final macro = macros[name]!;
      final use = RegExp('\\\\$name(?![A-Za-z])');
      var from = 0;
      while (true) {
        final m = use.firstMatch(s.substring(from));
        if (m == null) break;
        final at = from + m.start;
        var p = from + m.end;
        final args = <String>[];
        for (var k = 0; k < macro.args; k++) {
          while (p < s.length && s[p] == ' ') {
            p++;
          }
          if (p >= s.length) break;
          if (s[p] == '{') {
            final close = matchingBrace(s, p);
            if (close < 0) break;
            args.add(s.substring(p + 1, close));
            p = close + 1;
          } else {
            args.add(s[p]);
            p++;
          }
        }
        var body = macro.body;
        for (var k = args.length; k >= 1; k--) {
          body = body.replaceAll('#$k', args[k - 1]);
        }
        // A macro used as `\name x` must not run into the letter after it.
        final next = p < s.length ? s[p] : '';
        final pad = RegExp(r'[A-Za-z]').hasMatch(next) &&
                RegExp(r'\\[A-Za-z]+$').hasMatch(body)
            ? ' '
            : '';
        s = s.substring(0, at) + body + pad + s.substring(p);
        from = at + body.length;
        changed = true;
      }
    }
    if (!changed) break;
  }
  return s;
}

/// The index of the `}` matching the `{` at [open], or -1. Escaped braces
/// (`\{`, `\}`) do not count.
int matchingBrace(String s, int open) {
  if (open < 0 || open >= s.length || s[open] != '{') return -1;
  var depth = 0;
  for (var i = open; i < s.length; i++) {
    final c = s[i];
    if (c == r'\') {
      i++;
      continue;
    }
    if (c == '{') depth++;
    if (c == '}') {
      depth--;
      if (depth == 0) return i;
    }
  }
  return -1;
}

int _matching(String s, int open, String o, String c) {
  var depth = 0;
  for (var i = open; i < s.length; i++) {
    if (s[i] == r'\') {
      i++;
      continue;
    }
    if (s[i] == o) depth++;
    if (s[i] == c) {
      depth--;
      if (depth == 0) return i;
    }
  }
  return -1;
}

// ─── Text ─────────────────────────────────────────────────────────────

/// Text commands the renderers draw themselves; left as they are.
const keptTextCommands = {'textbf', 'textit', 'underline', 'texttt', 'vspace'};

/// Commands that mean nothing on a phone screen and are dropped.
const _droppedText = {
  'noindent', 'indent', 'centering', 'raggedright', 'raggedleft', 'hfill',
  'vfill', 'clearpage', 'newpage', 'pagebreak', 'maketitle', 'small',
  'large', 'Large', 'LARGE', 'huge', 'Huge', 'normalsize', 'footnotesize',
  'scriptsize', 'tiny', 'smallskip', 'medskip', 'nolinebreak', 'protect',
  'displaystyle', 'textstyle', 'selectfont', 'normalfont', 'bfseries',
  'itshape', 'rmfamily', 'sffamily', 'ttfamily', 'upshape', 'mdseries',
  'tableofcontents', 'nonumber', 'notag', 'hline', 'toprule', 'midrule',
  'bottomrule',
};

/// Commands with one argument that are dropped, argument and all.
const _droppedWithArg = {
  'label', 'index', 'cite', 'pagestyle', 'thispagestyle', 'vspace*',
  'setlength', 'usepackage', 'documentclass', 'includegraphics', 'caption',
  'ref', 'eqref', 'pageref',
};

/// Commands whose argument is shown as plain text.
const _unwrapped = {
  'textrm', 'textnormal', 'textup', 'textmd', 'mbox', 'hbox', 'text',
  'textsf', 'textsl', 'url', 'nolinkurl', 'fbox', 'framebox', 'makebox',
  'title', 'author', 'date', 'smash', 'boxed', 'ensuremath',
};

const _textSymbols = {
  '%': '%', '&': '&', '#': '#', '_': '_', '{': '{', '}': '}',
  ' ': ' ', ',': '\u2009', ';': '\u2005', ':': '\u2005', '!': '',
  '/': '', '-': '',
};

const _textNamedSymbols = {
  'ldots': '…', 'dots': '…', 'textellipsis': '…', 'textdegree': '°',
  'degree': '°', 'pounds': '£', 'textsterling': '£', 'euro': '€',
  'texteuro': '€', 'yen': '¥', 'copyright': '©', 'textcopyright': '©',
  'textregistered': '®', 'texttrademark': '™', 'textbullet': '•',
  'textendash': '–', 'textemdash': '—', 'textasciitilde': '~',
  'textasciicircum': '^', 'textbar': '|', 'textless': '<',
  'textgreater': '>', 'textquoteleft': '‘', 'textquoteright': '’',
  'textquotedblleft': '“', 'textquotedblright': '”', 'S': '§', 'P': '¶',
  'dag': '†', 'ddag': '‡', 'checkmark': '✓', 'LaTeX': 'LaTeX',
  'TeX': 'TeX', 'quad': '\u2003', 'qquad': '\u2003\u2003',
  'enspace': '\u2002', 'thinspace': '\u2009', 'naira': '₦', 'textnaira': '₦',
  'textonehalf': '½', 'texttimes': '×', 'textdiv': '÷', 'textpm': '±',
  'textmu': 'µ', 'ohm': 'Ω', 'textohm': 'Ω', 'celsius': '°C',
  'degreeCelsius': '°C', 'percent': '%', 'aa': 'å', 'AA': 'Å',
  'ss': 'ß', 'o': 'ø', 'O': 'Ø', 'ae': 'æ', 'AE': 'Æ', 'oe': 'œ',
  'OE': 'Œ', 'i': 'ı', 'l': 'ł', 'L': 'Ł',
};

const _accents = {
  "'": '\u0301', '`': '\u0300', '^': '\u0302', '"': '\u0308',
  '~': '\u0303', '=': '\u0304', '.': '\u0307', 'u': '\u0306',
  'v': '\u030C', 'H': '\u030B', 'c': '\u0327', 'd': '\u0323',
  'b': '\u0331', 'k': '\u0328', 'r': '\u030A',
};

const _sections = {
  'part', 'chapter', 'section', 'subsection', 'subsubsection', 'paragraph',
  'subparagraph',
};

const _displayEnvironments = {
  'equation': '', 'equation*': '', 'displaymath': '', 'align': 'aligned',
  'align*': 'aligned', 'flalign': 'aligned', 'flalign*': 'aligned',
  'alignat': 'alignedat', 'alignat*': 'alignedat', 'eqnarray': 'aligned',
  'eqnarray*': 'aligned', 'gather': 'gathered', 'gather*': 'gathered',
  'multline': 'gathered', 'multline*': 'gathered',
};

/// Maths environments that may appear bare in text and are wrapped whole.
const _inlineMathEnvironments = {
  'matrix', 'pmatrix', 'bmatrix', 'Bmatrix', 'vmatrix', 'Vmatrix',
  'smallmatrix', 'cases', 'dcases', 'aligned', 'gathered', 'array',
  'alignedat', 'split', 'subarray',
};

final _oldFontGroup = RegExp(
  r'\{\\(bf|bfseries|it|itshape|em|sl|slshape|rm|tt|ttfamily|sc|scshape)\b\s*([^{}]*)\}',
);

String _text(String t) {
  if (!t.contains(r'\')) return t;
  // {\bf x} and friends, the pre-LaTeX2e font switches.
  var s = t.replaceAllMapped(_oldFontGroup, (m) {
    final body = m.group(2)!;
    return switch (m.group(1)!) {
      'bf' || 'bfseries' => '\\textbf{$body}',
      'it' || 'itshape' || 'em' || 'sl' || 'slshape' => '\\textit{$body}',
      'tt' || 'ttfamily' => '\\texttt{$body}',
      'sc' || 'scshape' => body.toUpperCase(),
      _ => body,
    };
  });
  s = _environments(s);
  s = _textCommands(s);
  return s;
}

final _beginEnv = RegExp(r'\\begin\s*\{([A-Za-z*]+)\}');

/// The end of the environment opened at [bodyStart] (just after its
/// `\begin{name}`), counting nested environments of the same name: the
/// index of its `\end{name}`, or -1.
int _envEnd(String s, String name, int bodyStart) {
  final open = '\\begin{$name}';
  final close = '\\end{$name}';
  var depth = 1;
  var p = bodyStart;
  while (true) {
    final nextOpen = s.indexOf(open, p);
    final nextClose = s.indexOf(close, p);
    if (nextClose < 0) return -1;
    if (nextOpen >= 0 && nextOpen < nextClose) {
      depth++;
      p = nextOpen + open.length;
      continue;
    }
    depth--;
    if (depth == 0) return nextClose;
    p = nextClose + close.length;
  }
}

/// Environments in text. Maths environments are taken outermost first
/// and held whole (everything inside is maths); text environments — lists,
/// tables, center, quote — innermost first, so a list in a list or maths
/// in a table comes out right.
String _environments(String t) {
  var s = t;
  for (var guard = 0; guard < 200; guard++) {
    final begins = _beginEnv.allMatches(s).toList();
    if (begins.isEmpty) break;

    final maths = begins.where((b) {
      final n = b.group(1)!;
      return _displayEnvironments.containsKey(n) ||
          _inlineMathEnvironments.contains(n) ||
          n == 'math';
    });
    if (maths.isNotEmpty) {
      final b = maths.first;
      final name = b.group(1)!;
      final end = _envEnd(s, name, b.end);
      if (end >= 0) {
        final body = s.substring(b.end, end);
        final after = end + '\\end{$name}'.length;
        String held;
        if (_displayEnvironments.containsKey(name)) {
          final target = _displayEnvironments[name]!;
          final cleaned = normalizeMath(body.trim());
          held = target.isEmpty
              ? '\\[$cleaned\\]'
              : '\\[${normalizeMath('\\begin{$target}$cleaned\\end{$target}')}\\]';
        } else if (name == 'math') {
          held = '\\(${normalizeMath(body.trim())}\\)';
        } else {
          held = '\\(${normalizeMath('\\begin{$name}$body\\end{$name}')}\\)';
        }
        s = s.substring(0, b.start) + _hold(held) + s.substring(after);
        continue;
      }
    }

    // The innermost text environment: the last \begin whose body holds no
    // other \begin.
    Match? pick;
    var pickEnd = -1;
    for (final b in begins.reversed) {
      final name = b.group(1)!;
      final end = _envEnd(s, name, b.end);
      if (end < 0) continue;
      if (_beginEnv.hasMatch(s.substring(b.end, end))) continue;
      pick = b;
      pickEnd = end;
      break;
    }
    if (pick == null) break;
    final name = pick.group(1)!;
    var body = s.substring(pick.end, pickEnd);
    final after = pickEnd + '\\end{$name}'.length;
    String replacement;
    if (name == 'itemize' || name == 'enumerate' || name == 'description') {
      replacement = _list(name, body);
    } else if (name == 'tabular' || name == 'tabular*' || name == 'tabularx') {
      if (name != 'tabular') {
        // tabular* and tabularx take a width before the column spec.
        final w = body.trimLeft();
        if (w.startsWith('{')) {
          body = w.substring(matchingBrace(w, 0) + 1);
        }
      }
      replacement = '\n${_hold('\\[${_tabular(body)}\\]')}\n';
    } else {
      // center, flushleft, quote, minipage, figure, table, abstract … —
      // the content without the wrapper. A minipage or figure's
      // placement arguments go too.
      var b = body;
      final opt = RegExp(r'^\s*(\[[^\]]*\])?\s*(\{[^{}]*\})?');
      if (name == 'minipage' ||
          name == 'figure' ||
          name == 'table' ||
          name == 'wrapfigure') {
        b = b.replaceFirst(opt, '');
      }
      replacement = '\n${b.trim()}\n';
    }
    s = s.substring(0, pick.start) + replacement + s.substring(after);
  }
  return s.replaceAll(RegExp(r'\n{3,}'), '\n\n');
}

String _list(String kind, String body) {
  final parts = body.split(RegExp(r'\\item\b'));
  final items = parts.skip(1).toList();
  final out = <String>[];
  for (var k = 0; k < items.length; k++) {
    var item = items[k].trim();
    String? label;
    if (item.startsWith('[')) {
      final close = _matching(item, 0, '[', ']');
      if (close > 0) {
        label = item.substring(1, close);
        item = item.substring(close + 1).trim();
      }
    }
    final lines = item.split('\n');
    final head = lines.first;
    final rest = lines.skip(1).map((l) => '   $l');
    final marker = kind == 'description'
        ? (label == null ? '' : '\\textbf{$label} ')
        : label != null
            ? '$label '
            : kind == 'enumerate'
                ? '${k + 1}. '
                : '• ';
    out.add([
      '$marker$head',
      ...rest,
    ].join('\n'));
  }
  return '\n${out.join('\n')}\n';
}

/// A `tabular` as a maths `array`: text cells become `\text{}`, maths cells
/// stay maths.
String _tabular(String body) {
  var b = body.trimLeft();
  var spec = 'l';
  if (b.startsWith('{')) {
    final close = matchingBrace(b, 0);
    spec = b.substring(1, close);
    b = b.substring(close + 1);
  }
  final rows = _splitTopLevel(b, r'\\')
      .map((r) => r.trim())
      .where((r) => r.isNotEmpty)
      .map((row) {
    var r = row;
    final rules = <String>[];
    while (true) {
      final m = RegExp(r'^\\(hline|toprule|midrule|bottomrule|cline\{[^}]*\})\s*')
          .firstMatch(r);
      if (m == null) break;
      rules.add(r'\hline ');
      r = r.substring(m.end);
    }
    final cells = _splitTopLevel(r, '&').map(_cellToMath).join('&');
    return '${rules.join()}$cells';
  }).toList();
  return '\\begin{array}{${arraySpec(spec)}}${rows.join(r'\\')}\\end{array}';
}

/// A column spec the parser accepts: `p{2cm}`/`m{}`/`b{}`/`X` become `l`,
/// `@{…}`, `!{…}` and `>{…}`/`<{…}` go, `*{3}{c}` is expanded.
String arraySpec(String spec) {
  var s = spec.replaceAllMapped(
    RegExp(r'\*\{(\d+)\}\{([^{}]*)\}'),
    (m) => m.group(2)! * (int.tryParse(m.group(1)!) ?? 1),
  );
  s = s.replaceAll(RegExp(r'[@!<>]\{[^{}]*\}'), '');
  s = s.replaceAll(RegExp(r'[pmb]\{[^{}]*\}'), 'l');
  s = s.replaceAll(RegExp(r'[XS]'), 'l');
  s = s.replaceAll(RegExp(r'[^lcr|:]'), '');
  return s.isEmpty ? 'l' : s;
}

final _cellPiece = RegExp('\u0001(\\d+)\u0002|\\\\\\((.*?)\\\\\\)', dotAll: true);

/// One table cell as maths: its text in `\text{}`, its maths (held, or
/// bare commands the text pass wrapped) as it is.
String _cellToMath(String cell) {
  final c = _textCommands(cell.trim());
  if (c.trim().isEmpty) return '';
  final out = StringBuffer();
  var last = 0;
  void text(String t) {
    if (t.trim().isEmpty) {
      if (t.isNotEmpty && out.isNotEmpty) out.write(r'\ ');
      return;
    }
    out.write('\\text{${_escapeForText(t)}}');
  }

  for (final m in _cellPiece.allMatches(c)) {
    text(c.substring(last, m.start));
    out.write(m.group(1) != null
        ? _heldInner(int.parse(m.group(1)!))
        : m.group(2)!);
    last = m.end;
  }
  text(c.substring(last));
  return out.toString();
}

/// Characters that mean something in maths escaped for `\text{}`. Braces
/// are left alone: they belong to `\textbf{…}` and the like.
String _escapeForText(String s) => s.replaceAllMapped(
      RegExp(r'(?<!\\)([%&#_$])'),
      (m) => '\\${m.group(1)}',
    );

/// [s] split on [sep] outside braces.
List<String> _splitTopLevel(String s, String sep) {
  final out = <String>[];
  var depth = 0;
  var last = 0;
  for (var i = 0; i < s.length; i++) {
    final c = s[i];
    if (c == r'\' && sep != r'\\') {
      i++;
      continue;
    }
    if (c == '{') depth++;
    if (c == '}') depth--;
    if (depth == 0 && s.startsWith(sep, i)) {
      if (sep == '&' && i > 0 && s[i - 1] == r'\') continue;
      out.add(s.substring(last, i));
      i += sep.length - 1;
      last = i + 1;
    } else if (c == r'\' && sep == r'\\' && i + 1 < s.length) {
      // skip an escaped character that is not the separator
      if (s[i + 1] != r'\') i++;
    }
  }
  out.add(s.substring(last));
  return out;
}

final _commandName = RegExp(r'[A-Za-z]+\*?');

/// Every backslash command outside maths: rewritten, dropped, kept for the
/// renderer, or — if it is maths — wrapped as inline maths with its
/// arguments.
String _textCommands(String s) {
  final hasTeX = s.contains(r'\');
  final out = StringBuffer();
  var i = 0;
  // Characters a bare maths command may claim from just before it: digits
  // and a point (the `0.` of `0.\overline{3}`) or a lone variable (the `x`
  // of `x\times y`). Held back until it is known whether one follows.
  final pending = StringBuffer();

  void flushPending() {
    out.write(pending);
    pending.clear();
  }

  void emitPlain(String ch) {
    final p = pending.toString();
    // One space may sit between a claim and an operator: "2 \times 3".
    if (ch == ' ' && p.isNotEmpty && !p.endsWith(' ')) {
      pending.write(' ');
      return;
    }
    if (p.endsWith(' ')) flushPending();
    final isLetter = RegExp(r'[A-Za-z]').hasMatch(ch);
    if (RegExp(r'[0-9.]').hasMatch(ch)) {
      pending.write(ch);
      return;
    }
    if (isLetter && pending.isEmpty && _lastIsNotLetter(out)) {
      pending.write(ch);
      return;
    }
    flushPending();
    out.write(ch);
  }

  while (i < s.length) {
    final c = s[i];

    // Typography — only in text that is LaTeX at all, so a WAEC stem's
    // "------" blank or a 5'' measurement is never touched.
    if (hasTeX) {
      if (s.startsWith('---', i) && !_dashRun(s, i, 3)) {
        flushPending();
        out.write('—');
        i += 3;
        continue;
      }
      if (s.startsWith('--', i) && !_dashRun(s, i, 2)) {
        flushPending();
        out.write('–');
        i += 2;
        continue;
      }
    }
    if (s.startsWith('``', i)) {
      final close = s.indexOf("''", i + 2);
      if (close > 0) {
        flushPending();
        out.write('“');
        out.write(_textCommands(s.substring(i + 2, close)));
        out.write('”');
        i = close + 2;
        continue;
      }
    }
    if (hasTeX && c == '~') {
      flushPending();
      out.write('\u00A0');
      i++;
      continue;
    }

    if (c != r'\' || i + 1 >= s.length) {
      emitPlain(c);
      i++;
      continue;
    }

    final next = s[i + 1];

    // Kept as they are: \$, \\ (line break), delimiters.
    if (next == r'$') {
      flushPending();
      out.write(r'\$');
      i += 2;
      continue;
    }
    if (next == r'\') {
      flushPending();
      out.write('\n');
      i += 2;
      // \\[2mm] — the optional spacing goes too.
      if (i < s.length && s[i] == '[') {
        final close = s.indexOf(']', i);
        if (close > 0) i = close + 1;
      }
      while (i < s.length && s[i] == ' ') {
        i++;
      }
      continue;
    }
    // \'e, \"{o}, \c{c}: a letter-named accent only with a group, so \v x
    // or \b is never mistaken for one.
    final letterAccent = RegExp(r'[A-Za-z]').hasMatch(next);
    if (_accents.containsKey(next) &&
        (!letterAccent ||
            (i + 2 < s.length &&
                s[i + 2] == '{' &&
                _commandName.matchAsPrefix(s, i + 1)!.group(0)!.length ==
                    1))) {
      final r = _accent(s, i);
      if (r != null) {
        flushPending();
        out.write(r.text);
        i = r.end;
        continue;
      }
    }
    if (_textSymbols.containsKey(next)) {
      flushPending();
      out.write(_textSymbols[next]);
      i += 2;
      continue;
    }

    final nm = _commandName.matchAsPrefix(s, i + 1);
    if (nm == null) {
      emitPlain(c);
      i++;
      continue;
    }
    var name = nm.group(0)!;
    var p = nm.end;
    // A starred name only when the command takes the star (\section*).
    if (name.endsWith('*') &&
        !_sections.contains(name.substring(0, name.length - 1)) &&
        name != 'vspace*' &&
        name != 'hspace*') {
      name = name.substring(0, name.length - 1);
      p--;
    }
    final bare = name.endsWith('*') ? name.substring(0, name.length - 1) : name;

    if (keptTextCommands.contains(name)) {
      flushPending();
      out.write('\\$name');
      i = p;
      continue;
    }
    if (name == 'emph' || name == 'textsl') {
      flushPending();
      out.write(r'\textit');
      i = p;
      continue;
    }
    if (name == 'uline') {
      flushPending();
      out.write(r'\underline');
      i = p;
      continue;
    }
    if (name == 'textsc' || name == 'MakeUppercase' || name == 'uppercase') {
      final a = _arg(s, p);
      if (a != null) {
        flushPending();
        out.write(_textCommands(a.text).toUpperCase());
        i = a.end;
        continue;
      }
    }
    if (name == 'MakeLowercase' || name == 'lowercase') {
      final a = _arg(s, p);
      if (a != null) {
        flushPending();
        out.write(_textCommands(a.text).toLowerCase());
        i = a.end;
        continue;
      }
    }
    if (name == 'textsuperscript' || name == 'textsubscript') {
      final a = _arg(s, p);
      if (a != null) {
        flushPending();
        final mark = name == 'textsuperscript' ? '^' : '_';
        out.write('\\($mark{\\text{${_escapeForText(a.text)}}}\\)');
        i = a.end;
        continue;
      }
    }
    if (_sections.contains(bare)) {
      var q = p;
      if (q < s.length && s[q] == '[') q = _matching(s, q, '[', ']') + 1;
      final a = _arg(s, q);
      if (a != null) {
        flushPending();
        final sep = bare == 'paragraph' || bare == 'subparagraph' ? ' ' : '\n';
        out.write('\\textbf{${a.text.trim()}}$sep');
        i = a.end;
        while (i < s.length &&
            sep == '\n' &&
            (s[i] == '\n' || s[i] == ' ' || s[i] == '\t')) {
          i++;
        }
        continue;
      }
    }
    if (name == 'footnote') {
      final a = _arg(s, p);
      if (a != null) {
        flushPending();
        out.write(' (${a.text})');
        i = a.end;
        continue;
      }
    }
    if (name == 'href') {
      final a = _arg(s, p);
      final b = a == null ? null : _arg(s, a.end);
      if (b != null) {
        flushPending();
        out.write(b.text);
        i = b.end;
        continue;
      }
    }
    if (name == 'textcolor' || name == 'colorbox') {
      final a = _arg(s, p);
      final b = a == null ? null : _arg(s, a.end);
      if (b != null) {
        flushPending();
        out.write(_textCommands(b.text));
        i = b.end;
        continue;
      }
    }
    if (name == 'color') {
      final a = _arg(s, p);
      if (a != null) {
        i = a.end;
        continue;
      }
    }
    if (_unwrapped.contains(name)) {
      final a = _arg(s, p);
      if (a != null) {
        flushPending();
        out.write(_textCommands(a.text));
        i = a.end;
        continue;
      }
    }
    if (_droppedWithArg.contains(name)) {
      var q = p;
      if (q < s.length && s[q] == '[') q = _matching(s, q, '[', ']') + 1;
      final a = _arg(s, q);
      flushPending();
      i = a?.end ?? p;
      continue;
    }
    if (name == 'hspace' || name == 'hspace*' || name == 'vspace*') {
      final a = _arg(s, p);
      flushPending();
      if (name == 'hspace' || name == 'hspace*') out.write(' ');
      i = a?.end ?? p;
      continue;
    }
    if (name == 'par') {
      flushPending();
      out.write('\n\n');
      i = p;
      continue;
    }
    if (name == 'newline' || name == 'linebreak' || name == 'bigskip' ||
        name == 'break') {
      flushPending();
      out.write('\n');
      i = _skipSpaces(s, p);
      continue;
    }
    if (_droppedText.contains(name)) {
      flushPending();
      i = _skipSpaces(s, p);
      continue;
    }
    if (_textNamedSymbols.containsKey(name)) {
      flushPending();
      out.write(_textNamedSymbols[name]);
      // \ldots{} and \LaTeX\ eat their empty group or control space.
      i = p;
      if (s.startsWith('{}', i)) i += 2;
      continue;
    }
    if (name == 'item') {
      flushPending();
      out.write('• ');
      i = _skipSpaces(s, p);
      continue;
    }

    // Anything else is maths written without delimiters.
    final end = _mathRunEnd(s, i);
    // A claim across a space only for an operator: "2 \times 3", never
    // "Find x \frac…".
    if (pending.toString().endsWith(' ') && !_binaryOrFunction.contains(bare)) {
      flushPending();
    }
    final run = pending.toString() + s.substring(i, end);
    pending.clear();
    out.write('\\(${normalizeMath(run.trim())}\\)');
    i = end;
  }
  flushPending();
  return out.toString();
}

bool _lastIsNotLetter(StringBuffer out) {
  // A letter can be a lone variable only at the start of a word.
  final o = out.toString();
  return o.isEmpty || !RegExp(r'[A-Za-z]').hasMatch(o[o.length - 1]);
}

bool _dashRun(String s, int i, int n) {
  // Part of a longer run of dashes (a fill-in blank), or a maths minus
  // between digits — leave it.
  final before = i > 0 ? s[i - 1] : '';
  final after = i + n < s.length ? s[i + n] : '';
  return before == '-' || after == '-';
}

class _Arg {
  final String text;
  final int end;
  const _Arg(this.text, this.end);
}

_Arg? _arg(String s, int p) {
  var q = _skipSpaces(s, p);
  if (q < s.length && s[q] == '{') {
    final close = matchingBrace(s, q);
    if (close < 0) return null;
    return _Arg(s.substring(q + 1, close), close + 1);
  }
  return null;
}

int _skipSpaces(String s, int p) {
  var q = p;
  while (q < s.length && (s[q] == ' ' || s[q] == '\t')) {
    q++;
  }
  return q;
}

_Arg? _accent(String s, int i) {
  final mark = _accents[s[i + 1]]!;
  var q = i + 2;
  String letter;
  if (q < s.length && s[q] == '{') {
    final close = matchingBrace(s, q);
    if (close < 0) return null;
    letter = s.substring(q + 1, close);
    q = close + 1;
  } else {
    q = _skipSpaces(s, q);
    if (q >= s.length) return null;
    letter = s[q];
    q++;
  }
  if (letter == r'\i') letter = 'i';
  if (letter == r'\j') letter = 'j';
  if (letter.isEmpty) return _Arg(mark, q);
  return _Arg('${letter[0]}$mark${letter.substring(1)}', q);
}

/// The end of a bare maths run starting with the command at [i]: the
/// command, its arguments, sub- and superscripts, `\left…\right` and
/// `\begin…\end` pairs, and anything joined on without a space
/// (`\frac{1}{2}+\frac{1}{3}`, `\sqrt{2}x`, `\sin(x+y)`).
int _mathRunEnd(String s, int i) {
  var p = i;
  while (p < s.length) {
    final c = s[p];
    if (c == r'\') {
      if (p + 1 < s.length && (s[p + 1] == '(' || s[p + 1] == '[')) break;
      if (p + 1 < s.length && s[p + 1] == r'\') break;
      if (p + 1 < s.length && s[p + 1] == r'$') break;
      final nm = _commandName.matchAsPrefix(s, p + 1);
      if (nm == null) {
        p += 2; // \, \; \{ …
        continue;
      }
      final name = nm.group(0)!.replaceAll('*', '');
      if (keptTextCommands.contains(name) || name == 'emph') break;
      // The star belongs to \operatorname*; elsewhere it is multiplication.
      p = name == 'operatorname' ? nm.end : p + 1 + name.length;
      if (name == 'left') {
        p = _afterRight(s, p);
        continue;
      }
      if (name == 'begin') {
        final env = RegExp(r'\s*\{([A-Za-z*]+)\}').matchAsPrefix(s, p);
        if (env != null) {
          final endTag = '\\end{${env.group(1)}}';
          final e = s.indexOf(endTag, env.end);
          p = e < 0 ? s.length : e + endTag.length;
          continue;
        }
      }
      // Arguments: [..] and {..} directly after the name.
      while (p < s.length) {
        if (s[p] == '{') {
          final close = matchingBrace(s, p);
          if (close < 0) return s.length;
          p = close + 1;
        } else if (s[p] == '[' && _optionalArgCommand(name)) {
          final close = _matching(s, p, '[', ']');
          if (close < 0) break;
          p = close + 1;
        } else {
          break;
        }
      }
      continue;
    }
    if (c == '^' || c == '_') {
      p++;
      if (p < s.length && s[p] == '{') {
        final close = matchingBrace(s, p);
        p = close < 0 ? s.length : close + 1;
      } else if (p < s.length && s[p] == r'\') {
        final nm = _commandName.matchAsPrefix(s, p + 1);
        p = nm == null ? p + 2 : nm.end;
      } else if (p < s.length) {
        p++;
      }
      continue;
    }
    if (c == '{') {
      final close = matchingBrace(s, p);
      if (close < 0) break;
      p = close + 1;
      continue;
    }
    if (c == '(') {
      final close = _matching(s, p, '(', ')');
      if (close < 0 || close - p > 80) break;
      p = close + 1;
      continue;
    }
    if (RegExp(r'[A-Za-z0-9]').hasMatch(c)) {
      p++;
      continue;
    }
    if ('+-=*/<>|\''.contains(c) || c == '&') {
      // An operator joins only when the maths continues straight after it.
      if (p + 1 < s.length &&
          RegExp(r'[A-Za-z0-9\\({]').hasMatch(s[p + 1]) &&
          c != '&') {
        p++;
        continue;
      }
      break;
    }
    if ((c == '.' || c == ',') &&
        p + 1 < s.length &&
        RegExp(r'[0-9]').hasMatch(s[p + 1]) &&
        p > i &&
        RegExp(r'[0-9]').hasMatch(s[p - 1])) {
      p++;
      continue;
    }
    if (c == ' ' && p + 1 < s.length) {
      // "\sin x", "\log_2 8", "\pi r", "x \times y": one space joins a
      // short operand to an operator-like command, never a word.
      final rest = s.substring(p + 1);
      final word = RegExp(r'^[A-Za-z]+').firstMatch(rest)?.group(0);
      final prevCmd = RegExp(r'\\([A-Za-z]+)$').firstMatch(s.substring(i, p));
      if (prevCmd != null &&
          _binaryOrFunction.contains(prevCmd.group(1)) &&
          (RegExp(r'^[0-9\\(]').hasMatch(rest) ||
              (word != null && word.length == 1))) {
        p++;
        continue;
      }
      if (rest.startsWith(r'\') &&
          _binaryOrFunction.contains(
            _commandName.matchAsPrefix(rest, 1)?.group(0),
          )) {
        p++;
        continue;
      }
      break;
    }
    break;
  }
  return p;
}

bool _optionalArgCommand(String name) =>
    name == 'sqrt' || name.startsWith('x') || name == 'SI' || name == 'qty';

/// Commands after which a space and a short operand are still maths.
const _binaryOrFunction = {
  'times', 'div', 'cdot', 'pm', 'mp', 'le', 'leq', 'ge', 'geq', 'neq', 'ne',
  'approx', 'equiv', 'to', 'rightarrow', 'Rightarrow', 'implies', 'iff',
  'in', 'notin', 'subset', 'subseteq', 'cup', 'cap', 'sin', 'cos', 'tan',
  'log', 'ln', 'lg', 'exp', 'sec', 'csc', 'cot', 'arcsin', 'arccos',
  'arctan', 'sinh', 'cosh', 'tanh', 'pi', 'theta', 'alpha', 'beta',
  'propto', 'sim', 'cong', 'parallel', 'perp', 'angle', 'triangle', 'lt',
  'gt', 'leqslant', 'geqslant', 'circ', 'det', 'lim', 'sum', 'int', 'prod',
};

int _afterRight(String s, int from) {
  var depth = 1;
  var p = from;
  while (p < s.length) {
    if (s.startsWith(r'\left', p) &&
        !RegExp(r'[A-Za-z]').hasMatch(p + 5 < s.length ? s[p + 5] : ' ')) {
      depth++;
      p += 5;
      continue;
    }
    if (s.startsWith(r'\right', p) &&
        !RegExp(r'[A-Za-z]').hasMatch(p + 6 < s.length ? s[p + 6] : ' ')) {
      depth--;
      p += 6;
      if (depth == 0) {
        if (p < s.length && s[p] == r'\') {
          final nm = _commandName.matchAsPrefix(s, p + 1);
          p = nm == null ? p + 2 : nm.end;
        } else if (p < s.length) {
          p++;
        }
        return p;
      }
      continue;
    }
    p++;
  }
  return s.length;
}

// ─── Maths ────────────────────────────────────────────────────────────

/// Simple command → replacement inside maths, for commands the parser
/// lacks.
const _mathRenames = {
  'pmb': r'\boldsymbol',
  'bm': r'\boldsymbol',
  'emph': r'\textit',
  'mbox': r'\text',
  'hbox': r'\text',
  'textup': r'\text',
  'textnormal': r'\text',
  'uline': r'\underline',
  'textbackslash': r'\backslash',
  'S': r'\text{§}',
  'P': r'\text{¶}',
  'euro': r'\text{€}',
  'copyright': r'\text{©}',
  'naira': r'\text{₦}',
  'celsius': r'{}^{\circ}\mathrm{C}',
  'degreeCelsius': r'{}^{\circ}\mathrm{C}',
  'degree': r'{}^{\circ}',
  'textdegree': r'{}^{\circ}',
  'ohm': r'\Omega',
  'micro': r'\mu',
  'percent': r'\%',
  'recurring': r'\overline',
  'overarc': r'\overset{\frown}',
  'wideparen': r'\overset{\frown}',
  'overparen': r'\overset{\frown}',
  'limits': '',
  'nolimits': '',
  'nonumber': '',
  'notag': '',
  'displaybreak': '',
  'allowbreak': '',
  'smash': '',
  'centering': '',
};

const _mathEnvRenames = {
  'gathered': 'array}{c',
  'gather': 'array}{c',
  'gather*': 'array}{c',
  'multline': 'array}{c',
  'multline*': 'array}{c',
  'split': 'aligned',
  'align': 'aligned',
  'align*': 'aligned',
  'flalign': 'aligned',
  'flalign*': 'aligned',
  'eqnarray': 'aligned',
  'eqnarray*': 'aligned',
  'alignat': 'alignedat',
  'alignat*': 'alignedat',
  'equation': '',
  'equation*': '',
  'dcases*': 'dcases',
  'cases*': 'cases',
};

/// Maths (no delimiters) rewritten into commands flutter_math_fork parses.
String normalizeMath(String tex) {
  if (!tex.contains(r'\')) return tex;
  var s = tex;

  // Environments the parser lacks.
  s = s.replaceAllMapped(
    RegExp(r'\\(begin|end)\{([A-Za-z]+\*?)\}'),
    (m) {
      final env = m.group(2)!;
      final to = _mathEnvRenames[env];
      if (to == null) return m.group(0)!;
      if (to.isEmpty) return '';
      if (m.group(1) == 'end') {
        final base = to.split('}').first;
        return '\\end{$base}';
      }
      return '\\begin{$to}';
    },
  );
  // array column specs with p{}, @{} …
  s = _rewriteArraySpecs(s);

  final out = StringBuffer();
  final tags = <String>[];
  var i = 0;
  while (i < s.length) {
    final c = s[i];
    if (c != r'\') {
      out.write(c);
      i++;
      continue;
    }
    final nm = _commandName.matchAsPrefix(s, i + 1);
    if (nm == null) {
      out.write(s.substring(i, (i + 2).clamp(0, s.length)));
      i += 2;
      continue;
    }
    var name = nm.group(0)!;
    var p = nm.end;
    if (name.endsWith('*') && name != 'operatorname*') {
      name = name.substring(0, name.length - 1);
      p--;
    }

    switch (name) {
      case 'ce':
      case 'pu':
        final a = _arg(s, p);
        if (a != null) {
          out.write(name == 'ce' ? ceToTex(a.text) : _pu(a.text));
          i = a.end;
          continue;
        }
      case 'si':
      case 'unit':
        final a = _arg(s, _skipOptional(s, p));
        if (a != null) {
          out.write(siUnitToTex(a.text));
          i = a.end;
          continue;
        }
      case 'SI':
      case 'qty':
        final q = _skipOptional(s, p);
        final a = _arg(s, q);
        final b = a == null ? null : _arg(s, _skipOptional(s, a.end));
        if (b != null) {
          out.write('${_num(a!.text)}\\,${siUnitToTex(b.text)}');
          i = b.end;
          continue;
        }
      case 'num':
        final a = _arg(s, _skipOptional(s, p));
        if (a != null) {
          out.write(_num(a.text));
          i = a.end;
          continue;
        }
      case 'ang':
        final a = _arg(s, _skipOptional(s, p));
        if (a != null) {
          final parts = a.text.split(';');
          final marks = [r'^{\circ}', "'", "''"];
          final b = StringBuffer();
          for (var k = 0; k < parts.length && k < 3; k++) {
            if (parts[k].trim().isEmpty) continue;
            b.write('${parts[k].trim()}${marks[k]}');
          }
          out.write(b);
          i = a.end;
          continue;
        }
      case 'nicefrac':
      case 'sfrac':
      case 'xfrac':
        final a = _arg(s, p);
        final b = a == null ? null : _arg(s, a.end);
        if (b != null) {
          out.write('{}^{${a!.text}}\\!/_{${b.text}}');
          i = b.end;
          continue;
        }
      case 'substack':
        final a = _arg(s, p);
        if (a != null) {
          out.write('\\begin{array}{c}${a.text}\\end{array}');
          i = a.end;
          continue;
        }
      case 'sideset':
        final a = _arg(s, p);
        final b = a == null ? null : _arg(s, a.end);
        if (b != null) {
          i = b.end;
          continue;
        }
      case 'tag':
        final a = _arg(s, p);
        if (a != null) {
          tags.add(a.text);
          i = a.end;
          continue;
        }
      case 'label':
      case 'mspace':
      case 'hspace':
      case 'vspace':
        final a = _arg(s, p);
        if (a != null) {
          if (name == 'mspace' || name == 'hspace') out.write(r'\,');
          i = a.end;
          continue;
        }
      case 'textsc':
        final a = _arg(s, p);
        if (a != null) {
          out.write('\\text{${a.text.toUpperCase()}}');
          i = a.end;
          continue;
        }
    }
    if (_mathRenames.containsKey(name)) {
      final to = _mathRenames[name]!;
      out.write(to);
      i = p;
      // \degree then a letter: keep them apart.
      if (to.isNotEmpty &&
          RegExp(r'[A-Za-z]$').hasMatch(to) &&
          i < s.length &&
          RegExp(r'[A-Za-z]').hasMatch(s[i])) {
        out.write(' ');
      }
      continue;
    }
    out.write('\\$name');
    i = p;
  }
  // An equation number sits at the end, as LaTeX draws it.
  for (final t in tags) {
    out.write('\\qquad($t)');
  }
  return out.toString();
}

int _skipOptional(String s, int p) {
  final q = _skipSpaces(s, p);
  if (q < s.length && s[q] == '[') {
    final close = _matching(s, q, '[', ']');
    if (close > 0) return close + 1;
  }
  return q;
}

String _rewriteArraySpecs(String s) {
  final re = RegExp(r'\\begin\{(array|subarray)\}');
  final out = StringBuffer();
  var last = 0;
  for (final m in re.allMatches(s)) {
    if (m.start < last) continue;
    final open = m.end;
    if (open >= s.length || s[open] != '{') continue;
    final close = matchingBrace(s, open);
    if (close < 0) continue;
    out.write(s.substring(last, open));
    out.write('{${arraySpec(s.substring(open + 1, close))}}');
    last = close + 1;
  }
  out.write(s.substring(last));
  return out.toString();
}

// ─── siunitx ──────────────────────────────────────────────────────────

const _siPrefixes = {
  'yocto': 'y', 'zepto': 'z', 'atto': 'a', 'femto': 'f', 'pico': 'p',
  'nano': 'n', 'micro': r'\mu ', 'milli': 'm', 'centi': 'c', 'deci': 'd',
  'deca': 'da', 'deka': 'da', 'hecto': 'h', 'kilo': 'k', 'mega': 'M',
  'giga': 'G', 'tera': 'T', 'peta': 'P', 'exa': 'E',
};

const _siUnits = {
  'metre': 'm', 'meter': 'm', 'gram': 'g', 'kilogram': 'kg', 'second': 's',
  'ampere': 'A', 'kelvin': 'K', 'mole': 'mol', 'candela': 'cd',
  'newton': 'N', 'joule': 'J', 'watt': 'W', 'pascal': 'Pa', 'hertz': 'Hz',
  'coulomb': 'C', 'volt': 'V', 'ohm': r'\Omega', 'farad': 'F',
  'tesla': 'T', 'henry': 'H', 'weber': 'Wb', 'siemens': 'S',
  'becquerel': 'Bq', 'gray': 'Gy', 'sievert': 'Sv', 'lumen': 'lm',
  'lux': 'lx', 'radian': 'rad', 'steradian': 'sr', 'litre': 'L',
  'liter': 'L', 'tonne': 't', 'minute': 'min', 'hour': 'h', 'day': 'd',
  'electronvolt': 'eV', 'bar': 'bar', 'angstrom': 'Å', 'astronomicalunit':
      'au', 'dalton': 'Da', 'hectare': 'ha', 'decibel': 'dB', 'neper': 'Np',
  'percent': r'\%', 'atomicmassunit': 'u', 'mmHg': 'mmHg',
  'arcminute': "'", 'arcsecond': "''",
};

/// An siunitx unit (`\metre\per\second\squared`, or literal `m/s^2`,
/// `kg.m.s^-2`) as upright maths: `\mathrm{m}\,\mathrm{s}^{-2}`.
String siUnitToTex(String unit) {
  final u = unit.trim();
  if (u.isEmpty) return '';
  if (!u.contains(r'\')) return _literalUnit(u);
  final terms = <String>[];
  var prefix = '';
  var per = false;
  var power = '';
  var i = 0;
  String? pendingPower;
  while (i < u.length) {
    if (u[i] != r'\') {
      // A literal piece inside a macro unit: "\kilo g".
      final m = RegExp(r'[A-Za-z]+').matchAsPrefix(u, i);
      if (m != null) {
        terms.add(_unitTerm('$prefix${m.group(0)}', per, power, pendingPower));
        prefix = '';
        per = false;
        power = '';
        pendingPower = null;
        i = m.end;
      } else {
        i++;
      }
      continue;
    }
    final nm = RegExp(r'[A-Za-z]+').matchAsPrefix(u, i + 1);
    if (nm == null) {
      i += 2;
      continue;
    }
    final name = nm.group(0)!;
    i = nm.end;
    if (name == 'per') {
      per = true;
    } else if (name == 'square') {
      power = '2';
    } else if (name == 'cubic') {
      power = '3';
    } else if (name == 'squared' || name == 'cubed') {
      final pw = name == 'squared' ? '2' : '3';
      if (terms.isNotEmpty) terms[terms.length - 1] = _repower(terms.last, pw);
    } else if (name == 'tothe' || name == 'raiseto') {
      final a = _arg(u, i);
      if (a != null) {
        if (name == 'tothe' && terms.isNotEmpty) {
          terms[terms.length - 1] = _repower(terms.last, a.text);
        } else {
          pendingPower = a.text;
        }
        i = a.end;
      }
    } else if (_siPrefixes.containsKey(name)) {
      prefix += _siPrefixes[name]!;
    } else if (_siUnits.containsKey(name)) {
      terms.add(_unitTerm('$prefix${_siUnits[name]}', per, power, pendingPower));
      prefix = '';
      per = false;
      power = '';
      pendingPower = null;
    } else if (name == 'degreeCelsius' || name == 'celsius') {
      terms.add(r'{}^{\circ}\mathrm{C}');
    } else if (name == 'degree') {
      terms.add(r'{}^{\circ}');
    } else {
      terms.add('\\$name');
    }
  }
  return terms.join(r'\,');
}

String _unitTerm(String symbol, bool per, String power, String? raise) {
  final body = symbol.startsWith(r'\') && !symbol.startsWith(r'\mu')
      ? symbol
      : '\\mathrm{$symbol}';
  var exp = raise ?? power;
  if (per) exp = exp.isEmpty ? '-1' : '-$exp';
  return exp.isEmpty ? body : '$body^{$exp}';
}

String _repower(String term, String pw) {
  final m = RegExp(r'\^\{(-?)([^{}]*)\}$').firstMatch(term);
  if (m == null) return '$term^{$pw}';
  final sign = m.group(1)!;
  return '${term.substring(0, m.start)}^{$sign$pw}';
}

String _literalUnit(String u) {
  // m/s^2, kg.m.s^-2, kg m s^{-2}, J~K^{-1}
  final b = StringBuffer();
  var i = 0;
  var first = true;
  while (i < u.length) {
    final c = u[i];
    final word = RegExp(r'[A-Za-zµΩ°%]+').matchAsPrefix(u, i);
    if (word != null) {
      if (!first && !b.toString().endsWith('/')) b.write(r'\,');
      final w = word.group(0)!
          .replaceAll('µ', r'\mu ')
          .replaceAll('Ω', r'\Omega ')
          .replaceAll('%', r'\%');
      b.write(w.contains('°')
          ? '${w.replaceAll('°', r'{}^{\circ}\mathrm{')}}'
          : '\\mathrm{$w}');
      first = false;
      i = word.end;
      continue;
    }
    if (c == '^') {
      i++;
      if (i < u.length && u[i] == '{') {
        final close = matchingBrace(u, i);
        b.write('^{${u.substring(i + 1, close)}}');
        i = close + 1;
      } else {
        final e = RegExp(r'-?[0-9]+').matchAsPrefix(u, i);
        if (e != null) {
          b.write('^{${e.group(0)}}');
          i = e.end;
        }
      }
      continue;
    }
    if (c == '/') {
      b.write('/');
      i++;
      continue;
    }
    // . ~ space * are separators
    i++;
  }
  return b.toString().replaceAll(r'\mathrm{}', '');
}

String _num(String n) {
  final t = n.trim().replaceAll(' ', '');
  final m = RegExp(r'^([+-]?[0-9.,]+)[eE]([+-]?[0-9]+)$').firstMatch(t);
  if (m != null) return '${m.group(1)}\\times10^{${m.group(2)}}';
  return t.replaceAll('x', r'\times ').replaceAll('+-', r'\pm ');
}

String _pu(String s) {
  final m = RegExp(r'^\s*([+-]?[0-9.,]+(?:[eE][+-]?[0-9]+)?)\s*(.*)$')
      .firstMatch(s);
  if (m == null) return _literalUnit(s);
  final unit = m.group(2)!.trim();
  return unit.isEmpty
      ? _num(m.group(1)!)
      : '${_num(m.group(1)!)}\\,${_literalUnit(unit)}';
}

// ─── mhchem ───────────────────────────────────────────────────────────

/// A subset of mhchem's `\ce{}`: formulae with subscripts, charges,
/// states, coefficients, hydrates, arrows with conditions, `^` (gas) and
/// `v` (precipitate).
String ceToTex(String input) {
  final tokens = _ceTokens(input.trim());
  final out = <String>[];
  for (final t in tokens) {
    out.add(_ceToken(t));
  }
  return out.join(' ').replaceAll(RegExp(r' +'), ' ').trim();
}

List<String> _ceTokens(String s) {
  // Split on spaces, but keep arrow conditions in brackets together.
  final out = <String>[];
  final b = StringBuffer();
  var depth = 0;
  for (var i = 0; i < s.length; i++) {
    final c = s[i];
    if (c == '[' || c == '{') depth++;
    if (c == ']' || c == '}') depth--;
    if (c == ' ' && depth == 0) {
      if (b.isNotEmpty) out.add(b.toString());
      b.clear();
      continue;
    }
    b.write(c);
  }
  if (b.isNotEmpty) out.add(b.toString());
  return out;
}

const _ceArrows = {
  '<=>>': r'\rightleftharpoons',
  '<<=>': r'\rightleftharpoons',
  '<=>': r'\rightleftharpoons',
  '<-->': r'\leftrightarrows',
  '<->': r'\leftrightarrow',
  '->': r'\rightarrow',
  '<-': r'\leftarrow',
  '=': '=',
};

String _ceToken(String t) {
  if (t == '+') return '+';
  if (t == '^') return r'\uparrow';
  if (t == 'v') return r'\downarrow';
  if (t == '.' || t == '*') return r'\cdot';
  for (final a in _ceArrows.keys) {
    if (t.startsWith(a)) {
      final rest = t.substring(a.length);
      final conds = RegExp(r'\[([^\]]*)\]').allMatches(rest).map((m) => m.group(1)!).toList();
      final arrow = _ceArrows[a]!;
      if (conds.isEmpty) return arrow;
      String cond(String c) => c.startsWith(r'$') && c.endsWith(r'$')
          ? c.substring(1, c.length - 1)
          : '\\text{$c}';
      if (arrow == r'\rightarrow' || arrow == r'\leftarrow') {
        final x = arrow == r'\rightarrow' ? r'\xrightarrow' : r'\xleftarrow';
        return conds.length > 1
            ? '$x[${cond(conds[1])}]{${cond(conds[0])}}'
            : '$x{${cond(conds[0])}}';
      }
      final over = '\\overset{${cond(conds[0])}}{$arrow}';
      return conds.length > 1 ? '\\underset{${cond(conds[1])}}{$over}' : over;
    }
  }
  return _ceSpecies(t);
}

String _ceSpecies(String t) {
  final b = StringBuffer();
  var i = 0;
  // Coefficient: 2, 1/2, 0.5, n
  final coef = RegExp(r'^([0-9]+(?:[./][0-9]+)?|[a-z](?=[A-Z(]))').firstMatch(t);
  if (coef != null) {
    b.write('${coef.group(0)}\\,');
    i = coef.end;
  }
  var afterAtom = false;
  while (i < t.length) {
    final c = t[i];
    // State: (s) (l) (g) (aq)
    final state = RegExp(r'\((s|l|g|aq|aq\.|cr|ppt)\)').matchAsPrefix(t, i);
    if (state != null) {
      b.write('\\,(\\mathrm{${state.group(1)}})');
      i = state.end;
      afterAtom = false;
      continue;
    }
    if (c == '^') {
      i++;
      String charge;
      if (i < t.length && t[i] == '{') {
        final close = matchingBrace(t, i);
        charge = t.substring(i + 1, close);
        i = close + 1;
      } else {
        final m = RegExp(r'[0-9]*[+-]|[0-9]+').matchAsPrefix(t, i);
        charge = m?.group(0) ?? '';
        i = m?.end ?? i;
      }
      b.write('^{$charge}');
      afterAtom = false;
      continue;
    }
    if (c == '_') {
      i++;
      if (i < t.length && t[i] == '{') {
        final close = matchingBrace(t, i);
        b.write('_{${t.substring(i + 1, close)}}');
        i = close + 1;
      } else if (i < t.length) {
        b.write('_{${t[i]}}');
        i++;
      }
      continue;
    }
    final el = RegExp(r'[A-Z][a-z]?').matchAsPrefix(t, i);
    if (el != null) {
      b.write('\\mathrm{${el.group(0)}}');
      i = el.end;
      afterAtom = true;
      continue;
    }
    final digits = RegExp(r'[0-9]+').matchAsPrefix(t, i);
    if (digits != null) {
      if (afterAtom) {
        b.write('_{${digits.group(0)}}');
      } else {
        b.write(digits.group(0));
      }
      i = digits.end;
      continue;
    }
    if (c == '(' || c == '[') {
      b.write(c == '(' ? '(' : '[');
      i++;
      afterAtom = false;
      continue;
    }
    if (c == ')' || c == ']') {
      b.write(c);
      i++;
      afterAtom = true;
      continue;
    }
    if (c == '.' || c == '*' || c == '·') {
      b.write(r'\cdot ');
      i++;
      afterAtom = false;
      // A hydrate's count: CuSO4.5H2O
      final n = RegExp(r'[0-9]+').matchAsPrefix(t, i);
      if (n != null) {
        b.write(n.group(0));
        i = n.end;
      }
      continue;
    }
    if ((c == '+' || c == '-') && i == t.length - 1 && i > 0) {
      // Na+, Cl-: a trailing sign is a charge.
      b.write('^{$c}');
      i++;
      continue;
    }
    final charge = RegExp(r'([0-9])([+-])$').matchAsPrefix(t, i);
    if (charge != null && afterAtom) {
      b.write('^{${charge.group(1)}${charge.group(2)}}');
      i = charge.end;
      continue;
    }
    if (c == r'\') {
      final nm = _commandName.matchAsPrefix(t, i + 1);
      final end = nm?.end ?? i + 2;
      b.write(t.substring(i, end));
      i = end;
      continue;
    }
    if (c == r'$') {
      final close = t.indexOf(r'$', i + 1);
      if (close > i) {
        b.write(t.substring(i + 1, close));
        i = close + 1;
        continue;
      }
    }
    if (RegExp(r'[a-z]').hasMatch(c)) {
      // e- (electron), lowercase labels
      b.write('\\mathrm{$c}');
      i++;
      afterAtom = true;
      continue;
    }
    b.write(c);
    i++;
  }
  // Adjacent upright letters as one run: \mathrm{NH}, not N then H.
  var out = b.toString();
  final adjacent = RegExp(r'(\\mathrm\{[A-Za-z]+)\}\\mathrm\{');
  while (adjacent.hasMatch(out)) {
    out = out.replaceAllMapped(adjacent, (m) => m.group(1)!);
  }
  return out;
}
