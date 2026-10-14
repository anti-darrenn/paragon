/// The objective paper of each WASSCE subject, for the "Full paper" preset
/// on the exam setup screen (PLAN.md P5.2.1).
///
/// **Not yet confirmed.** These are the commonly published formats of the
/// multiple-choice paper, written down so the preset has something to be.
/// Until the owner checks them against current WAEC papers, [verified] is
/// false and the setup screen says "approximately". Change a row and set
/// `verified: true` when it is checked; nothing else needs to move.
library;

class ExamFormat {
  const ExamFormat({
    required this.questions,
    required this.minutes,
    this.options = 4,
    this.verified = false,
  });

  final int questions;
  final int minutes;
  final int options;
  final bool verified;

  /// "50 questions · 1 h 30 min".
  String get label => '$questions questions · ${formatMinutes(minutes)}';
}

/// By subject name, lower-cased (what both the WAEC list and the catalog
/// share). A subject missing here gets [kDefaultExamFormat].
const Map<String, ExamFormat> kExamFormats = {
  'mathematics': ExamFormat(questions: 50, minutes: 90),
  'further mathematics': ExamFormat(questions: 40, minutes: 90),
  'physics': ExamFormat(questions: 50, minutes: 75),
  'chemistry': ExamFormat(questions: 50, minutes: 60),
  'biology': ExamFormat(questions: 50, minutes: 50),
  'government': ExamFormat(questions: 50, minutes: 60),
  'economics': ExamFormat(questions: 50, minutes: 60),
};

const ExamFormat kDefaultExamFormat = ExamFormat(questions: 50, minutes: 60);

ExamFormat examFormatFor(String subjectName) =>
    kExamFormats[subjectName.trim().toLowerCase()] ?? kDefaultExamFormat;

/// 90 → "1 h 30 min", 60 → "1 h", 45 → "45 min".
String formatMinutes(int minutes) {
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (h == 0) return '$m min';
  if (m == 0) return '$h h';
  return '$h h $m min';
}
