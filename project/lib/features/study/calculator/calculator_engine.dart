/// The calculator's engine: tokenizer, parser and evaluator, plus the
/// display formatting. Pure Dart — no Flutter — so every rule here is
/// testable without a widget.
///
/// Semantics follow the Casio fx-82 series, the non-programmable scientific
/// calculator WAEC candidates actually carry into the hall:
///
/// * Priority, highest first: functions with brackets and postfix operators
///   (x², x³, x⁻¹, x!, %), powers (right-associative), the negative sign,
///   **multiplication with the sign omitted**, nCr/nPr, × ÷, then + −. So
///   `-2²` is −4, and `1÷2π` is 1/(2π), as on the fx-82.
/// * Missing right brackets at the end of the expression are closed
///   automatically.
/// * Domain problems are a [CalcError] of kind [CalcErrorKind.math]
///   ("Math ERROR"), malformed input one of kind [CalcErrorKind.syntax]
///   ("Syntax ERROR"). [evaluate] never throws.
///
/// The engine calculates in doubles and rounds each final answer to 15
/// significant digits (the fx-82 keeps 15 internally), which is what makes
/// `0.1+0.2` exactly 0.3 and `log 1000` exactly 3 when the answer is reused.
library;

import 'dart:math' as math;

enum AngleMode { deg, rad }

enum CalcErrorKind {
  math('Math ERROR'),
  syntax('Syntax ERROR');

  const CalcErrorKind(this.message);
  final String message;
}

/// The outcome of one evaluation: a value or a typed error.
sealed class CalcResult {
  const CalcResult();
}

class CalcValue extends CalcResult {
  const CalcValue(this.value);
  final double value;

  @override
  bool operator ==(Object other) => other is CalcValue && other.value == value;
  @override
  int get hashCode => value.hashCode;
  @override
  String toString() => 'CalcValue($value)';
}

class CalcError extends CalcResult {
  const CalcError(this.kind);
  final CalcErrorKind kind;
  String get message => kind.message;

  @override
  bool operator ==(Object other) => other is CalcError && other.kind == kind;
  @override
  int get hashCode => kind.hashCode;
  @override
  String toString() => 'CalcError(${kind.message})';
}

/// The fx-82 range: anything at or beyond ±1×10¹⁰⁰ is a Math ERROR.
const double _maxMagnitude = 1e100;

/// Evaluates [expression]. Never throws.
///
/// Accepts the calculator's own symbols (`×`, `÷`, `−`, `²`, `³`, `⁻¹`, `π`,
/// `√`, `∛`, `sin⁻¹`, `Ans`, `M`, `C` for nCr, `P` for nPr) and the ASCII
/// stand-ins a keyboard types (`*`, `/`, `-`).
CalcResult evaluate(
  String expression, {
  AngleMode angleMode = AngleMode.deg,
  double ans = 0,
  double memory = 0,
}) {
  final List<_Token> tokens;
  final _Node tree;
  try {
    tokens = _tokenize(expression);
    tree = _Parser(tokens).parse();
  } on _CalcException catch (e) {
    return CalcError(e.kind);
  } catch (_) {
    return const CalcError(CalcErrorKind.syntax);
  }
  try {
    final v = _Evaluator(angleMode, ans, memory).eval(tree);
    return CalcValue(_round15(v));
  } on _CalcException catch (e) {
    return CalcError(e.kind);
  } catch (_) {
    return const CalcError(CalcErrorKind.math);
  }
}

// ── Errors ──────────────────────────────────────────────────────────────

class _CalcException implements Exception {
  const _CalcException(this.kind);
  final CalcErrorKind kind;
}

const _syntax = _CalcException(CalcErrorKind.syntax);
const _math = _CalcException(CalcErrorKind.math);

// ── Tokenizer ───────────────────────────────────────────────────────────

enum _T {
  number,
  plus,
  minus,
  times,
  divide,
  power,
  lparen,
  rparen,
  square,
  cube,
  inverse,
  factorial,
  percent,
  comb,
  perm,
  pi,
  e,
  ans,
  mem,

  /// A function followed by its own opening bracket: `sin(`.
  funcOpen,

  /// A function written without a bracket: `sin 30`.
  func,
  end,
}

class _Token {
  const _Token(this.type, {this.value = 0, this.name = ''});
  final _T type;
  final double value;
  final String name;
}

