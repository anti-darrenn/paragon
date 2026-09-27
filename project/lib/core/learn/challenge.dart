/// Unit tests and the course challenge, as pure rules.
///
/// Both mix questions from several topics and, like the topic test, give
/// no feedback until the end. They differ in what they may do to the drill
/// gate:
///
/// - A **unit test** draws [kUnitTestPerTopic] questions per topic. A topic
///   with at least [kUnlockMinQuestions] answered at the topic-test pass
///   mark counts as that topic's test passed — Khan's "skip ahead", chosen
///   deliberately by the owner.
/// - The **course challenge** spreads [kCourseChallengeSize] questions
///   across the whole subject, weighted to the weakest topics. It has too
///   few questions per topic to be evidence of any one topic, so it never
///   unlocks anything.
///
/// Either way, answers feed the mastery counters **only for topics whose
/// drill is open** once the challenge is marked. Mastery at proficient
/// opens drill by itself, so counting answers on a locked topic would be
/// a second, quieter way around the gate.
library;

import 'topic_test.dart';

enum ChallengeKind { unitTest, courseChallenge }

const int kUnitTestPerTopic = 4;
const int kUnitTestMaxQuestions = 40;
const int kCourseChallengeSize = 30;

/// The fewest questions from one topic that can open its drill.
const int kUnlockMinQuestions = 4;

/// A topic that can be drawn from, with how far the student has got in it
/// (mastery points; lower is weaker).
typedef ChallengeTopic = ({String id, int points});

/// How many questions to draw from one topic.
typedef TopicDraw = ({String topicId, int count});

/// The unit test for [topics] (in course order): [kUnitTestPerTopic] from
/// each, at most [kUnitTestMaxQuestions] in all. A module with more topics
/// than fit takes the least-mastered ones. The result keeps course order.
List<TopicDraw> planUnitTest(List<ChallengeTopic> topics) {
  const maxTopics = kUnitTestMaxQuestions ~/ kUnitTestPerTopic;
  final chosen = _weakest(topics, maxTopics);
  return [
    for (final t in topics)
      if (chosen.contains(t.id)) (topicId: t.id, count: kUnitTestPerTopic),
  ];
}

/// The course challenge for [topics] (in course order): [size] questions,
/// one per topic from the weakest up, going round again when there are
/// fewer topics than questions. The result keeps course order.
List<TopicDraw> planCourseChallenge(
  List<ChallengeTopic> topics, {
  int size = kCourseChallengeSize,
}) {
  if (topics.isEmpty || size <= 0) return const [];
  final order = _byWeakness(topics);
  final counts = <String, int>{};
  for (var i = 0; i < size; i++) {
    final id = order[i % order.length].id;
    counts[id] = (counts[id] ?? 0) + 1;
  }
  return [
    for (final t in topics)
      if (counts[t.id] case final n?) (topicId: t.id, count: n),
  ];
}

/// Weakest first; ties keep course order.
List<ChallengeTopic> _byWeakness(List<ChallengeTopic> topics) {
  final indexed = [for (var i = 0; i < topics.length; i++) (i, topics[i])];
  indexed.sort((a, b) {
    final byPoints = a.$2.points.compareTo(b.$2.points);
    return byPoints != 0 ? byPoints : a.$1.compareTo(b.$1);
  });
  return [for (final e in indexed) e.$2];
}

Set<String> _weakest(List<ChallengeTopic> topics, int n) => {
  for (final t in _byWeakness(topics).take(n)) t.id,
};

/// One marked answer.
typedef ChallengeAnswer = ({String topicId, bool isCorrect});

/// Right and total per topic.
typedef TopicTally = ({int correct, int total});

Map<String, TopicTally> tallyByTopic(Iterable<ChallengeAnswer> answers) {
  final out = <String, TopicTally>{};
  for (final a in answers) {
    final t = out[a.topicId] ?? (correct: 0, total: 0);
    out[a.topicId] = (
      correct: t.correct + (a.isCorrect ? 1 : 0),
      total: t.total + 1,
    );
  }
  return out;
}

/// The topics whose drill this challenge opens. Only a unit test opens
/// anything, and only on [kUnlockMinQuestions] or more at the pass mark.
Set<String> topicsUnlockedBy(
  ChallengeKind kind,
  Map<String, TopicTally> tallies,
) {
  if (kind != ChallengeKind.unitTest) return const {};
  return {
    for (final e in tallies.entries)
      if (e.value.total >= kUnlockMinQuestions &&
          topicTestPassed(correct: e.value.correct, total: e.value.total))
        e.key,
  };
}

/// The topics whose answers may be added to the mastery counters: those
/// already open, and those this challenge has just opened. Never a topic
/// that is still locked.
Set<String> topicsFeedingMastery(
  Map<String, TopicTally> tallies, {
  required Set<String> openBefore,
  required Set<String> unlocked,
}) => {
  for (final id in tallies.keys)
    if (openBefore.contains(id) || unlocked.contains(id)) id,
};
