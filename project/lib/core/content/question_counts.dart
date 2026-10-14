/// How many questions a topic, module, course or subject has, said
/// honestly: past questions from real papers apart from Paragon's own
/// practice questions, never summed into one big number that reads as
/// "this many past questions".
///
/// The split comes from `pastQuestionCount` / `practiceQuestionCount`,
/// written nightly by `tools/admin/jobs.js --job=counts`. Both zero means
/// "not known yet" (a document from before the job first ran), and the
/// older single [total] is shown instead.
class QuestionCounts {
  const QuestionCounts({this.past = 0, this.practice = 0, this.total = 0});

  final int past;
  final int practice;

  /// The legacy unsplit count, for documents the job has not reached.
  final int total;

  bool get isSplit => past > 0 || practice > 0;

  /// What a student can practise: the split sum once known.
  int get servable => isSplit ? past + practice : total;

  QuestionCounts operator +(QuestionCounts o) => QuestionCounts(
    past: past + o.past,
    practice: practice + o.practice,
    total: total + o.total,
  );

  /// "48 past · 300 practice", "300 practice questions",
  /// "48 past questions", or "1,234 questions" while unsplit. Empty when
  /// there is nothing to show.
  String get label {
    if (!isSplit) {
      return total > 0 ? '${groupThousands(total)} questions' : '';
    }
    if (past == 0) return '${groupThousands(practice)} practice questions';
    if (practice == 0) return '${groupThousands(past)} past questions';
    return '${groupThousands(past)} past · ${groupThousands(practice)} practice';
  }
}

/// 14602 -> "14,602".
String groupThousands(int n) =>
    n.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
