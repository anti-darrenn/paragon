/// The objective paper of each WASSCE subject, for the "Full paper" preset
/// on the exam setup screen (PLAN.md P5.2.1).
///
/// Checked 2026-10-16: question counts against each WAEC syllabus, times
/// against WAEC's own May/June 2026 timetables (school and private
/// candidates agree). A row that has not been checked leaves [verified]
/// false, and the setup screen then says "approximately".
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
  'mathematics': ExamFormat(questions: 50, minutes: 90, verified: true),
  'further mathematics': ExamFormat(questions: 40, minutes: 90, verified: true),
  'physics': ExamFormat(questions: 50, minutes: 75, verified: true),
  'chemistry': ExamFormat(questions: 50, minutes: 60, verified: true),
  'biology': ExamFormat(questions: 50, minutes: 50, verified: true),
  'government': ExamFormat(questions: 50, minutes: 60, verified: true),
  'economics': ExamFormat(questions: 50, minutes: 60, verified: true),
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