/// Longest names first, so `sin⁻¹` is not read as `sin` then `⁻¹`.
const _functionNames = [
  'sin⁻¹',
  'cos⁻¹',
  'tan⁻¹',
  'sin',
  'cos',
  'tan',
  'log',
  'ln',
  '√',
  '∛',
];

const Map<String, _T> _symbols = {
  '+': _T.plus,
  '-': _T.minus,
  '−': _T.minus,
  '×': _T.times,
  '*': _T.times,
  '÷': _T.divide,
  '/': _T.divide,
  '^': _T.power,
  '(': _T.lparen,
  ')': _T.rparen,
  '²': _T.square,
  '³': _T.cube,
  '⁻¹': _T.inverse,
  '!': _T.factorial,
  '%': _T.percent,
  'C': _T.comb,
  'P': _T.perm,
  'π': _T.pi,
  'e': _T.e,
  'Ans': _T.ans,
  'M': _T.mem,
};

bool _isDigit(String c) => c.codeUnitAt(0) >= 48 && c.codeUnitAt(0) <= 57;

List<_Token> _tokenize(String src) {
  final out = <_Token>[];
  var i = 0;
  while (i < src.length) {
    final c = src[i];
    if (c.trim().isEmpty) {
      i++;
      continue;
    }
    if (_isDigit(c) || c == '.') {
      var j = i;
      var dots = 0;
      while (j < src.length && (_isDigit(src[j]) || src[j] == '.')) {
        if (src[j] == '.') dots++;
        j++;
      }
      final text = src.substring(i, j);
      if (dots > 1 || text == '.') throw _syntax;
      out.add(_Token(_T.number, value: double.parse(text)));
      i = j;
      continue;
    }
    final rest = src.substring(i);
    String? fn;
    for (final name in _functionNames) {
      if (rest.startsWith(name)) {
        fn = name;
        break;
      }
    }
    if (fn != null) {
      i += fn.length;
      if (i < src.length && src[i] == '(') {
        out.add(_Token(_T.funcOpen, name: fn));
        i++;
      } else {
        out.add(_Token(_T.func, name: fn));
      }
      continue;
    }
    var matched = false;
    for (final entry in _symbols.entries) {
      if (rest.startsWith(entry.key)) {
        out.add(_Token(entry.value));
        i += entry.key.length;
        matched = true;
        break;
      }
    }
    if (!matched) throw _syntax;
  }
  out.add(const _Token(_T.end));
  return out;
}

// ── Parser (recursive descent, fx-82 priority) ─────────────────────────

sealed class _Node {
  const _Node();
}

class _Num extends _Node {
  const _Num(this.value);
  final double value;
}

class _Var extends _Node {
  const _Var(this.type);
  final _T type; // pi, e, ans, mem
}

class _Neg extends _Node {
  const _Neg(this.child);
  final _Node child;
}

class _Bin extends _Node {
  const _Bin(this.op, this.left, this.right);
  final _T op; // plus, minus, times, divide, power, comb, perm
  final _Node left;
  final _Node right;
}

class _Postfix extends _Node {
  const _Postfix(this.op, this.child);
  final _T op; // square, cube, inverse, factorial, percent
  final _Node child;
}

class _Func extends _Node {
  const _Func(this.name, this.arg);
  final String name;
  final _Node arg;
}

class _Parser {
  _Parser(this.tokens);
  final List<_Token> tokens;
  int pos = 0;

  _Token get peek => tokens[pos];
  _Token next() => tokens[pos++];

  _Node parse() {
    if (peek.type == _T.end) throw _syntax;
    final node = _additive();
    if (peek.type != _T.end) throw _syntax;
    return node;
  }

  _Node _additive() {
    var left = _mulDiv();
    while (peek.type == _T.plus || peek.type == _T.minus) {
      final op = next().type;
      left = _Bin(op, left, _mulDiv());
    }
    return left;
  }

  _Node _mulDiv() {
    var left = _combination();
    while (peek.type == _T.times || peek.type == _T.divide) {
      final op = next().type;
      left = _Bin(op, left, _combination());
    }
    return left;
  }

  _Node _combination() {
    var left = _implicit();
    while (peek.type == _T.comb || peek.type == _T.perm) {
      final op = next().type;
      left = _Bin(op, left, _implicit());
    }
    return left;
  }

  static const _primaryStarts = {
    _T.number,
    _T.pi,
    _T.e,
    _T.ans,
    _T.mem,
    _T.lparen,
    _T.funcOpen,
    _T.func,
  };

