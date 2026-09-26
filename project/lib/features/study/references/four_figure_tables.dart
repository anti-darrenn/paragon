import 'four_figure_math.dart';

/// One printed four-figure table, as rows of strings ready to lay out.
/// Built entirely from `four_figure_math.dart`.
class FigureTable {
  const FigureTable({
    required this.title,
    required this.note,
    required this.rowLabels,
    required this.columnLabels,
    required this.meanDifferenceLabels,
    required this.cells,
    required this.meanDifferences,
    required this.lookupHint,
    required this.lookup,
  });

  final String title;
  final String note;
  final List<String> rowLabels;
  final List<String> columnLabels;
  final List<String> meanDifferenceLabels;

  /// `cells[row][column]`.
  final List<List<String>> cells;

  /// `meanDifferences[row][k - 1]`; a two-line string for rows with a
  /// separate set per half row, empty where the table prints none.
  final List<List<String>> meanDifferences;

  final String lookupHint;

  /// Parses what the student typed and looks it up; null if it cannot be.
  final TableLookup? Function(String input) lookup;
}

double? _parseNumber(String input) =>
    double.tryParse(input.trim().replaceAll(',', '').replaceAll(' ', ''));

/// Accepts "37.25", "37 15", "37°15'", "37° 15′": degrees, then optional
/// minutes.
double? parseAngle(String input) {
  final nums = RegExp(
    r'\d+(?:\.\d+)?',
  ).allMatches(input).map((m) => double.parse(m.group(0)!)).toList();
  if (nums.isEmpty || nums.length > 2) return null;
  if (nums.length == 2) {
    if (nums[1] >= 60) return null;
    return nums[0] + nums[1] / 60;
  }
  return nums[0];
}

FigureTable buildLogTable() {
  final rows = [for (var r = 10; r <= 99; r++) r];
  return FigureTable(
    title: 'Log',
    note:
        'Logarithms to base 10: the mantissa of log x for x from 1.000 to '
        '9.999. Read the first two figures down the side, the third across '
        'the top, and add the mean difference for the fourth. Rows 10–19 '
        'have two sets of differences: the upper for columns 0–4, the lower '
        'for 5–9.',
    rowLabels: [for (final r in rows) '$r'],
    columnLabels: [for (var c = 0; c <= 9; c++) '$c'],
    meanDifferenceLabels: [for (var k = 1; k <= 9; k++) '$k'],
    cells: [
      for (final r in rows)
        [for (var c = 0; c <= 9; c++) fourDigits(logEntry(r * 10 + c))],
    ],
    meanDifferences: [
      for (final r in rows)
        [
          for (var k = 1; k <= 9; k++)
            r < 20
                ? '${logMeanDifference(r, 0, k)}\n${logMeanDifference(r, 5, k)}'
                : '${logMeanDifference(r, 0, k)}',
        ],
    ],
    lookupHint: 'A number, e.g. 2, 7.5 or 0.0234',
    lookup: (s) {
      final x = _parseNumber(s);
      return x == null ? null : lookupLog(x);
    },
  );
}

FigureTable buildAntilogTable() {
  final rows = [for (var r = 0; r <= 99; r++) r];
  return FigureTable(
    title: 'Antilog',
    note:
        'Antilogarithms: 10 to the power of .0000 to .9999, to four '
        'significant figures. Place the decimal point from the '
        'characteristic.',
    rowLabels: [for (final r in rows) '.${r.toString().padLeft(2, '0')}'],
    columnLabels: [for (var c = 0; c <= 9; c++) '$c'],
    meanDifferenceLabels: [for (var k = 1; k <= 9; k++) '$k'],
    cells: [
      for (final r in rows)
        [for (var c = 0; c <= 9; c++) fourDigits(antilogEntry(r * 10 + c))],
    ],
    meanDifferences: [
      for (final r in rows)
        [for (var k = 1; k <= 9; k++) '${antilogMeanDifference(r, k)}'],
    ],
    lookupHint: 'A logarithm, e.g. 0.3010 or 2.4771',
    lookup: (s) {
      final y = _parseNumber(s);
      return y == null ? null : lookupAntilog(y);
    },
  );
}

FigureTable buildTrigTable(TrigRatio ratio) {
  final degrees = [for (var d = 0; d <= 89; d++) d];
  final name = switch (ratio) {
    TrigRatio.sine => 'Sine',
    TrigRatio.cosine => 'Cosine',
    TrigRatio.tangent => 'Tangent',
  };
  final note = switch (ratio) {
    TrigRatio.sine =>
      'Natural sines, 0° to 89.9° in steps of 6′ (0.1°). Add the mean '
          'difference for the remaining minutes.',
    TrigRatio.cosine =>
      'Natural cosines, 0° to 89.9° in steps of 6′ (0.1°). Cosines fall as '
          'the angle rises: SUBTRACT the mean difference.',
    TrigRatio.tangent =>
      'Natural tangents, 0° to 89.9° in steps of 6′ (0.1°). Add the mean '
          'difference. Tangents of 10 and over are printed to four '
          'significant figures, and from $kTangentSigFigFrom° there are no '
          'mean differences; the look-up computes those directly.',
  };
  return FigureTable(
    title: name,
    note: note,
    rowLabels: [for (final d in degrees) '$d°'],
    columnLabels: [for (var c = 0; c <= 9; c++) '${c * 6}′'],
    meanDifferenceLabels: [for (var k = 1; k <= 5; k++) '$k′'],
    cells: [
      for (final d in degrees)
        [for (var c = 0; c <= 9; c++) trigCell(ratio, d * 10 + c)],
    ],
    meanDifferences: [
      for (final d in degrees)
        [
          for (var k = 1; k <= 5; k++)
            trigMeanDifference(ratio, d, k)?.toString() ?? '',
        ],
    ],
    lookupHint: 'An angle in degrees, e.g. 30, 37.25 or 37 15',
    lookup: (s) {
      final a = parseAngle(s);
      return a == null ? null : lookupTrig(ratio, a);
    },
  );
}

List<FigureTable> buildFourFigureTables() => [
  buildLogTable(),
  buildAntilogTable(),
  buildTrigTable(TrigRatio.sine),
  buildTrigTable(TrigRatio.cosine),
  buildTrigTable(TrigRatio.tangent),
];
