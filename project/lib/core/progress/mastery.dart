/// Mastery: how far a student has got in one topic, and how that rolls up
/// to a module, a subject and a whole course.
///
/// Pure — no Firestore, no widgets — so the rings, the repository and the
/// tests all reason about the same thresholds, in the same way
/// `onboarding_step.dart` is the single source of the funnel's rules.
///
/// **The model is Khan Academy's, deliberately.** Per-topic progress is a
/// small set of named *levels*, not a percentage: a student who has
/// answered 300 of a topic's 300 questions badly is not further along than
/// one who answered 40 of them well, and a percentage would say otherwise.
/// Levels roll up into a percentage only at module and course level, where
/// "how much of this have I got to proficiency" is a real question.
///
/// **Why the thresholds are what they are.** A drill session serves 20
/// questions (`drillQuestionsProvider`), so the levels are built around
/// that unit: one attentive session reaches [MasteryLevel.proficient], and
/// [MasteryLevel.mastered] needs two sessions at near-perfect accuracy.
/// Topics hold 300 generated questions each, so none of this is capped by
/// running out of material.
///
/// **What it is counted from.** Questions answered, cumulatively — not
/// *distinct* questions. Storing the set of question ids a student has
/// seen would mean up to 300 ids per topic across 216 topics on one
/// document, which is the wrong shape and would not survive the free
/// tier. The consequence is honest and worth stating: a student who
/// re-drills the same topic climbs the levels on repeat questions.
/// Accuracy thresholds are what stop that from being free, and nothing of
/// value hangs off the number — see `ProgressRepository`.
library;

enum MasteryLevel {
  notStarted,
  attempted,
  familiar,
  proficient,
  mastered;

  /// Points toward an aggregate percentage. Mirrors Khan's own scheme:
  /// a course is "100% mastered" only when every topic is, and partial
  /// credit accrues level by level rather than all at the end.
  int get points => switch (this) {
    MasteryLevel.notStarted => 0,
    MasteryLevel.attempted => 1,
    MasteryLevel.familiar => 2,
    MasteryLevel.proficient => 3,
    MasteryLevel.mastered => 4,
  };

  static const int maxPoints = 4;

  /// How full the ring is drawn. Discrete, matching the levels — a ring
  /// that crept forward with every answered question would imply a
  /// precision the model does not have.
  double get ringFraction => points / maxPoints;

  String get label => switch (this) {
    MasteryLevel.notStarted => 'Not started',
    MasteryLevel.attempted => 'Attempted',
    MasteryLevel.familiar => 'Familiar',
    MasteryLevel.proficient => 'Proficient',
    MasteryLevel.mastered => 'Mastered',
  };

  bool get isStarted => this != MasteryLevel.notStarted;

  /// Whether to draw the tick rather than an arc. Proficient is included:
  /// it is the point at which a student can stop and be right to, and a
  /// screen full of not-quite-closed rings reads as a screen full of
  /// unfinished work.
  bool get isComplete =>
      this == MasteryLevel.proficient || this == MasteryLevel.mastered;
}

/// One topic's counters. The stored shape, and what the rings read.
class TopicProgress {
  const TopicProgress({
    this.answered = 0,
    this.correct = 0,
    this.subjectId = '',
  });

  /// Questions answered in this topic, cumulative across sessions.
  final int answered;

  /// How many of those were right.
  final int correct;

  /// Which subject the topic belongs to, stamped at write time so the
  /// progress document can be grouped by subject without loading any
  /// course outlines. Empty on entries written before this existed, which
  /// callers must treat as "unknown", never as a subject id that matches
  /// nothing.
  final String subjectId;

  static const TopicProgress none = TopicProgress();

  /// Guards against a stored `correct` larger than `answered` — which no
  /// write path produces, but a hand-edited document could, and it would
  /// otherwise report accuracy above 100%.
  double get accuracy {
    if (answered <= 0) return 0;
    return (correct / answered).clamp(0.0, 1.0);
  }

  /// Thresholds are (questions answered, accuracy) pairs, checked from the
  /// top down. Both halves matter: volume alone rewards clicking through,
  /// accuracy alone would make a single lucky answer "mastered".
  MasteryLevel get level {
    if (answered <= 0) return MasteryLevel.notStarted;
    if (answered >= 40 && accuracy >= 0.9) return MasteryLevel.mastered;
    if (answered >= 20 && accuracy >= 0.7) return MasteryLevel.proficient;
    if (answered >= 10 && accuracy >= 0.5) return MasteryLevel.familiar;
    return MasteryLevel.attempted;
  }

  TopicProgress plus({required int answered, required int correct}) {
    return TopicProgress(
      answered: this.answered + answered,
      correct: this.correct + correct,
      subjectId: subjectId,
    );
  }

  Map<String, Object?> toMap() => {
    'answered': answered,
    'correct': correct,
    'subjectId': subjectId,
  };

  /// Coerces rather than throwing, for the same reason
  /// `firestore_parsing.dart` does: this runs inside provider mapping, and
  /// one malformed entry must not take down a whole course page.
  static TopicProgress fromMap(Object? raw) {
    if (raw is! Map) return none;
    int asCount(Object? v) {
      final n = v is num ? v.toInt() : 0;
      return n < 0 ? 0 : n;
    }

    final subject = raw['subjectId'];
    return TopicProgress(
      answered: asCount(raw['answered']),
      correct: asCount(raw['correct']),
      subjectId: subject is String ? subject : '',
    );
  }
}

/// Aggregate mastery over a set of topics, as a fraction in 0..1.
///
/// Empty input is 0, not 1: a module with no topics has not been mastered,
/// and returning 1 would paint a full ring on an empty card — which is
/// exactly what a planned-but-unwritten subject is.
double masteryFraction(Iterable<MasteryLevel> levels) {
  final list = levels.toList(growable: false);
  if (list.isEmpty) return 0;
  final earned = list.fold<int>(0, (sum, level) => sum + level.points);
  return earned / (list.length * MasteryLevel.maxPoints);
}

/// The single level that best describes a set of topics — used for a
/// module's own circle, above its topics'.
///
/// The *weakest* level any topic is at, so a module reads as finished only
/// when all of it is. One untouched topic keeps the module at
/// [MasteryLevel.notStarted] only if nothing else has been started; once
/// anything has, the module is at least [MasteryLevel.attempted].
MasteryLevel aggregateLevel(Iterable<MasteryLevel> levels) {
  final list = levels.toList(growable: false);
  if (list.isEmpty) return MasteryLevel.notStarted;

  var weakest = MasteryLevel.mastered;
  var anyStarted = false;
  for (final level in list) {
    if (level.isStarted) anyStarted = true;
    if (level.points < weakest.points) weakest = level;
  }
  if (!anyStarted) return MasteryLevel.notStarted;
  return weakest == MasteryLevel.notStarted ? MasteryLevel.attempted : weakest;
}
