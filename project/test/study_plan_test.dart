import 'package:flutter_test/flutter_test.dart';
import 'package:paragon/core/plan/study_plan.dart';
import 'package:paragon/core/plan/weekly_goal.dart';
import 'package:paragon/core/progress/mastery.dart';

PlanTopic t(String id, int past, {int answered = 0, int correct = 0}) =>
    PlanTopic(
      id: id,
      name: id,
      pastQuestions: past,
      progress: TopicProgress(answered: answered, correct: correct),
    );

void main() {
  group('topic weights', () {
    test('a topic weighs its share of the past questions', () {
      final w = topicWeights([t('a', 30), t('b', 10), t('c', 0)]);
      expect(w.basis, WeightBasis.pastPapers);
      expect(w.weights['a'], 0.75);
      expect(w.weights['b'], 0.25);
      expect(w.weights['c'], 0);
    });

    test('control: with no past questions, every topic counts the same, '
        'and the plan says it follows the syllabus', () {
      final w = topicWeights([t('a', 0), t('b', 0)]);
      expect(w.basis, WeightBasis.syllabus);
      expect(w.weights.values, everyElement(0.5));
    });

    test('frequency phrase', () {
      expect(frequencyPhrase(0.04), 'about 1 in 25 WAEC questions');
      expect(frequencyPhrase(0), isNull);
      expect(frequencyPhrase(0.001), isNull); // too rare to say
    });
  });

  group('grade estimate', () {
    test('nothing below the minimum practice', () {
      expect(estimateGrade([t('a', 10, answered: 19, correct: 19)]), isNull);
    });

    test('little practice is a wide range, never a confident grade', () {
      final e = estimateGrade([
        t('a', 50, answered: 20, correct: 18),
        t('b', 50), // untouched: anywhere from a guess to 75%
      ])!;
      expect(e.isRange, isTrue);
      expect(e.highPercent - e.lowPercent, greaterThan(20));
      expect(e.label, contains('–'));
    });

    test('a lot of good practice everywhere narrows to one high grade', () {
      final e = estimateGrade([
        t('a', 50, answered: 200, correct: 190),
        t('b', 50, answered: 200, correct: 186),
      ])!;
      expect(e.isRange, isFalse);
      expect(e.label, 'A1');
    });

    test('control: weak practice estimates a low grade, so the estimate '
        'is reading the answers', () {
      final e = estimateGrade([
        t('a', 50, answered: 200, correct: 60),
        t('b', 50, answered: 200, correct: 50),
      ])!;
      expect(e.label, 'F9');
    });

    test('a topic that matters more moves the estimate more', () {
      final heavyStrong = estimateGrade([
        t('a', 90, answered: 100, correct: 95),
        t('b', 10, answered: 100, correct: 20),
      ])!;
      final heavyWeak = estimateGrade([
        t('a', 90, answered: 100, correct: 20),
        t('b', 10, answered: 100, correct: 95),
      ])!;
      expect(heavyStrong.midPercent, greaterThan(heavyWeak.midPercent));
    });
  });

  group('shortest path', () {
    test('ranks by weight × what is left; proficient topics drop out', () {
      final path = shortestPath([
        t('rare', 2),
        t('common', 40),
        t('done', 40, answered: 40, correct: 38), // mastered
        t('half', 40, answered: 12, correct: 8), // familiar
      ]);
      expect(path.map((p) => p.id), ['common', 'half', 'rare']);
    });

    test('ties keep course order', () {
      final path = shortestPath([t('x', 0), t('y', 0), t('z', 0)]);
      expect(path.map((p) => p.id), ['x', 'y', 'z']);
    });

    test('weeks and topics a week', () {
      final now = DateTime(2026, 10, 14);
      expect(weeksUntil(DateTime(2027, 5, 3), now), 29);
      expect(weeksUntil(DateTime(2026, 10, 1), now), 0);
      final topics = [for (var i = 0; i < 10; i++) t('t$i', 1)];
      expect(topicsPerWeek(topics, 4), 3);
      expect(topicsPerWeek(topics, 0), isNull);
    });
  });

  group('weekly goal', () {
    test('the week starts Monday 00:00 in Lagos, whatever the device zone', () {
      // Sunday 23:30 UTC is already Monday 00:30 in Lagos.
      expect(
        weekStartLagos(DateTime.utc(2026, 10, 18, 23, 30)),
        DateTime.utc(2026, 10, 18, 23),
      );
      // Control: Sunday 22:30 UTC is still Sunday in Lagos — last week.
      expect(
        weekStartLagos(DateTime.utc(2026, 10, 18, 22, 30)),
        DateTime.utc(2026, 10, 11, 23),
      );
    });

    test('progress toward the goal', () {
      const p = WeeklyGoalProgress(goal: 100, done: 40);
      expect((p.fraction, p.met, p.left), (0.4, false, 60));
      const done = WeeklyGoalProgress(goal: 100, done: 130);
      expect((done.fraction, done.met, done.left), (1.0, true, 0));
      expect(kWeeklyGoals, contains(kDefaultWeeklyGoal));
    });
  });
}
