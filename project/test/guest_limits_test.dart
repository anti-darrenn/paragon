import 'package:flutter_test/flutter_test.dart';
import 'package:paragon/core/auth/feature_access.dart';
import 'package:paragon/core/auth/guest_limits.dart';

/// The guest policy table (PLAN.md P1.4.4, adopted 2026-10-14) and the
/// words guests are shown. Every guest gate asks `canUse`; these tests pin
/// the table so a change to it is a deliberate, visible edit.
void main() {
  group('canUse', () {
    test('a signed-in student may use everything', () {
      for (final f in Feature.values) {
        expect(canUse(f, isGuest: false), isTrue, reason: f.name);
      }
    });

    test('a guest may drill, read, and sit untimed WAEC in any subject', () {
      for (final f in [
        Feature.readLessons,
        Feature.drill,
        Feature.waecUntimed,
        Feature.mistakesNotebook,
        Feature.reviewCards,
        Feature.examHistory,
        Feature.offlinePacks,
      ]) {
        expect(canUse(f, isGuest: true), isTrue, reason: f.name);
      }
    });

    test('control: timed exams and the study plan ask a guest to sign up', () {
      expect(canUse(Feature.waecTimed, isGuest: true), isFalse);
      expect(canUse(Feature.studyPlan, isGuest: true), isFalse);
    });

    test('every feature has a row', () {
      expect(kFeaturePolicy.keys.toSet(), Feature.values.toSet());
    });
  });

  group('GuestLimits.locks', () {
    test('no WAEC subject is locked, for guests or anyone', () {
      for (final name in ['Physics', 'Mathematics', 'Government']) {
        expect(GuestLimits.locks(isGuest: false, subjectName: name), isFalse);
        expect(GuestLimits.locks(isGuest: true, subjectName: name), isFalse);
      }
    });
  });

  group('messages', () {
    // A guest's progress survives a closed tab (checked on the live
    // site), so the message must not claim otherwise — it says where the
    // progress lives, how long it lasts, and how to keep it.
    test('the progress message is honest about where progress lives', () {
      final m = GuestLimits.progressNotKeptMessage.toLowerCase();
      expect(m, contains('this browser'));
      expect(m, contains('30 days'));
      expect(m, contains('account'));
      expect(m, isNot(contains('not saved')));
    });
  });
}
