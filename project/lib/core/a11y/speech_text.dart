/// Turns lesson text — prose with embedded LaTeX — into words a speech
/// engine can say in natural British English.
///
/// Pure Dart: no Flutter, no engine. Read-aloud calls [speakText] on every
/// segment it reads, and the tests call it directly.
///
/// **The dialect is the corpus dialect** (see CLAUDE.md, "LaTeX"): `\(...\)`
/// is inline maths, `\[...\]` and `$$...$$` are display maths, and a lone
/// `$` is a dollar sign, never a delimiter. So `$5 and $10` is money, and is
/// spoken as money.
///
/// **Two promises.** Plain prose comes out as it went in. And nothing is
/// ever read as a raw backslash command: a command this file does not know
/// is spoken as "expression", which is honest about there being maths the
/// student should look at rather than reciting `\mathscr` at them.
library;

/// [source] as spoken text: maths converted, prose left alone, whitespace
/// collapsed.
String speakText(String source) {
  final out = StringBuffer();
  var i = 0;
  while (i < source.length) {
    final start = _nextMath(source, i);
    if (start == null) {
      out.write(_speakProse(source.substring(i)));
      break;
    }
    out.write(_speakProse(source.substring(i, start.index)));
    final close = source.indexOf(start.close, start.index + start.open.length);
    final innerEnd = close < 0 ? source.length : close;
    final inner = source.substring(start.index + start.open.length, innerEnd);
    out.write(' ${speakMath(inner)} ');
    i = close < 0 ? source.length : close + start.close.length;
  }
  return _tidy(out.toString());
}

/// Pure maths (no delimiters) as spoken text.
String speakMath(String latex) {
  final parser = _MathParser(_tokenize(latex));
  final words = parser.parseSequence();
  return _tidy(_finishMath(words.join(' ')));
}

// ─── Finding the maths ────────────────────────────────────────────────

class _MathStart {
  const _MathStart(this.index, this.open, this.close);
  final int index;
  final String open;
  final String close;
}

_MathStart? _nextMath(String s, int from) {
  _MathStart? best;
  for (final (open, close) in const [
    (r'\(', r'\)'),
    (r'\[', r'\]'),
    (r'$$', r'$$'),
  ]) {
    final at = s.indexOf(open, from);
    if (at >= 0 && (best == null || at < best.index)) {
      best = _MathStart(at, open, close);
    }
  }
  return best;
}

// ─── Prose ────────────────────────────────────────────────────────────

final _proseTextCommand = RegExp(
  r'\\(?:textbf|textit|text|emph|textrm|underline|mbox)\s*\{([^{}]*)\}',
);
final _proseSpacing = RegExp(r'\\[vh]space\*?\s*\{[^{}]*\}');
final _proseCommand = RegExp(r'\\([A-Za-z]+)');
final _currency = RegExp(
  r'([$₦])(\d{1,3}(?:,\d{3})+|\d+)(\.\d+)?(\s+(?:thousand|million|billion|trillion)\b)?',
);

const _subscriptDigits = '₀₁₂₃₄₅₆₇₈₉';
final _unicodeBase = RegExp('([0-9]+)([$_subscriptDigits]+)');

const _vulgarFractions = {
  '½': 'one half',
  '⅓': 'one third',
  '⅔': 'two thirds',
  '¼': 'one quarter',
  '¾': 'three quarters',
  '⅕': 'one fifth',
  '⅖': 'two fifths',
  '⅗': 'three fifths',
  '⅘': 'four fifths',
  '⅙': 'one sixth',
  '⅚': 'five sixths',
  '⅛': 'one eighth',
  '⅜': 'three eighths',
  '⅝': 'five eighths',
  '⅞': 'seven eighths',
};

