/// The mistakes notebook, as pure logic.
///
/// A question is in the notebook when the student's **most recent** answer
/// to it was wrong. Nothing is stored for this: answering it correctly
/// later — in the notebook's own practice, in drill, anywhere — takes it
/// out, because that later attempt becomes the most recent one.
/// `attempts` stays append-only.
///
/// "Most recent" is within a window of the student's latest answers
/// ([kMistakesWindow]), since reading every attempt ever made would cost
/// a read per attempt on every visit. The screen says so.
library;

/// How many of a student's latest answers the notebook looks at.
const int kMistakesWindow = 200;

/// The fields of one `attempts` document the notebook needs.
class AttemptRecord {
  const AttemptRecord({
    required this.questionId,
    required this.topicId,
    required this.subjectId,
    required this.selectedIndex,
    required this.isCorrect,
    required this.source,
    this.at,
  });

  final String questionId;
  final String topicId;
  final String subjectId;
  final int selectedIndex;
  final bool isCorrect;

  /// `drill`, `waec`, `test`, `exercise` or `review`.
  final String source;

  /// Null for a write whose server timestamp has not come back yet.
  final DateTime? at;
}

/// A question whose latest answer was wrong, and what that answer was.
class Mistake {
  const Mistake(this.latest);

  final AttemptRecord latest;

  String get questionId => latest.questionId;
  String get subjectId => latest.subjectId;
  int get selectedIndex => latest.selectedIndex;
}

/// The open mistakes in [newestFirst], newest first.
///
/// [newestFirst] must be ordered newest first — the order the query
/// returns. The first attempt seen for a question is its latest; any
/// older one, right or wrong, is history.
List<Mistake> openMistakes(Iterable<AttemptRecord> newestFirst) {
  final seen = <String>{};
  final open = <Mistake>[];
  for (final a in newestFirst) {
    if (a.questionId.isEmpty || !seen.add(a.questionId)) continue;
    if (!a.isCorrect) open.add(Mistake(a));
  }
  return open;
}

/// How a notebook entry says where the mistake was made.
String mistakeSourceLabel(String source) => switch (source) {
  'drill' => 'Practice',
  'waec' => 'WAEC exam',
  'test' => 'Topic test',
  'exercise' => 'Lesson exercise',
  'review' => 'Mistakes practice',
  _ => 'Practice',
};
