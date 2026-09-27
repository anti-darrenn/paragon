/// An *estimated* WAEC grade from an objective-paper score.
///
/// The bands are the ones schools commonly quote (A1 from 75%, down to F9
/// below 40%). They are **not official**: WAEC does not publish its cut-offs
/// and scales results itself, and the real grade also includes Paper 2
/// (theory), which Paragon does not test. Every place this is shown must
/// say "estimate" and "objective questions only" — never present it as a
/// predicted result.
library;

class WaecGrade {
  const WaecGrade(this.code, this.label, this.minPercent);

  /// `A1` … `F9`.
  final String code;

  /// `Excellent`, `Credit`, …
  final String label;

  /// The lowest whole percentage in this band.
  final int minPercent;

  /// C6 or better: a credit, what most admissions ask for.
  bool get isCredit => minPercent >= 50;
}

/// Highest band first.
const List<WaecGrade> kWaecGrades = [
  WaecGrade('A1', 'Excellent', 75),
  WaecGrade('B2', 'Very good', 70),
  WaecGrade('B3', 'Good', 65),
  WaecGrade('C4', 'Credit', 60),
  WaecGrade('C5', 'Credit', 55),
  WaecGrade('C6', 'Credit', 50),
  WaecGrade('D7', 'Pass', 45),
  WaecGrade('E8', 'Pass', 40),
  WaecGrade('F9', 'Fail', 0),
];

/// The band for [percent] (0–100, fractions allowed and floored).
WaecGrade waecGradeFor(num percent) {
  final p = percent.isNaN ? 0 : percent.floor().clamp(0, 100);
  return kWaecGrades.firstWhere((g) => p >= g.minPercent);
}

/// The rolling estimate: the mean percentage of the latest [take] exams,
/// or null with none. [percents] is newest first.
double? rollingPercent(List<double> percents, {int take = 3}) {
  final recent = percents.take(take).toList();
  if (recent.isEmpty) return null;
  return recent.reduce((a, b) => a + b) / recent.length;
}

/// The words that go with any grade shown to a student.
const String kGradeEstimateNote =
    'An estimate from objective questions only. Your real grade also '
    'includes the theory paper, and WAEC sets its own grade boundaries.';
