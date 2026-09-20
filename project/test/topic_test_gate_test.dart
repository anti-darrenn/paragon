// The topic test and the drill gate.
//
// The gate is the part of this feature that can hurt someone: get it wrong
// in one direction and every existing student loses access to practice
// they already earned; get it wrong in the other and it gates nothing.
// Both directions are pinned here.
//
// The control group at the bottom is what stops this suite going vacuous.
// A `drillAccessFor` that simply returned `allowed` would pass every
// "can drill" test above it while gating nothing at all.

import 'package:flutter_test/flutter_test.dart';
import 'package:paragon/core/learn/topic_test.dart';
import 'package:paragon/core/progress/mastery.dart';

void main() {
  group('topicTestScore', () {
    test('scores the obvious cases', () {
      expect(topicTestScore(correct: 8, total: 10), 80);
      expect(topicTestScore(correct: 10, total: 10), 100);
      expect(topicTestScore(correct: 0, total: 10), 0);
      expect(topicTestScore(correct: 4, total: 5), 80);
    });

    test('rounds rather than truncates', () {
      // 7/9 is 77.8%.
      expect(topicTestScore(correct: 7, total: 9), 78);
      // 2/3 is 66.7%.
      expect(topicTestScore(correct: 2, total: 3), 67);
    });

    test('a test with no questions scores zero, not a crash', () {
      expect(topicTestScore(correct: 0, total: 0), 0);
      expect(topicTestScore(correct: 5, total: 0), 0);
    });

    test('impossible input is clamped rather than believed', () {
      // More correct than asked is not 150%.
      expect(topicTestScore(correct: 15, total: 10), 100);
      expect(topicTestScore(correct: -3, total: 10), 0);
    });
  });

  group('topicTestPassed — the 80% line', () {
    test('exactly 80% passes', () {
      expect(topicTestPassed(correct: 8, total: 10), isTrue);
      expect(topicTestPassed(correct: 4, total: 5), isTrue);
      expect(topicTestPassed(correct: 12, total: 15), isTrue);
    });

    test('just under 80% fails', () {
      expect(topicTestPassed(correct: 7, total: 10), isFalse);
      expect(topicTestPassed(correct: 3, total: 4), isFalse);
    });

    test('an empty test can never be passed', () {
      // 0 of 0 must not read as 100% — that would unlock drill on a topic
      // with no answerable questions at all.
      expect(topicTestPassed(correct: 0, total: 0), isFalse);
    });

    test('the pass mark shown to students is the one that is enforced', () {
      expect(kTopicTestPassPercent, 80);
    });
  });

  group('TopicTestRecord.fromMap', () {
    test('reads a well-formed entry', () {
      final r = TopicTestRecord.fromMap({
        'passed': true,
        'bestScore': 90,
        'attempts': 3,
        'subjectId': 's1',
      });
      expect(r.passed, isTrue);
      expect(r.bestScore, 90);
      expect(r.attempts, 3);
      expect(r.subjectId, 's1');
    });

    test('a passed flag that the score does not support is not believed', () {
      // A hand-edited or half-written document claiming a pass it never
      // earned. The score is the evidence; the flag is not.
      final r = TopicTestRecord.fromMap({'passed': true, 'bestScore': 40});
      expect(r.passed, isFalse);
    });

    test('never throws on malformed input', () {
      for (final raw in [
        null,
        'not a map',
        42,
        <String, dynamic>{},
        {'passed': 'yes', 'bestScore': 'lots', 'attempts': -4},
        {'bestScore': 500, 'subjectId': 99},
      ]) {
        expect(() => TopicTestRecord.fromMap(raw), returnsNormally,
            reason: 'from $raw');
      }
    });

    test('out-of-range values are clamped, not stored as given', () {
      expect(TopicTestRecord.fromMap({'bestScore': 500}).bestScore, 100);
      expect(TopicTestRecord.fromMap({'attempts': -4}).attempts, 0);
    });

    test('a missing entry reads as never attempted', () {
      const none = TopicTestRecord.none;
      expect(none.passed, isFalse);
      expect(none.isStarted, isFalse);
      expect(none.attempts, 0);
    });
  });

  group('TopicTestProgress.fromDocument', () {
    test('reads the stored shape', () {
      final p = TopicTestProgress.fromDocument({
        'userId': 'u1',
        'topics': {
          't1': {'passed': true, 'bestScore': 90, 'attempts': 1},
          't2': {'passed': false, 'bestScore': 30, 'attempts': 2},
        },
      });
      expect(p.forTopic('t1').passed, isTrue);
      expect(p.forTopic('t2').passed, isFalse);
      expect(p.passedCount, 1);
    });

    test('an unknown topic reads as never attempted, not an error', () {
      final p = TopicTestProgress.fromDocument({'topics': {}});
      expect(p.forTopic('nope').passed, isFalse);
    });

    test('a missing or malformed document is empty, never a throw', () {
      for (final data in <Map<String, dynamic>?>[
        null,
        {},
        {'topics': 'not a map'},
        {'topics': 42},
      ]) {
        expect(() => TopicTestProgress.fromDocument(data), returnsNormally);
        expect(TopicTestProgress.fromDocument(data).isEmpty(), isTrue);
      }
    });
  });

  group('drillAccessFor — the gate', () {
    DrillAccess access({
      bool signedIn = true,
      bool guest = false,
      bool passed = false,
      int bestScore = 0,
      MasteryLevel mastery = MasteryLevel.notStarted,
    }) {
      return drillAccessFor(
        isSignedIn: signedIn,
        isGuest: guest,
        testRecord: TopicTestRecord(passed: passed, bestScore: bestScore),
        drillMastery: mastery,
      );
    }

    test('a signed-out visitor is sent to sign in', () {
      expect(access(signedIn: false), DrillAccess.signedOut);
    });

    test('a guest is blocked whatever else is true', () {
      // The ordering that matters: a guest who has somehow passed the test,
      // or who carries proficient mastery, is still blocked — and is told
      // to get an account rather than to take a test they have passed.
      expect(access(guest: true), DrillAccess.guestBlocked);
      expect(
        access(guest: true, passed: true, bestScore: 100),
        DrillAccess.guestBlocked,
      );
      expect(
        access(guest: true, mastery: MasteryLevel.mastered),
        DrillAccess.guestBlocked,
      );
    });

    test('a signed-in student who has not passed is asked to take the test', () {
      expect(access(), DrillAccess.testRequired);
      // A failed attempt is still not a pass.
      expect(access(bestScore: 70), DrillAccess.testRequired);
    });

    test('passing the test opens the gate', () {
      expect(access(passed: true, bestScore: 80), DrillAccess.allowed);
    });

    group('grandfathering', () {
      test('proficient drill mastery opens the gate without a test', () {
        // The whole point: students who were drilling before the gate
        // existed must not be locked out of topics they already know.
        expect(
          access(mastery: MasteryLevel.proficient),
          DrillAccess.allowed,
        );
        expect(access(mastery: MasteryLevel.mastered), DrillAccess.allowed);
      });

      test('partial mastery does not', () {
        for (final level in [
          MasteryLevel.notStarted,
          MasteryLevel.attempted,
          MasteryLevel.familiar,
        ]) {
          expect(
            access(mastery: level),
            DrillAccess.testRequired,
            reason: '$level should not grandfather',
          );
        }
      });

      test('it only ever grants access, never withholds it', () {
        // The property that keeps `progress/{uid}` from becoming
        // load-bearing: a student who has passed the test is allowed
        // regardless of what the mastery cache says, so a missing, stale
        // or empty progress document can never cost anyone access.
        for (final level in MasteryLevel.values) {
          expect(
            access(passed: true, bestScore: 85, mastery: level),
            DrillAccess.allowed,
            reason: 'passed must win over mastery $level',
          );
        }
      });
    });
  });

  // ── Control ──────────────────────────────────────────────────────────
  //
  // Proves the gate group above is not vacuous. The two most likely ways
  // for this feature to silently stop working are a gate that always
  // allows and one that never does; both would leave most of the suite
  // above green on their own.
  group('control — the gate really does distinguish cases', () {
    test('it returns more than one outcome across realistic inputs', () {
      final outcomes = {
        drillAccessFor(
          isSignedIn: false,
          isGuest: false,
          testRecord: TopicTestRecord.none,
          drillMastery: MasteryLevel.notStarted,
        ),
        drillAccessFor(
          isSignedIn: true,
          isGuest: true,
          testRecord: TopicTestRecord.none,
          drillMastery: MasteryLevel.notStarted,
        ),
        drillAccessFor(
          isSignedIn: true,
          isGuest: false,
          testRecord: TopicTestRecord.none,
          drillMastery: MasteryLevel.notStarted,
        ),
        drillAccessFor(
          isSignedIn: true,
          isGuest: false,
          testRecord: const TopicTestRecord(passed: true, bestScore: 90),
          drillMastery: MasteryLevel.notStarted,
        ),
      };
      expect(outcomes.length, 4, reason: 'every branch must be reachable');
    });

    test('the default state of a new student is locked', () {
      // If this ever passes as `allowed`, the gate is open to everyone and
      // every other test here is measuring nothing.
      expect(
        drillAccessFor(
          isSignedIn: true,
          isGuest: false,
          testRecord: TopicTestRecord.none,
          drillMastery: MasteryLevel.notStarted,
        ),
        DrillAccess.testRequired,
      );
    });
  });
}
