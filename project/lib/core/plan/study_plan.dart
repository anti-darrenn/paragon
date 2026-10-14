/// The study plan's arithmetic: how much each topic matters, an estimated
/// grade from practice, and which topics are the shortest path up
/// (PLAN.md P7.2).
///
/// Pure — no Firestore, no widgets. Its inputs are already on the device:
/// each topic's `pastQuestionCount` (from the course outline, cached) and
/// the student's `progress/{uid}` counters. It costs no reads of its own.
///
/// **What this may and may not say.** It reads `progress` for display
/// only, as CLAUDE.md allows: private, and nothing competitive. The grade
/// is an *estimate from practice on objective questions*, shown as a range
/// until there is enough practice to narrow it, always beside
/// `kGradeEstimateNote` — never as a predicted result.
library;

import 'dart:math' as math;

import '../exam/waec_grade.dart';
import '../progress/mastery.dart';

/// One topic as the plan sees it.
class PlanTopic {
  const PlanTopic({
    required this.id,
    required this.name,
    required this.pastQuestions,
    this.progress = TopicProgress.none,
  });

  final String id;
  final String name;

  /// Real WAEC past questions on this topic (`pastQuestionCount`).
  final int pastQuestions;
  final TopicProgress progress;
}

/// Where the weights came from — the screen says which.
enum WeightBasis {
  /// Each topic's share of the subject's real WAEC past questions.
  pastPapers,

  /// No past questions in Paragon for this subject: every topic counts
  /// the same, and the screen says the plan follows the syllabus.
  syllabus,
}

/// Each topic's share of the subject (they sum to 1).
({Map<String, double> weights, WeightBasis basis}) topicWeights(
  List<PlanTopic> topics,
) {
  if (topics.isEmpty) return (weights: const {}, basis: WeightBasis.syllabus);
  final total = topics.fold<int>(0, (n, t) => n + math.max(0, t.pastQuestions));
  if (total == 0) {
    final w = 1 / topics.length;
    return (
      weights: {for (final t in topics) t.id: w},
      basis: WeightBasis.syllabus,
    );
  }
  return (
    weights: {
      for (final t in topics) t.id: math.max(0, t.pastQuestions) / total,
    },
    basis: WeightBasis.pastPapers,
  );
}

/// "about 1 in 25 WAEC questions" — or null for a topic too rare to say.
String? frequencyPhrase(double weight) {
  if (weight <= 0) return null;
  final n = (1 / weight).round();
  if (n > 200) return null;
  return n <= 1 ? 'most WAEC questions' : 'about 1 in $n WAEC questions';
}

/// A grade from practice: a range of percentages and the bands they fall
/// in. [isRange] until the student has answered [kNarrowAfter] questions
/// in the subject.
class GradeEstimate {
  const GradeEstimate({
    required this.lowPercent,
    required this.highPercent,
    required this.answered,
  });

  final double lowPercent;
  final double highPercent;
  final int answered;

  static const int kNarrowAfter = 50;

  bool get isRange => answered < kNarrowAfter;

  WaecGrade get low => waecGradeFor(lowPercent);
  WaecGrade get high => waecGradeFor(highPercent);

  double get midPercent => (lowPercent + highPercent) / 2;

  /// "C4" once narrow, "B3–C5" while a range ("C5" if both ends agree).
  String get label {
    if (!isRange) return waecGradeFor(midPercent).code;
    final hi = high.code, lo = low.code;
    return hi == lo ? hi : '$hi–$lo';
  }
}

/// Below this many answers the estimate is not shown at all.
const int kMinAnswersForEstimate = 20;

/// The estimate for one subject, or null with too little practice.
///
/// Each topic contributes its weight × how likely the student is to get
/// one of its questions right:
/// - practised: (correct + 1) / (answered + 2), give or take one standard
///   error — so ten answers are trusted less than a hundred;
/// - not practised: anywhere from a guess (25%, four options) to 75%,
///   which is what makes an early estimate a wide range rather than a
///   confident wrong number.
GradeEstimate? estimateGrade(List<PlanTopic> topics) {
  final answered = topics.fold<int>(0, (n, t) => n + t.progress.answered);
  if (answered < kMinAnswersForEstimate) return null;
  final w = topicWeights(topics).weights;
  var low = 0.0, high = 0.0;
  for (final t in topics) {
    final wt = w[t.id] ?? 0;
    final n = t.progress.answered;
    if (n <= 0) {
      low += wt * 0.25;
      high += wt * 0.75;
      continue;
    }
    final p = (t.progress.correct.clamp(0, n) + 1) / (n + 2);
    final se = math.sqrt(p * (1 - p) / (n + 2));
    low += wt * (p - se).clamp(0.0, 1.0);
    high += wt * (p + se).clamp(0.0, 1.0);
  }
  return GradeEstimate(
    lowPercent: low * 100,
    highPercent: high * 100,
    answered: answered,
  );
}

/// The topics worth the most marks per hour: weight × what is left to
/// learn there (1 − mastery). Proficient topics drop out. Highest first,
/// ties in course order.
List<PlanTopic> shortestPath(List<PlanTopic> topics, {int take = 5}) {
  final w = topicWeights(topics).weights;
  double gain(PlanTopic t) =>
      (w[t.id] ?? 0) * (1 - t.progress.level.ringFraction);
  final open = [
    for (final (i, t) in topics.indexed)
      if (!t.progress.level.isComplete) (i, t),
  ];
  open.sort((a, b) {
    final d = gain(b.$2).compareTo(gain(a.$2));
    return d != 0 ? d : a.$1.compareTo(b.$1);
  });
  return [for (final (_, t) in open.take(take)) t];
}

/// Whole weeks from [now] until [examDate], at least 0.
int weeksUntil(DateTime examDate, DateTime now) {
  final days = examDate.difference(now).inDays;
  return days <= 0 ? 0 : (days / 7).ceil();
}

/// How many not-yet-proficient topics to take on each week to cover them
/// all before the exam. Null with no exam date or no weeks left.
int? topicsPerWeek(List<PlanTopic> topics, int weeksLeft) {
  if (weeksLeft <= 0) return null;
  final left = topics.where((t) => !t.progress.level.isComplete).length;
  if (left == 0) return 0;
  return (left / weeksLeft).ceil();
}
