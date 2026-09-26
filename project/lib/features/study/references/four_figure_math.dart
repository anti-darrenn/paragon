/// Four-figure tables, computed.
///
/// **Nothing here is typed in.** Every entry is computed with `dart:math`
/// and rounded the way printed tables are: log mantissas and natural
/// trigonometric ratios to 4 decimal places, antilogarithms to 4
/// significant figures. Mean differences are then computed *from the
/// rounded table itself*, as printed tables do:
///
/// * logarithms and antilogarithms: the difference between the start of
///   this row and the start of the next, spread over the row's 100 steps of
///   the fourth figure — `md(k) = round(k × rowDiff / 100)`. Rows 10–19 of
///   the log table change too fast for one set, so, as in printed tables,
///   they carry two: one for columns 0–4 and one for 5–9, each spread over
///   its half row (`round(k × halfDiff / 50)`);
/// * sines, cosines, tangents: the difference between this degree and the
///   next, per minute of arc — `md(k′) = round(k × degreeDiff / 60)`.
///   Cosine differences are subtracted. Tangents of 10 and over (from
///   84.3°) are printed to four significant figures, and tangent mean
///   differences stop at the 84° row, where the next degree's tangent
///   passes 10 and a linear correction is no longer accurate.
///
/// A mean difference is an approximation by design: the answer the table
/// method gives can differ from the true value in the last figure, exactly
/// as it does with the printed book.
library;

import 'dart:math' as math;

// ── Entries ──────────────────────────────────────────────────────────────

/// log₁₀ of [n3]/100 for n3 in 100..1000, as an integer number of units in
/// the fourth decimal place (log 2.00 → 3010; log 10.00 → 10000).
int logEntry(int n3) {
  assert(n3 >= 100 && n3 <= 1000);
  return (math.log(n3 / 100) / math.ln10 * 10000).round();
}

/// 10^(x3/1000) for x3 in 0..1000, as an integer to 4 significant figures
/// in units of 0.001 (antilog 0.301 → 2000, i.e. 2.000; antilog 1 → 10000).
int antilogEntry(int x3) {
  assert(x3 >= 0 && x3 <= 1000);
  return (math.pow(10, x3 / 1000) * 1000).round();
}

double _rad(num degrees) => degrees * math.pi / 180;

/// Which trigonometric ratio a table holds.
enum TrigRatio { sine, cosine, tangent }

/// The ratio at [tenths] tenths of a degree (0..900; 6′ = 0.1°), in units
/// of 0.0001. Tangents of 90° have no value and return null.
int? trigEntry(TrigRatio ratio, int tenths) {
  assert(tenths >= 0 && tenths <= 900);
  final a = _rad(tenths / 10);
  switch (ratio) {
    case TrigRatio.sine:
      return (math.sin(a) * 10000).round();
    case TrigRatio.cosine:
      return (math.cos(a) * 10000).round();
    case TrigRatio.tangent:
      if (tenths == 900) return null;
      return (math.tan(a) * 10000).round();
  }
}

/// The exact (unrounded) tangent, for the four-significant-figure part of
/// the tangent table.
double tangentValue(int tenths) => math.tan(_rad(tenths / 10));

// ── Mean differences ─────────────────────────────────────────────────────

/// The log table's mean difference for fourth figure [k] (1..9) in row
/// [row] (10..99), at [column] (0..9) — the column matters only for rows
/// 10–19, which carry separate differences for each half row.
int logMeanDifference(int row, int column, int k) {
  if (row < 20) {
    final second = column >= 5;
    final from = logEntry(row * 10 + (second ? 5 : 0));
    final to = logEntry(second ? row * 10 + 10 : row * 10 + 5);
    return (k * (to - from) / 50).round();
  }
  final diff = logEntry(row * 10 + 10) - logEntry(row * 10);
  return (k * diff / 100).round();
}