String _speakProse(String text) {
  if (text.isEmpty) return text;
  var s = text;

  // `\textbf{..}` and friends read as their text. Repeated so a nested
  // `\textbf{\textit{..}}` unwraps from the inside out.
  for (var guard = 0; guard < 8 && _proseTextCommand.hasMatch(s); guard++) {
    s = s.replaceAllMapped(_proseTextCommand, (m) => m.group(1)!);
  }
  s = s.replaceAll(_proseSpacing, ' ');
  s = s
      .replaceAll(r'\$', r'$')
      .replaceAll(r'\%', '%')
      .replaceAll(r'\&', '&')
      .replaceAll(r'\_', '_')
      .replaceAll(r'\#', '#')
      .replaceAll(r'\\', ' ');

  // Money: `$5` is "5 dollars", `₦500` is "500 naira". A `$` with no
  // number after it is left exactly as written.
  s = s.replaceAllMapped(_currency, (m) {
    final amount = '${m.group(2)}${m.group(3) ?? ''}';
    final scale = m.group(4)?.trim();
    final unit = m.group(1) == r'$'
        ? (amount == '1' && scale == null ? 'dollar' : 'dollars')
        : 'naira';
    return scale == null ? '$amount $unit' : '$amount $scale $unit';
  });

  for (final e in _vulgarFractions.entries) {
    if (!s.contains(e.key)) continue;
    s = s.replaceAllMapped(RegExp('(\\d?)${e.key}'), (m) {
      final whole = m.group(1)!;
      // "2½" is "2 and a half", not "2 and one half".
      return whole.isEmpty
          ? ' ${e.value} '
          : '$whole and ${e.value.replaceFirst('one ', 'a ')} ';
    });
  }

  // Unicode subscripts are number bases (`1011₂`); superscripts ² and ³
  // are squared and cubed.
  s = s.replaceAllMapped(_unicodeBase, (m) {
    final radix = int.parse(
      m.group(2)!.split('').map((c) => '${_subscriptDigits.indexOf(c)}').join(),
    );
    final digits = m.group(1)!.split('').map((d) => _ones[int.parse(d)]);
    return '${digits.join(' ')}, base ${_numberWord(radix)}';
  });
  s = s.replaceAll('²', ' squared').replaceAll('³', ' cubed');

  // Any other command in prose is spoken the way maths would speak it, so
  // a stray `\pi` is "pi" and an unknown one is "expression" — never the
  // raw backslash.
  if (s.contains(r'\')) {
    s = s.replaceAllMapped(_proseCommand, (m) {
      final spoken = _commandWord(m.group(1)!);
      return ' ${spoken ?? 'expression'} ';
    });
    s = s.replaceAll(r'\', ' ');
  }
  return s;
}

// ─── Tokens ───────────────────────────────────────────────────────────

enum _K { command, open, close, sup, sub, number, letter, symbol, text }

class _Tok {
  _Tok(this.kind, this.text);
  final _K kind;
  String text;

  bool isSymbol(String s) => kind == _K.symbol && text == s;
  bool isCommand(String s) => kind == _K.command && text == s;

  @override
  String toString() => '${kind.name}($text)';
}

/// Commands whose argument is prose, read as written.
const _textCommands = {
  'text',
  'textbf',
  'textit',
  'textrm',
  'textnormal',
  'mbox',
  'operatorname',
  'emph',
  'textsf',
  'texttt',
  // Environment names are consumed the same way and then dropped.
  'begin',
  'end',
};

final _numberAt = RegExp(r'\d+(?:,\d{3})*(?:\.\d+)?');

List<_Tok> _tokenize(String src) {
  final s = src.replaceAll('{,}', ',');
  final toks = <_Tok>[];
  var i = 0;
  while (i < s.length) {
    final c = s[i];
    if (c == r'\') {
      if (i + 1 >= s.length) break;
      final next = s[i + 1];
      if (_isAsciiLetter(next)) {
        var j = i + 1;
        while (j < s.length && _isAsciiLetter(s[j])) {
          j++;
        }
        final name = s.substring(i + 1, j);
        if (_textCommands.contains(name)) {
          var k = j;
          while (k < s.length && s[k] == ' ') {
            k++;
          }
          if (k < s.length && s[k] == '{') {
            final end = _matchingBrace(s, k);
            final raw = s.substring(k + 1, end < 0 ? s.length : end);
            toks.add(
              _Tok(_K.text, name == 'begin' || name == 'end' ? '' : raw),
            );
            i = end < 0 ? s.length : end + 1;
            continue;
          }
        }
        toks.add(_Tok(_K.command, name));
        i = j;
      } else {
        toks.add(_Tok(_K.command, next));
        i += 2;
      }
      continue;
    }
    if (c == '{') {
      toks.add(_Tok(_K.open, c));
    } else if (c == '}') {
      toks.add(_Tok(_K.close, c));
    } else if (c == '^') {
      toks.add(_Tok(_K.sup, c));
    } else if (c == '_') {
      toks.add(_Tok(_K.sub, c));
    } else if (_isDigit(c)) {
      final m = _numberAt.matchAsPrefix(s, i)!;
      toks.add(_Tok(_K.number, m.group(0)!));
      i = m.end;
      continue;
    } else if (_isAsciiLetter(c)) {
      toks.add(_Tok(_K.letter, c));
    } else if (c.trim().isEmpty) {
      // Whitespace means nothing in maths.
    } else {
      toks.add(_Tok(_K.symbol, c));
    }
    i++;
  }
  return toks;
}

int _matchingBrace(String s, int openAt) {
  var depth = 0;
  for (var j = openAt; j < s.length; j++) {
    if (s[j] == r'\') {
      j++;
      continue;
    }
    if (s[j] == '{') depth++;
    if (s[j] == '}') {
      depth--;
      if (depth == 0) return j;
    }
  }
  return -1;
}

bool _isAsciiLetter(String c) {
  final u = c.codeUnitAt(0);
  return (u >= 65 && u <= 90) || (u >= 97 && u <= 122);
}

bool _isDigit(String c) {
  final u = c.codeUnitAt(0);
  return u >= 48 && u <= 57;
}

// ─── Vocabulary ───────────────────────────────────────────────────────

const _greek = {
  'alpha': 'alpha',
  'beta': 'beta',
  'gamma': 'gamma',
  'delta': 'delta',
  'epsilon': 'epsilon',
  'varepsilon': 'epsilon',
  'zeta': 'zeta',
  'eta': 'eta',
  'theta': 'theta',
  'vartheta': 'theta',
  'iota': 'iota',
  'kappa': 'kappa',
  'lambda': 'lambda',
  'mu': 'mu',
  'nu': 'nu',
  'xi': 'xi',
  'pi': 'pi',
  'varpi': 'pi',
  'rho': 'rho',
  'varrho': 'rho',
  'sigma': 'sigma',
  'varsigma': 'sigma',
  'tau': 'tau',
  'upsilon': 'upsilon',
  'phi': 'phi',
  'varphi': 'phi',
  'chi': 'chi',
  'psi': 'psi',
  'omega': 'omega',
  'Gamma': 'capital gamma',
  'Delta': 'capital delta',
  'Theta': 'capital theta',
  'Lambda': 'capital lambda',
  'Xi': 'capital xi',
  'Pi': 'capital pi',
  'Sigma': 'capital sigma',
  'Upsilon': 'capital upsilon',
  'Phi': 'capital phi',
  'Psi': 'capital psi',
  'Omega': 'capital omega',
};

/// Commands that are a word or phrase on their own.
const _words = {
  'times': 'times',
  'cdot': 'times',
  'ast': 'times',
  'div': 'divided by',
  'pm': 'plus or minus',
  'mp': 'minus or plus',
  'neq': 'is not equal to',
  'ne': 'is not equal to',
  'leq': 'is less than or equal to',
  'le': 'is less than or equal to',
  'leqslant': 'is less than or equal to',
  'geq': 'is greater than or equal to',
  'ge': 'is greater than or equal to',
  'geqslant': 'is greater than or equal to',
  'lt': 'is less than',
  'gt': 'is greater than',
  'approx': 'is approximately equal to',
  'simeq': 'is approximately equal to',
  'equiv': 'is equivalent to',
  'cong': 'is congruent to',
  'sim': 'is similar to',
  'propto': 'is proportional to',
  'infty': 'infinity',
  'degree': 'degrees',
  'circ': 'degrees',
  'prime': 'prime',
  'to': 'tends to',
  'rightarrow': 'gives',
  'longrightarrow': 'gives',
  'Rightarrow': 'implies',
  'implies': 'implies',
  'Leftrightarrow': 'if and only if',
  'iff': 'if and only if',
  'leftarrow': 'comes from',
  'rightleftharpoons': 'is in equilibrium with',
  'therefore': 'therefore',
  'because': 'because',
  'angle': 'angle',
  'triangle': 'triangle',
  'parallel': 'is parallel to',
  'perp': 'is perpendicular to',
  'in': 'is in',
  'notin': 'is not in',
  'subset': 'is a subset of',
  'subseteq': 'is a subset of',
  'cup': 'union',
  'cap': 'intersection',
  'emptyset': 'the empty set',
  'varnothing': 'the empty set',
  'forall': 'for all',
  'exists': 'there exists',
  'neg': 'not',
  'ldots': 'and so on',
  'cdots': 'and so on',
  'dots': 'and so on',
  'sum': 'the sum of',
  'prod': 'the product of',
  'int': 'the integral of',
  'lim': 'the limit of',
  r'\': ',',
  '|': '',
  '&': 'and',
  '#': 'number',
  '_': '',
  'partial': 'partial',
  'nabla': 'del',
  'percent': 'percent',
  '%': 'percent',
  r'$': 'dollars',
  '{': 'open curly bracket',
  '}': 'close curly bracket',
  'lbrace': 'open curly bracket',
  'rbrace': 'close curly bracket',
  'langle': 'open angle bracket',
  'rangle': 'close angle bracket',
  'lvert': 'modulus',
  'rvert': '',
  'mid': 'such that',
  'colon': 'such that',
  'uparrow': 'up arrow',
  'downarrow': 'down arrow',
};

/// Commands that print nothing: spacing, sizing, style switches.
const _silent = {
  ',', ';', ':', '!', ' ', 'quad', 'qquad', 'displaystyle', 'textstyle',
  'scriptstyle', 'limits', 'nolimits', 'left', 'right', 'big', 'Big',
  'bigg', 'Bigg', 'bigl', 'bigr', 'Bigl', 'Bigr', 'middle', 'mathrm',
  'mathbf', 'mathit', 'mathsf', 'mathtt', 'boldsymbol', 'bm', 'rm', 'bf',
  'it', 'cancel', 'boxed', 'phantom', 'hline', 'nonumber', 'notag', 'tag',
  'label', 'centering', 'small', 'large', 'Large', 'normalsize',
};

/// Trig, log and friends: spoken, then "of" their argument.
const _functions = {
  'sin': 'sine',
  'cos': 'cos',
  'tan': 'tan',
  'sec': 'sec',
  'csc': 'cosec',
  'cosec': 'cosec',
  'cot': 'cot',
  'arcsin': 'inverse sine',
  'arccos': 'inverse cos',
  'arctan': 'inverse tan',
  'sinh': 'hyperbolic sine',
  'cosh': 'hyperbolic cos',
  'tanh': 'hyperbolic tan',
  'log': 'log',
  'lg': 'log',
  'ln': 'natural log',
  'exp': 'the exponential of',
  'max': 'the maximum of',
  'min': 'the minimum of',
  'det': 'the determinant of',
};

String? _commandWord(String name) =>
    _greek[name] ?? _words[name] ?? _functions[name] ??
    (_silent.contains(name) ? '' : null);

const _symbols = {
  '+': 'plus',
  '-': 'minus',
  '−': 'minus',
  '=': 'equals',
  '<': 'is less than',
  '>': 'is greater than',
  '*': 'times',
  '×': 'times',
  '·': 'times',
  '÷': 'divided by',
  '/': 'over',
  '±': 'plus or minus',
  '≤': 'is less than or equal to',
  '≥': 'is greater than or equal to',
  '≠': 'is not equal to',
  '≈': 'is approximately equal to',
  '∞': 'infinity',
  '°': 'degrees',
  'π': 'pi',
  'θ': 'theta',
  'α': 'alpha',
  'β': 'beta',
  '(': 'open bracket',
  ')': 'close bracket',
  '[': 'open square bracket',
  ']': 'close square bracket',
  ',': ',',
  ';': ',',
  ':': 'to',
  '!': 'factorial',
  "'": 'prime',
  '′': 'prime',
  '%': 'percent',
  '.': '',
  '&': '',
  '~': '',
  '|': 'modulus',
  '?': '?',
};

// ─── Number words ─────────────────────────────────────────────────────

const _ones = [
  'zero', 'one', 'two', 'three', 'four', 'five', 'six', 'seven', 'eight',
  'nine', 'ten', 'eleven', 'twelve', 'thirteen', 'fourteen', 'fifteen',
  'sixteen', 'seventeen', 'eighteen', 'nineteen',
];
const _tens = [
  '', '', 'twenty', 'thirty', 'forty', 'fifty', 'sixty', 'seventy',
  'eighty', 'ninety',
];

/// 0–99 in words; larger numbers as numerals, which every engine reads.
String _numberWord(int n) {
  if (n < 0 || n > 99) return '$n';
  if (n < 20) return _ones[n];
  final t = _tens[n ~/ 10];
  return n % 10 == 0 ? t : '$t ${_ones[n % 10]}';
}

const _ordinalDenominators = {
  2: ('half', 'halves'),
  3: ('third', 'thirds'),
  4: ('quarter', 'quarters'),
  5: ('fifth', 'fifths'),
  6: ('sixth', 'sixths'),
  7: ('seventh', 'sevenths'),
  8: ('eighth', 'eighths'),
  9: ('ninth', 'ninths'),
  10: ('tenth', 'tenths'),
  12: ('twelfth', 'twelfths'),
  100: ('hundredth', 'hundredths'),
};

/// "one half", "three quarters" — or null when a fraction is not simple
/// enough to say that way.
String? _simpleFraction(String num, String den) {
  final n = int.tryParse(num);
  final d = int.tryParse(den);
  if (n == null || d == null || n < 1 || n > 20) return null;
  final names = _ordinalDenominators[d];
  if (names == null) return null;
  return '${_numberWord(n)} ${n == 1 ? names.$1 : names.$2}';
}

const _rootNames = {
  '2': 'square',
  '3': 'cube',
  '4': 'fourth',
  '5': 'fifth',
  'n': 'nth',
};

// ─── Parsing ──────────────────────────────────────────────────────────

/// One spoken piece of maths, and whether it is a single term (so it needs
/// no pause around it when it becomes a numerator, exponent or argument).
class _Spoken {
  const _Spoken(this.words, {required this.simple, this.raw});
  final String words;
  final bool simple;

  /// The single token's text, for decisions like "is this exponent 2".
  final String? raw;
}

class _MathParser {
  _MathParser(this.toks);
  final List<_Tok> toks;
  var _i = 0;

  _Tok? get _peek => _i < toks.length ? toks[_i] : null;

  /// Parses until a `}` (not consumed) or the end, or until [stop] matches
  /// (not consumed).
  List<String> parseSequence({bool Function(_Tok)? stop}) {
    final words = <String>[];
    while (_i < toks.length) {
      final t = toks[_i];
      if (t.kind == _K.close) return words;
      if (stop != null && stop(t)) return words;
      final atom = _parseAtomWithScripts();
      if (atom != null && atom.words.isNotEmpty) words.add(atom.words);
    }
    return words;
  }

  /// A whole argument: a braced group, or one token.
  _Spoken _parseArgument() {
    final t = _peek;
    if (t == null) return const _Spoken('', simple: true);
    if (t.kind == _K.open) {
      _i++;
      final start = _i;
      final words = parseSequence();
      final count = _i - start;
      if (_peek?.kind == _K.close) _i++;
      final raw = count == 1 ? toks[start].text : null;
      final rawKind = count == 1 ? toks[start].kind : null;
      return _Spoken(
        words.join(' '),
        simple: words.length <= 1,
        raw: rawKind == _K.number || rawKind == _K.letter ? raw : null,
      );
    }
    // `\frac12` is one half: an unbraced argument is one character.
    if (t.kind == _K.number && t.text.length > 1) {
      final first = t.text[0];
      t.text = t.text.substring(1);
      return _Spoken(first, simple: true, raw: first);
    }
    final atom = _parseAtom();
    return atom ?? const _Spoken('', simple: true);
  }

  _Spoken? _parseAtomWithScripts() {
    final start = _peek;
    var base = _parseAtom();
    if (base == null) return null;
    while (true) {
      final t = _peek;
      if (t == null) break;
      if (t.kind == _K.sup) {
        _i++;
        final exp = _parseArgument();
        base = _Spoken(
          '${base!.words} ${_power(exp)}',
          simple: false,
        );
      } else if (t.kind == _K.sub) {
        _i++;
        final sub = _parseArgument();
        base = _subscript(base!, start, sub);
      } else if (t.isSymbol("'")) {
        _i++;
        base = _Spoken('${base!.words} prime', simple: false);
      } else {
        break;
      }
    }
    return base;
  }

  String _power(_Spoken exp) {
    final w = exp.words.trim();
    if (w == '2') return 'squared';
    if (w == '3') return 'cubed';
    if (w == 'degrees') return 'degrees';
    if (w == 'prime') return 'prime';
    if (w.isEmpty) return '';
    return exp.simple ? 'to the power $w' : 'to the power $w,';
  }

  _Spoken _subscript(_Spoken base, _Tok? baseTok, _Spoken sub) {
    // `101_2` is a number in base two: its digits one by one, then the base.
    final radix = int.tryParse(sub.raw ?? '');
    if (baseTok != null &&
        baseTok.kind == _K.number &&
        RegExp(r'^[0-9]+$').hasMatch(baseTok.text) &&
        radix != null &&
        radix >= 2 &&
        radix <= 36) {
      final digits = baseTok.text.split('').map((d) => _ones[int.parse(d)]);
      return _Spoken(
        '${digits.join(' ')}, base ${_numberWord(radix)},',
        simple: false,
      );
    }
    final w = sub.words.trim();
    if (w.isEmpty) return base;
    return _Spoken(
      sub.simple ? '${base.words} sub $w' : '${base.words} sub $w,',
      simple: false,
    );
  }

  _Spoken? _parseAtom() {
    final t = _peek;
    if (t == null) return null;
    _i++;
    switch (t.kind) {
      case _K.open:
        final words = parseSequence();
        if (_peek?.kind == _K.close) _i++;
        return _Spoken(words.join(' '), simple: words.length <= 1);
      case _K.close:
        return null;
      case _K.sup:
      case _K.sub:
        // A script with no base: read what it applies to.
        final arg = _parseArgument();
        return t.kind == _K.sup
            ? _Spoken(_power(arg), simple: false)
            : _Spoken('sub ${arg.words}', simple: false);
      case _K.number:
        return _Spoken(t.text, simple: true, raw: t.text);
      case _K.letter:
        // f(x), g(x), h(x): "f of x", not "f open bracket x close bracket".
        if ('fgh'.contains(t.text) && (_peek?.isSymbol('(') ?? false)) {
          return _Spoken('${t.text} of ${_bracketed()}', simple: false);
        }
        return _Spoken(t.text, simple: true, raw: t.text);
      case _K.text:
        return _Spoken(_speakProse(t.text), simple: false);
      case _K.symbol:
        return _symbol(t);
      case _K.command:
        return _command(t.text);
    }
  }

  /// Contents of a `( ... )` at the cursor, brackets dropped; a trailing
  /// comma marks the end of a long argument.
  String _bracketed() {
    _i++; // (
    final words = parseSequence(stop: (t) => t.isSymbol(')'));
    if (_peek?.isSymbol(')') ?? false) _i++;
    final w = words.join(' ');
    return words.length > 1 ? '$w,' : w;
  }

  _Spoken _symbol(_Tok t) {
    final s = t.text;
    if (_vulgarFractions.containsKey(s)) {
      return _Spoken(_vulgarFractions[s]!, simple: true);
    }
    if (s == '|') {
      // |x| is "the modulus of x".
      final words = parseSequence(stop: (t) => t.isSymbol('|'));
      if (_peek?.isSymbol('|') ?? false) _i++;
      final w = words.join(' ');
      return _Spoken(
        words.length > 1 ? 'the modulus of $w,' : 'the modulus of $w',
        simple: false,
      );
    }
    if (s == '√') {
      final arg = _parseArgument();
      return _Spoken(_root('square', arg), simple: false);
    }
    final word = _symbols[s];
    if (word != null) return _Spoken(word, simple: true);
    // Another letter-like character (an accented name, say) is itself;
    // anything else is dropped rather than recited.
    return RegExp(r'\p{L}', unicode: true).hasMatch(s)
        ? _Spoken(s, simple: true)
        : const _Spoken('', simple: true);
  }

  String _root(String name, _Spoken arg) => arg.simple
      ? 'the $name root of ${arg.words}'
      : 'the $name root of ${arg.words},';

  _Spoken _command(String name) {
    switch (name) {
      case 'frac':
      case 'dfrac':
      case 'tfrac':
      case 'cfrac':
        final num = _parseArgument();
        final den = _parseArgument();
        final simple = _simpleFraction(num.raw ?? '', den.raw ?? '');
        if (simple != null) return _Spoken(simple, simple: true);
        final top = num.simple ? num.words : '${num.words}, all';
        final bottom = den.simple ? den.words : 'the quantity ${den.words},';
        return _Spoken('$top over $bottom', simple: false);
      case 'sqrt':
        var rootName = 'square';
        if (_peek?.isSymbol('[') ?? false) {
          _i++;
          final start = _i;
          final idx = parseSequence(stop: (t) => t.isSymbol(']'));
          final single = _i - start == 1 ? toks[start].text : null;
          if (_peek?.isSymbol(']') ?? false) _i++;
          rootName = _rootNames[single ?? ''] ??
              (idx.isEmpty ? 'square' : '${idx.join(' ')}th');
        }
        return _Spoken(_root(rootName, _parseArgument()), simple: false);
      case 'binom':
        final n = _parseArgument();
        final r = _parseArgument();
        return _Spoken('${n.words} choose ${r.words}', simple: false);
      case 'bar':
      case 'overline':
        // x̄ is "x bar"; a line over two points is the line segment.
        final arg = _parseArgument();
        return _Spoken(
          arg.simple ? '${arg.words} bar' : 'line ${arg.words}',
          simple: false,
        );
      case 'hat':
      case 'widehat':
        return _Spoken('${_parseArgument().words} hat', simple: false);
      case 'dot':
        return _Spoken('${_parseArgument().words} dot', simple: false);
      case 'vec':
      case 'overrightarrow':
        return _Spoken('vector ${_parseArgument().words}', simple: false);
      case 'underline':
        return _parseArgument();
      case 'mathbb':
        final arg = _parseArgument();
        return _Spoken(
          switch (arg.words) {
            'R' => 'the real numbers',
            'N' => 'the natural numbers',
            'Z' => 'the integers',
            'Q' => 'the rational numbers',
            'C' => 'the complex numbers',
            _ => arg.words,
          },
          simple: false,
        );
      case 'sum':
      case 'prod':
      case 'int':
        final (lower, upper) = _limits();
        final what = switch (name) {
          'sum' => 'the sum',
          'prod' => 'the product',
          _ => 'the integral',
        };
        if (lower == null && upper == null) return _Spoken('$what of', simple: false);
        final from = lower == null ? '' : ' from $lower';
        final to = upper == null ? '' : ' to $upper';
        return _Spoken('$what$from$to, of', simple: false);
      case 'lim':
        final (under, _) = _limits();
        return _Spoken(
          under == null ? 'the limit of' : 'the limit as $under, of',
          simple: false,
        );
      case 'color':
      case 'textcolor':
        _parseArgument(); // the colour name
        return _parseArgument();
    }

    final fn = _functions[name];
    if (fn != null) return _function(name, fn);

    final word = _commandWord(name);
    if (word != null) return _Spoken(word, simple: true);

    // Unknown: say so, and skip its arguments rather than reading them as
    // if they were the maths.
    while (_peek?.kind == _K.open) {
      _parseArgument();
    }
    return const _Spoken('expression', simple: true);
  }

  /// The `_{..}` and `^{..}` after a big operator, in either order.
  (String?, String?) _limits() {
    String? lower;
    String? upper;
    for (var k = 0; k < 2; k++) {
      final t = _peek;
      if (t?.kind == _K.sub) {
        _i++;
        lower = _parseArgument().words.trim();
      } else if (t?.kind == _K.sup) {
        _i++;
        upper = _parseArgument().words.trim();
      }
    }
    return (lower, upper);
  }

  /// `\sin x`, `\sin^2 x`, `\sin^{-1} x`, `\log_2 8`, `\sin(A + B)`.
  _Spoken _function(String name, String spoken) {
    var head = spoken;
    String? power;
    String? base;
    for (var k = 0; k < 2; k++) {
      final t = _peek;
      if (t?.kind == _K.sup) {
        _i++;
        power = _parseArgument().words.trim();
      } else if (t?.kind == _K.sub) {
        _i++;
        base = _parseArgument().words.trim();
      }
    }
    if (power == 'minus 1') {
      head = 'inverse $spoken';
    } else if (power != null && power.isNotEmpty) {
      head = '$spoken ${_power(_Spoken(power, simple: !power.contains(' ')))}';
    }
    if (base != null && base.isNotEmpty) head = '$head base $base';

    // Functions already phrased "the ... of" take their argument directly.
    final joiner = spoken.endsWith(' of') ? '' : ' of';
    final next = _peek;
    if (next == null || next.kind == _K.close) {
      return _Spoken(head, simple: false);
    }
    if (next.isSymbol('(')) {
      return _Spoken('$head$joiner ${_bracketed()}', simple: false);
    }
    if (next.kind == _K.symbol && _symbols[next.text] != null &&
        !_vulgarFractions.containsKey(next.text) && next.text != '|') {
      // Followed by an operator, not an argument: `\lim_{x \to 0}` etc.
      return _Spoken(head, simple: false);
    }
    final arg = _parseAtomWithScripts();
    if (arg == null || arg.words.isEmpty) return _Spoken(head, simple: false);
    return _Spoken('$head$joiner ${arg.words}', simple: false);
  }
}

// ─── Final polish ─────────────────────────────────────────────────────

String _finishMath(String s) => s
    .replaceAllMapped(
      RegExp(r'\bdegrees ([CF])\b'),
      (m) => m.group(1) == 'C' ? 'degrees Celsius' : 'degrees Fahrenheit',
    )
    .replaceAll(RegExp(r'^\s*,+'), '')
    .replaceAll(RegExp(r',+\s*$'), '');

/// Collapses whitespace and tidies the commas that joining words leaves.
String _tidy(String s) => s
    .replaceAll(RegExp(r'\s+'), ' ')
    .replaceAllMapped(RegExp(r'\s+([,.;:!?)])'), (m) => m.group(1)!)
    .replaceAllMapped(RegExp(r'\(\s+'), (m) => '(')
    .replaceAll(RegExp(r',(\s*,)+'), ',')
    .replaceAllMapped(RegExp(r',([.;:!?])'), (m) => m.group(1)!)
    .trim();