  /// Multiplication with the sign omitted: `2π`, `3(4)`, `2sin30`,
  /// `(1+2)(3+4)`. Two bare numbers side by side are not a product.
  _Node _implicit() {
    var left = _signed();
    while (_primaryStarts.contains(peek.type) &&
        !(peek.type == _T.number && tokens[pos - 1].type == _T.number)) {
      left = _Bin(_T.times, left, _power());
    }
    return left;
  }

  _Node _signed() {
    if (peek.type == _T.minus) {
      next();
      return _Neg(_signed());
    }
    if (peek.type == _T.plus) {
      next();
      return _signed();
    }
    return _power();
  }

  /// Right-associative: the exponent is parsed at the signed level, which
  /// recurses back here, so `2^3^2` is 2^9.
  _Node _power() {
    final base = _postfix();
    if (peek.type == _T.power) {
      next();
      return _Bin(_T.power, base, _signed());
    }
    return base;
  }

  static const _postfixOps = {
    _T.square,
    _T.cube,
    _T.inverse,
    _T.factorial,
    _T.percent,
  };

  _Node _postfix() {
    var node = _primary();
    while (_postfixOps.contains(peek.type)) {
      node = _Postfix(next().type, node);
    }
    return node;
  }

  /// A closing bracket, or the end of the input (auto-close).
  void _close() {
    if (peek.type == _T.rparen) {
      next();
    } else if (peek.type != _T.end) {
      throw _syntax;
    }
  }

  _Node _primary() {
    final t = next();
    switch (t.type) {
      case _T.number:
        return _Num(t.value);
      case _T.pi:
      case _T.e:
      case _T.ans:
      case _T.mem:
        return _Var(t.type);
      case _T.lparen:
        if (peek.type == _T.rparen || peek.type == _T.end) throw _syntax;
        final inner = _additive();
        _close();
        return inner;
      case _T.funcOpen:
        if (peek.type == _T.rparen || peek.type == _T.end) throw _syntax;
        final arg = _additive();
        _close();
        return _Func(t.name, arg);
      case _T.func:
        return _Func(t.name, _signed());
      default:
        throw _syntax;
    }
  }
}

// ── Evaluator ───────────────────────────────────────────────────────────

class _Evaluator {
  _Evaluator(this.mode, this.ans, this.memory);
  final AngleMode mode;
  final double ans;
  final double memory;

  double eval(_Node n) => _check(_eval(n));

  double _check(double v) {
    if (v.isNaN || v.isInfinite || v.abs() >= _maxMagnitude) throw _math;
    if (v.abs() < 1e-99) return 0;
    return v;
  }

  double _eval(_Node n) {
    switch (n) {
      case _Num(:final value):
        return value;
      case _Var(:final type):
        return switch (type) {
          _T.pi => math.pi,
          _T.e => math.e,
          _T.ans => ans,
          _ => memory,
        };
      case _Neg(:final child):
        return -eval(child);
      case _Bin(:final op, :final left, :final right):
        final a = eval(left);
        final b = eval(right);
        return _check(_binary(op, a, b));
      case _Postfix(:final op, :final child):
        return _check(_postfixOp(op, eval(child)));
      case _Func(:final name, :final arg):
        return _check(_function(name, eval(arg)));
    }
  }

  double _binary(_T op, double a, double b) {
    switch (op) {
      case _T.plus:
        return a + b;
      case _T.minus:
        return a - b;
      case _T.times:
        return a * b;
      case _T.divide:
        if (b == 0) throw _math;
        return a / b;
      case _T.power:
        return _pow(a, b);
      case _T.comb:
        return _nCr(a, b);
      case _T.perm:
        return _nPr(a, b);
      default:
        throw _syntax;
    }
  }

  double _postfixOp(_T op, double x) {
    switch (op) {
      case _T.square:
        return x * x;
      case _T.cube:
        return x * x * x;
      case _T.inverse:
        if (x == 0) throw _math;
        return 1 / x;
      case _T.factorial:
        return _factorial(x);
      case _T.percent:
        return x / 100;
      default:
        throw _syntax;
    }
  }