/// The antilog table's mean difference for fourth figure [k] (1..9) in row
/// [row] (0..99, i.e. .00 to .99).
int antilogMeanDifference(int row, int k) {
  final diff = antilogEntry(row * 10 + 10) - antilogEntry(row * 10);
  return (k * diff / 100).round();
}

/// The first degree row whose tangents carry no mean differences.
const int kTangentSigFigFrom = 84;

/// The magnitude of a trig table's mean difference for [k] minutes (1..5)
/// in the row for [degree] (0..89). Null where the table prints none
/// (tangents from [kTangentSigFigFrom]°).
int? trigMeanDifference(TrigRatio ratio, int degree, int k) {
  if (ratio == TrigRatio.tangent && degree >= kTangentSigFigFrom) return null;
  final from = trigEntry(ratio, degree * 10)!;
  final to = trigEntry(ratio, degree * 10 + 10)!;
  return (k * (to - from).abs() / 60).round();
}

// ── Formatting ───────────────────────────────────────────────────────────

/// A 4-digit table entry as printed: 3010, 0043.
String fourDigits(int v) => v.toString().padLeft(4, '0');

/// A value in units of 0.0001 as a decimal: 5000 → 0.5000.
String fourDp(int units) {
  final neg = units < 0;
  final a = units.abs();
  final s = '${a ~/ 10000}.${fourDigits(a % 10000)}';
  return neg ? '-$s' : s;
}

/// [x] to four significant figures, e.g. 11.43, 573.0.
String fourSigFigs(double x) {
  if (x == 0) return '0.000';
  final digits = (math.log(x.abs()) / math.ln10).floor() + 1;
  final decimals = (4 - digits).clamp(0, 20);
  return x.toStringAsFixed(decimals);
}

/// How the trig tables print an entry: four decimal places, except
/// tangents of 10 and over, which print four significant figures.
String trigCell(TrigRatio ratio, int tenths) {
  if (ratio == TrigRatio.tangent && tangentValue(tenths) >= 10) {
    return fourSigFigs(tangentValue(tenths));
  }
  return fourDp(trigEntry(ratio, tenths)!);
}

// ── Look-up: what a student does with the book ──────────────────────────

/// Where a look-up lands in a table, and what the table method gives.
class TableLookup {
  const TableLookup({
    required this.row,
    required this.column,
    required this.meanDifferenceColumn,
    required this.answer,
    required this.latex,
  });

  /// Row index into the table's rows (0-based).
  final int row;

  /// Main column, 0..9.
  final int column;

  /// Mean-difference column (1..9 for logs, 1..5 for trig), or 0 for none.
  final int meanDifferenceColumn;

  /// The table-method result, as the student would write it.
  final String answer;

  /// The sum as LaTeX, for display through FullLatexView.
  final String latex;
}

/// Looks up log₁₀ [x] (x > 0) with the table: four significant figures of
/// x, the entry at its first three, plus the mean difference for its
/// fourth. Returns null for x ≤ 0 or non-finite input.
TableLookup? lookupLog(double x) {
  if (!x.isFinite || x <= 0) return null;
  var n = (math.log(x) / math.ln10).floor();
  var s = (x / math.pow(10, n) * 1000).round();
  // Floating point can put x/10^n a hair either side of [1, 10).
  if (s >= 10000) {
    n += 1;
    s = (x / math.pow(10, n) * 1000).round();
  } else if (s < 1000) {
    n -= 1;
    s = (x / math.pow(10, n) * 1000).round();
  }
  final row = s ~/ 100;
  final col = (s ~/ 10) % 10;
  final k = s % 10;
  var mantissa =
      logEntry(s ~/ 10) + (k == 0 ? 0 : logMeanDifference(row, col, k));
  var characteristic = n;
  if (mantissa >= 10000) {
    mantissa -= 10000;
    characteristic += 1;
  }
  final m = fourDigits(mantissa);
  // A negative characteristic is written with a bar: 2̄.3692 = −2 + 0.3692.
  final answer = characteristic >= 0
      ? '$characteristic.$m'
      : '${-characteristic}̄.$m';
  final shown = characteristic >= 0 ? answer : '\\bar{${-characteristic}}.$m';
  final sig = _sigFigString(s, n);
  return TableLookup(
    row: row - 10,
    column: col,
    meanDifferenceColumn: k,
    answer: answer,
    latex: '\\(\\log_{10} $sig = $shown\\)',
  );
}

