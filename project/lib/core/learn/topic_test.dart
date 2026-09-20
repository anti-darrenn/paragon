/// The topic test and the drill gate it opens — the pure model.
///
/// No Firestore and no widgets, for the same reason `mastery.dart` has
/// none: the screen that scores an attempt, the repository that stores it,
/// the row that draws a padlock and the tests all have to reason about
/// "has this student unlocked drill here" in exactly one way. A second
/// opinion about what 80% means is a student who passes on one screen and
/// is locked on another.
///
/// ## What this can and cannot enforce
///
/// The gate is **client-enforced, and cannot be anything else.** Firestore
/// rules cannot verify a test score — they see one document write, not the
/// ten answers behind it — so whatever stores `passed: true` is written by
/// the client, and a determined student can write it directly. The rules
/// constrain the *shape* (see `firestore.rules`), which is the same
/// posture the streak rules took and with the same honest limit.
///
/// That is acceptable here and would not be everywhere: drill is practice,
/// not a reward, nothing competitive reads this, and a student who cheats
/// the gate has cheated themselves into some questions. If anything of
/// value is ever put behind it, this needs a server.
library;

import '../progress/mastery.dart';

/// One topic's test history.
class TopicTestRecord {
  const TopicTestRecord({
    this.passed = false,
    this.bestScore = 0,
    this.attempts = 0,
    this.subjectId = '',
  });

  /// Whether the student has ever scored [kTopicTestPassPercent] or above.
  ///
  /// Sticky. A retake that goes badly does not take proficiency away —
  /// retakes are unlimited and a student practising is not a student
  /// regressing, so re-locking drill after a bad day would punish exactly
  /// the behaviour the feature wants.
  final bool passed;

  /// Best percentage ever scored, 0-100.
  final int bestScore;

  /// How many times the test has been taken. Counts every attempt, passes
  /// included.
  final int attempts;

  /// Stamped at write time so the document can be grouped by subject
  /// without loading a course outline — the same reason
  /// `TopicProgress.subjectId` exists.
  final String subjectId;

  static const TopicTestRecord none = TopicTestRecord();

  bool get isStarted => attempts > 0;

  /// Coerces rather than throwing, like `TopicProgress.fromMap` — this
  /// runs inside provider mapping, where one malformed entry must not take
  /// down the whole screen.
  static TopicTestRecord fromMap(Object? raw) {
    if (raw is! Map) return none;

    int count(Object? v) {
      final n = v is num ? v.toInt() : 0;
      return n < 0 ? 0 : n;
    }

    final best = count(raw['bestScore']).clamp(0, 100);
    return TopicTestRecord(
      // A stored `passed` that disagrees with a stored `bestScore` is
      // resolved in favour of the score, so a hand-edited or
      // partially-written document cannot claim a pass it never earned.
      passed: raw['passed'] == true && best >= kTopicTestPassPercent,
      bestScore: best,
      attempts: count(raw['attempts']),
      subjectId: raw['subjectId'] is String ? raw['subjectId'] as String : '',
    );
  }
}

/// Every topic a student has attempted a test on, keyed by topic id.
class TopicTestProgress {
  const TopicTestProgress(this._topics);

  final Map<String, TopicTestRecord> _topics;

  static const TopicTestProgress empty = TopicTestProgress({});

  TopicTestRecord forTopic(String topicId) =>
      _topics[topicId] ?? TopicTestRecord.none;

  bool isEmpty() => _topics.isEmpty;

  int get passedCount => _topics.values.where((r) => r.passed).length;

  static TopicTestProgress fromDocument(Map<String, dynamic>? data) {
    final raw = data?['topics'];
    if (raw is! Map) return empty;
    return TopicTestProgress({
      for (final entry in raw.entries)
        if (entry.key is String)
          entry.key as String: TopicTestRecord.fromMap(entry.value),
    });
  }
}

/// The pass mark, as a whole percentage.
///
/// Whole, not a ratio, because it is also the number shown to students
/// ("You need 80%") and the two must not be able to disagree. Scores are
/// rounded to an integer percentage before comparison, so 8 of 10 is
/// exactly 80 and passes.
const int kTopicTestPassPercent = 80;

/// [correct] out of [total] as a whole percentage, 0-100.
///
/// Rounded rather than truncated: 7 of 9 is 77.8%, and truncating to 77
/// versus rounding to 78 decides nothing at this threshold, but truncation
/// would make 4 of 5 (80%) safe and 12 of 15 (80%) safe while quietly
/// failing anything that lands a hair under on binary floating point.
int topicTestScore({required int correct, required int total}) {
  if (total <= 0) return 0;
  final clamped = correct.clamp(0, total);
  return ((clamped / total) * 100).round().clamp(0, 100);
}

/// Whether [correct] of [total] passes.
bool topicTestPassed({required int correct, required int total}) {
  if (total <= 0) return false;
  return topicTestScore(correct: correct, total: total) >= kTopicTestPassPercent;
}

// ─── The drill gate ───────────────────────────────────────────────────

/// Why a student can or cannot drill a topic.
enum DrillAccess {
  /// Open. Either the test is passed, or drill practice already carried
  /// this topic to proficient before the gate existed.
  allowed,

  /// Signed out entirely. Nothing to do here but sign in.
  signedOut,

  /// A guest. Drill needs a real account, and no test result changes that.
  guestBlocked,

  /// Signed in, but the topic test has not been passed yet.
  testRequired;

  bool get isAllowed => this == DrillAccess.allowed;
}

/// Decides whether this student may drill this topic.
///
/// Order matters, and it is the order of the product rules rather than
/// convenience: **guests are refused before proficiency is even
/// considered**, because a guest who has somehow passed a test still
/// cannot drill, and telling them "take the test" would be a dead end —
/// their result dies with the session anyway.
///
/// ## Grandfathering
///
/// [drillMastery] at proficient or above opens the gate on its own. Every
/// student who was drilling before this shipped would otherwise find every
/// topic locked overnight, including topics they had already mastered —
/// a feature that takes practice away from the people using it most.
///
/// This is the one place `progress/{uid}` affects *access* rather than
/// display, and the tension is real: CLAUDE.md keeps that document
/// display-only and recomputable. What keeps it honest is that
/// grandfathering is **one-way — it can only ever grant access, never
/// withhold it.** A missing, empty or stale progress document costs a
/// student nothing more than taking the test they were going to take
/// anyway, so nothing here depends on that cache being correct, present,
/// or trustworthy. Nothing competitive reads it, and nothing here makes it
/// worth forging: the prize is a practice screen.
DrillAccess drillAccessFor({
  required bool isSignedIn,
  required bool isGuest,
  required TopicTestRecord testRecord,
  required MasteryLevel drillMastery,
}) {
  if (!isSignedIn) return DrillAccess.signedOut;
  if (isGuest) return DrillAccess.guestBlocked;
  if (testRecord.passed) return DrillAccess.allowed;
  if (drillMastery.isComplete) return DrillAccess.allowed;
  return DrillAccess.testRequired;
}