  double _function(String name, double x) {
    switch (name) {
      case 'sin':
      case 'cos':
      case 'tan':
        return _trig(name, x);
      case 'sin⁻¹':
        if (x.abs() > 1 + 1e-12) throw _math;
        return _fromRadians(math.asin(x.clamp(-1.0, 1.0)));
      case 'cos⁻¹':
        if (x.abs() > 1 + 1e-12) throw _math;
        return _fromRadians(math.acos(x.clamp(-1.0, 1.0)));
      case 'tan⁻¹':
        return _fromRadians(math.atan(x));
      case 'log':
        if (x <= 0) throw _math;
        return math.log(x) / math.ln10;
      case 'ln':
        if (x <= 0) throw _math;
        return math.log(x);
      case '√':
        if (x < 0) throw _math;
        return math.sqrt(x);
      case '∛':
        final r = math.pow(x.abs(), 1 / 3).toDouble();
        // Snap perfect cubes: pow(27, 1/3) is 3.0000000000000004.
        final rounded = r.roundToDouble();
        final root = rounded * rounded * rounded == x.abs() ? rounded : r;
        return x < 0 ? -root : root;
      default:
        throw _syntax;
    }
  }

  /// Inverse-trig results. In DEG an answer within a hair of a whole
  /// degree is that degree: sin⁻¹ 0.5 is 30, not 30.000000000000004.
  double _fromRadians(double r) {
    if (mode == AngleMode.rad) return r;
    final d = r * 180 / math.pi;
    final whole = d.roundToDouble();
    return (d - whole).abs() < 1e-9 ? whole : d;
  }

  /// sin/cos/tan. Angles that are whole multiples of 15° (or of π/12 in
  /// RAD) go through an exact table where the answer is rational, so
  /// `cos 90` is 0 rather than 6.123e-17 and `tan 90` is a Math ERROR
  /// rather than 1.633e16.
  double _trig(String name, double x) {
    double? degrees;
    if (mode == AngleMode.deg) {
      if (x.abs() >= 9e9) throw _math;
      degrees = x;
    } else {
      if (x.abs() >= 157079632.7) throw _math;
      final q = x / (math.pi / 12);
      final k = q.roundToDouble();
      if ((q - k).abs() < 1e-9) degrees = k * 15;
    }
    if (degrees != null) {
      final d = degrees % 360; // Dart's % on doubles is never negative.
      final exact = _exactTrig(name, d);
      if (exact != null) {
        if (exact.isNaN) throw _math;
        return exact;
      }
      final r = degrees * math.pi / 180;
      return _rawTrig(name, r);
    }
    return _rawTrig(name, x);
  }

  double _rawTrig(String name, double r) => switch (name) {
    'sin' => math.sin(r),
    'cos' => math.cos(r),
    _ => math.tan(r),
  };

  /// Exact values on [0, 360). NaN marks tan's poles; null means "no
  /// rational value here, compute it".
  static double? _exactTrig(String name, double d) {
    if (d != d.roundToDouble()) return null;
    final i = d.round();
    const sin = {
      0: 0.0,
      30: 0.5,
      90: 1.0,
      150: 0.5,
      180: 0.0,
      210: -0.5,
      270: -1.0,
      330: -0.5,
    };
    const cos = {
      0: 1.0,
      60: 0.5,
      90: 0.0,
      120: -0.5,
      180: -1.0,
      240: -0.5,
      270: 0.0,
      300: 0.5,
    };
    const tan = {
      0: 0.0,
      45: 1.0,
      90: double.nan,
      135: -1.0,
      180: 0.0,
      225: 1.0,
      270: double.nan,
      315: -1.0,
    };
    return switch (name) {
      'sin' => sin[i],
      'cos' => cos[i],
      _ => tan[i],
    };
  }

  double _pow(double a, double b) {
    if (a == 0 && b <= 0) throw _math;
    if (a < 0 && !_isInteger(b)) throw _math;
    if (a < 0) {
      final r = math.pow(-a, b.roundToDouble()).toDouble();
      return b.roundToDouble() % 2 == 0 ? r : -r;
    }
    return math.pow(a, b).toDouble();
  }

  double _factorial(double x) {
    if (!_isInteger(x) || x < 0 || x.round() > 69) throw _math;
    var r = 1.0;
    for (var i = 2; i <= x.round(); i++) {
      r *= i;
    }
    return r;
  }

  (int, int) _nr(double n, double r) {
    if (!_isInteger(n) || !_isInteger(r)) throw _math;
    if (n < 0 || r < 0 || n >= 1e10) throw _math;
    final ni = n.round();
    final ri = r.round();
    if (ri > ni) throw _math;
    return (ni, ri);
  }

