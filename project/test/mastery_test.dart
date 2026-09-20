import 'package:flutter_test/flutter_test.dart';
import 'package:paragon/core/progress/mastery.dart';
import 'package:paragon/core/repositories/progress_repository.dart';

/// The rings are the most visible claim the app makes about a student's
/// work, so the rules behind them are pinned here rather than left to the
/// widgets that draw them.
void main() {
  group('TopicProgress.level', () {
    test('nothing answered is not started', () {
      expect(const TopicProgress().level, MasteryLevel.notStarted);
      expect(TopicProgress.none.level, MasteryLevel.notStarted);
    });

    test('a single answer starts the topic but earns nothing else', () {
      const p = TopicProgress(answered: 1, correct: 1);
      expect(p.level, MasteryLevel.attempted);
      // The control that makes this test mean something: perfect accuracy
      // on one question must not shortcut to mastered.
      expect(p.accuracy, 1.0);
    });

    test('volume without accuracy stays attempted', () {
      // 100 answered, 40% right — more work than a proficient student has
      // done, and deliberately worth less.
      const p = TopicProgress(answered: 100, correct: 40);
      expect(p.level, MasteryLevel.attempted);
    });

    test('accuracy without volume stays attempted', () {
      const p = TopicProgress(answered: 9, correct: 9);
      expect(p.level, MasteryLevel.attempted);
    });

    test('familiar needs ten answered at half right', () {
      expect(
        const TopicProgress(answered: 10, correct: 5).level,
        MasteryLevel.familiar,
      );
      expect(
        const TopicProgress(answered: 10, correct: 4).level,
        MasteryLevel.attempted,
      );
    });

    test('proficient is one attentive session', () {
      // A drill session is 20 questions; 14 of 20 is the boundary.
      expect(
        const TopicProgress(answered: 20, correct: 14).level,
        MasteryLevel.proficient,
      );
      expect(
        const TopicProgress(answered: 20, correct: 13).level,
        MasteryLevel.familiar,
      );
    });

    test('mastered needs two sessions at near-perfect accuracy', () {
      expect(
        const TopicProgress(answered: 40, correct: 36).level,
        MasteryLevel.mastered,
      );
      expect(
        const TopicProgress(answered: 40, correct: 35).level,
        MasteryLevel.proficient,
      );
      expect(
        const TopicProgress(answered: 39, correct: 39).level,
        MasteryLevel.proficient,
      );
    });

    test('a corrupt document cannot report over 100% accuracy', () {
      const p = TopicProgress(answered: 2, correct: 50);
      expect(p.accuracy, 1.0);
    });
  });

  group('TopicProgress.fromMap', () {
    test('coerces rather than throwing, like firestore_parsing', () {
      expect(TopicProgress.fromMap(null).answered, 0);
      expect(TopicProgress.fromMap('nonsense').answered, 0);
      expect(TopicProgress.fromMap({'answered': 'x'}).answered, 0);
      expect(TopicProgress.fromMap({'answered': 4.0}).answered, 4);
      // Negative counters would drive the ring backwards.
      expect(TopicProgress.fromMap({'answered': -3}).answered, 0);
    });
  });

  group('masteryFraction', () {
    test('an empty set is zero, never full', () {
      // A planned subject has no topics; painting it as 100% mastered is
      // the one wrong answer that would look right.
      expect(masteryFraction(const []), 0);
    });

    test('all mastered is one, none started is zero', () {
      expect(masteryFraction(List.filled(5, MasteryLevel.mastered)), 1.0);
      expect(masteryFraction(List.filled(5, MasteryLevel.notStarted)), 0.0);
    });

    test('partial credit accrues level by level', () {
      // Two of four topics proficient (3 points each) out of 16 possible.
      final levels = [
        MasteryLevel.proficient,
        MasteryLevel.proficient,
        MasteryLevel.notStarted,
        MasteryLevel.notStarted,
      ];
      expect(masteryFraction(levels), 6 / 16);
    });
  });

  group('aggregateLevel', () {
    test('an empty module has not been started', () {
      expect(aggregateLevel(const []), MasteryLevel.notStarted);
    });

    test(
      'is the weakest topic, so a module finishes only when all of it does',
      () {
        expect(
          aggregateLevel([MasteryLevel.mastered, MasteryLevel.familiar]),
          MasteryLevel.familiar,
        );
      },
    );

    test('one started topic lifts the module off not-started', () {
      expect(
        aggregateLevel([MasteryLevel.mastered, MasteryLevel.notStarted]),
        MasteryLevel.attempted,
      );
    });

    test('nothing started stays not started', () {
      expect(
        aggregateLevel([MasteryLevel.notStarted, MasteryLevel.notStarted]),
        MasteryLevel.notStarted,
      );
    });
  });

  group('UserProgress.fromDocument', () {
    test('a missing or malformed document is empty, not an error', () {
      expect(UserProgress.fromDocument(null).isEmpty, isTrue);
      expect(UserProgress.fromDocument({}).isEmpty, isTrue);
      expect(UserProgress.fromDocument({'topics': 'nope'}).isEmpty, isTrue);
    });

    test('an unknown topic reads as not started', () {
      final progress = UserProgress.fromDocument({
        'topics': {
          't1': {'answered': 20, 'correct': 18},
        },
      });
      expect(progress.levelFor('t1'), MasteryLevel.proficient);
      expect(progress.levelFor('never-practised'), MasteryLevel.notStarted);
    });

    test('counts only topics actually started', () {
      final progress = UserProgress.fromDocument({
        'topics': {
          't1': {'answered': 20, 'correct': 18},
          't2': {'answered': 0, 'correct': 0},
        },
      });
      expect(progress.startedTopicCount, 1);
    });
  });

  group('UserProgress.levelsForSubject', () {
    UserProgress build() => UserProgress.fromDocument({
      'topics': {
        'a': {'answered': 40, 'correct': 40, 'subjectId': 'physics'},
        'b': {'answered': 20, 'correct': 15, 'subjectId': 'physics'},
        'c': {'answered': 20, 'correct': 18, 'subjectId': 'maths'},
        'd': {'answered': 0, 'correct': 0, 'subjectId': 'physics'},
      },
    });

    test('pads untouched topics so the ring is not flattering', () {
      // Two started topics out of a subject that has ten. Averaging only
      // the started ones would report a student who has mastered their one
      // practised topic as having mastered the subject.
      final levels = build().levelsForSubject('physics', outOf: 10);
      expect(levels.length, 10);
      expect(levels.where((l) => l == MasteryLevel.notStarted).length, 8);
      expect(masteryFraction(levels), (4 + 3) / 40);
    });

    test('counts only its own subject', () {
      final levels = build().levelsForSubject('maths', outOf: 4);
      expect(levels.where((l) => l.isStarted).length, 1);
    });

    test('an unknown topic count yields no ring at all', () {
      // Zero means "not known yet" — a subject seeded before topicCount
      // existed. The caller suppresses the ring rather than drawing an
      // empty one.
      expect(build().levelsForSubject('physics', outOf: 0), isEmpty);
      expect(build().levelsForSubject('', outOf: 10), isEmpty);
    });

    test('cannot report over 100% when stored topics exceed the count', () {
      // Possible for a moment after topics are removed, before the nightly
      // recount catches up.
      final levels = build().levelsForSubject('physics', outOf: 1);
      expect(levels.length, 1);
      expect(masteryFraction(levels), lessThanOrEqualTo(1.0));
    });
  });

  group('MasteryLevel', () {
    test('ring fractions rise with the level and end at full', () {
      var previous = -1.0;
      for (final level in MasteryLevel.values) {
        expect(level.ringFraction, greaterThan(previous));
        previous = level.ringFraction;
      }
      expect(MasteryLevel.notStarted.ringFraction, 0.0);
      expect(MasteryLevel.mastered.ringFraction, 1.0);
    });

    test('the tick appears at proficient, not before', () {
      expect(MasteryLevel.familiar.isComplete, isFalse);
      expect(MasteryLevel.proficient.isComplete, isTrue);
      expect(MasteryLevel.mastered.isComplete, isTrue);
    });
  });
}
