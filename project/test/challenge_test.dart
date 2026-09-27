import 'package:flutter_test/flutter_test.dart';
import 'package:paragon/core/learn/challenge.dart';
import 'package:paragon/core/learn/topic_test.dart';
import 'package:paragon/core/progress/mastery.dart';

List<ChallengeTopic> _topics(List<int> points) => [
  for (var i = 0; i < points.length; i++) (id: 't$i', points: points[i]),
];

void main() {
  group('planUnitTest', () {
    test('four from each topic, in course order', () {
      final plan = planUnitTest(_topics([3, 0, 1]));
      expect([for (final d in plan) d.topicId], ['t0', 't1', 't2']);
      expect(plan.every((d) => d.count == kUnitTestPerTopic), isTrue);
    });

    test('a big module keeps the ten least mastered, still in order', () {
      // t0..t11; t0 and t1 are the most mastered and are left out
      final plan = planUnitTest(_topics([9, 8, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]));
      expect(plan, hasLength(10));
      expect(plan.map((d) => d.topicId), isNot(contains('t0')));
      expect(plan.map((d) => d.topicId), isNot(contains('t1')));
      expect(plan.first.topicId, 't2');
      final total = plan.fold(0, (s, d) => s + d.count);
      expect(total, kUnitTestMaxQuestions);
    });
  });

  group('planCourseChallenge', () {
    test('one each from the weakest when topics outnumber questions', () {
      final plan = planCourseChallenge(_topics([5, 0, 2, 1]), size: 2);
      expect({for (final d in plan) d.topicId: d.count}, {'t1': 1, 't3': 1});
    });

    test('goes round again, weakest first, when topics are few', () {
      final plan = planCourseChallenge(_topics([2, 0]), size: 5);
      expect({for (final d in plan) d.topicId: d.count}, {'t0': 2, 't1': 3});
    });

    test('nothing to draw from gives an empty plan', () {
      expect(planCourseChallenge(const []), isEmpty);
    });
  });

  group('unlocking', () {
    Map<String, TopicTally> tally(List<(String, bool)> answers) => tallyByTopic(
      [for (final a in answers) (topicId: a.$1, isCorrect: a.$2)],
    );

    test('a unit test opens a topic at 4 of 4 and at 4 of 5', () {
      final t = tally([
        ('a', true),
        ('a', true),
        ('a', true),
        ('a', true),
        ('b', true),
        ('b', true),
        ('b', true),
        ('b', true),
        ('b', false),
      ]);
      expect(topicsUnlockedBy(ChallengeKind.unitTest, t), {'a', 'b'});
    });

    test('CONTROL: 3 of 4 does not, nor 3 of 3 (too few questions)', () {
      final t = tally([
        ('a', true),
        ('a', true),
        ('a', true),
        ('a', false),
        ('b', true),
        ('b', true),
        ('b', true),
      ]);
      expect(topicsUnlockedBy(ChallengeKind.unitTest, t), isEmpty);
    });

    test('the course challenge never unlocks, even when perfect', () {
      final t = tally([('a', true), ('a', true), ('a', true), ('a', true)]);
      expect(topicsUnlockedBy(ChallengeKind.courseChallenge, t), isEmpty);
    });

    test('mastery is fed only for topics open afterwards', () {
      final t = tally([('open', true), ('new', true), ('locked', true)]);
      expect(topicsFeedingMastery(t, openBefore: {'open'}, unlocked: {'new'}), {
        'open',
        'new',
      });
    });

    test('a pass written by a unit test opens drill through the one gate', () {
      // what recordChallengePass stores for a 4-of-4 topic
      final record = TopicTestRecord.fromMap({
        'passed': true,
        'bestScore': 100,
        'passedVia': 'unit_test',
      });
      expect(
        drillAccessFor(
          isSignedIn: true,
          isGuest: false,
          testRecord: record,
          drillMastery: MasteryLevel.notStarted,
        ),
        DrillAccess.allowed,
      );
      // control: without the pass, the same student is still gated
      expect(
        drillAccessFor(
          isSignedIn: true,
          isGuest: false,
          testRecord: TopicTestRecord.fromMap(const {}),
          drillMastery: MasteryLevel.notStarted,
        ),
        DrillAccess.testRequired,
      );
    });
  });
}