  double _nCr(double n, double r) {
    final (ni, r0) = _nr(n, r);
    final ri = math.min(r0, ni - r0);
    var result = 1.0;
    for (var i = 1; i <= ri; i++) {
      result = result * (ni - ri + i) / i;
      if (result >= _maxMagnitude) throw _math;
    }
    return result.roundToDouble();
  }

  double _nPr(double n, double r) {
    final (ni, ri) = _nr(n, r);
    var result = 1.0;
    for (var i = 0; i < ri; i++) {
      result *= ni - i;
      if (result >= _maxMagnitude) throw _math;
    }
    return result;
  }
}

/// Integer to within rounding noise: `(0.1+0.2)×10` is 3 for x! and nCr,
/// as it is on a calculator that keeps 15 digits.
bool _isInteger(double x) =>
    (x - x.roundToDouble()).abs() <= 1e-10 * math.max(1, x.abs());

double _round15(double v) {
  if (v == 0) return 0;
  final r = double.parse(v.toStringAsPrecision(15));
  return r == 0 ? 0 : r;
}

// ── Display ─────────────────────────────────────────────────────────────

const _superscripts = {
  '0': '⁰',
  '1': '¹',
  '2': '²',
  '3': '³',
  '4': '⁴',
  '5': '⁵',
  '6': '⁶',
  '7': '⁷',
  '8': '⁸',
  '9': '⁹',
  '-': '⁻',
};

String _trimZeros(String s) {
  if (!s.contains('.')) return s;
  s = s.replaceFirst(RegExp(r'0+$'), '');
  return s.endsWith('.') ? s.substring(0, s.length - 1) : s;
}

/// A result as the display shows it: up to 10 significant digits,
/// trailing zeros trimmed, and scientific notation (`1.5×10¹²`) when the
/// magnitude is below 1×10⁻⁹ or at least 1×10¹⁰ — the fx-82's Norm 2
/// range. Negative numbers use the minus sign `−`.
String formatNumber(double v) {
  if (v.isNaN || v.isInfinite) return CalcErrorKind.math.message;
  if (v == 0) return '0';
  final negative = v < 0;
  final a = double.parse(v.abs().toStringAsPrecision(10));
  final expForm = a.toStringAsExponential(9); // "1.234567890e+3"
  final eAt = expForm.indexOf('e');
  final exponent = int.parse(expForm.substring(eAt + 1));
  String body;
  if (a >= 1e10 || a < 1e-9) {
    final mantissa = _trimZeros(expForm.substring(0, eAt));
    final sup = exponent
        .toString()
        .split('')
        .map((c) => _superscripts[c] ?? c)
        .join();
    body = '$mantissa×10$sup';
  } else {
    body = _trimZeros(a.toStringAsFixed(math.max(0, 9 - exponent)));
  }
  return negative ? '−$body' : body;
}

/// [v] as a fraction `p/q`, or null when it is not one worth showing.
///
/// Uses the continued-fraction expansion of [v] and returns the first
/// convergent (so the smallest denominator) that is **exact to display
/// precision** — it formats to the same 10 significant digits as [v].
/// Denominators stop at 10000, and, as on the fx-82, a fraction whose
/// digits would not fit the 10-digit display is not offered. Whole
/// numbers have no fraction form.
String? formatFraction(double v) {
  if (v.isNaN || v.isInfinite || v == 0) return null;
  final x = v.abs();
  if (x >= 1e10 || x < 1e-9) return null;
  final target = formatNumber(x);
  if (!target.contains('.')) return null; // whole number
  var h1 = 1.0, h2 = 0.0; // numerators
  var k1 = 0.0, k2 = 1.0; // denominators
  var rest = x;
  for (var i = 0; i < 40; i++) {
    final a = rest.floorToDouble();
    final h = a * h1 + h2;
    final k = a * k1 + k2;
    if (k > 10000) return null;
    if (k > 1 && formatNumber(h / k) == target) {
      final p = h.round();
      final q = k.round();
      if (p.toString().length + q.toString().length > 10) return null;
      return '${v < 0 ? '−' : ''}$p/$q';
    }
    h2 = h1;
    h1 = h;
    k2 = k1;
    k1 = k;
    final frac = rest - a;
    if (frac < 1e-12) return null;
    rest = 1 / frac;
  }
  return null;
}