/// Looks up the antilogarithm of [y] (any real; the characteristic is its
/// floor) with the table. Returns null for non-finite input.
TableLookup? lookupAntilog(double y) {
  if (!y.isFinite) return null;
  var n = y.floor();
  var f4 = ((y - n) * 10000).round();
  if (f4 >= 10000) {
    f4 -= 10000;
    n += 1;
  }
  final row = f4 ~/ 100;
  final col = (f4 ~/ 10) % 10;
  final k = f4 % 10;
  var digits =
      antilogEntry(f4 ~/ 10) + (k == 0 ? 0 : antilogMeanDifference(row, k));
  var exp = n;
  if (digits >= 10000) {
    digits = (digits / 10).round();
    exp += 1;
  }
  final value = _sigFigString(digits, exp);
  final shownY = n >= 0
      ? '$n.${fourDigits(f4)}'
      : '\\bar{${-n}}.${fourDigits(f4)}';
  return TableLookup(
    row: row,
    column: col,
    meanDifferenceColumn: k,
    answer: value,
    latex: '\\(\\text{antilog}\\ $shownY = $value\\)',
  );
}

/// Looks up [ratio] of [degrees] (0 ≤ degrees < 90) with the table: the
/// entry at the degree and the 6′ step at or below, then the mean
/// difference for the remaining minutes (added; subtracted for cosines).
/// Minutes are rounded to the nearest whole minute first.
TableLookup? lookupTrig(TrigRatio ratio, double degrees) {
  if (!degrees.isFinite || degrees < 0 || degrees >= 90) return null;
  var deg = degrees.floor();
  var minutes = ((degrees - deg) * 60).round();
  if (minutes == 60) {
    deg += 1;
    minutes = 0;
  }
  if (deg >= 90) return null;
  final col = minutes ~/ 6;
  final k = minutes % 6;
  final tenths = deg * 10 + col;
  final name = switch (ratio) {
    TrigRatio.sine => r'\sin',
    TrigRatio.cosine => r'\cos',
    TrigRatio.tangent => r'\tan',
  };
  final angle = minutes == 0 ? '$deg^\\circ' : "$deg^\\circ\\,$minutes'";
  String value;
  int shownK = k;
  final md = k == 0 ? 0 : trigMeanDifference(ratio, deg, k);
  if (md == null) {
    // No mean differences here: compute the tangent directly, and say
    // nothing about a mean-difference column.
    value = fourSigFigs(math.tan(_rad(deg + minutes / 60)));
    shownK = 0;
  } else if (ratio == TrigRatio.tangent && tenths >= kTangentSigFigFrom * 10) {
    value = trigCell(ratio, tenths);
  } else {
    final base = trigEntry(ratio, tenths)!;
    value = fourDp(ratio == TrigRatio.cosine ? base - md : base + md);
  }
  return TableLookup(
    row: deg,
    column: col,
    meanDifferenceColumn: shownK,
    answer: value,
    latex: '\\($name $angle = $value\\)',
  );
}

/// A number whose four significant figures are [s] (1000..9999) times
/// 10^([n] - 3), written out plainly: (2000, 0) → 2.000, (1234, 2) → 123.4,
/// (1234, -2) → 0.01234.
String _sigFigString(int s, int n) {
  final digits = s.toString();
  if (n >= 3) return digits + '0' * (n - 3);
  if (n >= 0) return '${digits.substring(0, n + 1)}.${digits.substring(n + 1)}';
  return '0.${'0' * (-n - 1)}$digits';
}
