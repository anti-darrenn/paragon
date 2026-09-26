import 'package:flutter_test/flutter_test.dart';
import 'package:paragon/features/study/calculator/calculator_engine.dart';
import 'package:paragon/features/study/calculator/calculator_state.dart';

/// Evaluates and formats, as the display would show it.
String calc(
  String expr, {
  AngleMode mode = AngleMode.deg,
  double ans = 0,
  double memory = 0,
}) {
  final r = evaluate(expr, angleMode: mode, ans: ans, memory: memory);
  return switch (r) {
    CalcValue(:final value) => formatNumber(value),
    CalcError(:final message) => message,
  };
}

double value(String expr, {AngleMode mode = AngleMode.deg}) =>
    (evaluate(expr, angleMode: mode) as CalcValue).value;

const mathError = 'Math ERROR';
const syntaxError = 'Syntax ERROR';
const rad = AngleMode.rad;

/// Presses a sequence of keys from a fresh (or given) state.
CalculatorState keys(List<CalcKey> ks, [CalculatorState? from]) {
  var s = from ?? const CalculatorState();
  for (final k in ks) {
    s = s.press(k);
  }
  return s;
}

void main() {
  group('precedence', () {
    test('× ÷ before + −', () {
      expect(calc('2+3×4'), '14');
      expect(calc('10−6÷2'), '7');
      expect(calc('2×3+4×5'), '26');
    });
    test('left to right within a level', () {
      expect(calc('10−4−3'), '3');
      expect(calc('100÷10÷5'), '2');
      expect(calc('8÷2×4'), '16');
    });
    test('brackets override', () {
      expect(calc('(2+3)×4'), '20');
      expect(calc('2×(3+4)×(5−1)'), '56');
    });
    test('powers bind tighter than × and unary minus', () {
      expect(calc('2×3^(2)'), '18');
      expect(calc('2^3×2'), '16');
    });
    test('ASCII operators are accepted', () {
      expect(calc('6*7-2/2'), '41');
    });
  });

  group('unary minus', () {
    test('leading and after an operator', () {
      expect(calc('−5+3'), '−2');
      expect(calc('3×−2'), '−6');
      expect(calc('3−−2'), '5');
      expect(calc('+4'), '4');
    });
    test('the sign is below powers and postfix squares', () {
      expect(calc('−2²'), '−4');
      expect(calc('(−2)²'), '4');
      expect(calc('−2^(2)'), '−4');
    });
    test('in an exponent', () {
      expect(calc('2^−1'), '0.5');
      expect(calc('10^(−2)'), '0.01');
    });
  });

  group('powers', () {
    test('right-associative', () {
      expect(calc('2^3^2'), '512');
      expect(calc('2^(3)^(2)'), '512');
      expect(calc('(2^3)^2'), '64');
    });
    test('x², x³, x⁻¹', () {
      expect(calc('5²'), '25');
      expect(calc('3³'), '27');
      expect(calc('4⁻¹'), '0.25');
      expect(calc('2²³'), '64'); // (2²)³
    });
    test('negative base with integer exponent', () {
      expect(calc('(−2)^(3)'), '−8');
      expect(calc('(−3)^(4)'), '81');
    });
  });

  group('implicit multiplication', () {
    test('number before a constant, bracket or function', () {
      expect(calc('2π'), '6.283185307');
      expect(calc('3(4)'), '12');
      expect(calc('2sin30'), '1');
      expect(calc('2sin(30)'), '1');
      expect(calc('(1+2)(3+4)'), '21');
      expect(calc('2Ans', ans: 5), '10');
      expect(calc('3M', memory: 4), '12');
    });
    test('outranks explicit × and ÷, as on the fx-82', () {
      expect(calc('1÷2π'), '0.1591549431');
      expect(calc('6÷2(1+2)'), '1');
    });
    test('function without brackets takes the next operand', () {
      expect(calc('sin30cos60'), '0.25');
      expect(calc('√4+1'), '3');
    });
    test('two bare numbers are not a product', () {
      expect(calc('2 3'), syntaxError);
    });
  });

  group('brackets', () {
    test('missing right brackets close at the end', () {
      expect(calc('(2+3'), '5');
      expect(calc('2×(3+(4'), '14');
      expect(calc('sin(30'), '0.5');
      expect(calc('√(cos(0'), '1');
    });
    test('mismatched or empty brackets are syntax errors', () {
      expect(calc('2+3)'), syntaxError);
      expect(calc('()'), syntaxError);
      expect(calc('sin()'), syntaxError);
    });
  });

  group('trigonometry, DEG', () {
    test('exact standard angles', () {
      expect(value('sin30'), 0.5);
      expect(value('cos60'), 0.5);
      expect(value('tan45'), 1);
      expect(value('cos90'), 0);
      expect(value('sin180'), 0);
      expect(value('cos180'), -1);
      expect(value('sin270'), -1);
      expect(value('tan135'), -1);
      expect(value('sin(−30)'), -0.5);
      expect(value('cos(420)'), 0.5);
    });
    test('other angles', () {
      expect(calc('sin60'), '0.8660254038');
      expect(calc('tan60'), '1.732050808');
      expect(calc('cos45'), '0.7071067812');
    });
    test('tan at its poles is a Math ERROR', () {
      expect(calc('tan90'), mathError);
      expect(calc('tan270'), mathError);
      expect(calc('tan(−90)'), mathError);
    });
    test('inverse trig', () {
      expect(value('sin⁻¹(0.5)'), 30);
      expect(value('cos⁻¹(0.5)'), 60);
      expect(value('tan⁻¹(1)'), 45);
      expect(value('cos⁻¹(−1)'), 180);
      expect(calc('sin⁻¹(0.3)'), '17.45760312');
    });
    test('inverse sin/cos outside [−1, 1] is a Math ERROR', () {
      expect(calc('sin⁻¹(1.5)'), mathError);
      expect(calc('cos⁻¹(−2)'), mathError);
    });
  });

  group('trigonometry, RAD', () {
    test('multiples of π are exact', () {
      expect(value('sin(π)', mode: rad), 0);
      expect(value('cos(π)', mode: rad), -1);
      expect(value('sin(π÷6)', mode: rad), 0.5);
      expect(value('cos(π÷2)', mode: rad), 0);
      expect(calc('tan(π÷2)', mode: rad), mathError);
    });
    test('ordinary radians', () {
      expect(calc('sin(1)', mode: rad), '0.8414709848');
      expect(calc('cos(2)', mode: rad), '−0.4161468365');
      // 30 in RAD is 30 radians, not degrees.
      expect(calc('sin30', mode: rad), '−0.9880316241');
    });
    test('inverse trig answers in radians', () {
      expect(calc('sin⁻¹(1)', mode: rad), '1.570796327');
      expect(calc('tan⁻¹(1)', mode: rad), '0.7853981634');
      expect(calc('cos⁻¹(1.1)', mode: rad), mathError);
    });
  });

  group('logs and exponentials', () {
    test('log and ln', () {
      expect(value('log(1000)'), 3);
      expect(calc('log(2)'), '0.3010299957');
      expect(value('ln(e)'), 1);
      expect(calc('ln(2)'), '0.6931471806');
    });
    test('10ˣ and eˣ', () {
      expect(calc('10^(3)'), '1000');
      expect(calc('e^(1)'), '2.718281828');
      expect(calc('e^(0)'), '1');
      expect(calc('2e^(0)'), '2');
    });
    test('log of zero or a negative is a Math ERROR', () {
      expect(calc('log(0)'), mathError);
      expect(calc('log(−5)'), mathError);
      expect(calc('ln(0)'), mathError);
      expect(calc('ln(−1)'), mathError);
    });
  });

  group('roots', () {
    test('square and cube roots', () {
      expect(calc('√(16)'), '4');
      expect(calc('√(2)'), '1.414213562');
      expect(value('∛(27)'), 3);
      expect(value('∛(−8)'), -2);
      expect(calc('∛(2)'), '1.25992105');
    });
    test('√ of a negative is a Math ERROR', () {
      expect(calc('√(−4)'), mathError);
    });
  });

  group('factorial, nCr, nPr', () {
    test('factorials', () {
      expect(calc('0!'), '1');
      expect(calc('5!'), '120');
      expect(calc('10!'), '3628800');
      expect(calc('69!'), '1.711224524×10⁹⁸');
      // 3.0000000000000004 in doubles, but a whole number to the display.
      expect(calc('((0.1+0.2)×10)!'), '6');
    });
    test('factorial domain', () {
      expect(calc('70!'), mathError);
      expect(calc('2.5!'), mathError);
      expect(calc('(−3)!'), mathError);
    });
    test('combinations and permutations', () {
      expect(calc('5C2'), '10');
      expect(calc('10C0'), '1');
      expect(calc('52C5'), '2598960');
      expect(calc('5P2'), '20');
      expect(calc('10P10'), '3628800');
      expect(calc('2×5C2'), '20'); // nCr before ×
      expect(calc('5C2+1'), '11');
    });
    test('nCr/nPr domain', () {
      expect(calc('2C5'), mathError);
      expect(calc('5C2.5'), mathError);
      expect(calc('(−5)C2'), mathError);
      expect(calc('3P4'), mathError);
    });
  });

  group('percent, constants', () {
    test('% divides by 100', () {
      expect(calc('50%'), '0.5');
      expect(calc('200×15%'), '30');
    });
    test('π and e', () {
      expect(calc('π'), '3.141592654');
      expect(calc('e'), '2.718281828');
    });
  });

  group('math errors', () {
    test('division by zero and 0⁻¹', () {
      expect(calc('5÷0'), mathError);
      expect(calc('0⁻¹'), mathError);
      expect(calc('1÷(2−2)'), mathError);
    });
    test('0 to a non-positive power, negative base to a fraction', () {
      expect(calc('0^(0)'), mathError);
      expect(calc('0^(−1)'), mathError);
      expect(calc('(−8)^(0.5)'), mathError);
    });
    test('overflow past 10¹⁰⁰', () {
      expect(calc('10^(100)'), mathError);
      expect(calc('10^(99)×10'), mathError);
      expect(calc('9.9×10^(99)'), '9.9×10⁹⁹');
    });
    test('syntax is checked before maths', () {
      expect(calc('1÷0+'), syntaxError);
    });
  });

  group('syntax errors', () {
    test('malformed input', () {
      expect(calc(''), syntaxError);
      expect(calc('2+'), syntaxError);
      expect(calc('×3'), syntaxError);
      expect(calc('1.2.3'), syntaxError);
      expect(calc('.'), syntaxError);
      expect(calc('2#3'), syntaxError);
      expect(calc('²'), syntaxError);
    });
    test('never throws, whatever the input', () {
      for (final s in ['((((', '))', 'sin', '^^', 'CP', '−', 'Ans(', '!!!']) {
        expect(evaluate(s), isA<CalcResult>());
      }
    });
  });

  group('display formatting', () {
    test('ten significant digits, trailing zeros trimmed', () {
      expect(formatNumber(1 / 3), '0.3333333333');
      expect(formatNumber(2 / 3), '0.6666666667');
      expect(formatNumber(2.50), '2.5');
      expect(formatNumber(1234.5678901234), '1234.56789');
      expect(formatNumber(-0.125), '−0.125');
      expect(formatNumber(0), '0');
      expect(formatNumber(-0.0), '0');
    });
    test('floating noise disappears', () {
      expect(calc('0.1+0.2'), '0.3');
      expect(value('0.1+0.2'), 0.3); // stored to 15 digits
    });
    test('scientific notation at 10¹⁰ and above', () {
      expect(formatNumber(9999999999), '9999999999');
      expect(formatNumber(1e10), '1×10¹⁰');
      expect(formatNumber(123456789012), '1.23456789×10¹¹');
      // Rounding to ten digits can carry into the next power.
      expect(formatNumber(9999999999.6), '1×10¹⁰');
    });
    test('scientific notation below 10⁻⁹', () {
      expect(formatNumber(1e-9), '0.000000001');
      expect(formatNumber(1.5e-10), '1.5×10⁻¹⁰');
      expect(formatNumber(-2.5e-12), '−2.5×10⁻¹²');
    });
  });

  group('fraction display (S⇔D)', () {
    test('simple rationals', () {
      expect(formatFraction(0.5), '1/2');
      expect(formatFraction(1 / 3), '1/3');
      expect(formatFraction(0.75), '3/4');
      expect(formatFraction(7 / 6), '7/6');
      expect(formatFraction(-1 / 3), '−1/3');
      expect(formatFraction(value('0.1+0.2')), '3/10');
    });
    test('largest denominators', () {
      expect(formatFraction(1 / 9973), '1/9973');
      expect(formatFraction(1 / 10007), isNull); // denominator > 10000
    });
    test('irrationals and whole numbers stay decimal', () {
      expect(formatFraction(3.141592654), isNull);
      expect(formatFraction(1.414213562), isNull);
      expect(formatFraction(4), isNull);
      expect(formatFraction(0), isNull);
    });
  });

  group('keys: Ans, memory, SHIFT, S⇔D', () {
    test('= stores Ans; an operator after = continues from Ans', () {
      var s = keys([CalcKey.d3, CalcKey.add, CalcKey.d4, CalcKey.equals]);
      expect(s.resultText, '7');
      expect(s.ans, 7);
      s = keys([CalcKey.multiply, CalcKey.d2, CalcKey.equals], s);
      expect(s.expression, 'Ans×2');
      expect(s.resultText, '14');
      // A digit after = starts afresh.
      s = keys([CalcKey.d5, CalcKey.equals], s);
      expect(s.expression, '5');
    });
    test('repeated = re-evaluates, iterating on Ans', () {
      var s = keys([CalcKey.d1, CalcKey.equals]);
      s = keys([CalcKey.add, CalcKey.d1, CalcKey.equals, CalcKey.equals], s);
      expect(s.resultText, '3');
    });
    test('an error leaves Ans untouched', () {
      var s = keys([CalcKey.d9, CalcKey.equals]);
      s = keys([CalcKey.d1, CalcKey.divide, CalcKey.d0, CalcKey.equals], s);
      expect(s.resultText, mathError);
      expect(s.ans, 9);
    });
    test('M+, M−, MR, MC', () {
      var s = keys([CalcKey.d5, CalcKey.memoryPlus]);
      expect(s.memory, 5);
      expect(s.resultText, '5');
      s = keys([CalcKey.d2, CalcKey.shift, CalcKey.memoryPlus], s);
      expect(s.memory, 3);
      s = keys([
        CalcKey.memoryRecall,
        CalcKey.multiply,
        CalcKey.d2,
        CalcKey.equals,
      ], s);
      expect(s.resultText, '6');
      expect(s.hasMemory, isTrue);
      s = keys([CalcKey.memoryClear], s);
      expect(s.memory, 0);
      expect(s.hasMemory, isFalse);
    });
    test('SHIFT applies to one key only', () {
      final s = keys([CalcKey.shift, CalcKey.sin, CalcKey.sin]);
      expect(s.expression, 'sin⁻¹(sin(');
      expect(s.shift, isFalse);
    });
    test('SHIFT variants enter their tokens', () {
      final s = keys([
        CalcKey.shift, CalcKey.log, CalcKey.d2, CalcKey.close, //
        CalcKey.add, CalcKey.shift, CalcKey.sqrt, CalcKey.d8, CalcKey.close,
        CalcKey.add, CalcKey.d2, CalcKey.shift, CalcKey.square,
        CalcKey.add, CalcKey.d4, CalcKey.shift, CalcKey.nCr, CalcKey.d2,
        CalcKey.add, CalcKey.shift, CalcKey.pi,
      ]);
      expect(s.expression, '10^(2)+∛(8)+2³+4P2+e');
      expect(keys([CalcKey.equals], s).resultText, '124.7182818');
    });
    test('10ˣ after a digit multiplies rather than joining digits', () {
      final s = keys([CalcKey.d2, CalcKey.shift, CalcKey.log, CalcKey.d3]);
      expect(s.expression, '2×10^(3');
      expect(keys([CalcKey.equals], s).resultText, '2000');
    });
    test('DEL removes a whole function, AC keeps Ans and memory', () {
      var s = keys([CalcKey.d2, CalcKey.sin, CalcKey.delete]);
      expect(s.expression, '2');
      s = keys([CalcKey.equals, CalcKey.memoryPlus, CalcKey.clear], s);
      expect(s.expression, '');
      expect(s.resultText, '');
      expect(s.ans, 2);
      expect(s.memory, 2);
    });
    test('DEL after an error returns to the expression', () {
      var s = keys([CalcKey.d1, CalcKey.divide, CalcKey.d0, CalcKey.equals]);
      s = keys([CalcKey.delete], s);
      expect(s.resultText, '');
      expect(s.expression, '1÷0');
    });
    test('DRG switches DEG and RAD', () {
      var s = keys([CalcKey.angle]);
      expect(s.angleMode, AngleMode.rad);
      s = keys([CalcKey.sin, CalcKey.pi, CalcKey.equals], s);
      expect(s.resultText, '0');
      s = keys([CalcKey.angle], s);
      expect(s.angleMode, AngleMode.deg);
    });
    test('S⇔D toggles a fraction, and does nothing for an irrational', () {
      var s = keys([CalcKey.d1, CalcKey.divide, CalcKey.d3, CalcKey.equals]);
      expect(s.resultText, '0.3333333333');
      s = keys([CalcKey.fraction], s);
      expect(s.resultText, '1/3');
      s = keys([CalcKey.fraction], s);
      expect(s.resultText, '0.3333333333');
      s = keys([CalcKey.sqrt, CalcKey.d2, CalcKey.equals, CalcKey.fraction], s);
      expect(s.resultText, '1.414213562');
      expect(s.showFraction, isFalse);
    });
    test('= on an empty expression does nothing', () {
      expect(keys([CalcKey.equals]).result, isNull);
    });
  });

  // ── Control group ──────────────────────────────────────────────────────
  // Worked examples from the Casio fx-82 series user guides (fx-82MS / fx-82ES
  // PLUS). These are the calculator the engine imitates; if any of these
  // fails, the engine has drifted from the real thing. Each expected value was
  // also checked independently against the mathematics.
  group('control: Casio fx-82 user guide examples', () {
    test('Basic Calculations: priority and negative numbers', () {
      // fx-82MS, "Basic Calculations": 2 × (5 + 4) − 2 × (−3) = 24
      expect(calc('2×(5+4)−2×(−3)'), '24');
      // fx-82ES PLUS, "Calculation Priority Sequence": −2² = −4, (−2)² = 4
      expect(calc('−2²'), '−4');
      expect(calc('(−2)²'), '4');
      // fx-82MS, "Basic Calculations": 1 ÷ (1/3 − 1/4)… as x⁻¹: (3⁻¹ − 4⁻¹)⁻¹ = 12
      expect(calc('(3⁻¹−4⁻¹)⁻¹'), '12');
    });
    test('Answer Memory', () {
      // fx-82MS, "Answer Memory": 123 + 456 = 579, then 789 − Ans = 210
      var s = keys([
        CalcKey.d1, CalcKey.d2, CalcKey.d3, CalcKey.add, //
        CalcKey.d4, CalcKey.d5, CalcKey.d6, CalcKey.equals,
      ]);
      expect(s.resultText, '579');
      s = keys([
        CalcKey.d7, CalcKey.d8, CalcKey.d9, CalcKey.subtract, CalcKey.ans, //
        CalcKey.equals,
      ], s);
      expect(s.resultText, '210');
    });
    test('Independent Memory', () {
      // fx-82MS, "Independent Memory": 23 + 9 M+, 53 − 6 M+, 45 × 2 M−,
      // RCL M = −11
      var s = keys([
        CalcKey.d2, CalcKey.d3, CalcKey.add, CalcKey.d9, CalcKey.memoryPlus, //
        CalcKey.d5, CalcKey.d3, CalcKey.subtract, CalcKey.d6,
        CalcKey.memoryPlus,
        CalcKey.d4, CalcKey.d5, CalcKey.multiply, CalcKey.d2, CalcKey.shift,
        CalcKey.memoryPlus,
      ]);
      expect(s.resultText, '90');
      s = keys([CalcKey.memoryRecall, CalcKey.equals], s);
      expect(s.resultText, '−11');
    });
    test('Percentage Calculations', () {
      // fx-82MS, "Percentage": 12% of 1500 = 180; 660 as a % of 880 = 75
      expect(calc('1500×12%'), '180');
      expect(calc('660÷880%'), '75');
    });
    test('Trigonometric and inverse trigonometric functions', () {
      // fx-82MS, "Trigonometric / Inverse Trigonometric Functions":
      // sin 63°52'41" skipped (no DMS key); sin 30° = 0.5;
      // cos(π/3 rad) = 0.5; sin⁻¹ 0.5 = 30°; cos⁻¹(√2/2) = 0.785398163 rad
      expect(calc('sin30'), '0.5');
      expect(calc('cos(π÷3)', mode: rad), '0.5');
      expect(calc('sin⁻¹(0.5)'), '30');
      expect(calc('cos⁻¹(√(2)÷2)', mode: rad), '0.7853981634');
      // tan⁻¹ 0.741 = 36.53844577°
      expect(calc('tan⁻¹(0.741)'), '36.53844577');
    });
    test('Logarithms and antilogarithms', () {
      // fx-82MS, "Logarithms and Antilogarithms": log 1.23 = 0.089905111,
      // ln 90 = 4.49980967, ln e = 1, 10^1.23 = 16.98243652,
      // e^4.5 = 90.0171313, (−3)^4 = 81, −3^4 = −81
      expect(calc('log(1.23)'), '0.08990511144');
      expect(calc('ln(90)'), '4.49980967');
      expect(calc('ln(e)'), '1');
      expect(calc('10^(1.23)'), '16.98243652');
      expect(calc('e^(4.5)'), '90.0171313');
      expect(calc('(−3)^(4)'), '81');
      expect(calc('−3^(4)'), '−81');
    });
    test(
      'Square roots, cube roots, squares, cubes, reciprocals, factorials',
      () {
        // fx-82MS, "Square Roots, Cube Roots, …": √2 + √3 × √5 = 5.287196909,
        // ∛5 + ∛−27 = −1.290024053, 123 + 30² = 1023, 12³ = 1728,
        // 1/(1/3 − 1/4) = 12, 8! = 40320
        expect(calc('√(2)+√(3)×√(5)'), '5.287196909');
        expect(calc('∛(5)+∛(−27)'), '−1.290024053');
        expect(calc('123+30²'), '1023');
        expect(calc('12³'), '1728');
        expect(calc('1÷(1÷3−1÷4)'), '12');
        expect(calc('8!'), '40320');
      },
    );
    test('Permutation and combination', () {
      // fx-82MS, "Permutation / Combination": 7P4 = 840 (four-digit values
      // from 1–7), 10C4 = 210 (four-member groups from ten people)
      expect(calc('7P4'), '840');
      expect(calc('10C4'), '210');
    });
    test('Fractions', () {
      // fx-82ES PLUS, "Fraction Calculations": 2/3 + 1/2 = 7/6,
      // 4 − 3½ = 1/2
      expect(formatFraction(value('2÷3+1÷2')), '7/6');
      expect(formatFraction(value('4−(3+1÷2)')), '1/2');
    });
  });
}
