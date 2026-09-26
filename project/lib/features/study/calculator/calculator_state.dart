/// What the calculator's keys do: an immutable state and one transition per
/// key press. Pure Dart, like the engine, so the fx-82 key behaviour (Ans,
/// memory, SHIFT, carrying on from a result) is tested without a widget.
library;

import 'calculator_engine.dart';

/// Every key on the keypad. SHIFT changes what some of them enter — see
/// [CalculatorState.press].
enum CalcKey {
  d0,
  d1,
  d2,
  d3,
  d4,
  d5,
  d6,
  d7,
  d8,
  d9,
  point,
  add,
  subtract,
  multiply,
  divide,
  power,
  square, // SHIFT: cube
  inverse,
  factorial,
  percent,
  open,
  close,
  pi, // SHIFT: e
  sin, // SHIFT: sin⁻¹
  cos, // SHIFT: cos⁻¹
  tan, // SHIFT: tan⁻¹
  log, // SHIFT: 10ˣ
  ln, // SHIFT: eˣ
  sqrt, // SHIFT: ∛
  nCr, // SHIFT: nPr
  ans,
  memoryRecall,
  memoryPlus, // SHIFT: M−
  memoryClear,
  delete,
  clear,
  equals,
  shift,
  angle,
  fraction,
}

/// The token a key enters, unshifted and shifted. Keys that are actions
/// rather than input are absent.
const Map<CalcKey, (String, String?)> calcKeyTokens = {
  CalcKey.d0: ('0', null),
  CalcKey.d1: ('1', null),
  CalcKey.d2: ('2', null),
  CalcKey.d3: ('3', null),
  CalcKey.d4: ('4', null),
  CalcKey.d5: ('5', null),
  CalcKey.d6: ('6', null),
  CalcKey.d7: ('7', null),
  CalcKey.d8: ('8', null),
  CalcKey.d9: ('9', null),
  CalcKey.point: ('.', null),
  CalcKey.add: ('+', null),
  CalcKey.subtract: ('−', null),
  CalcKey.multiply: ('×', null),
  CalcKey.divide: ('÷', null),
  CalcKey.power: ('^(', null),
  CalcKey.square: ('²', '³'),
  CalcKey.inverse: ('⁻¹', null),
  CalcKey.factorial: ('!', null),
  CalcKey.percent: ('%', null),
  CalcKey.open: ('(', null),
  CalcKey.close: (')', null),
  CalcKey.pi: ('π', 'e'),
  CalcKey.sin: ('sin(', 'sin⁻¹('),
  CalcKey.cos: ('cos(', 'cos⁻¹('),
  CalcKey.tan: ('tan(', 'tan⁻¹('),
  CalcKey.log: ('log(', '10^('),
  CalcKey.ln: ('ln(', 'e^('),
  CalcKey.sqrt: ('√(', '∛('),
  CalcKey.nCr: ('C', 'P'),
  CalcKey.ans: ('Ans', null),
  CalcKey.memoryRecall: ('M', null),
};

/// Tokens that carry on from a result: pressing `+` after `=` gives
/// `Ans+`, as on the fx-82. Anything else starts a fresh expression.
const _continuesFromAns = {
  '+',
  '−',
  '×',
  '÷',
  '^(',
  '²',
  '³',
  '⁻¹',
  '!',
  '%',
  'C',
  'P',
};

class CalculatorState {
  const CalculatorState({
    this.tokens = const [],
    this.result,
    this.ans = 0,
    this.memory = 0,
    this.angleMode = AngleMode.deg,
    this.shift = false,
    this.showFraction = false,
  });

  /// The expression being typed, one entry per key press, so DEL removes
  /// `sin(` whole, as the fx-82 does.
  final List<String> tokens;

  /// The answer on the display, or null while an expression is being
  /// edited.
  final CalcResult? result;
  final double ans;
  final double memory;
  final AngleMode angleMode;
  final bool shift;

  /// S⇔D: show the result as a fraction when it has one.
  final bool showFraction;

  String get expression => tokens.join();
  bool get hasMemory => memory != 0;

  /// The result line: the answer, its fraction form under S⇔D, an error
  /// message, or empty while editing.
  String get resultText {
    final r = result;
    return switch (r) {
      null => '',
      CalcError() => r.message,
      CalcValue(:final value) =>
        (showFraction ? formatFraction(value) : null) ?? formatNumber(value),
    };
  }

  CalculatorState copyWith({
    List<String>? tokens,
    CalcResult? result,
    bool clearResult = false,
    double? ans,
    double? memory,
    AngleMode? angleMode,
    bool? shift,
    bool? showFraction,
  }) => CalculatorState(
    tokens: tokens ?? this.tokens,
    result: clearResult ? null : (result ?? this.result),
    ans: ans ?? this.ans,
    memory: memory ?? this.memory,
    angleMode: angleMode ?? this.angleMode,
    shift: shift ?? this.shift,
    showFraction: showFraction ?? this.showFraction,
  );

  /// The state after [key] is pressed. SHIFT applies to the next key only.
  CalculatorState press(CalcKey key) {
    final entry = calcKeyTokens[key];
    if (entry != null) {
      final (plain, shifted) = entry;
      return _input(shift && shifted != null ? shifted : plain);
    }
    final s = copyWith(shift: false);
    switch (key) {
      case CalcKey.shift:
        return copyWith(shift: !shift);
      case CalcKey.delete:
        return s._delete();
      case CalcKey.clear:
        return s.copyWith(
          tokens: const [],
          clearResult: true,
          showFraction: false,
        );
      case CalcKey.equals:
        return s._equals();
      case CalcKey.memoryPlus:
        return s._memory(shift ? -1 : 1);
      case CalcKey.memoryClear:
        return s.copyWith(memory: 0);
      case CalcKey.angle:
        return s.copyWith(
          angleMode: angleMode == AngleMode.deg ? AngleMode.rad : AngleMode.deg,
        );
      case CalcKey.fraction:
        final r = result;
        if (r is CalcValue && formatFraction(r.value) != null) {
          return s.copyWith(showFraction: !showFraction);
        }
        return s;
      default:
        return s;
    }
  }

  CalculatorState _input(String token) {
    var base = tokens;
    if (result != null) {
      base = result is CalcValue && _continuesFromAns.contains(token)
          ? const ['Ans']
          : const [];
    }
    // 10ˣ straight after a digit: `2` then `10^(` must not read as `210^(`.
    final needsTimes =
        token == '10^(' &&
        base.isNotEmpty &&
        RegExp(r'^[0-9.]$').hasMatch(base.last);
    return CalculatorState(
      tokens: [...base, if (needsTimes) '×', token],
      ans: ans,
      memory: memory,
      angleMode: angleMode,
    );
  }

  /// After a result or an error, DEL returns to the expression for editing,
  /// as on the fx-82; otherwise it removes the last key press.
  CalculatorState _delete() {
    if (result != null) return copyWith(clearResult: true, showFraction: false);
    if (tokens.isEmpty) return this;
    return copyWith(tokens: tokens.sublist(0, tokens.length - 1));
  }

  CalcResult _evaluate() =>
      evaluate(expression, angleMode: angleMode, ans: ans, memory: memory);

  CalculatorState _equals() {
    if (tokens.isEmpty) return this;
    final r = _evaluate();
    return copyWith(
      result: r,
      ans: r is CalcValue ? r.value : ans,
      showFraction: false,
    );
  }

  /// M+ / M−: adds the answer on display, or evaluates the expression being
  /// edited first (which also makes it Ans).
  CalculatorState _memory(int sign) {
    final shown = result;
    if (shown is CalcValue) {
      return copyWith(memory: _tidy(memory + sign * shown.value));
    }
    if (shown is CalcError || tokens.isEmpty) return this;
    final next = _equals();
    final r = next.result;
    if (r is CalcValue) {
      return next.copyWith(memory: _tidy(memory + sign * r.value));
    }
    return next;
  }

  static double _tidy(double v) =>
      v == 0 ? 0 : double.parse(v.toStringAsPrecision(15));
}
